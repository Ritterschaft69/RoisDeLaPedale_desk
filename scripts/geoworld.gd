class_name GeographicWorld
extends RefCounted

const M = preload("res://scripts/materials.gd")
var data: Dictionary = {}
var vegetation: Array[Dictionary] = []
var building_bounds: Array[Dictionary] = []
var ground_material := M.toon(Color("c6c0a5"))
var glass_material := M.toon(Color("465d60"))

func _init() -> void:
	var path := "res://assets/geodata/world.json"
	if not FileAccess.file_exists(path): return
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for building in data.buildings:
		var ring := PackedVector2Array()
		for p in building.footprint: ring.append(Vector2(p[0],p[1]))
		var bounds := Rect2(ring[0],Vector2.ZERO)
		for p in ring: bounds = bounds.expand(p)
		building_bounds.append({"ring":ring,"bounds":bounds.grow(0.5)})
	for zone in data.vegetation:
		var rings: Array[PackedVector2Array] = []
		for source_ring in zone.rings:
			var ring := PackedVector2Array()
			for p in source_ring: ring.append(Vector2(p[0],p[1]))
			rings.append(ring)
		var bounds := Rect2(rings[0][0],Vector2.ZERO)
		for p in rings[0]: bounds = bounds.expand(p)
		vegetation.append({"rings":rings,"bounds":bounds,"nature":zone.nature})

func building_at(point: Vector2) -> bool:
	if data.is_empty(): return false
	for building in building_bounds:
		if building.bounds.has_point(point) and Geometry2D.is_point_in_polygon(point,building.ring): return true
	return false

func covers(station: float) -> bool:
	return not data.is_empty() and station >= data.coverage.start_m and station <= data.coverage.end_m

func elevation(station: float, cross: float, fallback: float) -> float:
	if not covers(station): return fallback
	var rows: Array = data.terrain.rows
	var lo := 0
	var hi := rows.size()-1
	while lo+1<hi:
		var mid := (lo+hi)/2
		if rows[mid].s <= station: lo = mid
		else: hi = mid
	var t: float = clampf((station-float(rows[lo].s))/maxf(1,float(rows[hi].s)-float(rows[lo].s)),0,1)
	return lerpf(row_height(rows[lo],cross),row_height(rows[hi],cross),t)

func row_height(row: Dictionary, cross: float) -> float:
	var samples: Array = row.samples
	for i in range(samples.size()-1):
		if cross <= float(samples[i+1].cross):
			var t := clampf((cross-float(samples[i].cross))/(float(samples[i+1].cross)-float(samples[i].cross)),0,1)
			return lerpf(samples[i].ign_altitude,samples[i+1].ign_altitude,t)+float(row.render_vertical_offset)
	return float(samples[-1].ign_altitude)+float(row.render_vertical_offset)

func forest(at: Vector3) -> bool:
	var p := Vector2(at.x,at.z)
	for zone in vegetation:
		if not zone.bounds.has_point(p): continue
		if not Geometry2D.is_point_in_polygon(p,zone.rings[0]): continue
		var hole := false
		for i in range(1,zone.rings.size()):
			if Geometry2D.is_point_in_polygon(p,zone.rings[i]): hole = true
		if not hole: return true
	return false

func buildings(parent: Node3D, station: float) -> void:
	if data.is_empty(): return
	for building in data.buildings:
		if float(building.station)<station-100 or float(building.station)>station+380: continue
		build(parent,building,absf(float(building.station)-station)<180)

