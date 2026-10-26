## Save the authoring result as portable Godot meshes, with continuous hip weights.
extends SceneTree
func _initialize():
 var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/rider_garments.json"))
 DirAccess.make_dir_recursive_absolute("res://assets/models")
 for name in source:
  var data: Dictionary = source[name]
  var vertices := PackedVector3Array()
  var normals := PackedVector3Array()
  var bones := PackedInt32Array()
  var weights := PackedFloat32Array()
  for i in range(data.vertices.size()):
   var v: Array = data.vertices[i]
   var n: Array = data.normals[i]
   var p := Vector3(v[0],v[1],v[2])
   vertices.append(p); normals.append(Vector3(n[0],n[1],n[2]).normalized())
   if name=="bib":
    var side := -1.0 if p.x<0 else 1.0
    var rest_axis := Vector3(side*.045,-.36,-.12).normalized()
    var along := (p-Vector3(side*.115,1.08,.24)).dot(rest_axis)
    var leg := smoothstep(-.025,.14,along)
    var seam_width := lerpf(.04,.005,smoothstep(.06,.20,along))
    var right := smoothstep(-seam_width,seam_width,p.x)
    bones.append_array(PackedInt32Array([0,1,2,0]))
    weights.append_array(PackedFloat32Array([1-leg,leg*(1-right),leg*right,0]))
  var arrays := []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_NORMAL] = normals
  arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(data.indices)
  if name=="bib":
   arrays[Mesh.ARRAY_BONES] = bones
   arrays[Mesh.ARRAY_WEIGHTS] = weights
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var error := ResourceSaver.save(mesh,"res://assets/models/"+name+".res",ResourceSaver.FLAG_COMPRESS)
  if error!=OK: push_error("Cannot save garment mesh "+name); quit(1); return
  print("SAVED_GARMENT ",name," vertices=",vertices.size()," triangles=",data.indices.size()/3)
 quit()
