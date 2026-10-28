extends SceneTree
const Ambience = preload("res://scripts/ambience.gd")
var passed := 0
var failed := 0
class FakeGeo extends RefCounted:
	var data := {"water":[],"buildings":[]}
	var wooded := false
	var reads := 0
	var queries := 0
	func forest(_at: Vector3) -> bool:
		reads+=1
		return wooded
	func nearby_buildings(_at: Vector2, _radius: float) -> Array:
		queries+=1
		return range(data.buildings.size())
class FakeWorld extends Node3D:
	var geographic := FakeGeo.new()
	func roadside(station: float, lateral: float) -> Vector3:
		return Vector3(station,0,lateral)
func check(ok: bool, message: String) -> void:
	if ok:passed+=1;print("PASS ",message)
	else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
	var a := Ambience.new()
	root.add_child(a)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/catalog.json"))
	var valid: bool = catalog.clips.size()==10
	for clip in catalog.clips:
		var stream = a.stream_for(clip.id)
		valid = valid and stream!=null and stream.get_length()>45 and stream.loop
	check(valid,"ten distinct compressed recordings load and loop")
	check(a.get_child_count()==5,"mixer uses at most five playback voices")
	var world := FakeWorld.new()
	root.add_child(world)
	check(a.classify(world,0)=="country","open landscape selects countryside")
	world.geographic.wooded=true
	check(a.classify(world,0)=="forest","woodland selects forest ambience")
	world.geographic.data.water=[{"points":[[0,0,10],[20,0,10]]}]
	a.index_water(world.geographic)
	check(a.near_water(Vector2.ZERO) and not a.near_water(Vector2(1000,0)),"water sound query uses nearby indexed geometry")
	check(a.classify(world,0)=="stream","woodland beside mapped water selects stream recording")
	world.geographic.data.buildings=[{"center":[0,0]},{"center":[20,0]},{"center":[30,0]}]
	check(a.classify(world,0)=="village","nearby buildings select village ambience")
	a.observe("country");a.observe("forest")
	check(a.biome=="country","single landscape observation does not switch ambience")
	a.observe("forest");a.observe("forest")
	check(a.biome=="forest","three stable observations confirm a landscape transition")
	a.switch_clip("base","0097")
	for i in range(40):a.mix_layer("base",.1,1)
	a.switch_clip("base","0100")
	a.mix_layer("base",1,1)
	var gains:Array=a.groups.base.gains
	check(absf(gains[0]+gains[1]-1)<.001 and minf(gains[0],gains[1])>.2,"landscape transition overlaps streams with a progressive fade")
	a.reset();world.geographic.queries=0
	a.step(.01,world,0,5,true)
	var reads:int=world.geographic.queries
	for i in range(20):a.step(.01,world,0,5,true)
	check(world.geographic.queries==reads,"environment queries are throttled instead of running each frame")
	a.reset()
	world.geographic.data.buildings=[];world.geographic.data.water=[]
	a.elapsed=481;a.forest_seconds=61
	a.step(.1,world,0,5,true)
	check(a.wildlife.playing and not a.wildlife.stream.loop and a.wildlife_due>a.elapsed,"rare forest wildlife plays once with a cooldown")
	a.biome="country";a.step(.1,world,0,5,true)
	check(not a.wildlife.playing,"wildlife fades away when leaving forest")
	a.configure(false,.5)
	var stopped:=true
	for player in a.get_children():
		stopped=stopped and not player.playing and player.stream==null
	check(stopped,"disable immediately stops playback and releases streams")
	a.configure(true,.5);a.step(.1,world,0,5,true);a.step(.1,world,0,5,false)
	stopped=true
	for player in a.get_children():stopped=stopped and not player.playing
	check(stopped,"pause and menus stop ambient playback")
	a.configure(true,0);a.step(.1,world,0,5,true)
	check(a.biome=="","zero volume avoids decoding inaudible streams")
	a.reset();check(a.geography==null and a.elapsed==0 and a.water_cells.is_empty(),"new session releases old geography and resets ambience")
	var capture := AudioEffectCapture.new()
	capture.buffer_length=.5
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	a.reset();a.configure(true,1)
	a.switch_clip("base","0097");a.mix_layer("base",4,1)
	await create_timer(.4).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in samples:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	AudioServer.remove_bus_effect(0,effect_index)
	check(samples.size()>512 and peak>.001,"native audio mixer decodes recording into non-silent stereo samples")
	a.free();world.free()
	var app=load("res://main.tscn").instantiate();root.add_child(app)
	app.set_process(false);app.set_physics_process(false)
	app.show_settings()
	check(app.overlay.find_child("AmbienceVolume",true,false)!=null,"audio volume is available in settings")
	app.ambience.configure(false,.37);app.save_settings();app.free()
	var restored=load("res://main.tscn").instantiate();root.add_child(restored)
	restored.set_process(false);restored.set_physics_process(false)
	check(not restored.ambience.enabled and absf(restored.ambience.volume-.37)<.001,"audio enable and volume settings survive restart")
	restored.ambience.configure(true,.5);restored.save_settings();restored.free()
	await process_frame
	print("RESULT_AMBIENCE passed=",passed," failed=",failed)
	quit(0 if failed==0 else 1)
