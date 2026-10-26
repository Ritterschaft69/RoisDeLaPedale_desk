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
void fragment() { ALBEDO = tint.rgb; ROUGHNESS = 1.0; }
void light() {
 float n = dot(NORMAL, LIGHT);
 float band = n > 0.65 ? 1.0 : (n > 0.05 ? 0.65 : 0.25);
 DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / 3.14159265;
}
"""
	var material := ShaderMaterial.new()
	if no_shadows:
		shader_toon.code = shader_toon.code.replace("render_mode specular_disabled, cull_disabled;", "render_mode specular_disabled, cull_disabled, shadows_disabled;")
	material.shader = shader_toon
	material.set_shader_parameter("tint",color)
	if outline:
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, cull_front; void vertex(){ VERTEX += NORMAL * 0.009; } void fragment(){ ALBEDO = vec3(0.055, 0.085, 0.09); }"
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
