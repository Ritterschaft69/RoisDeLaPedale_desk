class_name GeographicWorld
extends RefCounted

const M = preload("res://scripts/materials.gd")
var data: Dictionary = {}
var vegetation: Array[Dictionary] = []
var building_bounds: Array[Dictionary] = []
var vegetation_cells: Dictionary = {}
var terrain_source: RefCounted
var roads: Array = []
var building_cells: Dictionary = {}
var geometry_cache: Dictionary = {}
var geometry_order: Array[String] = []
var last_building_candidates := 0
var vegetation_ready := false
var road_cells: Dictionary = {}
var road_segments := PackedInt64Array()
var road_shapes: Dictionary = {}
var road_shape_order: Array[int] = []
var junctions: Array[Dictionary] = []
var forest_data: Dictionary = {}
var forest_tiles: Dictionary = {}
var forest_cache: Dictionary = {}
var forest_order: Array[Vector2i] = []
var forest_directory := ""
var last_forest_triangles := 0
const CELL := 128.0

func index_bounds(index: Dictionary, bounds: Rect2, item: int) -> void:
	for x in range(floori(bounds.position.x/CELL),floori(bounds.end.x/CELL)+1):
		for z in range(floori(bounds.position.y/CELL),floori(bounds.end.y/CELL)+1):
			var key := Vector2i(x,z)
			if not index.has(key): index[key] = []
			index[key].append(item)

func nearby_buildings(center: Vector2, radius: float) -> Array:
	var found: Dictionary = {}
	for x in range(floori((center.x-radius)/CELL),floori((center.x+radius)/CELL)+1):
		for z in range(floori((center.y-radius)/CELL),floori((center.y+radius)/CELL)+1):
			for item in building_cells.get(Vector2i(x,z),[]): found[item] = true
	return found.keys()
var ground_material := M.toon(Color("c6c0a5"))
var glass_material := M.toon(Color("465d60"))

func _init(path: String = "res://assets/geodata/world.json") -> void:
	if not FileAccess.file_exists(path): return
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data.get("schema",1)==2:
		terrain_source = preload("res://scripts/ign_terrain.gd").new(data.terrain_transform)
		var roads_path := path.get_base_dir()+"/"+str(data.roads_file)
		if FileAccess.file_exists(roads_path):
			roads = JSON.parse_string(FileAccess.get_file_as_string(roads_path)).roads
			for road_index in range(roads.size()):
				var road: Dictionary = roads[road_index]
				for i in range(road.points.size()-1):
					var a: Array = road.points[i]
					var b: Array = road.points[i+1]
					var box := Rect2(Vector2(a[0],a[2]),Vector2.ZERO).expand(Vector2(b[0],b[2]))
					road_segments.append((road_index<<32)|i)
					index_bounds(road_cells,box,road_segments.size()-1)
	forest_directory=path.get_base_dir()+"/"
	var forest_path := forest_directory+"forest.json"
	if FileAccess.file_exists(forest_path):
		var prepared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(forest_path))
		if prepared.get("route_source_sha256","")==data.get("route_source_sha256",""):
			forest_data=prepared
			for tile in forest_data.tiles:
				forest_tiles[Vector2i(roundi(float(tile.x)/float(forest_data.tile_size_m)),roundi(float(tile.z)/float(forest_data.tile_size_m)))]=tile
	for building in data.buildings:
		var ring := PackedVector2Array()
		for p in building.footprint: ring.append(Vector2(p[0],p[1]))
		var bounds := Rect2(ring[0],Vector2.ZERO)
		for p in ring: bounds = bounds.expand(p)
		building_bounds.append({"ring":ring,"bounds":bounds.grow(0.5)})
		index_bounds(building_cells,bounds.grow(.5),building_bounds.size()-1)
	if terrain_source==null: prepare_vegetation()

func prepare_vegetation() -> void:
	if vegetation_ready: return
	vegetation_ready = true
	for zone in data.vegetation:
		var rings: Array[PackedVector2Array] = []
		for source_ring in zone.rings:
			var ring := PackedVector2Array()
			for p in source_ring: ring.append(Vector2(p[0],p[1]))
			rings.append(ring)
		var bounds := Rect2(rings[0][0],Vector2.ZERO)
		for p in rings[0]: bounds = bounds.expand(p)
		vegetation.append({"rings":rings,"bounds":bounds,"nature":zone.nature})
		for x in range(floori(bounds.position.x/256),floori(bounds.end.x/256)+1):
			for z in range(floori(bounds.position.y/256),floori(bounds.end.y/256)+1):
				var key := Vector2i(x,z)
				if not vegetation_cells.has(key): vegetation_cells[key] = []
				vegetation_cells[key].append(vegetation.size()-1)

