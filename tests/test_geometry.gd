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
	app.rider.crank = 0
	app.rider.animate(0,60,4)
	var foot: Vector3 = app.rider.limbs[0].shoe.position
	var angle: float = app.rider.wheels[0].rotation.x
	var finite := true
	for i in range(24):
		app.rider.animate(1.0/24,60,4)
		for leg in app.rider.limbs:
			if not leg.shoe.position.is_finite() or leg.shoe.position.y<0.10: finite = false
	check(finite and app.rider.limbs[0].shoe.position.distance_to(foot)<0.001,"pedal animation is cyclic, finite and above the pavement")
	check(absf(app.rider.wheels[0].rotation.x-angle+4.0/0.349)<0.001,"wheel rotation matches distance and 700C tyre radius")
	app.rider.crank = 0
	app.rider.animate(0,60,0)
	var top: Vector3 = app.rider.limbs[0].shoe.position
	app.rider.animate(.25,60,0)
	var front: Vector3 = app.rider.limbs[0].shoe.position
	app.rider.animate(.25,60,0)
	var bottom: Vector3 = app.rider.limbs[0].shoe.position
	app.rider.animate(.25,60,0)
	var back: Vector3 = app.rider.limbs[0].shoe.position
	check(front.z<top.z and bottom.y<front.y and back.z>bottom.z,"forward pedal cycle: top, forward (-Z), bottom, rear")
	check(app.rider.limbs[0].shoe.position.y != app.rider.limbs[1].shoe.position.y or absf(app.rider.limbs[0].shoe.position.z-app.rider.limbs[1].shoe.position.z)>.3,"pedals remain diametrically opposed")
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
