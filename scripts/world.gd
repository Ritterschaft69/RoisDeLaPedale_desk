class_name CyclingWorld
extends Node3D

const M = preload("res://scripts/materials.gd")
const Scenery = preload("res://scripts/scenery.gd")
var route: CyclingRoute
var generated := Node3D.new()
var build_target := generated
var pending_chunk: Node3D
var generation := 0
var streaming := false
var cloud_cache: Mesh
signal stream_frame
var last_center := -10000.0
var noise := FastNoiseLite.new()
var road_material: Material
var grass_material: Material
var shoulder_material: Material
var stripe_material: Material
var quality := 1
var geographic := preload("res://scripts/geoworld.gd").new("")
var road_overlay := preload("res://scripts/terrain_overlay.gd").new()
var road_cells: Dictionary = {}
var tree_batches: Dictionary = {}
var terrain_samples: Array[Dictionary] = []
var terrain_cells: Dictionary = {}
var life: Node3D

func set_route(source: CyclingRoute) -> void:
	cancel_stream()
	route = source
	var path := "res://assets/geodata/circuits/"+str(route.data.source).get_basename()+"/world.json"
	geographic = preload("res://scripts/geoworld.gd").new(path if FileAccess.file_exists(path) else "res://assets/geodata/world.json")
	if not geographic.data.is_empty() and geographic.data.route_source_sha256 != route.data.source_sha256:
		geographic.data.clear()
		geographic.vegetation.clear()
		geographic.vegetation_cells.clear()
		geographic.building_bounds.clear()
		geographic.roads.clear()
		geographic.terrain_source = null
	road_cells.clear()
	for i in range(route.points.size()-1):
		var a: Dictionary = route.points[i]
		var b: Dictionary = route.points[i+1]
		for x in range(floori((minf(a.x,b.x)-8)/128),floori((maxf(a.x,b.x)+8)/128)+1):
			for z in range(floori((minf(a.z,b.z)-8)/128),floori((maxf(a.z,b.z)+8)/128)+1):
				var key := Vector2i(x,z)
				if not road_cells.has(key): road_cells[key] = []
				road_cells[key].append(i)
	last_center = -10000
	if life != null: life.set_route(self)

func setup(source: CyclingRoute) -> void:
	set_route(source)
	add_child(generated)
	noise.seed = 6914
	noise.frequency = 0.012
	road_material = M.asphalt()
	grass_material = M.toon(Color.WHITE)
	shoulder_material = M.asphalt(true)
	stripe_material = M.toon(Color("e6e1cf"))
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("388dca")
	atmosphere.sky_horizon_color = Color("c9dedf")
	atmosphere.ground_bottom_color = Color("667f51")
	atmosphere.ground_horizon_color = Color("c9dedf")
	sky.sky_material = atmosphere
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d7e2")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("bdd4dc")
	environment.fog_density = 0.00015
	environment.fog_sky_affect = 0.12
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47,-34,0)
	sun.light_color = Color("fff0d5")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2
	add_child(sun)
	life = preload("res://scripts/world_life.gd").new()
	add_child(life)
	life.set_route(self)

func cancel_stream() -> void:
	generation += 1
	streaming = false
	stream_frame.emit()
	if is_instance_valid(pending_chunk): pending_chunk.queue_free()
	pending_chunk = null
	build_target = generated

func _exit_tree() -> void:
	cancel_stream()

func stream_valid(ticket: int) -> bool:
	return ticket==generation and is_inside_tree()

func _process(_dt: float) -> void:
	if streaming: stream_frame.emit()

func next_stage(ticket: int) -> bool:
	if not stream_valid(ticket): return false
	await stream_frame
	return stream_valid(ticket)

func update_at(distance: float, force: bool = false) -> void:
	if not force and (streaming or absf(distance-last_center)<55): return
	cancel_stream()
	last_center = distance
	streaming = not force
	pending_chunk = Node3D.new()
	build_target = pending_chunk
	rebuild(distance,force,generation,pending_chunk)