func elevation_at(point: Vector2, station: float, cross: float, fallback: float) -> float:
	if terrain_source == null: return elevation(station,cross,fallback)
	var height: float = terrain_source.height(point)
	return height if is_finite(height) else fallback

func canopy_at(point: Vector2) -> float:
	if terrain_source == null: return NAN
	return terrain_source.height(point,"mnh")

func building_at(point: Vector2) -> bool:
	if data.is_empty(): return false
	for index in building_cells.get(Vector2i(floori(point.x/CELL),floori(point.y/CELL)),[]):
		var building: Dictionary = building_bounds[index]
		if building.bounds.has_point(point) and Geometry2D.is_point_in_polygon(point,building.ring): return true
	return false

func covers(station: float) -> bool:
	return not data.is_empty() and station >= float(data.coverage.start_m)-.01 and station <= float(data.coverage.end_m)+.01

func elevation(station: float, cross: float, fallback: float) -> float:
	if not covers(station): return fallback
	if terrain_source != null: return fallback # Numeric tiles require actual world coordinates.
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
	var canopy := canopy_at(p)
	if is_finite(canopy): return canopy>=3.0
	prepare_vegetation()
	for index in vegetation_cells.get(Vector2i(floori(p.x/256),floori(p.y/256)),[]):
		var zone: Dictionary = vegetation[index]
		if not zone.bounds.has_point(p): continue
		if not Geometry2D.is_point_in_polygon(p,zone.rings[0]): continue
		var hole := false
		for i in range(1,zone.rings.size()):
			if Geometry2D.is_point_in_polygon(p,zone.rings[i]): hole = true
		if not hole: return true
	return false

