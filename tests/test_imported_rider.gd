extends SceneTree
const Rider = preload("res://scripts/rider.gd")
var passed:=0
var failed:=0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1;print("PASS ",message)
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var rider:=Rider.new();root.add_child(rider)
 check(rider.model!=null and rider.skeleton!=null and rider.skeleton.get_bone_count()==22,"supplied model loads with its 22-bone skeleton")
 check(rider.find_children("*","MeshInstance3D",true,false).size()==38,"import retains supplied cyclist and bicycle meshes")
 check((rider.model.basis*Vector3.BACK).dot(Vector3.FORWARD)>.999,"whole-model axis conversion faces along the simulation road")
 var pedal:=rider.pedal_player.get_animation(Rider.PEDAL_CLIP)
 var wheel:=rider.wheel_player.get_animation(Rider.WHEEL_CLIP)
 var independent:=pedal.get_track_count()==9 and wheel.get_track_count()==2
 for i in range(pedal.get_track_count()):
  if "/Wheel_" in str(pedal.track_get_path(i)):independent=false
 for i in range(wheel.get_track_count()):
  if not "/Wheel_" in str(wheel.track_get_path(i)):independent=false
 check(independent,"native importer reset tracks are removed so clips remain independent")
 rider.crank=0;rider.wheel_phase=0;rider.animate(0,0,0)
 var foot:Vector3=rider.pedal_position(0)
 rider.animate(.1,0,8)
 check(rider.crank==0 and foot.distance_to(rider.pedal_position(0))<.0001 and rider.wheel_phase>0,"coasting advances wheels while pedals and legs hold their pose")
 var rolling:=rider.wheel_phase
 rider.animate(.1,60,0)
 check(rider.wheel_phase==rolling and rider.pedal_position(0).distance_to(foot)>.02,"pedalling at rest does not rotate wheels or reset pedal phase")
 rider.crank=0;rider.wheel_phase=0;rider.animate(0,0,0)
 var top:=rider.pedal_position(0)
 rider.animate(.125,60,0);rider.animate(.125,60,0);var front:=rider.pedal_position(0)
 rider.animate(.125,60,0);rider.animate(.125,60,0);var bottom:=rider.pedal_position(0)
 rider.animate(.125,60,0);rider.animate(.125,60,0);var back:=rider.pedal_position(0)
 check(front.z<top.z and bottom.y<front.y and back.z>bottom.z,"supplied pedal clip rotates forward after the global axis conversion")
 rider.animate(.125,60,0);rider.animate(.125,60,0)
 check(top.distance_to(rider.pedal_position(0))<.001,"supplied pedal animation closes without a pose discontinuity")
 rider.wheel_phase=0;rider.animate(.25,0,TAU*Rider.WHEEL_RADIUS)
 var spoke:Vector3=rider.wheels[0].to_global(Vector3.UP*Rider.WHEEL_RADIUS)-rider.wheels[0].global_position
 check(absf(rider.wheel_phase-PI/2)<.0001 and spoke.z<-.3,"wheel radius and roll direction match forward travel")
 var weights_valid:=true;var skinned:=0
 for mesh in rider.find_children("*","MeshInstance3D",true,false):
  if mesh.skin==null:continue
  skinned+=1
  for surface in range(mesh.mesh.get_surface_count()):
   var a: Array=mesh.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
   var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
   var bones:PackedInt32Array=a[Mesh.ARRAY_BONES]
   var stride:=weights.size()/vertices.size()
   if stride not in [4,8]:weights_valid=false;continue
   for i in range(vertices.size()):
    var total:=0.
    for j in range(stride):
     var w:=weights[i*stride+j];total+=w
     if not is_finite(w) or w<0 or bones[i*stride+j]<0 or bones[i*stride+j]>=mesh.skin.get_bind_count():weights_valid=false
    if absf(total-1)>.001:weights_valid=false
 check(weights_valid and skinned>0,"supplied skinned body has finite normalized weights and valid binds")
 var finite:=true;var hips:=rider.skeleton.find_bone("Hips")
 var anchor:Vector3=rider.skeleton.get_bone_global_pose(hips).origin
 for i in range(32):
  rider.crank=TAU*i/32;rider.animate(0,0,0)
  for bone in range(rider.skeleton.get_bone_count()):
   if not rider.skeleton.get_bone_global_pose(bone).is_finite():finite=false
  if rider.skeleton.get_bone_global_pose(hips).origin.distance_to(anchor)>.0001:finite=false
 check(finite,"full pedal cycle keeps rig transforms finite and the seated hips fixed")
 rider.crank=0;rider.animate(.6,90,0)
 check(rider.crank<=PI/3+.00001,"long render stalls retain the forward-pedalling phase bound")
 rider.free();await process_frame
 print("RESULT_IMPORTED_RIDER passed=",passed," failed=",failed)
 quit(0 if failed==0 else 1)
