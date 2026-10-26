extends SceneTree

const Planner = preload("res://scripts/lane_planner.gd")
const Physics = preload("res://scripts/physics.gd")
var passed := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ",message)
	else: failures.append(message); push_error("FAIL "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var planner := Planner.new()
	for i in range(500): planner.step(i*0.1,5,0.02,[])
	check(absf(planner.lateral-1.55)<0.001,"rider defaults to the right at 1.55 metres")
	for speed in [2.0,8.0,16.0]:
		planner.reset()
		var station := 0.0
		var minimum := INF
		var maximum_rate := 0.0
		var low := planner.lateral
		var overlaps_bike := false
		while station<125:
			var previous := planner.lateral
			planner.step(station,speed,0.02,[{"s":60.0,"lateral":1.55,"radius":0.55}])
			station += speed*0.02
			minimum = minf(minimum,Vector2(station-60,planner.lateral-1.55).length())
			maximum_rate = maxf(maximum_rate,absf(planner.lateral-previous)/0.02)
			low = minf(low,planner.lateral)
			if absf(station-60)<1.55 and absf(planner.lateral-1.55)<0.87: overlaps_bike = true
		check(minimum>=0.87 and not overlaps_bike,"no collision with full bike footprint at %.0f m/s" % speed)
		check(low<0.6 and absf(planner.lateral-1.55)<0.03,"smooth bypass and return to right at %.0f m/s" % speed)
		check(maximum_rate<=0.901 and absf(planner.lateral)<=2.55,"bounded lateral speed and road edge at %.0f m/s" % speed)
	planner.reset()
	var station := 0.0
	var clock := 0.0
	var clearance := INF
	var crossing_overlap := false
	while station<105:
		var cross := -3.1875+clock*0.625
		planner.step(station,8,0.02,[{"s":60.0,"lateral":cross,"velocity_lateral":0.625,"radius":0.32}])
		station += 8*0.02
		clock += 0.02
		clearance = minf(clearance,Vector2(station-60,planner.lateral-(-3.1875+clock*0.625)).length())
		if absf(station-60)<1.32 and absf(planner.lateral-(-3.1875+clock*0.625))<0.64: crossing_overlap = true
	check(clearance>=0.64 and not crossing_overlap,"crossing pedestrian is anticipated without bike or body overlap")
	planner.reset()
	var engine := Physics.new()
	var velocity := 10.0
	station = 0
	for i in range(3000):
		var plan := planner.step(station,velocity,0.02,[{"s":45.0,"lateral":0.0,"radius":6.0}])
		var result := engine.step(velocity,0.0 if plan.blocked else 180.0,0,0.02,0,-1,0,engine.effective_mass_kg*3.5 if plan.blocked else 0.0)
		velocity = result.speed
		station += result.distance
	check(velocity<0.01 and station<38,"fully blocked road stops before obstacle instead of crossing it")
	planner.reset()
	for i in range(200): planner.step(i*0.16,8,0.02,[{"s":30.0,"lateral":-2.0,"radius":0.3}])
	check(absf(planner.lateral-1.55)<0.01,"obstacle in opposite lane does not trigger unnecessary weaving")
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.start_session()
	for i in range(100): app._physics_process(0.02)
	await process_frame
	await process_frame
	var center: Vector3 = app.route.sample(app.distance).position
	var direction: Vector3 = app.route.direction(app.distance)
	var right := Vector3(-direction.z,0,direction.x).normalized()
	check(absf((app.rider.position-center).dot(right)-app.lane.lateral)<0.02 and app.lane.lateral>0,"native rider is on the right of the GPX centreline")
	var life = app.world.life
	var kinds: Dictionary = {}
	for actor in life.actors.values(): kinds[actor.kind] = true
	check(kinds.has("walker") and kinds.has("deer") and kinds.has("fox") and kinds.has("bird"),"pedestrians, roe deer, foxes and birds exist in streamed scenery")
	check(life.actors.size()<=10,"living scenery uses a bounded nearby pool")
	app.distance = app.route.start_m+35
	app.speed = 7
	app.lane.reset()
	var overlap := false
	var saw_bypass := false
	for i in range(2500):
		app._physics_process(0.02)
		saw_bypass = saw_bypass or app.lane.avoiding
		for actor in life.actors.values():
			if actor.kind=="bird" or not actor.node.visible: continue
			var position: Dictionary = life.state(actor,life.time_s)
			var radius := 1.0 if actor.kind in ["deer","fox"] else (0.55 if actor.kind=="obstacle" else 0.32)
			var separation := Vector2(float(position.s)-app.distance,float(position.lateral)-app.lane.lateral).length()
			if separation<radius+0.32 or (absf(float(position.s)-app.distance)<radius+1.0 and absf(float(position.lateral)-app.lane.lateral)<radius+0.32): overlap = true
	check(not overlap,"integrated session has no body overlap with streamed pedestrians or cones")
	check(saw_bypass and app.distance>app.route.start_m+95,"integrated session actually passes the procedural road obstacle")
	var before: float = life.time_s
	app.toggle_pause()
	for i in range(50): app._physics_process(0.02)
	check(life.time_s==before,"pause freezes animals and pedestrian simulation")
	app.resume_session()
	app._physics_process(0.02)
	check(life.time_s>before,"resume restarts scenery simulation")
	life.set_route(app.world)
	life.step(0,1200,0)
	var snapshot: Dictionary = {}
	for id in life.actors: snapshot[id] = life.actors[id].node.position
	life.set_route(app.world)
	life.step(0,1200,0)
	var stable := true
	# Compare identical time, not two different phases.
	for id in life.actors:
		if not snapshot.has(id): stable = false
		elif snapshot[id].distance_to(life.actors[id].node.position)>0.001: stable = false
	check(stable and life.actors.size()<=10,"streamed identities are deterministic and old actors are retired")
	app.queue_free()
	await process_frame
	print("RESULT_NAVIGATION passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