func buildings(parent: Node3D, station: float, center: Vector3 = Vector3.INF, tick: Signal = Signal(), guard: Callable = Callable()) -> void:
	var budget := Time.get_ticks_usec()
	if data.is_empty(): return
	var candidates: Array = nearby_buildings(Vector2(center.x,center.z),420) if center.is_finite() else range(data.buildings.size())
	last_building_candidates = candidates.size()
	var batches: Dictionary = {}
	for index in candidates:
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call(): return
			budget = Time.get_ticks_usec()
		var building: Dictionary = data.buildings[index]
		var detailed := false
		if center.is_finite() and data.get("schema",1)==2:
			var distance := Vector2(center.x,center.z).distance_to(Vector2(building.center[0],building.center[1]))
			if distance>420: continue
			detailed = distance<160
		else:
			if float(building.station)<station-100 or float(building.station)>station+380: continue
			detailed = absf(float(building.station)-station)<180
		var key := str(building.id)+str(detailed)
		if not geometry_cache.has(key):
			var holder := Node3D.new()
			build(holder,building,detailed)
			var pieces: Array = []
			if holder.get_child_count()>0:
				var house := holder.get_child(0)
				for child in house.get_children():
					if child is MeshInstance3D:
						pieces.append({"mesh":child.mesh,"material":child.material_override,"transform":house.transform*child.transform})
			holder.free()
			geometry_cache[key] = pieces
			geometry_order.append(key)
			if geometry_order.size()>2048: geometry_cache.erase(geometry_order.pop_front())
		for piece in geometry_cache[key]:
			var material: Material = piece.material
			# Spatial batches retain frustum culling behind the camera.
			var batch_key := str(material.get_instance_id())+":"+str(floori(float(building.center[0])/128))+":"+str(floori(float(building.center[1])/128))
			if not batches.has(batch_key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[batch_key] = {"surface":surface,"material":material}
			for surface_index in range(piece.mesh.get_surface_count()):
				batches[batch_key].surface.append_from(piece.mesh,surface_index,piece.transform)
	for batch in batches.values():
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call(): return
			budget = Time.get_ticks_usec()
		var material: Material = batch.material
		var mesh := M.mesh(parent,batch.surface.commit(),material,Vector3.ZERO)
		mesh.name = "BuildingsBatch"
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if material.next_pass!=null else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func road_style(tags: Dictionary) -> Dictionary:
	var kind: String = tags.get("highway","")
	var narrow := kind in ["path","footway","cycleway","track","pedestrian"]
	var width := 1.8 if narrow else 5.0
	if kind=="track":width=2.6
	elif kind in ["primary","secondary","tertiary"]:width=6.0
	elif kind in ["service","living_street"]:width=3.5
	var lanes := str(tags.get("lanes",""))
	if not narrow and lanes.is_valid_int():width=clampf(float(lanes)*2.8+.4,2.5,10)
	var explicit_width := str(tags.get("width","")).replace(",",".").get_slice(" ",0)
	if explicit_width.is_valid_float():width=clampf(float(explicit_width),1,12)
	var finish: String = tags.get("surface","")
	var dirt := finish in ["unpaved","gravel","fine_gravel","ground","dirt","earth","grass","sand","compacted"] or (finish=="" and kind in ["path","track","footway"])
	var marked := not dirt and not narrow and kind not in ["service","living_street","residential"] and width>=4.8
	return {"width":width,"dirt":dirt,"marked":marked,"center_marked":marked and width>=5.5,"shoulder":.35 if not narrow else .15}

func road_shape(index: int) -> Dictionary:
	if road_shapes.has(index):return road_shapes[index]
	var source: Array = roads[index].points
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	var stations := PackedFloat32Array()
	for i in range(source.size()):
		var p := Vector2(source[i][0],source[i][2])
		if i>0 and i<source.size()-1:
			var previous := Vector2(source[i-1][0],source[i-1][2])
			var next := Vector2(source[i+1][0],source[i+1][2])
			p+=((previous+next-2*p)*.25).limit_length(.45)
		points.append(p)
		stations.append(0 if i==0 else stations[i-1]+p.distance_to(points[i-1]))
	for i in range(points.size()):
		var before := (points[i]-points[maxi(0,i-1)]).normalized()
		var after := (points[mini(i+1,points.size()-1)]-points[i]).normalized()
		if before==Vector2.ZERO:before=after
		if after==Vector2.ZERO:after=before
		var edge := Vector2(-after.y,after.x)
		var join := Vector2(-(before+after).y,(before+after).x).normalized()
		normals.append(join/maxf(absf(join.dot(edge)),.5) if join!=Vector2.ZERO else edge)
	var shape := {"points":points,"normals":normals,"stations":stations,"style":road_style(roads[index].tags)}
	road_shapes[index]=shape;road_shape_order.append(index)
	if road_shape_order.size()>64:road_shapes.erase(road_shape_order.pop_front())
	return shape

func road_strip(overlay: RefCounted, surface: SurfaceTool, shape: Dictionary, i: int, left: float, right: float, lift: float, t0: float = 0, t1: float = 1) -> int:
	var a: Vector2 = shape.points[i].lerp(shape.points[i+1],t0)
	var b: Vector2 = shape.points[i].lerp(shape.points[i+1],t1)
	var n0: Vector2 = shape.normals[i].lerp(shape.normals[i+1],t0)
	var n1: Vector2 = shape.normals[i].lerp(shape.normals[i+1],t1)
	var forward := (b-a).normalized()
	var polygon := PackedVector2Array([a+n0*left,b+n1*left,b+n1*right,a+n0*right])
	return overlay.paint(surface,polygon,lift,a,forward,Vector2(-forward.y,forward.x),lerpf(shape.stations[i],shape.stations[i+1],t0))

func road_candidates(center: Vector3) -> Array:
	var result: Dictionary = {}
	for x in range(floori((center.x-440)/CELL),floori((center.x+440)/CELL)+1):
		for z in range(floori((center.z-440)/CELL),floori((center.z+440)/CELL)+1):
			for item in road_cells.get(Vector2i(x,z),[]):result[item]=true
	return result.keys()

func prepare_junctions(world: Node3D, center: Vector3, tick: Signal = Signal(), guard: Callable = Callable()) -> void:
	junctions.clear()
	var budget := Time.get_ticks_usec()
	for item in road_candidates(center):
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call():return
			budget=Time.get_ticks_usec()
		var packed: int = road_segments[item]
		var tags: Dictionary = roads[packed>>32].tags
		if str(tags.get("bridge","no")) not in ["no","false","0"] or str(tags.get("tunnel","no")) not in ["no","false","0"] or str(tags.get("layer","0"))!="0":continue
		var shape := road_shape(packed>>32)
		if shape.style.dirt:continue
		var i := int(packed&0xffffffff)
		var a: Vector2 = shape.points[i]
		var b: Vector2 = shape.points[i+1]
		var n: Dictionary = world.nearest((a+b)*.5,true)
		if n.is_empty() or n.distance>8:continue
		if world.route.structure_at(n.s)!="":continue
		var direction: Vector3 = world.route.direction(n.s)
		var main := Vector2(direction.x,direction.z).normalized()
		var branch := (b-a).normalized()
		if absf(main.dot(branch))>.8:continue
		var na: Dictionary = world.nearest(a,true)
		var nb: Dictionary = world.nearest(b,true)
		if na.is_empty() or nb.is_empty() or minf(na.distance,nb.distance)>5.5:continue
		var left := minf(na.cross,nb.cross)<-1.5
		var right := maxf(na.cross,nb.cross)>1.5
		if not left and not right:continue
		var half: float = shape.style.width*.5/maxf(absf(main.cross(branch)),.4)+1.0
		var start: float = n.s-half
		var end: float = n.s+half
		var merged := false
		for junction in junctions:
			if junction.left==left and junction.right==right and junction.end>=start and junction.start<=end:
				junction.start=minf(junction.start,start);junction.end=maxf(junction.end,end);merged=true;break
		if not merged:junctions.append({"start":start,"end":end,"left":left,"right":right})

func junction_at(station: float, side: int) -> bool:
	for junction in junctions:
		if station>=junction.start and station<=junction.end and (junction.left if side<0 else junction.right):return true
	return false

func side_roads(parent: Node3D, world: Node3D, center: Vector3, tick: Signal = Signal(), guard: Callable = Callable()) -> void:
	var budget := Time.get_ticks_usec()
	if roads.is_empty():return
	var surfaces := [SurfaceTool.new(),SurfaceTool.new(),SurfaceTool.new(),SurfaceTool.new()]
	var counts := [0,0,0,0]
	for surface in surfaces:surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in road_candidates(center):
		if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
			await tick
			if not guard.is_valid() or not guard.call():return
			budget=Time.get_ticks_usec()
		var packed: int = road_segments[item]
		var shape := road_shape(packed>>32)
		var i := int(packed&0xffffffff)
		var a: Vector2 = shape.points[i]
		var b: Vector2 = shape.points[i+1]
		if a.distance_to(Vector2(center.x,center.z))>430 and b.distance_to(Vector2(center.x,center.z))>430:continue
		if a.distance_squared_to(b)<.001:continue
		# Only suppress segments wholly inside the ridden carriageway. Testing
		# just a midpoint used to remove the end of intersecting side roads.
		var na: Dictionary = world.nearest(a,true)
		var nb: Dictionary = world.nearest(b,true)
		if not na.is_empty() and not nb.is_empty() and na.distance<2.6 and nb.distance<2.6:continue
		var style: Dictionary = shape.style
		var half: float = style.width*.5
		var base := 1 if style.dirt else 0
		counts[base]+=road_strip(world.road_overlay,surfaces[base],shape,i,-half,half,.025)
		counts[2]+=road_strip(world.road_overlay,surfaces[2],shape,i,-half-style.shoulder,-half,.018)
		counts[2]+=road_strip(world.road_overlay,surfaces[2],shape,i,half,half+style.shoulder,.018)
		if style.marked:
			for side in [-1,1]:
				counts[3]+=road_strip(world.road_overlay,surfaces[3],shape,i,side*(half-.20)-.035,side*(half-.20)+.035,.031)
			var start: float = shape.stations[i]
			var end: float = shape.stations[i+1]
			var dash := floorf(start/12)*12
			while style.center_marked and dash<end:
				var lo := maxf(start,dash)
				var hi := minf(end,dash+3)
				if hi>lo:counts[3]+=road_strip(world.road_overlay,surfaces[3],shape,i,-.055,.055,.032,(lo-start)/(end-start),(hi-start)/(end-start))
				dash+=12
	for i in range(4):
		if counts[i]==0:continue
		surfaces[i].generate_normals()
		var node := M.mesh(parent,surfaces[i].commit(),[world.road_material,world.shoulder_material,world.shoulder_material,world.stripe_material][i],Vector3.ZERO)
		node.name=["SecondaryAsphalt","SecondaryTracks","SecondaryShoulders","SecondaryMarkings"][i]
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func water_surfaces(parent: Node3D, center: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for water in data.get("water",[]):
		var polygon := PackedVector2Array()
		var nearby := false
		for p in water.points:
			var at := Vector2(p[0],p[2])
			polygon.append(at)
			if at.distance_to(Vector2(center.x,center.z))<650: nearby=true
		if not nearby: continue
		var indices: Array = water.indices
		for i in range(0,indices.size(),3):
			var a := polygon[indices[i]]
			var b := polygon[indices[i+1]]
			var c := polygon[indices[i+2]]
			var winding := [0,1,2] if (b-a).cross(c-a)>0 else [0,2,1]
			for j in winding:
				var p: Array = water.points[indices[i+j]]
				surface.add_vertex(Vector3(p[0],p[1],p[2]))
			count += 1
	if count>0:
		surface.generate_normals()
		var mesh := M.mesh(parent,surface.commit(),M.toon(Color("4d8998")),Vector3.ZERO)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	var wall_tint: Color = palette[rng.randi_range(0,palette.size()-1)].srgb_to_linear()
	var wall_material := M.facade()
	var roof_material := M.toon(Color("786754") if rng.randf()>0.45 else Color("855b4c"),false,true)
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
			var repeats := maxi(1,mini(6,int(a.distance_to(b)/2.8)))
			for index in winding:
				var vertex: Vector3 = vertices[index]
				var along := Vector2(vertex.x,vertex.z).distance_to(a)/maxf(a.distance_to(b),.01)
				walls.set_color(wall_tint)
				walls.set_uv(Vector2(along*repeats,1.0-vertex.y/2.7))
				walls.set_uv2(Vector2(vertex.y,eave if detailed else 0.0))
				walls.add_vertex(vertex)
	walls.generate_normals()
	M.mesh(node,walls.commit(),wall_material,Vector3.ZERO)
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

func forest_masses(parent: Node3D, center: Vector3, quality: int, ground_height: Callable, tick: Signal = Signal(), guard: Callable = Callable()) -> void:
	last_forest_triangles=0
	if forest_data.is_empty():return
	var radius := 1450.0 if quality>0 else 550.0
	var size := float(forest_data.tile_size_m)
	var file := FileAccess.open(forest_directory+str(forest_data.file),FileAccess.READ)
	if file==null:return
	var budget := Time.get_ticks_usec()
	for x in range(floori((center.x-radius)/size),floori((center.x+radius)/size)+1):
		for z in range(floori((center.z-radius)/size),floori((center.z+radius)/size)+1):
			if not tick.is_null() and Time.get_ticks_usec()-budget>6000:
				await tick
				if not guard.is_valid() or not guard.call():return
				budget=Time.get_ticks_usec()
			var key := Vector2i(x,z)
			if not forest_tiles.has(key):continue
			var tile: Dictionary = forest_tiles[key]
			if Vector2(tile.x+size*.5,tile.z+size*.5).distance_to(Vector2(center.x,center.z))>radius+size*.5:continue
			if not forest_cache.has(key):
				file.seek(int(tile.offset))
				var block := file.get_buffer(int(tile.byte_length)).decompress(int(tile.vertices)*16,FileAccess.COMPRESSION_GZIP)
				var loaded := block.to_float32_array()
				if loaded.size()!=int(tile.vertices)*4:continue
				forest_cache[key]=loaded;forest_order.append(key)
				if forest_order.size()>192:forest_cache.erase(forest_order.pop_front())
			var packed: PackedFloat32Array = forest_cache[key]
			var vertices := PackedVector3Array();var normals := PackedVector3Array()
			vertices.resize(int(tile.vertices));normals.resize(int(tile.vertices))
			var projected: Dictionary = {}
			for i in range(int(tile.vertices)):
				if i%192==0 and not tick.is_null() and Time.get_ticks_usec()-budget>6000:
					await tick
					if not guard.is_valid() or not guard.call():return
					budget=Time.get_ticks_usec()
				var p := Vector2(packed[i*4],packed[i*4+2])
				var position_key := Vector2i(roundi(p.x*100),roundi(p.y*100))
				if not projected.has(position_key):
					var visible_height: float = ground_height.call(p)
					projected[position_key]=visible_height-packed[i*4+3] if is_finite(visible_height) else 0.0
				vertices[i]=Vector3(p.x,packed[i*4+1]+float(projected[position_key]),p.y)
			for i in range(0,vertices.size(),3):
				var normal := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
				if normal.y<0:normal=-normal
				for j in range(3):normals[i+j]=normal
			var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
			var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var item := M.mesh(parent,mesh,M.forest_canopy(),Vector3.ZERO)
			item.name="ForestParcel_%d_%d"%[x,z]
			item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			last_forest_triangles+=int(tile.vertices)/3

func forest_fraction(p: Vector2) -> float:
	if forest_data.is_empty():return 0.0
	var size := float(forest_data.tile_size_m)
	var tile: Dictionary = forest_tiles.get(Vector2i(floori(p.x/size),floori(p.y/size)),{})
	return float(tile.get("forest_fraction",0.0))
