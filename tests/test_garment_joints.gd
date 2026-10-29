extends SceneTree
var passed := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
 if ok: passed+=1; print("PASS ",message)
 else: failures.append(message); push_error(message)
func continuous_closed(mesh: ArrayMesh) -> bool:
 var a := mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
 var neighbours: Array = []
 for i in range(vertices.size()): neighbours.append([])
 var edges := {}
 for i in range(0,indices.size(),3):
  for j in range(3):
   var u := indices[i+j]
   var v := indices[i+(j+1)%3]
   var key := Vector2i(mini(u,v),maxi(u,v))
   edges[key] = edges.get(key,0)+1
   neighbours[u].append(v); neighbours[v].append(u)
 for count in edges.values():
  if count!=2: return false
 var seen := PackedByteArray(); seen.resize(vertices.size())
 var queue := PackedInt32Array([0]); seen[0]=1
 var count := 0
 while not queue.is_empty():
  var u := queue[queue.size()-1]; queue.resize(queue.size()-1)
  count+=1
  for v in neighbours[u]:
   if seen[v]==0: seen[v]=1; queue.append(v)
 return count==vertices.size()
func _initialize(): call_deferred("run")
func run():
 var rider = load("res://tools/legacy_rider.gd").new()
 root.add_child(rider)
 check(continuous_closed(rider.jersey_mesh.mesh),"torso and both sleeves are one connected, closed manifold mesh")
 check(continuous_closed(rider.pants_mesh.mesh),"pelvis and both shorts legs are one connected, closed manifold mesh")
 var a: Array = rider.pants_mesh.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
 var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
 var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
 var valid := bones.size()==vertices.size()*4 and weights.size()==vertices.size()*4
 var independent_cuffs := true
 for i in range(vertices.size()):
  var sum := 0.0
  for j in range(4):
   var w := weights[i*4+j]
   if not is_finite(w) or w<0 or bones[i*4+j]<0 or bones[i*4+j]>2: valid=false
   sum+=w
  if absf(sum-1)>4.0/65535.0: valid=false
  var side := -1.0 if vertices[i].x<0 else 1.0
  var along := (vertices[i]-Vector3(side*.115,1.08,.24)).dot(rider.bib_rest_axis(side))
  if along>.25:
   var correct_bone := 1 if vertices[i].x<0 else 2
   var own_weight := 0.0
   for j in range(4):
    if bones[i*4+j]==correct_bone: own_weight+=weights[i*4+j]
   if own_weight<.999: independent_cuffs=false
 check(valid,"all cloth vertices have finite normalised skin weights and valid bones")
 check(independent_cuffs,"each cuff follows its own thigh without being pulled by the opposite leg")
 var pivots := true
 var finite := true
 for phase in range(32):
  rider.crank = TAU*phase/32
  rider.animate(0,0,0)
  var matrices: Array[Transform3D] = []
  for bone in range(3):
   var pose: Transform3D = rider.garment_skeleton.get_bone_global_pose(bone)
   matrices.append(pose*rider.pants_mesh.skin.get_bind_pose(bone))
   if bone>0:
    var limb: Dictionary = rider.limbs[bone-1]
    var hip := Vector3(float(limb.side)*.115,1.08,.24)
    var direction: Vector3 = (limb.knee.position-hip).normalized()
    if pose.origin.distance_to(hip)>.0001 or (pose.basis*rider.bib_rest_axis(float(limb.side))).distance_to(direction)>.0001: pivots=false
  for i in range(vertices.size()):
   var p := Vector3.ZERO
   for j in range(4): p += (matrices[bones[i*4+j]]*vertices[i])*weights[i*4+j]
   if not p.is_finite() or absf(p.x)>.4 or p.y<.45 or p.y>1.4 or absf(p.z)>.65: finite=false
 check(pivots,"hip pivots stay fixed and cloth thigh bones follow IK throughout a pedal cycle")
 check(finite,"continuous bib deformation stays finite and within rider bounds for the full cycle")
 rider.queue_free()
 await process_frame
 print("RESULT_GARMENT_JOINTS passed=",passed," failed=",failures.size())
 quit(0 if failures.is_empty() else 1)
