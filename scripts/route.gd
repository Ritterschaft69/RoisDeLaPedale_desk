class_name CyclingRoute
extends RefCounted

var data: Dictionary
var points: Array
var source_points: Array
var geography: Dictionary = {}
var source_length_m := 0.0
var coordinates := PackedFloat64Array()
var length_m: float
var ascent_m: float
var curve := PackedVector3Array()
var spacing := 2.0

var start_m := 0.0 # Explicit playable start; source samples stay intact.

func _init(path: String = "res://assets/routes/saint_die.json", use_geography: bool = true) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	points = data.points
	source_points = data.points
	length_m = data.length_m
	source_length_m = length_m
	ascent_m = data.ascent_raw_m
	var directory := "res://assets/geodata/circuits/"+path.get_file().get_basename()+"/"
	if use_geography and FileAccess.file_exists(directory+"route.json"):
		var prepared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"route.json"))
		if prepared.get("route_source_sha256","") == data.get("source_sha256",""):
			var file := FileAccess.open(directory+str(prepared.points_file),FileAccess.READ)
			var packed := file.get_buffer(file.get_length()).to_float32_array()
			if packed.size() == int(prepared.point_count)*4:
				geography = prepared
				var coordinate_file := FileAccess.open(directory+str(prepared.coordinates_file),FileAccess.READ)
				coordinates = coordinate_file.get_buffer(coordinate_file.get_length()).to_float64_array()
				length_m = prepared.length_m
				ascent_m = prepared.ascent_m
				spacing = prepared.spacing_m
				points = []
				for i in range(int(prepared.point_count)):
					var p := Vector3(packed[i*4],packed[i*4+1],packed[i*4+2])
					curve.append(p)
					points.append({"s":i*spacing,"x":p.x,"alt":p.y,"z":p.z,"source_s":packed[i*4+3]})
				return
	# A derived, uniform spatial grid: never rewrite source GPX or its metrics.
	var count := int(ceil(length_m / 2.0))
	spacing = length_m / count
	for i in range(count + 1): curve.append(sample_raw(i * spacing).position)
	# Remove short GPS/elevation jitter before fitting the continuous curve.
	# Bound the extra correction: narrow bends stay close to their source track.
	var grid := curve.duplicate()
	for i in range(1,count):
		var filtered := Vector3.ZERO
		var weights := [1.0,4.0,6.0,4.0,1.0]
		for j in range(-2,3):
			filtered += (grid[clampi(i+j,0,count)]-grid[i])*weights[j+2]/16.0
		var horizontal := Vector2(filtered.x,filtered.z).limit_length(.35)
		curve[i] += Vector3(horizontal.x,clampf(filtered.y,-.25,.25),horizontal.y)

func source_station(distance: float) -> float:
	if geography.is_empty(): return clampf(distance,0,source_length_m)
	if distance<=0: return 0
	if distance>=length_m: return source_length_m
	var u := clampf(distance,0,length_m)/spacing
	var i := mini(int(floor(u)),points.size()-2)
	return lerpf(points[i].source_s,points[i+1].source_s,clampf(u-i,0,1))

func sample_raw(distance: float) -> Dictionary:
	var s := source_station(distance)
	var lo := 0
	var hi := source_points.size() - 1
	while lo + 1 < hi:
		var mid := (lo + hi) / 2
		if float(source_points[mid].s) <= s: lo = mid
		else: hi = mid
	var a: Dictionary = source_points[lo]
	var b: Dictionary = source_points[hi]
	var t := clampf((s - float(a.s)) / maxf(float(b.s) - float(a.s), 0.0001), 0, 1)
	return {"position": Vector3(lerpf(a.x, b.x, t), lerpf(a.alt, b.alt, t), lerpf(a.z, b.z, t)),
		"lat": lerpf(a.lat, b.lat, t), "lon": lerpf(a.lon, b.lon, t), "index": lo}

func control(index: int) -> Vector3:
	# Linear ghost knots keep endpoint tangents defined and endpoints anchored.
	if index < 0: return curve[0] + (curve[1] - curve[0]) * index
	if index >= curve.size():
		return curve[-1] + (curve[-1] - curve[-2]) * (index - curve.size() + 1)
	return curve[index]

func structure_at(station: float) -> String:
	for structure in geography.get("structures",[]):
		if station>=float(structure.start_m) and station<=float(structure.end_m): return str(structure.kind)
	return ""

func osm_verified_at(station: float) -> bool:
	if geography.is_empty(): return false
	var source_s := source_station(station)
	for interval in geography.osm_match.unverified_source_intervals_m:
		if source_s>=float(interval[0]) and source_s<=float(interval[1]): return false
	return true

func smooth_position(distance: float) -> Vector3:
	var u := clampf(distance, 0, length_m) / spacing
	var i := mini(int(floor(u)), curve.size() - 2)
	var t := u - i
	# Uniform cubic B-spline: C2 continuity, nonnegative weights (no overshoot
	# beyond the local control hull), smoothing over a six metre neighbourhood.
	var origin := control(i)
	var position := origin + ((control(i-1)-origin)*pow(1-t,3)
		+ (control(i+1)-origin)*(-3*t*t*t+3*t*t+3*t+1)
		+ (control(i+2)-origin)*t*t*t) / 6.0
	# Only geometric lookahead/aprons may extrapolate, bounded to 12 metres.
	var extra := clampf(distance - clampf(distance,0,length_m),-12,12)
	if extra != 0:
		var tangent := (curve[1]-curve[0]) if distance<0 else (curve[-1]-curve[-2])
		position += tangent / spacing * extra
	return position

func sample(distance: float) -> Dictionary:
	var result := sample_raw(distance)
	result.source_alt_m = result.position.y
	result.source_lat = result.lat
	result.source_lon = result.lon
	result.source_station_m = source_station(distance)
	result.position = smooth_position(distance)
	if not coordinates.is_empty():
		var u := clampf(distance,0,length_m)/spacing
		var i := mini(int(floor(u)),points.size()-2)
		result.lat = lerpf(coordinates[i*2],coordinates[(i+1)*2],u-i)
		result.lon = lerpf(coordinates[i*2+1],coordinates[(i+1)*2+1],u-i)
	return result

func grade(distance: float, window_m: float = 12.0) -> float:
	var a := maxf(0, distance - window_m * 0.5)
	var b := minf(length_m, distance + window_m * 0.5)
	return (smooth_position(b).y - smooth_position(a).y) / maxf(b-a, 0.001)

func tangent(distance: float) -> Vector3:
	var u := clampf(distance,0,length_m) / spacing
	var i := mini(int(floor(u)),curve.size()-2)
	var t := u-i
	# Analytic derivative in local coordinates avoids cancellation far from origin.
	var origin := control(i)
	return ((control(i-1)-origin)*(-3*pow(1-t,2))
		+ (control(i+1)-origin)*(-9*t*t+6*t+3)
		+ (control(i+2)-origin)*3*t*t) / (6*spacing)

func direction(distance: float) -> Vector3:
	var velocity := tangent(distance)
	return velocity.normalized() if velocity.length_squared()>0.000001 else Vector3.FORWARD
