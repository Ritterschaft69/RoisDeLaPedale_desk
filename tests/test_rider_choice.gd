extends SceneTree
const Rider=preload("res://scripts/rider.gd")
var passed:=0
var failed:=0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1;print("PASS ",message)
 else:failed+=1;push_error(message)
func deformed_bounds(rider: Node3D) -> bool:
 var skeleton:Skeleton3D=rider.skeleton
 for mesh in rider.model.find_children("*","MeshInstance3D",true,false):
  if mesh.skin==null:continue
  var matrices:Array[Transform3D]=[]
  for i in range(mesh.skin.get_bind_count()):
   var bone:int=mesh.skin.get_bind_bone(i)
   if bone<0:bone=skeleton.find_bone(mesh.skin.get_bind_name(i))
   if bone<0:return false
   matrices.append(rider.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
  for surface in range(mesh.mesh.get_surface_count()):
   var a:Array=mesh.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
   var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
   var bones:PackedInt32Array=a[Mesh.ARRAY_BONES]
   var stride:=weights.size()/vertices.size()
   for i in range(0,vertices.size(),53):
    var p:=Vector3.ZERO
    for j in range(stride):p+=(matrices[bones[i*stride+j]]*vertices[i])*weights[i*stride+j]
    if not p.is_finite() or absf(p.x)>.65 or p.y<-.08 or p.y>1.9 or absf(p.z)>1.1:return false
 return true
func _initialize():call_deferred("run")
func run():
 var rider:=Rider.new();root.add_child(rider)
 check(rider.variant_id=="original","provided orange cyclist remains the default")
 rider.crank=.7;rider.wheel_phase=1.2;rider.animate(0,0,0)
 var old:=rider.model
 check(rider.set_variant("tricolour") and rider.variant_id=="tricolour" and not is_instance_valid(old),"selecting tricolour replaces the old scene instead of stacking avatars")
 check(absf(rider.crank-.7)<.001 and absf(rider.wheel_phase-1.2)<.001,"model switch preserves pedal and wheel phases")
 check(rider.model.find_child("Cyclist_Mesh",true,false)!=null and rider.skeleton.get_bone_count()==18,"replacement GLB loads its supplied character and 18-bone rig")
 check(rider.pedal_player.has_animation("Pedal_60_RPM"),"replacement uses its supplied pedal animation")
 var valid:=true
 for phase in range(32):
  rider.crank=phase*TAU/32;rider.animate(0,0,0)
  if not deformed_bounds(rider):valid=false
 check(valid,"new skinned body stays finite and within rider bounds for a full cycle")
 var anchored:=true
 for phase in range(32):
  rider.crank=phase*TAU/32;rider.animate(0,0,0)
  for side in range(2):
   var foot:Vector3=rider.to_local(rider.skeleton.to_global(rider.skeleton.get_bone_global_pose(rider.skeleton.find_bone("Foot_L" if side==0 else "Foot_R")).origin))
   if (foot-rider.pedal_position(side)).distance_to(Vector3(0,.085,.075))>.004:anchored=false
 check(anchored,"replacement ankle positions stay aligned with their pedals for a full cycle")
 rider.crank=PI;rider.animate(0,0,0)
 var top:Vector3=rider.pedal_position(0);rider.animate(.05,60,0)
 check(rider.pedal_position(0).z<top.z and rider.pedal_position(0).y<top.y,"replacement top pedal moves forward and down")
 var phase_before:float=rider.crank;var wheel_before:Basis=rider.wheels[0].basis
 rider.animate(.05,0,8)
 check(rider.crank==phase_before and not rider.wheels[0].basis.is_equal_approx(wheel_before),"coasting turns road wheels while stopping the supplied leg animation")
 wheel_before=rider.wheels[0].basis;rider.animate(.05,60,0)
 check(rider.wheels[0].basis.is_equal_approx(wheel_before),"pedalling at zero road speed does not rotate road wheels")
 var top_direction:Vector3=rider.to_local(rider.wheels[0].to_global(Vector3.UP))-rider.to_local(rider.wheels[0].global_position)
 rider.wheel_phase=0;rider.animate(0,0,0);rider.animate(.01,0,1)
 top_direction=rider.to_local(rider.wheels[0].to_global(Vector3.UP))-rider.to_local(rider.wheels[0].global_position)
 check(top_direction.z<0,"replacement wheel top rolls toward the simulation forward direction")
 var active:=rider.model
 check(not rider.set_variant("unknown") and rider.model==active,"invalid character leaves current choice intact")
 rider.set_variant("original")
 check(rider.skeleton.get_bone_count()==22,"switching back restores the original supplied rider")
 rider.free()
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false);app.show_home()
 check(app.overlay.find_child("ChooseRider",true,false)!=null,"home provides a character selector")
 app.show_riders()
 var button=app.overlay.find_child("Rider_tricolour",true,false)
 check(button!=null and app.overlay.find_child("Rider_original",true,false)!=null,"selector offers both character choices")
 button.pressed.emit()
 check(app.rider.variant_id=="tricolour" and app.screen=="riders","character button updates the live preview")
 var phase:float=app.rider.crank
 var station:float=app.distance
 app._process(.1)
 check(app.rider.crank!=phase and app.distance==station,"animated selection preview does not advance the simulated circuit")
 app.camera_follow.set_view(1);app.position_scene(0,true)
 check(app.rider.visible,"selector preview remains visible even if first-person view is saved")
 app.show_home();app.start_session()
 check(not app.rider.visible and not app.select_rider("original"),"ride restores first-person visibility and prevents accidental mid-session replacement")
 app.finish_session();app.save_settings();app.free()
 var restored=load("res://main.tscn").instantiate();root.add_child(restored)
 restored.set_process(false);restored.set_physics_process(false)
 check(restored.rider.variant_id=="tricolour","character choice survives an application restart")
 restored.show_home();restored.select_rider("original");restored.camera_follow.set_view(0);restored.save_settings();restored.free()
 await process_frame
 print("RESULT_RIDER_CHOICE passed=",passed," failed=",failed)
 quit(0 if failed==0 else 1)
