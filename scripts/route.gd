class_name CyclingRoute
extends RefCounted

var data: Dictionary
var points: Array
var length_m: float
var ascent_m: float
var start_m := 0.0 # Explicit playable start; source samples stay intact.

func _init(path: String = "res://assets/routes/saint_die.json") -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	points = data.points
	length_m = data.length_m
	ascent_m = data.ascent_raw_m

func sample(distance: float) -> Dictionary:
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

func grade(distance: float, window_m: float = 12.0) -> float:
	var a := maxf(0, distance - window_m * 0.5)
	var b := minf(length_m, distance + window_m * 0.5)
	return (sample(b).position.y - sample(a).position.y) / maxf(b-a, 0.001)

func direction(distance: float) -> Vector3:
	var a: Vector3 = sample(maxf(0, distance - 2.0)).position
	var b: Vector3 = sample(minf(length_m, distance + 2.0)).position
	return (b-a).normalized()