func rebuild(distance: float, force: bool, ticket: int, target: Node3D) -> void:
	var tick: Signal = Signal() if force else stream_frame
	var guard := func(): return stream_valid(ticket)
	tree_batches.clear()
	road_overlay.clear()
	var start := maxf(route.start_m-48,floorf((distance-100)/6)*6)
	var end := minf(route.length_m,distance+(440 if quality>0 else 280))
	terrain_samples.clear()
	var s := start
	while s<end:
		terrain_samples.append({"s":s,"p":roadside(s,0)})
		s += 8
	terrain_samples.append({"s":end,"p":roadside(end,0)})
	terrain_cells.clear()
	for i in range(terrain_samples.size()-1):
		var a: Vector3 = terrain_samples[i].p
		var b: Vector3 = terrain_samples[i+1].p
		for x in range(floori((minf(a.x,b.x)-15)/32),floori((maxf(a.x,b.x)+15)/32)+1):
			for z in range(floori((minf(a.z,b.z)-15)/32),floori((maxf(a.z,b.z)+15)/32)+1):
				var key := Vector2i(x,z)
				if not terrain_cells.has(key): terrain_cells[key] = []
				terrain_cells[key].append(i)
	if force:geographic.prepare_junctions(self,roadside(distance,0))
	else:
		await geographic.prepare_junctions(self,roadside(distance,0),tick,guard)
		if not await next_stage(ticket):return
	if force: terrain(distance,start,end)
	else:
		await terrain(distance,start,end,tick,guard)
		if not await next_stage(ticket): return
	var surfaces := [SurfaceTool.new(),SurfaceTool.new(),SurfaceTool.new()]
	for surface in surfaces: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	s = start
	var road_budget := Time.get_ticks_usec()
	while s<end-0.01:
		if not force and Time.get_ticks_usec()-road_budget>6000:
			if not await next_stage(ticket): return
			road_budget = Time.get_ticks_usec()
		# Refine tight bends, retain a cheaper mesh on straight road sections.
		var angle := route.direction(s).angle_to(route.direction(minf(end,s+4)))
		var next := minf(minf(end,s+clampf(.08/maxf(angle/4,.0133),.75,3)),(floorf(s/3)+1)*3)
		quad(surfaces[0],s,next,-3.3,3.3,0.045)
		var left_junction := geographic.junction_at((s+next)*.5,-1)
		var right_junction := geographic.junction_at((s+next)*.5,1)
		quad(surfaces[0] if left_junction else surfaces[1],s,next,-3.95,-3.3,0.018)
		quad(surfaces[0] if right_junction else surfaces[1],s,next,3.3,3.95,0.018)
		if not left_junction:quad(surfaces[2],s,next,-3.03,-2.94,0.053)
		if not right_junction:quad(surfaces[2],s,next,2.94,3.03,0.053)
		if posmod(int(floor(s/3)),4)==0:
			quad(surfaces[2],s,next,-0.065,0.065,0.056)
		s = next
	for i in range(3):
		surfaces[i].generate_normals()
		var strip := M.mesh(build_target,surfaces[i].commit(),[road_material,shoulder_material,stripe_material][i],Vector3.ZERO)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not force and not await next_stage(ticket): return
	# Shared tree meshes and GPU instancing, with simpler silhouettes at distance.
	var spacing := 9 if quality>0 else 17
	for index in range(maxi(0,int(start/spacing)),int(end/spacing)):
		var rng := RandomNumberGenerator.new()
		rng.seed = index*7919+20261025
		for side in [-1,1]:
			for band in range(2 if quality>0 else 1):
				var lateral: float = side*rng.randf_range(8+band*27,30+band*30)
				var at := roadside(index*spacing,lateral,true)
				if (not geographic.covers(index*spacing) or geographic.forest(at)) and safe_land(at):
					var canopy := geographic.canopy_at(Vector2(at.x,at.z))
					var size := clampf(canopy/7,.65,3.5) if is_finite(canopy) else rng.randf_range(.8,1.35)
					tree(at,size,rng.randf()>0.35,absf(index*spacing-distance)<95,rng.randf()*TAU)
	for key in tree_batches:
		var batch: Dictionary = tree_batches[key]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.mesh = Scenery.tree_mesh(batch.kind,batch.detailed)
		instances.instance_count = batch.transforms.size()
		for i in range(batch.transforms.size()):
			instances.set_instance_transform(i,batch.transforms[i])
			instances.set_instance_color(i,batch.colors[i])
		var item := MultiMeshInstance3D.new()
		item.multimesh = instances
		item.material_override = grass_material
		if not batch.detailed: item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		build_target.add_child(item)
	if force: verges(start,end)
	else:
		await verges(start,end,tick,guard)
		if not await next_stage(ticket): return
	bridge_details(start,end)
	if not force and not await next_stage(ticket): return
	if force: backdrop(distance)
	else:
		await backdrop(distance,tick,guard)
		if not await next_stage(ticket): return
	if force: geographic.side_roads(build_target,self,roadside(distance,0))
	else:
		await geographic.side_roads(build_target,self,roadside(distance,0),tick,guard)
		if not await next_stage(ticket): return
	geographic.water_surfaces(build_target,roadside(distance,0))
	if force: geographic.buildings(build_target,distance,roadside(distance,0))
	else:
		await geographic.buildings(build_target,distance,roadside(distance,0),tick,guard)
		if not stream_valid(ticket): return
	var previous := generated
	generated = target
	add_child(generated)
	if previous.get_parent()==self: remove_child(previous)
	previous.queue_free()
	pending_chunk = null
	streaming = false
	build_target = generated
	if life != null: life.step(0,distance,0)