func build(parent: Node3D, building: Dictionary, detailed: bool) -> void:
	var polygon := PackedVector2Array()
	var center := Vector2(building.center[0],building.center[1])
	for p in building.footprint: polygon.append(Vector2(p[0],p[1])-center)
	if Geometry2D.triangulate_polygon(polygon).is_empty(): return
	var node := Node3D.new()
	node.name = str(building.id).replace(":","_")
	parent.add_child(node)
	node.position = Vector3(center.x,building.base_render,center.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = building.seed
	var palette := [Color("d3c4a6"),Color("d8d0b9"),Color("c5bc9b"),Color("d4c5b6")]
	var wall_material := M.toon(palette[rng.randi_range(0,palette.size()-1)],detailed,true)
	var roof_material := M.toon(Color("786754") if rng.randf()>0.45 else Color("855b4c"),detailed,true)
	var axis := Vector2.RIGHT
	var longest := 0.0
	for i in range(polygon.size()):
		var edge := polygon[(i+1)%polygon.size()]-polygon[i]
		if edge.length_squared()>longest:
			longest = edge.length_squared()
			axis = edge.normalized()
	var across := Vector2(-axis.y,axis.x)
	var minimum := INF
	var maximum := -INF
	for p in polygon:
		minimum = minf(minimum,p.dot(across))
		maximum = maxf(maximum,p.dot(across))
	var ridge := (minimum+maximum)*0.5
	var half_width := maxf(0.5,(maximum-minimum)*0.5)
	var rise := minf(float(building.height)*0.30,half_width*0.55)
	var eave := maxf(2.2,float(building.height)-rise)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facade := SurfaceTool.new()
	facade.begin(Mesh.PRIMITIVE_TRIANGLES)
	var facade_vertices := 0
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var split := PackedVector2Array([a,b])
		var da := a.dot(across)-ridge
		var db := b.dot(across)-ridge
		if (da>0) != (db>0): split.insert(1,a.lerp(b,da/(da-db)))
		for j in range(split.size()-1):
			var p := split[j]
			var q := split[j+1]
			var a_top := eave+rise*(1-absf(p.dot(across)-ridge)/half_width)
			var b_top := eave+rise*(1-absf(q.dot(across)-ridge)/half_width)
			var vertices := [Vector3(p.x,-1,p.y),Vector3(q.x,-1,q.y),Vector3(q.x,b_top,q.y),Vector3(p.x,a_top,p.y)]
			var winding := [0,2,1,0,3,2] if Geometry2D.is_polygon_clockwise(polygon) else [0,1,2,0,2,3]
			for index in winding: walls.add_vertex(vertices[index])
		if detailed: facade_vertices += windows(facade,a,b,eave,Geometry2D.is_polygon_clockwise(polygon),int(building.seed),i==0)
	walls.generate_normals()
	M.mesh(node,walls.commit(),wall_material,Vector3.ZERO)
	if facade_vertices>0:
		M.mesh(node,facade.commit(),M.toon(Color.WHITE,false,true),Vector3.ZERO)
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sign_side in [-1.0,1.0]:
		var clipped := clip_ridge(polygon,across,ridge,sign_side)
		var indices := Geometry2D.triangulate_polygon(clipped)
		for index in indices:
			var p := clipped[index]
			roof.add_vertex(Vector3(p.x,eave+rise*(1-absf(p.dot(across)-ridge)/half_width),p.y))
	roof.generate_normals()
	var roof_mesh := M.mesh(node,roof.commit(),roof_material,Vector3.ZERO)
	if detailed and float(building.height)>4 and longest>36:
		var chimney_at := axis*sqrt(longest)*0.16
		var chimney_y := eave+rise*(1-absf(chimney_at.dot(across)-ridge)/half_width)
		M.box(node,Vector3(chimney_at.x,chimney_y+0.6,chimney_at.y),Vector3(0.55,1.2,0.55),M.toon(Color("9a8d77")))
		M.box(node,Vector3(chimney_at.x,chimney_y+1.23,chimney_at.y),Vector3(0.68,0.12,0.68),M.toon(Color("655f53")))
	# Irregular source polygons can have either winding; surface normals are
	# generated, while two-sided materials preserve both source orientations.
	if not detailed:
		roof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func windows(surface: SurfaceTool, a: Vector2, b: Vector2, height: float, clockwise: bool, seed_value: int, entrance: bool) -> int:
	var length := a.distance_to(b)
	if length<3: return 0
	var direction := (b-a).normalized()
	var normal := Vector2(-direction.y,direction.x)*(1.0 if clockwise else -1.0)
	var angles := Vector3(0,-atan2(direction.y,direction.x),0)
	var count := mini(6,int(length/2.8))
	var shutter := Color("526759") if seed_value%2==0 else Color("79554b")
	var shape := BoxMesh.new()
	shape.size = Vector3.ONE
	for floor_index in range(mini(3,maxi(1,int(height/3)))):
		for i in range(count):
			var at := a.lerp(b,float(i+1)/(count+1))
			var y := 1.65+floor_index*2.7
			var center := Vector3(at.x,y,at.y)+Vector3(normal.x,0,normal.y)*0.08
			if entrance and i==0 and floor_index==0:
				center.y = 1.05
				preload("res://scripts/scenery.gd").append_shape(surface,shape,center,Vector3(1.05,2.1,0.18),Color("e7ddc4"),angles)
				preload("res://scripts/scenery.gd").append_shape(surface,shape,center+Vector3(normal.x,0,normal.y)*0.10,Vector3(0.82,1.95,0.09),shutter,angles)
				continue
			preload("res://scripts/scenery.gd").append_shape(surface,shape,center,Vector3(1.02,1.32,0.12),Color("e4dcc4"),angles)
			preload("res://scripts/scenery.gd").append_shape(surface,shape,center+Vector3(normal.x,0,normal.y)*0.08,Vector3(0.82,1.11,0.08),Color("455b60"),angles)
			for side in [-1.0,1.0]:
				var panel_at: Vector3 = center+Vector3(direction.x,0,direction.y)*side*0.65
				preload("res://scripts/scenery.gd").append_shape(surface,shape,panel_at,Vector3(0.23,1.2,0.10),shutter,angles)
			preload("res://scripts/scenery.gd").append_shape(surface,shape,center+Vector3(normal.x,0,normal.y)*0.14,Vector3(0.035,1.12,0.03),Color("c7bfa6"),angles)
	return count

func clip_ridge(polygon: PackedVector2Array, normal: Vector2, offset: float, side: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var da := (a.dot(normal)-offset)*side
		var db := (b.dot(normal)-offset)*side
		if da>=0: result.append(a)
		if (da>=0) != (db>=0): result.append(a.lerp(b,da/(da-db)))
	return result
