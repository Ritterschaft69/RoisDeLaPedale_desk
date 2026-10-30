class_name TerrainOverlay
extends RefCounted

## Paint geometry on the rendered triangles, not on the higher-resolution IGN
## samples: their interpolated heights differ from the terrain's actual mesh.
const CELL := 32.0
var near_triangles: Array[PackedVector3Array] = []
var far_triangles: Array[PackedVector3Array] = []
var near_cells: Dictionary = {}
var far_cells: Dictionary = {}
var hull := PackedVector2Array()

func clear() -> void:
	near_triangles.clear();far_triangles.clear()
	near_cells.clear();far_cells.clear();hull.clear()

func add_triangle(a: Vector3, b: Vector3, c: Vector3, distant: bool = false) -> void:
	var triangles := far_triangles if distant else near_triangles
	var cells := far_cells if distant else near_cells
	var index := triangles.size()
	triangles.append(PackedVector3Array([a,b,c]))
	var bounds := Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).expand(Vector2(c.x,c.z))
	for x in range(floori(bounds.position.x/CELL),floori(bounds.end.x/CELL)+1):
		for z in range(floori(bounds.position.y/CELL),floori(bounds.end.y/CELL)+1):
			var key := Vector2i(x,z)
			if not cells.has(key):cells[key]=[]
			cells[key].append(index)

func add_mesh(mesh: Mesh, distant: bool = false, maximum_triangles: int = 0) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var size := indices.size() if not indices.is_empty() else vertices.size()
	if maximum_triangles>0:size=mini(size,maximum_triangles*3)
	for i in range(0,size,3):
		add_triangle(vertices[indices[i] if not indices.is_empty() else i],vertices[indices[i+1] if not indices.is_empty() else i+1],vertices[indices[i+2] if not indices.is_empty() else i+2],distant)

func candidates(polygon: PackedVector2Array, distant: bool) -> Array:
	if polygon.is_empty():return []
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for p in polygon:bounds=bounds.expand(p)
	var cells := far_cells if distant else near_cells
	var result: Dictionary = {}
	for x in range(floori(bounds.position.x/CELL),floori(bounds.end.x/CELL)+1):
		for z in range(floori(bounds.position.y/CELL),floori(bounds.end.y/CELL)+1):
			for index in cells.get(Vector2i(x,z),[]):result[index]=true
	return result.keys()

static func weights(p: Vector2, triangle: PackedVector3Array) -> Vector2:
	var a := Vector2(triangle[0].x,triangle[0].z)
	var b := Vector2(triangle[1].x,triangle[1].z)-a
	var c := Vector2(triangle[2].x,triangle[2].z)-a
	var q := p-a
	var determinant := b.cross(c)
	if absf(determinant)<.0000001:return Vector2(INF,INF)
	return Vector2(q.cross(c),b.cross(q))/determinant

static func plane_height(p: Vector2, triangle: PackedVector3Array) -> float:
	var uv := weights(p,triangle)
	return triangle[0].y*(1-uv.x-uv.y)+triangle[1].y*uv.x+triangle[2].y*uv.y

func height(p: Vector2, near_only: bool = false) -> float:
	for distant in ([false] if near_only else [false,true]):
		var cells := far_cells if distant else near_cells
		var triangles := far_triangles if distant else near_triangles
		for index in cells.get(Vector2i(floori(p.x/CELL),floori(p.y/CELL)),[]):
			var uv := weights(p,triangles[index])
			if uv.x>=-.0001 and uv.y>=-.0001 and uv.x+uv.y<=1.0001:return plane_height(p,triangles[index])
	return NAN

func paint(surface: SurfaceTool, polygon: PackedVector2Array, lift: float, origin: Vector2, forward: Vector2, side: Vector2, station: float) -> int:
	var count := 0
	# Near and far terrain overlap: retain the near surface within its hull.
	for distant in [false,true]:
		var pieces: Array[PackedVector2Array] = [polygon]
		if distant and not hull.is_empty():pieces=Geometry2D.clip_polygons(polygon,hull)
		var triangles := far_triangles if distant else near_triangles
		for piece in pieces:
			for index in candidates(piece,distant):
				var tri: PackedVector3Array = triangles[index]
				var triangle := PackedVector2Array()
				var local := PackedVector2Array()
				for p in tri:triangle.append(Vector2(p.x,p.z)-origin)
				for p in piece:local.append(p-origin)
				for clipped in Geometry2D.intersect_polygons(local,triangle):
					if clipped.size()<3:continue
					var faces := Geometry2D.triangulate_polygon(clipped)
					for j in range(0,faces.size(),3):
						var order := [faces[j],faces[j+1],faces[j+2]]
						if (clipped[order[1]]-clipped[order[0]]).cross(clipped[order[2]]-clipped[order[0]])<0:order.reverse()
						var actual := PackedVector3Array()
						for vertex in order:
							var p: Vector2 = clipped[vertex]+origin
							actual.append(Vector3(p.x,plane_height(p,tri)+lift,p.y))
						# Tiny clipping slivers can collapse after float32 quantisation at
						# coordinates tens of kilometres from the route origin.
						var area := Vector2(actual[1].x-actual[0].x,actual[1].z-actual[0].z).cross(Vector2(actual[2].x-actual[0].x,actual[2].z-actual[0].z))
						if absf(area)<.01:continue
						if area<0:actual.reverse()
						for v in actual:
							var p := Vector2(v.x,v.z)
							surface.set_uv(Vector2((p-origin).dot(side),station+(p-origin).dot(forward)))
							surface.add_vertex(v)
						count+=1
	return count
