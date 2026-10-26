class_name CyclingWorldLife
extends Node3D

const M = preload("res://scripts/materials.gd")
var world: Node3D
var actors: Dictionary = {}
var time_s := 0.0
var last_bucket := -999999
var route_seed := 0

func set_route(source: Node3D) -> void:
	world = source
	time_s = 0
	last_bucket = -999999
	route_seed = abs(str(world.route.data.source_sha256).hash())
	for actor in actors.values():
		remove_child(actor.node)
		actor.node.queue_free()
	actors.clear()

func sync(station: float) -> void:
	var bucket := floori((station-world.route.start_m)/120)
	if bucket==last_bucket: return
	last_bucket = bucket
	var wanted: Dictionary = {}
	for i in range(maxi(0,bucket-1),bucket+4):
		var anchor: float = world.route.start_m+i*120+55
		if anchor>=world.route.length_m-10: continue
		var kind := "walker" if i%2==0 else ("deer" if i%3!=0 else "fox")
		var id := kind+str(i)
		wanted[id] = true
		if not actors.has(id): create_actor(id,kind,i,anchor)
		if i%4==0:
			id = "obstacle"+str(i)
			wanted[id] = true
			if not actors.has(id): create_actor(id,"obstacle",i,anchor+23)
		if i%3==1:
			id = "bird"+str(i)
			wanted[id] = true
			if not actors.has(id): create_actor(id,"bird",i,anchor)
	for id in actors.keys():
		if wanted.has(id): continue
		remove_child(actors[id].node)
		actors[id].node.queue_free()
		actors.erase(id)

func create_actor(id: String, kind: String, index: int, anchor: float) -> void:
	var root := Node3D.new()
	root.name = id
	add_child(root)
	var record := {"node":root,"kind":kind,"index":index,"anchor":anchor,"phase":float(posmod(index*37+route_seed,64)),"legs":[],"arms":[],"wings":[],"wait_delay":0.0,"waiting":false,"crossing":(kind=="walker" and index%6==0) or (kind=="deer" and index%9==1)}
	if kind=="walker": person(record)
	elif kind=="deer" or kind=="fox": animal(record)
	elif kind=="bird": bird(record)
	else: obstacle(root)
	actors[id] = record

func state(record: Dictionary, at_time: float) -> Dictionary:
	var s: float = record.anchor
	var lateral := 0.0
	var vs := 0.0
	var vx := 0.0
	var t: float = at_time+record.phase-record.wait_delay
	var side := -1.0 if int(record.index)%3==1 else 1.0
	if record.kind=="obstacle": lateral = 1.55
	elif record.kind=="walker":
		if record.crossing:
			var cycle := fposmod(t,64)
			if cycle<16: lateral = lerpf(-5,5,cycle/16); vx = 0.625
			elif cycle<32: lateral = 5
			elif cycle<48: lateral = lerpf(5,-5,(cycle-32)/16); vx = -0.625
			else: lateral = -5
		else:
			s += sin(t*0.09)*7
			vs = cos(t*0.09)*0.63
			lateral = side*4.95
	elif record.kind=="deer" or record.kind=="fox":
		if record.crossing:
			var cycle := fposmod(t,80)
			if cycle<14: lateral = lerpf(-8,8,cycle/14); vx = 16.0/14
			elif cycle<40: lateral = 8
			elif cycle<54: lateral = lerpf(8,-8,(cycle-40)/14); vx = -16.0/14
			else: lateral = -8
		else:
			s += sin(t*0.12)*5
			vs = cos(t*0.12)*0.6
			lateral = side*(7.0+sin(t*0.18)*0.6)
			vx = side*cos(t*0.18)*0.108
	else:
		s += sin(t*0.11)*25
		vs = cos(t*0.11)*2.75
		lateral = sin(t*0.13)*18
		vx = cos(t*0.13)*2.34
	return {"s":clampf(s,world.route.start_m,world.route.length_m),"lateral":lateral,"velocity_s":0.0 if record.waiting else vs,"velocity_lateral":0.0 if record.waiting else vx}

func step(dt: float, station: float, speed: float, rider_lateral: float = 1.55) -> void:
	time_s += dt
	sync(station)
	for record in actors.values():
		record.waiting = false
		var observation := state(record,time_s)
		var body_radius := 1.0 if record.kind=="deer" else 0.32
		if record.crossing and speed<0.2 and absf(float(observation.s)-station)<body_radius+1.2 and absf(float(observation.lateral)-rider_lateral)<body_radius+0.67:
			record.wait_delay += dt
			record.waiting = true
			observation = state(record,time_s)
		var at: Vector3 = world.roadside(observation.s,observation.lateral,absf(observation.lateral)>4.6)
		if record.kind=="bird": at.y += 12+sin((time_s+record.phase)*0.2)*3
		record.node.position = at+Vector3.UP*(0.055 if absf(observation.lateral)<3.3 else 0)
		record.node.visible = record.kind=="obstacle" or record.kind=="bird" or not world.geographic.building_at(Vector2(at.x,at.z))
		var forward: Vector3 = world.route.direction(observation.s)
		var right := Vector3(-forward.z,0,forward.x).normalized()
		var moving: Vector3 = forward*observation.velocity_s+right*observation.velocity_lateral
		if moving.length()>0.03:
			var angle := atan2(-moving.x,-moving.z)
			record.node.rotation.y = angle if dt==0 else lerp_angle(record.node.rotation.y,angle,minf(1,dt*5))
		else: record.node.rotation.y = atan2(-forward.x,-forward.z)
		animate(record,time_s+record.phase,moving.length())