func roadside(s: float, lateral: float, terrain: bool = false) -> Vector3:
	var effective := maxf(route.start_m,s)
	var at: Vector3 = route.smooth_position(effective)
	var direction := route.direction(effective)
	if s<route.start_m: at += direction*(s-route.start_m)
	var right := Vector3(-direction.z,0,direction.x).normalized()
	at += right*lateral
	if terrain:
		if geographic.covers(s):
			var real_height: float = geographic.elevation_at(Vector2(at.x,at.z),s,lateral,at.y)
			at.y = lerpf(at.y,real_height,clampf((absf(lateral)-4.6)/8,0,1))
		else:
			at.y += noise.get_noise_2d(at.x,at.z)*minf(maxf(absf(lateral)-4.6,0)*0.22,12)
	return at

func nearest(point: Vector2, local_only: bool = false) -> Dictionary:
	var best := INF
	var result: Dictionary = {}
	var candidates: Array = terrain_cells.get(Vector2i(floori(point.x/32),floori(point.y/32)),[]) if local_only else range(terrain_samples.size()-1)
	for i in candidates:
		var a: Vector3 = terrain_samples[i].p
		var b: Vector3 = terrain_samples[i+1].p
		var v := Vector2(a.x,a.z)
		var w := Vector2(b.x,b.z)
		var delta := w-v
		var t := clampf((point-v).dot(delta)/maxf(delta.length_squared(),0.00001),0,1)
		var projected := v.lerp(w,t)
		var squared := point.distance_squared_to(projected)
		if squared<best:
			best = squared
			var right := Vector2(-delta.y,delta.x).normalized()
			result = {"s":lerpf(terrain_samples[i].s,terrain_samples[i+1].s,t),"cross":(point-projected).dot(right),"distance":sqrt(squared),"alt":lerpf(a.y,b.y,t)}
	return result

