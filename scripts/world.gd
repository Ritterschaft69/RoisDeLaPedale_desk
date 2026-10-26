class_name CyclingWorld
extends Node3D

const M = preload("res://scripts/materials.gd")
var route: CyclingRoute
var generated := Node3D.new()
var last_center := -10000.0
var noise := FastNoiseLite.new()
var tree_material: Material
var trunk_material: Material
var road_material: Material
var grass_material: Material
var shoulder_material: Material
var stripe_material: Material
var quality := 1
var geographic := preload("res://scripts/geoworld.gd").new()
var road_cells: Dictionary = {}

func set_route(source: CyclingRoute) -> void:
	route = source
	# Reload the original cache on every selection so returning to Saint-Dié
	# restores its IGN data after another route used illustrative scenery.
	geographic = preload("res://scripts/geoworld.gd").new()
	if not geographic.data.is_empty() and geographic.data.route_source_sha256 != route.data.source_sha256:
		geographic.data.clear()
		geographic.vegetation.clear()
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

func setup(source: CyclingRoute) -> void:
	set_route(source)
	add_child(generated)
	noise.seed = 6914
	noise.frequency = 0.014
	tree_material = M.toon(Color("3d6953"))
	trunk_material = M.toon(Color("655747"))
	road_material = M.toon(Color("555e60"))
	grass_material = M.toon(Color("8aa669"))
	shoulder_material = M.toon(Color("b5af8d"))
	stripe_material = M.toon(Color("ece6cc"))
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("4b91be")
	atmosphere.sky_horizon_color = Color("c7dcd7")
	atmosphere.ground_bottom_color = Color("53654e")
	atmosphere.ground_horizon_color = Color("c7dcd7")
	sky.sky_material = atmosphere
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d4e0")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("b6d4d5")
	environment.fog_density = 0.0016
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 2.0
	add_child(sun)

func update_at(distance: float, force: bool = false) -> void:
	if not force and absf(distance-last_center) < 45: return
	last_center = distance
	for child in generated.get_children():
		generated.remove_child(child)
		child.queue_free()
	# Visual apron before the start keeps the chase camera and rear wheel over
	# ground. It is not added to GPX distance, altitude samples or progress.
	var start := maxf(-48, floorf((distance-100)/8)*8)
	var end := minf(route.length_m, distance + (450 if quality > 0 else 260))
	var surfaces := [SurfaceTool.new(),SurfaceTool.new(),SurfaceTool.new(),SurfaceTool.new()]
	for surface in surfaces: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := start
	while s < end-0.01:
		var next := minf(end,s+6)
		quad(surfaces[0],s,next,-3.3,3.3,0.035)
		quad(surfaces[1],s,next,-4.8,-3.3,0.005)
		quad(surfaces[1],s,next,3.3,4.8,0.005)
		for lane in [[-150.0,-90.0],[-90.0,-45.0],[-45.0,-12.0],[-12.0,-4.8],[4.8,12.0],[12.0,45.0],[45.0,90.0],[90.0,150.0]]:
			quad(surfaces[2],s,next,lane[0],lane[1],-0.02,true)
		# Road markings are geometry above road, no z-fighting.
		quad(surfaces[3],s,next,-3.05,-2.96,0.045)
		quad(surfaces[3],s,next,2.96,3.05,0.045)
		if int(s/6)%2 == 0:
			quad(surfaces[3],s,minf(s+3,next),-0.055,0.055,0.048)
		s = next
	var materials := [road_material,shoulder_material,grass_material,stripe_material]
	for i in range(surfaces.size()):
		surfaces[i].generate_normals()
		var strip := M.mesh(generated,surfaces[i].commit(),materials[i],Vector3.ZERO)
		# This illustrative strip receives object shadows but should not shadow
		# itself with a nearly coplanar shoulder/paint mesh.
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Decorative vegetation is explicitly illustrative, not claimed as IGN/OSM.
	var step := 10 if quality > 0 else 20
	for index in range(maxi(0,int(start/step)),int(end/step)):
		var rng := RandomNumberGenerator.new()
		rng.seed = index * 7919 + 20261025
		for side in [-1,1]:
			var lateral: float = side * rng.randf_range(9,60)
			var at := roadside(index*step,lateral,true)
			if (not geographic.covers(index*step) or geographic.forest(at)) and clear_of_road(at,6.5):
				tree(at,rng.randf_range(0.8,1.8),rng.randf() > 0.28)
	geographic.buildings(generated,distance)

func roadside(s: float, lateral: float, terrain: bool = false) -> Vector3:
	var at: Vector3 = route.sample(s).position
	var direction := route.direction(maxf(0,s))
	if s < 0: at += direction*s
	var right := Vector3(-direction.z,0,direction.x).normalized()
	at += right*lateral
	if terrain:
		if geographic.covers(s):
			var real_height: float = geographic.elevation(s,lateral,at.y)
			at.y = lerpf(at.y,real_height,clampf((absf(lateral)-4.8)/7.2,0,1))
		else:
			at.y += noise.get_noise_2d(at.x,at.z) * minf(maxf(absf(lateral)-4.8,0)*0.38,18)
	return at

func clear_of_road(at: Vector3, margin: float) -> bool:
	# Check whole source track, including hairpins and crossings, not just the
	# segment that generated the tree. Avoid trunks on another part of the road.
	for i in road_cells.get(Vector2i(floori(at.x/128),floori(at.z/128)),[]):
		var a: Dictionary = route.points[i]
		var b: Dictionary = route.points[i+1]
		var p := Vector2(at.x,at.z)
		var v := Vector2(a.x,a.z)
		var w := Vector2(b.x,b.z)
		var t := clampf((p-v).dot(w-v)/maxf(v.distance_squared_to(w),0.00001),0,1)
		if p.distance_to(v.lerp(w,t)) < margin: return false
	return true

func quad(surface: SurfaceTool, a: float, b: float, left: float, right: float, lift: float, terrain: bool = false) -> void:
	var corners := [roadside(a,left,terrain),roadside(b,left,terrain),roadside(b,right,terrain),roadside(a,right,terrain)]
	for i in [0,1,2,0,2,3]:
		surface.add_vertex(corners[i]+Vector3.UP*lift)

func tree(at: Vector3, size: float, evergreen: bool) -> void:
	var trunk := CylinderMesh.new()
	trunk.height = 5*size
	trunk.top_radius = 0.12*size
	trunk.bottom_radius = 0.23*size
	trunk.radial_segments = 7
	M.mesh(generated,trunk,trunk_material,at+Vector3.UP*2.5*size)
	if evergreen:
		for i in range(3):
			var crown := CylinderMesh.new()
			crown.top_radius = 0
			crown.bottom_radius = (2.3-i*0.5)*size
			crown.height = (4-i*0.5)*size
			crown.radial_segments = 9
			M.mesh(generated,crown,tree_material,at+Vector3.UP*(3.5+i*1.5)*size)
	else:
		M.ball(generated,at+Vector3.UP*5.4*size,Vector3(4,4.6,3.6)*size,tree_material)
