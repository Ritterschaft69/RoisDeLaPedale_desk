extends SceneTree

var passed := 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ",description)
	else:
		failures.append(description)
		push_error("FAIL "+description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	check(app.circuits.size() == 4,"catalogue contains all four installed circuits")
	for id in ["home_sweet_home","sortie_matin","oderen_grand_ballon","saint_die"]:
		app.show_circuits()
		var button = app.overlay.find_child("Circuit_"+id,true,false)
		check(button != null,"menu button exists for "+id)
		button.pressed.emit()
		await process_frame
		check(app.screen == "home" and app.selected_circuit.id == id,"menu selects correct circuit "+id)
		check(app.world.route == app.route and app.distance == app.route.start_m and app.elapsed == 0,"route/world/progress reset for "+id)
		check(absf(app.world.roadside(app.route.start_m-20,0).distance_to(app.route.sample(app.route.start_m).position)-20) < 0.001,"visual start apron supports the chase camera for "+id)
		app.hud.ensure_route_cache()
		check(app.hud.cached_route == app.route and app.hud.map_points.size() <= 702,"map and profile refresh with bounded display geometry for "+id)
		check(app.world.geographic.covers(0) and app.world.geographic.covers(app.route.length_m),"full IGN cache is scoped and restored correctly for "+id)
		app.start_session()
		check(not app.select_circuit("sortie_matin"),"active session cannot silently change circuit")
		for i in range(100): app._physics_process(0.02)
		# Let the HUD actually draw the selected route's profile in ride mode.
		await process_frame
		await process_frame
		check(app.distance > app.route.start_m and is_finite(app.speed),"session advances on "+id)
		var before := DirAccess.get_files_at("user://activities") if DirAccess.dir_exists_absolute("user://activities") else PackedStringArray()
		app.finish_session()
		var saved: Dictionary = {}
		for path in DirAccess.get_files_at("user://activities"):
			if path not in before:
				saved = JSON.parse_string(FileAccess.get_file_as_string("user://activities/"+path))
		check(saved.get("route","") == id and saved.get("route_name","") == app.selected_circuit.name and saved.get("route_source_sha256","") == app.route.data.source_sha256,"activity records chosen route and source hash for "+id)
		check(absf(float(saved.get("distance_m",-1))-(app.distance-app.route.start_m))<0.0001 and saved.get("route_start_m",-1)==app.route.start_m,"activity counts ridden metres only for "+id)
		var samples: Array = saved.get("samples",[])
		var coherent := false
		if not samples.is_empty() and samples[0].has("source_gpx"):
			var station: float = float(samples[0].distance_m)+app.route.start_m
			coherent = absf(float(samples[0].alt_m)-app.route.sample(station).position.y)<.02 and absf(float(samples[0].source_gpx.alt_m)-app.route.sample_raw(station).position.y)<.02
		check(coherent and "IGN69" in saved.get("altitude_source",""),"activity separates simulated IGN altitude from original GPX values for "+id)
		app.show_home()
	check(not app.select_circuit("unknown") and app.selected_circuit.id == "saint_die","invalid circuit leaves selection intact")
	app.select_circuit("oderen_grand_ballon")
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	check(settings.get_value("route","selected_id","") == "oderen_grand_ballon","selection persists in user settings")
	app.queue_free()
	await process_frame
	var restored = load("res://main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	check(restored.selected_circuit.id == "oderen_grand_ballon" and restored.route.source_points.size() == 20459,"restart restores selected circuit and its original source points")
	restored.set_physics_process(false)
	restored.select_circuit("saint_die")
	restored.queue_free()
	await process_frame
	print("RESULT_CIRCUITS passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