func terrain(distance: float, start: float, end: float, tick: Signal = Signal(), guard: Callable = Callable()) -> void:
	var budget := Time.get_ticks_usec()
	var centre: Vector3 = roadside(minf(route.length_m,distance+150),0)
	var points := PackedVector2Array()
	var heights: Array[float] = []
	var keys: Dictionary = {}
	var cell := (12 if geographic.terrain_source != null else 16) if quality>0 else 26
	var radius := 285 if quality>0 else 220
	for x in range(-radius,radius+1,cell):
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call(): return
			budget = Time.get_ticks_usec()
		for z in range(-radius,radius+1,cell):
			var p := Vector2(floorf(centre.x/cell)*cell+x,floorf(centre.z/cell)*cell+z)
			var n := nearest(p,geographic.terrain_source!=null)
			var y: float = geographic.elevation_at(p,float(n.get("s",distance)),float(n.get("cross",0)),centre.y)
			if not n.is_empty() and geographic.covers(n.s):
				var blend := 1.0 if route.structure_at(n.s)=="bridge" else clampf((float(n.distance)-4.4)/9,0,1)
				y = lerpf(float(n.alt),y,blend)
			elif geographic.terrain_source==null and not n.is_empty():
				y = n.alt
				y += noise.get_noise_2d(p.x,p.y)*minf(maxf(float(n.distance)-4.5,0)*0.22,15)
			terrain_point(points,heights,keys,p,y-0.025)
	var station := start
	while station<=end:
		if route.structure_at(station)!="bridge":
			for edge in [[-4.65,.035],[-3.95,.07],[0.0,.14],[3.95,.07],[4.65,.035]]:
				var p := roadside(station,float(edge[0]))
				terrain_point(points,heights,keys,Vector2(p.x,p.z),p.y-float(edge[1]))
		station += 3
	road_overlay.hull = Geometry2D.convex_hull(points)
	var indices := Geometry2D.triangulate_delaunay(points)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,indices.size(),3):
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call(): return
			budget = Time.get_ticks_usec()
		# Delaunay winding is unspecified; orient every triangle skywards before
		# averaging normals, otherwise neighbours cancel and the lawn flickers.
		var a := points[indices[i]]
		var b := points[indices[i+1]]
		var c := points[indices[i+2]]
		var winding := [0,1,2] if (b-a).cross(c-a)>0 else [0,2,1]
		road_overlay.add_triangle(Vector3(a.x,heights[indices[i]],a.y),Vector3(b.x,heights[indices[i+1]],b.y),Vector3(c.x,heights[indices[i+2]],c.y))
		for j in winding:
			var index := indices[i+j]
			var p := points[index]
			var variation := clampf(noise.get_noise_2d(p.x*2,p.y*2)*0.5+0.5,0,1)
			surface.set_color(Color("718e4e").lerp(Color("a1af6b"),variation).srgb_to_linear())
			surface.add_vertex(Vector3(p.x,heights[index],p.y))
	surface.generate_normals()
	var ground := M.mesh(build_target,surface.commit(),grass_material,Vector3.ZERO)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func terrain_point(points: PackedVector2Array, heights: Array[float], keys: Dictionary, p: Vector2, y: float) -> void:
	var key := Vector2i(roundi(p.x*100),roundi(p.y*100))
	if keys.has(key): return
	keys[key] = points.size()
	points.append(p)
	heights.append(y)

func safe_land(at: Vector3) -> bool:
	if not clear_of_road(at,6.4): return false
	return not geographic.building_at(Vector2(at.x,at.z))

func clear_of_road(at: Vector3, margin: float) -> bool:
	for i in road_cells.get(Vector2i(floori(at.x/128),floori(at.z/128)),[]):
		var a: Dictionary = route.points[i]
		var b: Dictionary = route.points[i+1]
		var p := Vector2(at.x,at.z)
		var v := Vector2(a.x,a.z)
		var w := Vector2(b.x,b.z)
		var t := clampf((p-v).dot(w-v)/maxf(v.distance_squared_to(w),0.00001),0,1)
		if p.distance_to(v.lerp(w,t))<margin: return false
	return true

func quad(surface: SurfaceTool, a: float, b: float, left: float, right: float, lift: float) -> void:
	var corners := [roadside(a,left),roadside(b,left),roadside(b,right),roadside(a,right)]
	var uv := [Vector2(left,a),Vector2(left,b),Vector2(right,b),Vector2(right,a)]
	for i in [0,1,2,0,2,3]:
		surface.set_uv(uv[i])
		surface.add_vertex(corners[i]+Vector3.UP*lift)

func tree(at: Vector3, size: float, evergreen: bool, detailed: bool = true, yaw: float = 0.0) -> void:
	var kind := (0 if evergreen else 2)+posmod(roundi(at.x+at.z),2)
	var key := "%s:%s:%s:%s" % [kind,detailed,floori(at.x/96.0),floori(at.z/96.0)]
	if not tree_batches.has(key): tree_batches[key] = {"kind":kind,"detailed":detailed,"transforms":[],"colors":[]}
	tree_batches[key].transforms.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),at))
	tree_batches[key].colors.append(Color.WHITE.lerp(Color("c3ccac"),fposmod(at.x*0.71,0.2)))

