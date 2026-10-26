class_name CyclingRoute
extends RefCounted

var data: Dictionary
var points: Array
var length_m: float
var ascent_m: float
var curve := PackedVector3Array()
var spacing := 2.0

var start_m := 0.0 # Explicit playable start; source samples stay intact.

func _init(path: String = "res://assets/routes/saint_die.json") -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	points = data.points
	length_m = data.length_m
	ascent_m = data.ascent_raw_m
	# A derived, uniform spatial grid: never rewrite source GPX or its metrics.
	var count := int(ceil(length_m / 2.0))
	spacing = length_m / count
	for i in range(count + 1): curve.append(sample_raw(i * spacing).position)

func sample_raw(distance: float) -> Dictionary:
	var s := clampf(distance, 0, length_m)
	var lo := 0
	var hi := points.size() - 1
	while lo + 1 < hi:
		var mid := (lo + hi) / 2
		if float(points[mid].s) <= s: lo = mid
		else: hi = mid
	var a: Dictionary = points[lo]
	var b: Dictionary = points[hi]
	var t := clampf((s - float(a.s)) / maxf(float(b.s) - float(a.s), 0.0001), 0, 1)
	return {"position": Vector3(lerpf(a.x, b.x, t), lerpf(a.alt, b.alt, t), lerpf(a.z, b.z, t)),
		"lat": lerpf(a.lat, b.lat, t), "lon": lerpf(a.lon, b.lon, t), "index": lo}

func control(index: int) -> Vector3:
	# Linear ghost knots keep endpoint tangents defined and endpoints anchored.
	if index < 0: return curve[0] + (curve[1] - curve[0]) * index
	if index >= curve.size():
		return curve[-1] + (curve[-1] - curve[-2]) * (index - curve.size() + 1)
	return curve[index]

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
	result.position = smooth_position(distance)
	return result

func grade(distance: float, window_m: float = 12.0) -> float:
	var a := maxf(0, distance - window_m * 0.5)
	var b := minf(length_m, distance + window_m * 0.5)
	return (sample(b).position.y - sample(a).position.y) / maxf(b-a, 0.001)

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
