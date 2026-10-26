## Smooth, closed parametric surfaces used only by the cyclist.
## Dimensions are metres; the longitudinal axis of a sweep is local +Y.
extends RefCounted
const M = preload("res://scripts/materials.gd")

static func finish(parent: Node3D, vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, material: Material) -> MeshInstance3D:
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_INDEX] = indices
 var shape := ArrayMesh.new()
 shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return M.mesh(parent,shape,material,Vector3.ZERO)

static func fabric(color: Color, roughness: float = .85) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.roughness = roughness
 material.metallic_specular = .22
 return material

static func radii(profile: Array, t: float) -> Vector2:
 var i := 0
 while i<profile.size()-2 and float(profile[i+1][0])<t: i+=1
 var a: Array = profile[maxi(0,i-1)]
 var b: Array = profile[i]
 var c: Array = profile[i+1]
 var d: Array = profile[mini(profile.size()-1,i+2)]
 var span := float(c[0])-float(b[0])
 var u := clampf((t-float(b[0]))/span,0,1)
 var first := Vector2(b[1],b[2])
 var last := Vector2(c[1],c[2])
 var m0 := (Vector2(c[1],c[2])-Vector2(a[1],a[2]))*span/(float(c[0])-float(a[0]))
 var m1 := (Vector2(d[1],d[2])-Vector2(b[1],b[2]))*span/(float(d[0])-float(b[0]))
 return (first*(2*u*u*u-3*u*u+1) + m0*(u*u*u-2*u*u+u) + last*(-2*u*u*u+3*u*u) + m1*(u*u*u-u*u)).max(Vector2(.001,.001))

static func sweep(parent: Node3D, profile: Array, material: Material, rings: int = 48, sides: int = 32) -> MeshInstance3D:
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var indices := PackedInt32Array()
 for i in range(rings+1):
  var t := float(i)/rings
  var radius := radii(profile,t)
  var lo := maxf(0,t-.0005)
  var hi := minf(1,t+.0005)
  var slope := (radii(profile,hi)-radii(profile,lo))/(hi-lo)
  for j in range(sides):
   var angle := TAU*j/sides
   var c := cos(angle)
   var s := sin(angle)
   vertices.append(Vector3(radius.x*c,t-.5,radius.y*s))
   normals.append(Vector3(radius.y*c,-radius.y*slope.x*c*c-radius.x*slope.y*s*s,radius.x*s).normalized())
   if i<rings:
    var a := i*sides+j
    var b := (i+1)*sides+j
    var c_index := (i+1)*sides+(j+1)%sides
    var d := i*sides+(j+1)%sides
    indices.append_array(PackedInt32Array([a,c_index,b,a,d,c_index]))
 # Independent cap normals prevent either end looking hollow.
 for end in [0,1]:
  var start := vertices.size()
  var t := float(end)
  var radius := radii(profile,t)
  var normal := Vector3.DOWN if end==0 else Vector3.UP
  vertices.append(Vector3(0,t-.5,0)); normals.append(normal)
  for j in range(sides):
   var angle := TAU*j/sides
   vertices.append(Vector3(radius.x*cos(angle),t-.5,radius.y*sin(angle))); normals.append(normal)
  for j in range(sides):
   var a := start+1+j
   var b := start+1+(j+1)%sides
   indices.append_array(PackedInt32Array([start,b,a] if end==0 else [start,a,b]))
 return finish(parent,vertices,normals,indices,material)

static func ellipsoid(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
 var shape := SphereMesh.new()
 shape.radial_segments = 48
 shape.rings = 24
 var result := M.mesh(parent,shape,material,at)
 result.scale = dimensions
 return result

static func helmet(parent: Node3D, at: Vector3, material: Material) -> MeshInstance3D:
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var indices := PackedInt32Array()
 var rows := 64
 var cols := 64
 # A continuous white dome with real openings, above a recessed foam liner.
 for i in range(rows+1):
  var z := lerpf(-.167,.167,float(i)/rows)
  var width := sqrt(maxf(.0001,1-pow(z/.17,2)))
  for j in range(cols+1):
   var a := lerpf(-PI/2,PI/2,float(j)/cols)
   var p := Vector3(.135*width*sin(a),.125*width*cos(a),z)
   vertices.append(p)
   normals.append(Vector3(p.x/(.135*.135),p.y/(.125*.125),p.z/(.17*.17)).normalized())
 for i in range(rows):
  for j in range(cols):
   var z := lerpf(-.167,.167,(float(i)+.5)/rows)
   var a := absf(lerpf(-PI/2,PI/2,(float(j)+.5)/cols))
   var opening := false
   for centre in [.26,.71,1.17]:
    for station in [-.073,.066]:
     if pow((a-centre)/.115,2)+pow((z-station)/.052,2)<1: opening=true
   if opening: continue
   var v := i*(cols+1)+j
   indices.append_array(PackedInt32Array([v,v+cols+2,v+cols+1,v,v+1,v+cols+2]))
 var result := finish(parent,vertices,normals,indices,material)
 result.position = at
 return result

static func tube(parent: Node3D, path: Array, radius: float, material: Material) -> MeshInstance3D:
 var vertices := PackedVector3Array()
 var normals := PackedVector3Array()
 var indices := PackedInt32Array()
 var sides := 10
 for i in range(path.size()):
  var tangent: Vector3 = path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]
  var frame := Quaternion(Vector3.UP,tangent.normalized())
  for j in range(sides):
   var angle := TAU*j/sides
   var normal := frame*Vector3(cos(angle),0,sin(angle))
   vertices.append(path[i]+normal*radius); normals.append(normal)
   if i<path.size()-1:
    var a := i*sides+j
    var b := (i+1)*sides+j
    var c := (i+1)*sides+(j+1)%sides
    var d := i*sides+(j+1)%sides
    indices.append_array(PackedInt32Array([a,c,b,a,d,c]))
 var result := finish(parent,vertices,normals,indices,material)
 result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return result