func verges(start: float, end: float, tick: Signal = Signal(), guard: Callable = Callable()) -> void:
	var budget := Time.get_ticks_usec()
	var rock_material := M.toon(Color("8d8979"),true)
	var plant := SurfaceTool.new()
	plant.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(maxi(0,int(start/4)),int(end/4)):
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call(): return
			budget = Time.get_ticks_usec()
		if route.structure_at(index*4)=="bridge": continue
		var rng := RandomNumberGenerator.new()
		rng.seed = index*2311+405
		for side in [-1.0,1.0]:
			var at := roadside(index*4,side*rng.randf_range(4.9,7),true)
			if geographic.building_at(Vector2(at.x,at.z)): continue
			for blade in range(3):
				var angle := rng.randf()*TAU
				var base := at+Vector3(rng.randf_range(-0.5,0.5),0,rng.randf_range(-0.5,0.5))
				var width := Vector3(cos(angle),0,sin(angle))*0.065
				plant.set_color(Color("6c853e").srgb_to_linear())
				for v in [base-width,base+width,base+Vector3(0.10,rng.randf_range(0.15,0.45),0.03)]: plant.add_vertex(v)
			if index%12 == 0:
				var rock_at := roadside(index*4,side*rng.randf_range(6.6,11),true)
				if safe_land(rock_at):
					var rock := M.mesh(build_target,Scenery.rock_mesh(index%3),rock_material,rock_at)
					rock.scale = Vector3(1.3,0.65,1.0)*rng.randf_range(0.55,1.6)
					rock.rotation.y = rng.randf()*TAU
			# White delineator posts, infrequent and entirely outside the pavement.
			if index%15 == 0:
				var post_at := roadside(index*4,side*4.1)
				M.box(build_target,post_at+Vector3.UP*0.45,Vector3(0.12,0.9,0.13),M.toon(Color("d9d5bf")))
				M.box(build_target,post_at+Vector3.UP*0.70,Vector3(0.13,0.12,0.14),M.toon(Color("bd633a")))
	plant.generate_normals()
	M.mesh(build_target,plant.commit(),grass_material,Vector3.ZERO)
	# Rural fence sections are decorative, not surveyed geographic objects.
	for index in range(maxi(0,int(start/80)),int(end/80)):
		if index%3!=1: continue
		var station := index*80.0
		var side := -1.0 if index%2==0 else 1.0
		var wood := M.toon(Color("807257"))
		for j in range(5):
			var at := roadside(station+j*3,side*6.7,true)
			if not safe_land(at): continue
			M.box(build_target,at+Vector3.UP*0.5,Vector3(0.10,1,0.10),wood)
			if j<4:
				var next := roadside(station+(j+1)*3,side*6.7,true)
				for height in [0.42,0.78]: M.rod(build_target,at+Vector3.UP*height,next+Vector3.UP*height,0.025,wood)
	stone_walls(start,end)

func bridge_details(start: float, end: float) -> void:
	var material := M.toon(Color("8a9090"))
	for structure in route.geography.get("structures",[]):
		if structure.kind!="bridge" or float(structure.end_m)<start or float(structure.start_m)>end: continue
		var s := maxf(start,float(structure.start_m))
		var last := minf(end,float(structure.end_m))
		while s<last:
			var next := minf(last,s+6)
			for side in [-1.0,1.0]:
				var a := roadside(s,side*3.5)
				var b := roadside(next,side*3.5)
				M.rod(build_target,a+Vector3.UP*.05,a+Vector3.UP*.95,.045,material)
				M.rod(build_target,a+Vector3.UP*.92,b+Vector3.UP*.92,.045,material)
				M.rod(build_target,a-Vector3.UP*.08,b-Vector3.UP*.08,.14,material)
			s = next

func stone_walls(start: float, end: float) -> void:
	var transforms: Array[Transform3D] = []
	for index in range(maxi(0,int(start/80)),int(end/80)):
		if index%3!=0: continue
		var station := index*80.0
		if geographic.covers(station): continue
		var side := -1.0 if index%2==0 else 1.0
		for block in range(18):
			for row in range(3):
				var s := station+block+row%2*0.45
				var at := roadside(s,side*4.35)
				var direction := route.direction(s)
				var angles := Vector3(0,-atan2(direction.z,direction.x),0)
				var scale_size := Vector3(1.18,0.43,0.75)
				at.y += 0.10+row*0.28
				transforms.append(Transform3D(Basis.from_euler(angles).scaled(scale_size),at))
	if transforms.is_empty(): return
	var stones := MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	stones.mesh = Scenery.rock_mesh(1)
	stones.instance_count = transforms.size()
	for i in range(transforms.size()): stones.set_instance_transform(i,transforms[i])
	var wall := MultiMeshInstance3D.new()
	wall.multimesh = stones
	wall.material_override = M.toon(Color("929184"))
	build_target.add_child(wall)

