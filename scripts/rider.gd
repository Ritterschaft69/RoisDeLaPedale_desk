class_name CyclingRider
extends Node3D

## The supplied asset faces +Z; the simulation faces -Z. Rotate the whole model,
## keeping its meshes, skin and animation targets in the same coordinate frame.
const MODEL = preload("res://assets/models/imported-cyclist/cycliste-universel.glb")
const WHEEL_RADIUS := 0.3355
const PEDAL_CLIP := "PedalForward_60rpm"
const WHEEL_CLIP := "WheelRoll_1turn"
var model: Node3D
var pedal_player: AnimationPlayer
var wheel_player: AnimationPlayer
var skeleton: Skeleton3D
var wheels: Array[Node3D] = []
var pedals: Array[Node3D] = []
var crank := 0.0
var wheel_phase := 0.0

func _ready() -> void:
	model = MODEL.instantiate()
	model.name="ImportedCyclist"
	model.rotation.y=PI
	# Tyre outer radius .3355 m, wheel axle .335 m: align contact with y=0.
	model.position.y=.0005
	add_child(model)
	pedal_player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	assert(pedal_player!=null,"The supplied cyclist must contain its animation player")
	wheel_player=pedal_player.duplicate() as AnimationPlayer
	wheel_player.name="IndependentWheelPlayer"
	pedal_player.get_parent().add_child(wheel_player)
	# Godot's glTF importer adds constant reset tracks for unrelated targets.
	# Give each player its own filtered library so it cannot reset the other clip.
	for item in [[pedal_player,PEDAL_CLIP,false],[wheel_player,WHEEL_CLIP,true]]:
		var player: AnimationPlayer=item[0]
		var animation: Animation=player.get_animation(item[1]).duplicate(true)
		for track in range(animation.get_track_count()-1,-1,-1):
			var is_wheel := "/Wheel_" in str(animation.track_get_path(track))
			if is_wheel!=bool(item[2]):animation.remove_track(track)
		animation.loop_mode=Animation.LOOP_LINEAR
		for library in player.get_animation_library_list():player.remove_animation_library(library)
		var library:=AnimationLibrary.new()
		library.add_animation(item[1],animation);player.add_animation_library("",library)
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play(item[1])

	skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
	for name in ["Wheel_Front","Wheel_Rear"]:wheels.append(model.find_child(name,true,false) as Node3D)
	for name in ["Pedal_L","Pedal_R"]:pedals.append(model.find_child(name,true,false) as Node3D)
	animate(0,0,0)

func pedal_position(index: int) -> Vector3:
	return to_local(pedals[index].global_position)

func animate(dt: float, cadence: float, speed: float) -> void:
	if pedal_player==null:return
	# Preserve the anti-aliasing bound used by the original rider after stalls.
	var phase_step := clampf(maxf(dt,0)*maxf(cadence,0)*TAU/60,0,PI/3)
	crank=fposmod(crank+phase_step,TAU)
	wheel_phase=fposmod(wheel_phase+maxf(dt,0)*maxf(speed,0)/WHEEL_RADIUS,TAU)
	# Seeking each independent clip avoids one AnimationPlayer replacing the other.
	pedal_player.seek(crank/TAU,true)
	wheel_player.seek(wheel_phase/TAU,true)
	if skeleton!=null:skeleton.force_update_all_bone_transforms()
