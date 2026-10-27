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
	check(app.screen == "home" and app.world.geographic.covers(0) and app.world.geographic.covers(app.route.length_m) and not app.world.geographic.covers(app.route.length_m+1),"native scene opens with full-circuit bounded geographic coverage")
	var geo = app.world.geographic
	var all_valid := true
	for building in geo.data.buildings:
		var polygon := PackedVector2Array()
		var center := Vector2(building.center[0],building.center[1])
		for p in building.footprint: polygon.append(Vector2(p[0],p[1])-center)
		if Geometry2D.triangulate_polygon(polygon).is_empty(): all_valid = false
	check(all_valid,"all cached source footprints can be triangulated")
	var square := PackedVector2Array([Vector2(-2,-1),Vector2(2,-1),Vector2(2,1),Vector2(-2,1)])
	var left: PackedVector2Array = geo.clip_ridge(square,Vector2.RIGHT,0,-1)
	var right: PackedVector2Array = geo.clip_ridge(square,Vector2.RIGHT,0,1)
	check(left.size() == 4 and right.size() == 4,"gable roof clips both sides of the ridge")
	var station: Vector3 = app.route.sample(1000).position
	check(absf(geo.elevation_at(Vector2(station.x,station.z),1000,0,NAN)-station.y) < 2,"simulation road follows numeric LiDAR ground without altering the GPX")
	app.start_session()
	for i in range(150): app._physics_process(0.02)
	check(app.distance>1 and app.elapsed>2.9 and app.speed>0,"demo watts advance native session")
	app.toggle_pause()
	var before: float = app.distance
	for i in range(50): app._physics_process(0.02)
	check(app.screen == "paused" and app.distance == before,"pause freezes physics and progress")
	app.resume_session()
	for i in range(50): app._physics_process(0.02)
	check(app.screen == "ride" and app.distance>before and app.overlay.get_child_count() == 2,"resume restores progress and mouse power controls")
	app.finish_session()
	check(app.screen == "summary","session ends on local saved summary")
	app.show_history()
	check(app.overlay.get_child_count() == 1,"local activity history opens")
	app.show_settings()
	app.save_settings()
	var settings := ConfigFile.new()
	check(settings.load("user://settings.cfg") == OK and settings.has_section_key("rider","mass_kg"),"desktop preferences persist")
	app.queue_free()
	await process_frame
	print("RESULT_DESKTOP passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