func backdrop(distance: float, tick: Signal = Signal(), guard: Callable = Callable()) -> void:
	var budget := Time.get_ticks_usec()
	var center: Vector3 = roadside(distance,0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [260.0,440.0,730.0,1100.0,1700.0]
	if geographic.terrain_source != null and not geographic.terrain_source.horizon.is_empty():
		radii.append_array([2500.0,4000.0,7000.0,11000.0,16000.0])
	# Sample each ring vertex once, instead of six times per quad.
	var segments := 128 if quality>0 else 64
	var ring_vertices := PackedVector3Array()
	for ring in range(radii.size()):
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call(): return
			budget = Time.get_ticks_usec()
		for i in range(segments+1):
			var r: float = radii[ring]
			var angle := i*TAU/segments
			var at := center+Vector3(cos(angle)*r,0,sin(angle)*r)
			at.y = center.y-70 if ring==0 else center.y-18+(noise.get_noise_2d(at.x*.10,at.z*.10)+.45)*minf(r*.24,240)
			if geographic.terrain_source != null:
				at.y = geographic.elevation_at(Vector2(at.x,at.z),distance,0,at.y)-.06
			var tint := Color("728c74").lerp(Color("94b0b5"),float(ring)/(radii.size()-1))
			surface.set_color(tint.srgb_to_linear())
			surface.add_vertex(at)
			ring_vertices.append(at)
	var next_vertex := ring_vertices.size()
	for ring in range(radii.size()-1):
		for i in range(segments):
			if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
				await tick
				if not guard.is_valid() or not guard.call():return
				budget=Time.get_ticks_usec()
			var a := ring*(segments+1)+i
			var b := a+segments+1
			if ring>=2:
				for index in [a,b,b+1,a,b+1,a+1]:surface.add_index(index)
				continue
			# The coarse horizon must not poke through the near terrain. Trim its
			# inner bands and stitch their boundary to the actual near mesh.
			for face in [[a,b,b+1],[a,b+1,a+1]]:
				var triangle := PackedVector3Array([ring_vertices[face[0]],ring_vertices[face[1]],ring_vertices[face[2]]])
				var polygon := PackedVector2Array()
				for p in triangle:polygon.append(Vector2(p.x,p.z))
				for piece in Geometry2D.clip_polygons(polygon,road_overlay.hull):
					var indices := Geometry2D.triangulate_polygon(piece)
					for j in range(0,indices.size(),3):
						var actual := PackedVector3Array()
						var order := [indices[j],indices[j+1],indices[j+2]]
						if (piece[order[1]]-piece[order[0]]).cross(piece[order[2]]-piece[order[0]])<0:order.reverse()
						for vertex in order:
							var p: Vector2 = piece[vertex]
							var y: float = road_overlay.height(p,true)
							if not is_finite(y):y=road_overlay.plane_height(p,triangle)
							var v := Vector3(p.x,y,p.y)
							var blend := clampf((p.distance_to(Vector2(center.x,center.z))-radii[ring])/(radii[ring+1]-radii[ring]),0,1)
							var tint := Color("728c74").lerp(Color("94b0b5"),(ring+blend)/(radii.size()-1))
							surface.set_color(tint.srgb_to_linear());surface.add_vertex(v);surface.add_index(next_vertex)
							next_vertex+=1;actual.append(v)
						road_overlay.add_triangle(actual[0],actual[1],actual[2],true)

	surface.generate_normals()
	var hills := M.mesh(build_target,surface.commit(),grass_material,Vector3.ZERO)
	hills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if cloud_cache!=null:
		var cached := M.mesh(build_target,cloud_cache,grass_material,center)
		cached.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	var clouds := SurfaceTool.new()
	clouds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cloud_index in range(6):
		var angle := cloud_index*TAU/6+0.35
		var origin := Vector3(cos(angle)*850,145+cloud_index%3*20,sin(angle)*850)
		for lobe in range(6):
			var at := origin+Vector3((lobe-2.5)*30,sin(lobe*2.1)*12,cos(lobe)*12)
			Scenery.append_shape(clouds,Scenery.sphere(16,8),at,Vector3(95,50+posmod(lobe*17,42),65),Color("f1eee1"))
	cloud_cache = clouds.commit()
	var cloud_mesh := M.mesh(build_target,cloud_cache,grass_material,center)
	cloud_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
