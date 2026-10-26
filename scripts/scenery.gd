class_name CyclingScenery
extends RefCounted

const M = preload("res://scripts/materials.gd")
static var trees: Dictionary = {}
static var rocks: Dictionary = {}

static func append_shape(surface: SurfaceTool, shape: Mesh, at: Vector3, scale_size: Vector3, color: Color, angles: Vector3 = Vector3.ZERO) -> void:
	var arrays := shape.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var transform := Transform3D(Basis.from_euler(angles).scaled(scale_size),at)
	var normal_matrix := transform.basis.inverse().transposed()
	var tint := color.srgb_to_linear()
	for i in range(indices.size() if not indices.is_empty() else vertices.size()):
		var index := indices[i] if not indices.is_empty() else i
		surface.set_color(tint)
		surface.set_normal((normal_matrix*normals[index]).normalized())
		surface.add_vertex(transform*vertices[index])

static func sphere(segments: int = 14, rings_count: int = 7) -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radial_segments = segments
	shape.rings = rings_count
	return shape

static func tree_mesh(kind: int, detailed: bool = true) -> ArrayMesh:
	var key := str(kind)+str(detailed)
	if trees.has(key): return trees[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1497+kind*291
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.bottom_radius = 0.22
	trunk.top_radius = 0.055
	trunk.height = 6.9
	trunk.radial_segments = 9
	append_shape(surface,trunk,Vector3(0,3.45,0),Vector3.ONE,Color("6c5843"))
	if kind < 2:
		var levels := 6 if detailed else 4
		for level in range(levels):
			var t := float(level)/levels
			var radius := lerpf(2.05,0.42,t)
			var y := lerpf(2.1,6.5,t)
			var leaves := CylinderMesh.new()
			leaves.bottom_radius = radius
			leaves.top_radius = 0.04
			leaves.height = lerpf(2.8,1.8,t)
			leaves.radial_segments = 14 if detailed else 9
			var color := Color("345e48").lerp(Color("658958"),t*0.65)
			append_shape(surface,leaves,Vector3(0,y,0),Vector3(1,1,0.90),color)
			if detailed:
				for branch in range(3):
					var angle := branch*TAU/3+level*1.12+kind
					var at := Vector3(cos(angle)*radius*0.43,y-0.27,sin(angle)*radius*0.43)
					append_shape(surface,leaves,at,Vector3(0.62,0.54,0.62),color.darkened(rng.randf_range(0,0.13)),Vector3(0,angle,0))
	else:
		var branch := CylinderMesh.new()
		branch.height = 1
		branch.bottom_radius = 0.10
		branch.top_radius = 0.035
		branch.radial_segments = 8
		var count := 9 if detailed else 5
		for i in range(count):
			var angle := i*2.39996
			var radius := rng.randf_range(0.8,1.7)
			var at := Vector3(cos(angle)*radius,5.4+rng.randf_range(-0.8,1.6),sin(angle)*radius)
			if detailed:
				var a := Vector3(0,3.8,0)
				var direction := at-a
				var rotation := Quaternion(Vector3.UP,direction.normalized()).get_euler()
				append_shape(surface,branch,(a+at)*0.5,Vector3(1,direction.length(),1),Color("6c5843"),rotation)
			var color := Color("638445").lerp(Color("a1ac61"),rng.randf_range(0,0.40))
			append_shape(surface,sphere(16 if detailed else 10,8 if detailed else 5),at,Vector3(2.8,2.8,2.6)*rng.randf_range(0.85,1.20),color)
	var mesh := surface.commit()
	trees[key] = mesh
	return mesh

static func rock_mesh(kind: int) -> ArrayMesh:
	if rocks.has(kind): return rocks[kind]
	var source := sphere(12,6)
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var v := vertices[i]
		var wave := 1+sin(v.x*13+kind)*cos(v.z*9+kind)*0.13
		vertices[i] = Vector3(v.x*wave,maxf(-0.24,v.y*wave),v.z*wave)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	rocks[kind] = mesh
	return mesh
