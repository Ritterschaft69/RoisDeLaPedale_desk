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
   var p := Vector3(.135*width*sin(a),.098*width*cos(a),z)
   vertices.append(p)
   normals.append(Vector3(p.x/(.135*.135),p.y/(.098*.098),p.z/(.17*.17)).normalized())
 for i in range(rows):
  for j in range(cols):
   var z := lerpf(-.167,.167,(float(i)+.5)/rows)
   var a := absf(lerpf(-PI/2,PI/2,(float(j)+.5)/cols))
   var slot := (a>.16 and a<.36) or (a>.59 and a<.83) or (a>1.06 and a<1.29)
   var length_slot := (z>-.125 and z<-.018) or (z>.012 and z<.115)
   if slot and length_slot: continue
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
