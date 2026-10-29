extends SceneTree

const M = preload("res://scripts/materials.gd")
var passed := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ",message)
	else: failures.append(message); push_error("FAIL "+message)

func outward(instance: MeshInstance3D) -> bool:
	var arrays := instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		if Vector2(vertices[i].x,vertices[i].z).dot(Vector2(normals[i].x,normals[i].z)) < 0.05: return false
	return true

func up_facing(instance: MeshInstance3D) -> bool:
	var arrays := instance.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		if normal.y<=0: return false
	return true

func road_clearance(app: Node3D, station: float) -> float:
	var ground: MeshInstance3D = app.world.generated.get_child(0)
	var vertices: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var minimum := INF
	for step in range(16):
		for lateral in [-2.7,0.0,2.7]:
			var p: Vector3 = app.world.roadside(station+step*3,lateral)
			var found := false
			for i in range(0,vertices.size(),3):
				var a := Vector2(vertices[i].x,vertices[i].z)
				var b := Vector2(vertices[i+1].x,vertices[i+1].z)-a
				var c := Vector2(vertices[i+2].x,vertices[i+2].z)-a
				var q := Vector2(p.x,p.z)-a
				var determinant := b.cross(c)
				if absf(determinant)<.00001: continue
				var u := q.cross(c)/determinant
				var v := b.cross(q)/determinant
				if u<-.0001 or v<-.0001 or u+v>1.0001: continue
				var y := vertices[i].y*(1-u-v)+vertices[i+1].y*u+vertices[i+2].y*v
				minimum = minf(minimum,p.y+.045-y)
				found = true
			if not found: return -INF
	return minimum

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var loft := M.loft(holder,[{"center":Vector3.ZERO,"width":0.5,"depth":0.3},{"center":Vector3.UP,"width":0.5,"depth":0.3}],M.toon(Color.WHITE,true))
	check(outward(loft),"tailored garment normals face outward, avoiding outline depth artefacts")
	var geo = load("res://scripts/geoworld.gd").new()
	for reverse in [false,true]:
		var ring := [[-2,-2],[-2,2],[2,2],[2,-2]]
		if reverse: ring.reverse()
		var fixture := {"id":"fixture","center":[0,0],"footprint":ring,"base_render":0,"seed":1,"height":6}
		geo.build(holder,fixture,false)
		var house := holder.get_child(holder.get_child_count()-1)
		check(outward(house.get_child(0)),"building exterior normals respect source winding "+str(reverse))
		check(up_facing(house.get_child(1)),"gable roof faces the sky "+str(reverse))
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	check(up_facing(app.world.generated.get_child(0)),"Delaunay terrain has consistently upward normals")
	app.select_circuit("oderen_grand_ballon")
	app.world.update_at(65782.9,true)
	var clearance := road_clearance(app,65782.9)
	print("CORNER_TERRAIN_CLEARANCE_M ",clearance)
	check(clearance>.01,"terrain stays below both lanes through the real Grand Ballon bend")
	app.rider.crank = 0
	app.rider.animate(0,60,4)
	var foot: Vector3 = app.rider.pedal_position(0)
	var angle: float = app.rider.wheel_phase
	var finite := true
	for i in range(24):
		app.rider.animate(1.0/24,60,4)
		for index in range(2):
			var pedal: Vector3 = app.rider.pedal_position(index)
			if not pedal.is_finite() or pedal.y<0.09: finite = false
	check(finite and app.rider.pedal_position(0).distance_to(foot)<0.001,"pedal animation is cyclic, finite and above the pavement")
	check(absf(wrapf(app.rider.wheel_phase-angle-4.0/app.rider.WHEEL_RADIUS,-PI,PI))<0.001,"wheel rotation matches distance and supplied tyre radius")
	app.rider.crank = 0
	app.rider.animate(0,60,0)
	var top: Vector3 = app.rider.pedal_position(0)
	app.rider.animate(.125,60,0);app.rider.animate(.125,60,0)
	var front: Vector3 = app.rider.pedal_position(0)
	app.rider.animate(.125,60,0);app.rider.animate(.125,60,0)
	var bottom: Vector3 = app.rider.pedal_position(0)
	app.rider.animate(.125,60,0);app.rider.animate(.125,60,0)
	var back: Vector3 = app.rider.pedal_position(0)
	check(front.z<top.z and bottom.y<front.y and back.z>bottom.z,"forward pedal cycle: top, forward (-Z), bottom, rear")
	check(app.rider.pedal_position(0).y != app.rider.pedal_position(1).y or absf(app.rider.pedal_position(0).z-app.rider.pedal_position(1).z)>.3,"pedals remain diametrically opposed")
	app.rider.crank = 0
	app.rider.animate(.6,90,0)
	check(app.rider.crank>0 and app.rider.crank<=PI/3+.00001,"render stalls cannot skip backward-looking pedal phases")
	var crank: float = app.rider.crank
	app.rider.animate(0.5,0,4)
	check(app.rider.crank==crank,"coasting stops pedalling while wheels keep turning")
	app.queue_free()
	holder.queue_free()
	await process_frame
	print("RESULT_GEOMETRY passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
