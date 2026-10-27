class_name SessionRecorder
extends RefCounted

var points: Array[Dictionary] = []
var started_at := ""
var sum_watts := 0.0
var max_watts := 0.0
var ascent_m := 0.0
var previous_altitude := 0.0
var cadence_sum := 0.0
var elapsed_s := 0.0
var route_id := "saint_die"
var route_name := "Boucle de Saint-Dié-des-Vosges"
var route_source_sha256 := ""
var route_start_m := 0.0
var geographic_route := false

func begin(altitude: float) -> void:
	points.clear()
	started_at = Time.get_datetime_string_from_system(true)
	sum_watts = 0
	max_watts = 0
	ascent_m = 0
	previous_altitude = altitude
	cadence_sum = 0
	elapsed_s = 0

func tick(dt: float, distance: float, speed: float, watts: float, cadence: float, location: Dictionary, lateral_m: float = 0.0) -> void:
	var previous_second := int(elapsed_s)
	elapsed_s += dt
	sum_watts += watts * dt
	cadence_sum += cadence * dt
	max_watts = maxf(watts,max_watts)
	ascent_m += maxf(0,location.position.y-previous_altitude)
	previous_altitude = location.position.y
	if int(elapsed_s) > previous_second:
		points.append({"t": elapsed_s,"distance_m": distance,"speed_mps": speed,"watts": watts,
			"cadence_rpm": cadence,"lat": location.lat,"lon": location.lon,"alt_m": location.position.y,"lateral_m":lateral_m})
		if geographic_route:
			points[-1].source_gpx = {"lat":location.source_lat,"lon":location.source_lon,"alt_m":location.source_alt_m,"station_m":location.source_station_m}

func save(distance: float, complete: bool) -> Dictionary:
	var summary := {"schema":1,"started_at_utc":started_at,"duration_s":elapsed_s,"distance_m":distance,
		"ascent_m":ascent_m,"average_watts":sum_watts/maxf(elapsed_s,0.001),"max_watts":max_watts,
		"average_cadence_rpm":cadence_sum/maxf(elapsed_s,0.001),"completed":complete,"input_source":"demo",
		"route":route_id,"route_name":route_name,"route_source_sha256":route_source_sha256,"route_start_m":route_start_m,"samples":points}
	summary["altitude_source"] = "IGN LiDAR HD, IGN69, smoothed simulation route" if geographic_route else "original GPX, unspecified vertical datum"
	summary["route_geometry"] = "OSM matched simulation; source_gpx retained per sample" if geographic_route else "original GPX"
	if DirAccess.make_dir_recursive_absolute("user://activities") != OK:
		return {"error":"Impossible de créer le dossier des activités."}
	var path := "user://activities/%s_%d.json" % [started_at.replace(":","-"),Time.get_ticks_msec()]
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return {"error":"Impossible d’enregistrer l’activité : %s" % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(summary,"\t"))
	file.flush()
	if file.get_error() != OK: return {"error":"Erreur d’écriture de l’activité."}
	file.close()
	summary["path"] = ProjectSettings.globalize_path(path)
	return summary
