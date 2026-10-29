## Comfort camera: independent road frame, fixed framing and a level horizon.
extends RefCounted
enum View { CHASE, FIRST_PERSON, DISTANT }
const VIEW_NAMES := ["Vue arrière", "Vue du cycliste", "Vue arrière éloignée"]
var view := View.CHASE
var reframe := false

func set_view(value: int) -> void:
 view = clampi(value,View.CHASE,View.DISTANT)
 reframe = true

func field_of_view() -> float:
 return 65.0 if view==View.FIRST_PERSON else 48.0

func cycle_view() -> void:
 set_view((view+1)%VIEW_NAMES.size())

const DEFAULT_LATERAL := 1.55
const LATERAL_DEAD_ZONE := .55
const HEADING_DEAD_ZONE := deg_to_rad(.8)
const MAX_YAW_SPEED := deg_to_rad(35)
const BACK_DISTANCE := 4.2
const LOOK_AHEAD := 2.2
var initialised := false
var yaw := 0.0
var lateral := DEFAULT_LATERAL
var ground_height := 0.0
var last_station := 0.0
var route_id := 0
var pose := Transform3D.IDENTITY

func step(route: RefCounted, station: float, rider_lateral: float, speed: float, dt: float, immediate: bool = false) -> Transform3D:
 var centre: Vector3 = route.smooth_position(station)
 # A spatial chord ignores small changes in the instantaneous GPX tangent.
 var chord: Vector3 = route.smooth_position(station+8)-route.smooth_position(station-8)
 chord.y = 0
 if chord.length_squared()<.000001:
  chord = route.direction(station)
  chord.y = 0
 var road_forward := chord.normalized() if chord.length_squared()>.000001 else Vector3.FORWARD
 var desired_yaw := atan2(-road_forward.x,-road_forward.z)
 var offset := rider_lateral-DEFAULT_LATERAL
 var desired_lateral := DEFAULT_LATERAL+signf(offset)*maxf(0,absf(offset)-LATERAL_DEAD_ZONE)
 var before: Vector3 = route.smooth_position(station-4)
 var after: Vector3 = route.smooth_position(station+4)
 var desired_height := (before.y+2*centre.y+after.y)*.25
 var reset := immediate or not initialised or route_id!=route.get_instance_id() or absf(station-last_station)>30
 if not reset and not reframe and speed<=.001 and absf(station-last_station)<.00001:
  return pose
 if reset:
  yaw = desired_yaw
  lateral = desired_lateral
  ground_height = clampf(desired_height,centre.y-.2,centre.y+.2)
  initialised = true
  route_id = route.get_instance_id()
 else:
  # No searching for a new heading while the bicycle is stopped.
  if speed>.15 and dt>0:
   var error := wrapf(desired_yaw-yaw,-PI,PI)
   var correction := signf(error)*maxf(0,absf(error)-HEADING_DEAD_ZONE)
   yaw += clampf(correction*(1-exp(-dt/.65)),-MAX_YAW_SPEED*dt,MAX_YAW_SPEED*dt)
  var softened := lerpf(lateral,desired_lateral,1-exp(-maxf(dt,0)/.9))
  lateral = move_toward(lateral,softened,.7*maxf(dt,0))
  ground_height = lerpf(ground_height,desired_height,1-exp(-maxf(dt,0)/.45))
  # Keep the wheels in frame on sustained descents while filtering small bumps.
  ground_height = clampf(ground_height,centre.y-.2,centre.y+.2)
 last_station = station
 var forward := Vector3(-sin(yaw),0,-cos(yaw))
 var right := Vector3(-forward.z,0,forward.x)
 var physical_forward: Vector3 = route.direction(station)
 physical_forward.y = 0
 physical_forward = physical_forward.normalized() if physical_forward.length_squared()>.000001 else road_forward
 # Keep the nominal lane anchored to the road even in a very tight hairpin;
 # only orientation and avoidance offsets use the filtered camera heading.
 var road_right := Vector3(-physical_forward.z,0,physical_forward.x)
 var anchor := centre+road_right*DEFAULT_LATERAL+right*(lateral-DEFAULT_LATERAL)
 anchor.y = ground_height+.065
 var eye := anchor-forward*BACK_DISTANCE+Vector3.UP*2.2-right*.45
 var target := anchor+forward*LOOK_AHEAD+Vector3.UP*1.3
 if view==View.DISTANT:
  eye = anchor-forward*7.5+Vector3.UP*3.2-right*.45
 elif view==View.FIRST_PERSON:
  # Use the rider's lane, but never inherit head bob, pedalling or bicycle roll.
  anchor = centre+road_right*rider_lateral
  anchor.y = ground_height+.065
  eye = anchor+forward*.45+Vector3.UP*1.5
  target = anchor+forward*14+Vector3.UP*1.5
  target.y += clampf(route.smooth_position(station+14).y-centre.y,-3,3)
 reframe = false
 # Position and target share the same filtered frame. No unsmoothed look_at
 # target, no rider lean/pedalling input, no zoom, and no camera roll.
 pose = Transform3D(Basis.looking_at(target-eye,Vector3.UP),eye)
 return pose