func observations(station: float, speed: float) -> Array:
	var results: Array = []
	for record in actors.values():
		if record.kind=="bird" or not record.node.visible: continue
		var current := state(record,time_s)
		if absf(float(current.s)-station)>maxf(22,speed*5+5): continue
		var arrival := clampf((float(current.s)-station)/maxf(speed-float(current.velocity_s),1),0,6)
		var future := current if record.waiting else state(record,time_s+arrival)
		var radius := 1.0 if record.kind in ["deer","fox"] else (0.55 if record.kind=="obstacle" else 0.32)
		results.append({"id":record.node.name,"s":current.s,"lateral":current.lateral,"velocity_lateral":current.velocity_lateral,"predicted_lateral":future.lateral,"radius":radius})
	return results

func person(record: Dictionary) -> void:
	var root: Node3D = record.node
	var skin := M.toon(Color("d6aa88"),true)
	var clothes := M.toon(Color("617b7d") if int(record.index)%3==0 else Color("8c6254"),true)
	var pants := M.toon(Color("39444d"),true)
	var boots := M.toon(Color("493c31"))
	M.loft(root,[{"center":Vector3(0,0.91,0),"width":0.13,"depth":0.09},{"center":Vector3(0,1.18,0),"width":0.17,"depth":0.12},{"center":Vector3(0,1.46,0),"width":0.21,"depth":0.11},{"center":Vector3(0,1.5,0),"width":0.07,"depth":0.065}],clothes)
	M.rod(root,Vector3(0,1.46,0),Vector3(0,1.60,0),0.05,skin)
	M.ball(root,Vector3(0,1.67,-0.015),Vector3(0.20,0.25,0.21),skin)
	M.ball(root,Vector3(0,1.78,0),Vector3(0.22,0.09,0.23),M.toon(Color("6e684a")))
	M.ball(root,Vector3(0,1.67,-0.12),Vector3(0.04,0.04,0.05),skin)
	for side in [-1.0,1.0]:
		var upper := M.tapered(root,Vector3.ZERO,Vector3.UP,0.08,0.065,pants)
		var lower := M.tapered(root,Vector3.ZERO,Vector3.UP,0.065,0.044,pants)
		var shoe := M.ball(root,Vector3.ZERO,Vector3(0.13,0.09,0.24),boots)
		record.legs.append({"side":side,"upper":upper,"lower":lower,"shoe":shoe})
		var arm := M.tapered(root,Vector3.ZERO,Vector3.UP,0.06,0.045,clothes)
		var forearm := M.tapered(root,Vector3.ZERO,Vector3.UP,0.043,0.031,skin)
		var hand := M.ball(root,Vector3.ZERO,Vector3(0.064,0.085,0.06),skin)
		record.arms.append({"side":side,"upper":arm,"lower":forearm,"hand":hand})

func animal(record: Dictionary) -> void:
	var root: Node3D = record.node
	var deer: bool = record.kind=="deer"
	var fur := M.toon(Color("977249") if deer else Color("b66b35"),true)
	var pale := M.toon(Color("d4c5a3"))
	var dark := M.toon(Color("302f29"))
	var height := 0.85 if deer else 0.40
	M.ball(root,Vector3(0,height,0),Vector3(0.45,0.52,1.0) if deer else Vector3(0.28,0.29,0.66),fur)
	M.ball(root,Vector3(0,height-0.10,-0.02),Vector3(0.30,0.20,0.68) if deer else Vector3(0.22,0.17,0.46),pale)
	var head := Node3D.new()
	root.add_child(head)
	head.position = Vector3(0,height+0.13,-0.36)
	record["head"] = head
	M.tapered(head,Vector3.ZERO,Vector3(0,0.33 if deer else 0.08,-0.18),0.13 if deer else 0.085,0.09,fur)
	var face := Vector3(0,0.36 if deer else 0.11,-0.24)
	M.ball(head,face,Vector3(0.23,0.24,0.36) if deer else Vector3(0.20,0.19,0.24),fur)
	M.ball(head,face+Vector3(0,-0.045,-0.17),Vector3(0.12,0.11,0.18),pale)
	M.ball(head,face+Vector3(0,-0.045,-0.25),Vector3(0.07,0.065,0.055),dark)
	for side in [-1.0,1.0]:
		var ear := M.ball(head,face+Vector3(side*0.11,0.16,0.04),Vector3(0.09,0.25 if deer else 0.15,0.065),fur)
		ear.rotation.z = side*-0.35
		M.ball(head,face+Vector3(side*0.115,0.025,-0.07),Vector3(0.022,0.027,0.025),dark)
	for i in range(4):
		var x := (-1.0 if i%2==0 else 1.0)*(0.14 if deer else 0.09)
		var z := (-1.0 if i<2 else 1.0)*(0.31 if deer else 0.22)
		var upper := M.tapered(root,Vector3.ZERO,Vector3.UP,0.057 if deer else 0.037,0.035 if deer else 0.025,fur)
		var lower := M.tapered(root,Vector3.ZERO,Vector3.UP,0.030 if deer else 0.023,0.022 if deer else 0.019,fur)
		var hoof := M.ball(root,Vector3.ZERO,Vector3(0.065,0.075,0.10),dark)
		record.legs.append({"x":x,"z":z,"upper":upper,"lower":lower,"shoe":hoof,"height":height})
	if deer: M.ball(root,Vector3(0,height,0.51),Vector3(0.14,0.13,0.13),pale)
	else:
		M.tapered(root,Vector3(0,0.43,0.28),Vector3(0,0.29,0.79),0.09,0.07,fur)
		M.tapered(root,Vector3(0,0.29,0.79),Vector3(0,0.28,0.96),0.07,0.025,pale)