static func path(points: Array) -> Curve3D:
 var curve := Curve3D.new()
 curve.bake_interval = .005
 for i in range(points.size()):
  var tangent: Vector3 = (points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)])/6.0
  if i==0: tangent=(points[1]-points[0])/3.0
  if i==points.size()-1: tangent=(points[-1]-points[-2])/3.0
  curve.add_point(points[i],-tangent,tangent)
 return curve

static func frame(curve: Curve3D, t: float) -> Transform3D:
 var length := curve.get_baked_length()
 var s := clampf(t,0,1)*length
 var before := curve.sample_baked(maxf(0,s-.001),true)
 var after := curve.sample_baked(minf(length,s+.001),true)
 return Transform3D(Basis(Quaternion(Vector3.UP,(after-before).normalized())),curve.sample_baked(s,true))

static func side_normals(vertices: PackedVector3Array, normals: PackedVector3Array, rings: int, sides: int) -> void:
 for i in range(rings+1):
  for j in range(sides):
   var along := vertices[mini(i+1,rings)*sides+j]-vertices[maxi(0,i-1)*sides+j]
   var across := vertices[i*sides+(j+1)%sides]-vertices[i*sides+(j+sides-1)%sides]
   normals[i*sides+j] = along.cross(across).normalized()

static func replace_geometry(instance: MeshInstance3D, arrays: Array) -> void:
 var shape := ArrayMesh.new()
 shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 instance.mesh = shape

static func curved_sweep(parent: Node3D, profile: Array, curve: Curve3D, material: Material, rings: int = 64, sides: int = 40) -> MeshInstance3D:
 var instance := sweep(parent,profile,material,rings,sides)
 var arrays := instance.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 for i in range(rings+1):
  var pose := frame(curve,float(i)/rings)
  for j in range(sides):
   var v := vertices[i*sides+j]
   vertices[i*sides+j] = pose*Vector3(v.x,0,v.z)
 side_normals(vertices,normals,rings,sides)
 for end in [0,1]:
  var pose := frame(curve,float(end))
  var first: int = (rings+1)*sides+end*(sides+1)
  for j in range(sides+1):
   var v := vertices[first+j]
   vertices[first+j] = pose*Vector3(v.x,0,v.z)
   normals[first+j] = pose.basis.y*(-1 if end==0 else 1)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 replace_geometry(instance,arrays)
 return instance

static func face(parent: Node3D, material: Material) -> MeshInstance3D:
 var rings := 64
 var sides := 64
 var instance := sweep(parent,[[0,.028,.037],[.13,.060,.063],[.30,.080,.077],[.55,.092,.085],[.78,.093,.082],[.94,.073,.069],[1,.04,.04]],material,rings,sides)
 var arrays := instance.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 for i in range(vertices.size()):
  var p := vertices[i]
  var t := p.y+.5
  var a := atan2(p.x,-p.z)
  # Nose, bridge, lips and chin are sculpted into the same surface.
  var nose := .035*exp(-pow((t-.54)/.085,2)-pow(a/.18,2))
  var bridge := .012*exp(-pow((t-.65)/.13,2)-pow(a/.15,2))
  var lip := .003*exp(-pow((t-.26)/.025,2)-pow(a/.36,2))
  var chin := .006*exp(-pow((t-.10)/.10,2)-pow(a/.7,2))
  p.z -= nose+bridge+lip+chin
  p.y *= .225
  vertices[i] = p
 side_normals(vertices,normals,rings,sides)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 replace_geometry(instance,arrays)
 return instance

static func ink(material: StandardMaterial3D, width: float = .0012) -> StandardMaterial3D:
 # A grazing-angle ink pass avoids noisy expanded hulls on clothing joins.
 var shader := Shader.new()
 shader.code = "shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never, cull_back; uniform float edge; void fragment(){float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));ALBEDO=vec3(.035,.045,.06);ALPHA=(1.0-smoothstep(.015,edge,facing))*.9;}"
 var outline := ShaderMaterial.new()
 outline.shader = shader
 outline.set_shader_parameter("edge",clampf(width*70,.045,.10))
 material.next_pass = outline
 return material

static func muscle(parent: Node3D, profile: Array, material: Material, side: float, calf: bool = false) -> MeshInstance3D:
 var rings := 64
 var sides := 48
 var instance := sweep(parent,profile,material,rings,sides)
 var arrays := instance.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 for i in range(rings+1):
  var t := float(i)/rings
  for j in range(sides):
   var a := TAU*j/sides
   # Two calf heads / quadriceps ridge, tapering to the knee and ankle.
   var volume := sin(t*PI)*(.065*cos(2*a)+.035*cos(3*a+side*.45))
   if calf: volume*=1.3
   var p := vertices[i*sides+j]
   p.x *= 1+volume
   p.z *= 1+volume
   vertices[i*sides+j] = p
 side_normals(vertices,normals,rings,sides)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 replace_geometry(instance,arrays)
 return instance

static func badge(parent: Node3D, centre: Vector3, right: Vector3, up: Vector3, material: Material) -> MeshInstance3D:
 var normal := right.cross(up).normalized()
 return finish(parent,PackedVector3Array([centre-right-up*.5,centre+right-up*.5,centre+up]),PackedVector3Array([normal,normal,normal]),PackedInt32Array([0,2,1]),material)
