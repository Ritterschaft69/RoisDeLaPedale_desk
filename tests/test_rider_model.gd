extends SceneTree
const S = preload("res://scripts/rider_shapes.gd")
var passed := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
 if ok: passed+=1; print("PASS ",message)
 else: failures.append(message); push_error(message)
func geometry(instance: MeshInstance3D) -> bool:
 var a := instance.mesh.surface_get_arrays(0)
 var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
 var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
 var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
 for i in range(v.size()):
  if not v[i].is_finite() or absf(n[i].length()-1)>.0001: return false
 for i in range(0,indices.size(),3):
  var normal := (v[indices[i+1]]-v[indices[i]]).cross(v[indices[i+2]]-v[indices[i]])
  if normal.length()<.00000001: return false
  if normal.dot(n[indices[i]]+n[indices[i+1]]+n[indices[i+2]])>.000001: return false
 return true
func hit(instance: MeshInstance3D, x: float, z: float) -> bool:
 var a := instance.mesh.surface_get_arrays(0)
 var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
 for i in range(0,indices.size(),3):
  if Geometry3D.ray_intersects_triangle(Vector3(x,.3,z),Vector3.DOWN,v[indices[i]],v[indices[i+1]],v[indices[i+2]])!=null: return true
 return false
func _initialize(): call_deferred("run")
func run():
 var holder := Node3D.new()
 root.add_child(holder)
 var material := S.fabric(Color.WHITE)
 var limb := S.sweep(holder,[[0,.03,.04],[.3,.1,.08],[.6,.08,.09],[1,.04,.03]],material)
 check(geometry(limb),"closed anatomical mesh has finite unit normals, nondegenerate outward faces")
 var helmet := S.helmet(holder,Vector3.ZERO,material)
 check(geometry(helmet),"helmet shell winding and smooth normals agree")
 var z := -.07
 var x := .135*sqrt(1-pow(z/.17,2))*sin(.25)
 check(not hit(helmet,x,z) and hit(helmet,0,z),"helmet vent is an actual opening beside a solid structural rib")
 var rider = load("res://scripts/rider.gd").new()
 holder.add_child(rider)
 var meshes: int = rider.find_children("*","MeshInstance3D",true,false).size()
 print("RIDER_MESHES=",meshes)
 check(meshes<220,"cyclist avoids hundreds of separate helmet pieces")
 rider.crank=0
 for i in range(120): rider.animate(1.0/60,75,0)
 check(absf(sin(rider.crank)-sin(5*PI))<.0001,"normal frame rates preserve commanded cadence exactly")
 rider.crank=0
 rider.animate(.6,90,0)
 check(rider.limbs[0].shoe.position.z<.035,"after a long render stall, top pedal visibly advances toward the front")
 holder.queue_free()
 await process_frame
 print("RESULT_RIDER_MODEL passed=",passed," failed=",failures.size())
 quit(0 if failures.is_empty() else 1)