func bird(record: Dictionary) -> void:
	var root: Node3D = record.node
	var feather := M.toon(Color("495051"))
	M.ball(root,Vector3.ZERO,Vector3(0.14,0.12,0.32),feather)
	for side in [-1.0,1.0]:
		var pivot := Node3D.new()
		root.add_child(pivot)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3.ZERO,Vector3(side*0.65,0,0.06),Vector3(side*0.36,0,-0.21)]: surface.add_vertex(v)
		surface.generate_normals()
		M.mesh(pivot,surface.commit(),feather,Vector3.ZERO)
		record.wings.append({"node":pivot,"side":side})

func obstacle(root: Node3D) -> void:
	var orange := M.toon(Color("dc7635"),true)
	var white := M.toon(Color("e5dfcd"))
	for x in [-0.25,0.25]:
		M.box(root,Vector3(x,0.035,0),Vector3(0.25,0.07,0.25),M.toon(Color("454a43")))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.025
		cone.bottom_radius = 0.10
		cone.height = 0.44
		cone.radial_segments = 16
		M.mesh(root,cone,orange,Vector3(x,0.29,0))
		var band := CylinderMesh.new()
		band.top_radius = 0.057
		band.bottom_radius = 0.073
		band.height = 0.08
		M.mesh(root,band,white,Vector3(x,0.28,0))
	M.rod(root,Vector3(-0.36,0.10,0.21),Vector3(0.38,0.14,0.12),0.052,M.toon(Color("77614b")))

func animate(record: Dictionary, clock: float, speed: float) -> void:
	if record.kind=="walker":
		for i in range(2):
			var limb: Dictionary = record.legs[i]
			var phase := clock*4.6+i*PI
			var stride := sin(phase)*0.23 if speed>0.1 else 0.0
			var hip := Vector3(float(limb.side)*0.105,0.94,0)
			var foot := Vector3(float(limb.side)*0.105,0.055+maxf(0,cos(phase))*0.08 if speed>0.1 else 0.055,stride)
			var knee := (hip+foot)*0.5+Vector3(0,0,-0.08)
			M.place_rod(limb.upper,hip,knee)
			M.place_rod(limb.lower,knee,foot)
			limb.shoe.position = foot+Vector3(0,0,-0.03)
			var arm: Dictionary = record.arms[i]
			var shoulder := Vector3(float(arm.side)*0.20,1.44,0)
			var elbow := Vector3(float(arm.side)*0.23,1.15,-stride*0.65)
			var hand := Vector3(float(arm.side)*0.22,0.94,-stride)
			M.place_rod(arm.upper,shoulder,elbow)
			M.place_rod(arm.lower,elbow,hand)
			arm.hand.position = hand
	elif record.kind in ["deer","fox"]:
		for i in range(4):
			var limb: Dictionary = record.legs[i]
			var phase := clock*4+i*PI*0.5
			var move: float = sin(phase)*0.13 if speed>0.1 else 0.0
			var top := Vector3(limb.x,float(limb.height)-0.10,limb.z)
			var foot := Vector3(limb.x,0.04+maxf(0,cos(phase))*0.06,limb.z+move)
			var knee := (top+foot)*0.5+Vector3(0,0,0.05 if i<2 else -0.05)
			M.place_rod(limb.upper,top,knee)
			M.place_rod(limb.lower,knee,foot)
			limb.shoe.position = foot
		record.head.rotation.x = sin(clock*0.6)*0.14
	elif record.kind=="bird":
		for wing in record.wings: wing.node.rotation.z = sin(clock*7)*0.55*float(wing.side)
