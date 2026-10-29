extends SceneTree
const Follow = preload("res://scripts/camera_follow.gd")
var passed := 0
var failures: Array[String] = []
class StraightRoute extends RefCounted:
 func smooth_position(s: float) -> Vector3: return Vector3(0,0,-s)
 func direction(_s: float) -> Vector3: return Vector3.FORWARD
class BumpyRoute extends StraightRoute:
 func smooth_position(s: float) -> Vector3: return Vector3(0,.06*sin(s*3),-s)
class BendRoute extends StraightRoute:
 func smooth_position(s: float) -> Vector3:
  return Vector3(30*(1-cos(s/30)),0,-30*sin(s/30))
 func direction(s: float) -> Vector3: return Vector3(sin(s/30),0,-cos(s/30))
class SlopeRoute extends StraightRoute:
 func smooth_position(s: float) -> Vector3: return Vector3(0,-s*.15,-s)
func check(ok: bool, message: String) -> void:
 if ok: passed+=1; print("PASS ",message)
 else: failures.append(message); push_error(message)
func _initialize(): call_deferred("run")
func run():
 var straight := StraightRoute.new()
 var final_poses: Array[Transform3D] = []
 var fixed := true
 for fps in [30,60,144]:
  var follow := Follow.new()
  follow.step(straight,0,1.55,8,0,true)
  for i in range(1,fps*4+1):
   var station: float = 8.0*i/fps
   var pose: Transform3D = follow.step(straight,station,1.55,8,1.0/fps)
   if absf(pose.origin.z+station-Follow.BACK_DISTANCE)>.0001: fixed=false
  final_poses.append(follow.pose)
 check(fixed and final_poses[0].is_equal_approx(final_poses[1]) and final_poses[1].is_equal_approx(final_poses[2]),"fixed chase distance without longitudinal lag at 30/60/144 FPS")
 var follow := Follow.new()
 var start: Transform3D = follow.step(straight,0,1.55,8,0,true)
 var quiet := true
 for i in range(240):
  var pose: Transform3D = follow.step(straight,i*8.0/60,1.55+.25*sin(i*.3),8,1.0/60)
  if absf(pose.origin.x-start.origin.x)>.00001 or not pose.basis.is_equal_approx(start.basis): quiet=false
 check(quiet,"small lateral movements remain inside the camera dead zone")
 var bounded := true
 var visible := true
 var previous_x := follow.pose.origin.x
 for i in range(600):
  var t := i/60.0
  var lateral := maxf(-2.35,1.55-t*.9) if t<5 else minf(1.55,-2.35+(t-5)*.9)
  var pose: Transform3D = follow.step(straight,t*8,lateral,8,1.0/60)
  if absf(pose.origin.x-previous_x)>.7/60+.00001: bounded=false
  previous_x = pose.origin.x
  var local := pose.affine_inverse()*Vector3(lateral,1.0,-t*8)
  if absf(local.x)+.3>=(-local.z)*tan(deg_to_rad(24))*1.6: visible=false
 check(bounded and visible,"large avoidance manoeuvres remain framed with bounded lateral camera speed")
 var bumpy := BumpyRoute.new()
 follow = Follow.new()
 follow.step(bumpy,0,1.55,8,0,true)
 var raw_energy := 0.0
 var filtered_energy := 0.0
 var level := true
 for i in range(1,601):
  var s := i*8.0/60
  var pose: Transform3D = follow.step(bumpy,s,1.55,8,1.0/60)
  raw_energy+=pow(bumpy.smooth_position(s).y,2)
  filtered_energy+=pow(follow.ground_height,2)
  if absf(pose.basis.x.y)>.00001: level=false
 check(filtered_energy<raw_energy*.04 and level,"road bumps are attenuated by over 80 percent and the horizon never rolls")
 var bend := BendRoute.new()
 follow = Follow.new()
 follow.step(bend,0,1.55,8,0,true)
 var previous_yaw := follow.yaw
 var smooth_turn := true
 for i in range(1,601):
  follow.step(bend,i*12.0/60,1.55,12,1.0/60)
  if absf(wrapf(follow.yaw-previous_yaw,-PI,PI))>Follow.MAX_YAW_SPEED/60+.00001: smooth_turn=false
  previous_yaw=follow.yaw
 check(smooth_turn and absf(wrapf(follow.yaw,-PI,PI))>.5,"sustained turns are followed with bounded angular speed")
 follow.step(bend,60,1.55,0,0,true)
 var held := follow.yaw
 for i in range(60): follow.step(bend,60.1,1.55,0,1.0/60)
 check(follow.yaw==held,"stopped bicycle does not make the camera hunt for a heading")
 var slope := SlopeRoute.new()
 follow = Follow.new()
 follow.step(slope,0,1.55,12,0,true)
 var height_bound := true
 for i in range(1,601):
  var s := i*12.0/60
  follow.step(slope,s,1.55,12,1.0/60)
  if absf(follow.ground_height-slope.smooth_position(s).y)>.201: height_bound=false
 check(height_bound,"height filtering stays within 20 cm of the road on a sustained descent")
 var turn_headings: Array[float] = []
 for fps in [30,60,144]:
  var rig := Follow.new()
  rig.step(bend,0,1.55,12,0,true)
  for i in range(1,fps*8+1): rig.step(bend,12.0*i/fps,1.55,12,1.0/fps)
  turn_headings.append(rig.yaw)
 check(absf(wrapf(turn_headings[0]-turn_headings[2],-PI,PI))<deg_to_rad(.6),"turn framing agrees within 0.6 degrees between 30 and 144 FPS")
 var stopped_rig := Follow.new()
 stopped_rig.step(bumpy,0,1.55,8,0,true)
 stopped_rig.step(bumpy,1.2,-.85,8,.05)
 var stopped_pose: Transform3D = stopped_rig.pose
 var still := true
 for i in range(120):
  var pose: Transform3D = stopped_rig.step(bumpy,1.2,-.85+.2*sin(i*.2),0,1.0/60)
  if not pose.is_equal_approx(stopped_pose): still=false
 check(still,"complete camera pose freezes at rest, including unfinished height and lateral settling")
 var snapped: Transform3D = follow.step(straight,6200,1.55,0,0,true)
 check(absf(snapped.origin.z+6200-Follow.BACK_DISTANCE)<.001,"teleport and circuit reset snap the rig without a long camera catch-up")
 var app = load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.set_physics_process(false)
 app.start_session()
 for i in range(10): app._physics_process(.02)
 app.position_scene(.02)
 app.toggle_pause()
 var paused: Transform3D = app.camera.transform
 for i in range(60): app.position_scene(1.0/60)
 check(app.camera.transform.is_equal_approx(paused),"pausing freezes the actual application camera")
 var views := Follow.new()
 var chase: Transform3D = views.step(straight,0,1.55,0,0,true)
 views.cycle_view()
 var first: Transform3D = views.step(straight,0,1.55,0,0)
 check(views.view==Follow.View.FIRST_PERSON and absf(first.origin.x-1.55)<.001 and first.origin.z<0 and first.origin.y<chase.origin.y,"first person uses rider eye position and reframes even at rest")
 views.cycle_view()
 var distant: Transform3D = views.step(straight,0,1.55,0,0)
 check(distant.origin.z>chase.origin.z+3 and distant.origin.y>chase.origin.y,"distant view increases setback and height")
 views.cycle_view()
 check(views.view==Follow.View.CHASE and views.step(straight,0,1.55,0,0).is_equal_approx(chase),"three views cycle back to the unchanged original framing")
 var heading := views.yaw
 views.cycle_view();views.step(straight,0,1.55,0,0)
 check(views.yaw==heading and absf(views.pose.basis.x.y)<.00001,"view switch preserves filtered heading and level horizon")
 app.camera_follow.set_view(Follow.View.CHASE)
 app.position_scene(0,true)
 var key := InputEventKey.new();key.keycode=KEY_V;key.pressed=true
 app._unhandled_key_input(key)
 check(app.camera_follow.view==Follow.View.FIRST_PERSON and not app.rider.visible and app.camera.fov==65,"V selects rider view and hides the obstructing avatar")
 key.echo=true;app._unhandled_key_input(key)
 check(app.camera_follow.view==Follow.View.FIRST_PERSON,"holding V does not cycle through repeated key events")
 key.echo=false;app._unhandled_key_input(key)
 check(app.camera_follow.view==Follow.View.DISTANT and app.rider.visible,"next V restores avatar in distant view")
 var saved := ConfigFile.new();saved.load("user://settings.cfg")
 check(saved.get_value("graphics","camera_view",-1)==Follow.View.DISTANT,"selected camera view is saved")
 app._unhandled_key_input(key)
 app.queue_free()
 await process_frame
 print("RESULT_CAMERA passed=",passed," failed=",failures.size())
 quit(0 if failures.is_empty() else 1)
