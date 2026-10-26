class_name CyclingMaterials
extends RefCounted
static var cache: Dictionary = {}

static func toon(color: Color, outline: bool = false, no_shadows: bool = false) -> ShaderMaterial:
	var key := color.to_html()+str(outline)+str(no_shadows)
	if cache.has(key): return cache[key]
	var shader_toon := Shader.new()
	shader_toon.code = """shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() { ALBEDO = tint.rgb * COLOR.rgb; ROUGHNESS = 1.0; }
void light() {
 float n = dot(NORMAL, LIGHT);
 float band = n > 0.65 ? 1.0 : (n > 0.05 ? 0.65 : 0.25);
 DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / 3.14159265;
}
"""
	var material := ShaderMaterial.new()
	if no_shadows:
		shader_toon.code = shader_toon.code.replace("render_mode specular_disabled, cull_disabled;", "render_mode specular_disabled, cull_disabled, shadows_disabled;")
	material.shader = shader_toon
	material.set_shader_parameter("tint",color)
	if outline:
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, cull_front; void vertex(){ VERTEX += NORMAL * 0.0035; } void fragment(){ ALBEDO = vec3(0.045, 0.065, 0.075); }"
		var ink := ShaderMaterial.new()
		ink.shader = shader
		material.next_pass = ink
	cache[key] = material
	return material

static func mesh(parent: Node3D, shape: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

static func ball(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	var instance := mesh(parent, sphere, material, at)
	instance.scale = size
	return instance

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 1
	cylinder.radial_segments = 10
	var instance := mesh(parent, cylinder, material, Vector3.ZERO)
	place_rod(instance, a, b)
	return instance

static func place_rod(instance: Node3D, a: Vector3, b: Vector3) -> void:
	var direction := b - a
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	instance.scale = Vector3(1, maxf(direction.length(), 0.001), 1)

static func tapered(parent: Node3D, a: Vector3, b: Vector3, from_radius: float, to_radius: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = from_radius
	shape.top_radius = to_radius
	shape.height = 1
	shape.radial_segments = 16
	var instance := mesh(parent,shape,material,Vector3.ZERO)
	place_rod(instance,a,b)
	return instance

static func box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return mesh(parent,shape,material,at)

static func loft(parent: Node3D, rings: Array, material: Material, segments: int = 24) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size()-1):
		for j in range(segments):
			var corners: Array[Vector3] = []
			for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
				var ring: Dictionary = rings[pair[0]]
				var angle: float = pair[1]*TAU/segments
				corners.append(ring.center+Vector3(cos(angle)*float(ring.width),0,sin(angle)*float(ring.depth)))
			for index in [0,2,1,0,3,2]: surface.add_vertex(corners[index])
	surface.generate_normals()
	return mesh(parent,surface.commit(),material,Vector3.ZERO)

static func asphalt(gravel: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode specular_disabled, cull_disabled;
varying vec3 world_position;
float noise_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 cell = world_position.xz * 70.0;
 float fade = 1.0-smoothstep(0.6,2.0,length(fwidth(cell)));
 float grain = (noise_hash(floor(cell))-0.5)*0.09*fade;
 float wear = -0.008*exp(-pow((abs(UV.x)-1.6)/0.45,2.0));
 ALBEDO = vec3(0.26,0.27,0.275)+grain+wear;
 ROUGHNESS = 0.98;
}
void light() {
 float band = dot(NORMAL,LIGHT)>0.35 ? 1.0 : 0.55;
 DIFFUSE_LIGHT += LIGHT_COLOR*ATTENUATION*band/3.14159265;
}
"""
	material.shader = shader
	if gravel:
		shader.code = shader.code.replace("world_position.xz * 70.0","world_position.xz * 28.0").replace("vec3(0.26,0.27,0.275)","vec3(0.30,0.28,0.22)")
	return material
