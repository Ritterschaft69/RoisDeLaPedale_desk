class_name CyclingAmbience
extends Node

## Compressed streams only; two crossfade slots per layer, one rare wildlife slot.
const CROSSFADE := 4.0
const HEADROOM := 0.65
const SAMPLE_INTERVAL := 1.0
const CELL := 128.0
var enabled := true
var volume := 0.5
var groups: Dictionary = {}
var wildlife := AudioStreamPlayer.new()
var wildlife_gain := 0.0
var biome := ""
var candidate := ""
var candidate_seconds := 0.0
var query_timer := 0.0
var elapsed := 0.0
var forest_seconds := 0.0
var wildlife_due := 480.0
var strong_wind := false
var geography: RefCounted
var water_cells: Dictionary = {}

func _ready() -> void:
	for key in ["base","wind"]:
		var players: Array[AudioStreamPlayer] = []
		for i in range(2):
			var player := AudioStreamPlayer.new()
			player.volume_db = -80
			add_child(player)
			players.append(player)
		groups[key] = {"players":players,"ids":["",""],"gains":[0.0,0.0],"targets":[0.0,0.0]}
	wildlife.volume_db = -80
	add_child(wildlife)

func configure(is_enabled: bool, level: float) -> void:
	enabled = is_enabled
	volume = clampf(level,0,1) if is_finite(level) else 0.5
	if not enabled or volume==0: stop_all()

func stop_all() -> void:
	for group in groups.values():
		for i in range(2):
			group.players[i].stop()
			group.players[i].stream = null
			group.ids[i] = ""
			group.gains[i] = 0.0
			group.targets[i] = 0.0
	wildlife.stop()
	wildlife.stream = null
	wildlife_gain = 0
	biome = ""
	candidate = ""
	candidate_seconds = 0
	query_timer = 0

func reset() -> void:
	stop_all()
	elapsed = 0
	forest_seconds = 0
	wildlife_due = 480
	strong_wind = false
	geography = null
	water_cells.clear()

func stream_for(id: String, looping: bool = true) -> AudioStreamOggVorbis:
	var stream := load("res://assets/audio/"+id+".ogg") as AudioStreamOggVorbis
	if stream != null: stream.loop = looping
	return stream

func switch_clip(layer: String, id: String) -> void:
	var group: Dictionary = groups[layer]
	for i in range(2):
		if group.ids[i]==id and group.targets[i]>0: return
	var slot := 0 if float(group.gains[0])<=float(group.gains[1]) else 1
	for i in range(2):
		if group.ids[i]==id: slot=i
	if group.ids[slot]!=id:
		var stream := stream_for(id)
		if stream==null: return
		group.players[slot].stop()
		group.players[slot].stream = stream
		group.players[slot].volume_db = -80
		group.players[slot].play()
		group.ids[slot] = id
		group.gains[slot] = 0.0
	for i in range(2): group.targets[i] = 1.0 if i==slot else 0.0

func index_water(source: RefCounted) -> void:
	geography = source
	water_cells.clear()
	for water in source.data.get("water",[]):
		for point in water.points:
			var p := Vector2(point[0],point[2])
			var key := Vector2i(floori(p.x/CELL),floori(p.y/CELL))
			if not water_cells.has(key): water_cells[key] = PackedVector2Array()
			water_cells[key].append(p)

func near_water(at: Vector2) -> bool:
	for x in range(floori((at.x-45)/CELL),floori((at.x+45)/CELL)+1):
		for z in range(floori((at.y-45)/CELL),floori((at.y+45)/CELL)+1):
			for point in water_cells.get(Vector2i(x,z),PackedVector2Array()):
				if at.distance_squared_to(point)<45*45: return true
	return false

func classify(world: Node3D, station: float) -> String:
	var source: RefCounted = world.geographic
	if source!=geography: index_water(source)
	var at: Vector3 = world.roadside(station,0)
	var center := Vector2(at.x,at.z)
	var buildings := 0
	for index in source.nearby_buildings(center,100):
		var b: Dictionary = source.data.buildings[index]
		if Vector2(b.center[0],b.center[1]).distance_squared_to(center)<10000: buildings+=1
	if buildings>=3: return "village"
	var trees := 0
	for offset in [-24.0,0.0,24.0]:
		if source.forest(world.roadside(station,offset)): trees+=1
	if trees>=2: return "stream" if near_water(center) else "forest"
	if trees==1: return "edge"
	return "country"

func observe(wanted: String) -> void:
	if biome=="": biome=wanted
	if wanted==biome:
		candidate="";candidate_seconds=0
	elif candidate!=wanted:
		candidate=wanted;candidate_seconds=SAMPLE_INTERVAL
	else:
		candidate_seconds+=SAMPLE_INTERVAL
		if candidate_seconds>=3:
			biome=wanted;candidate="";candidate_seconds=0

func base_clip() -> String:
	match biome:
		"village": return "0870"
		"stream": return "2713"
		"edge": return "0905"
		"forest": return ["0100","2715","0905"][int(elapsed/180)%3]
	return "0097"

func mix_layer(layer: String, dt: float, level: float) -> void:
	var group: Dictionary = groups[layer]
	for i in range(2):
		group.gains[i] = move_toward(group.gains[i],group.targets[i],dt/CROSSFADE)
		var gain: float = group.gains[i]*volume*level*HEADROOM
		group.players[i].volume_db = linear_to_db(gain) if gain>0.00001 else -80.0
		if group.targets[i]==0 and group.gains[i]==0 and group.ids[i]!="":
			group.players[i].stop()
			group.players[i].stream = null
			group.ids[i] = ""

func step(dt: float, world: Node3D, station: float, speed: float, active: bool) -> void:
	if not active or not enabled or volume==0:
		if biome!="": stop_all()
		return
	var delta := clampf(dt,0,0.25)
	elapsed+=delta
	query_timer-=delta
	if query_timer<=0:
		query_timer=SAMPLE_INTERVAL
		observe(classify(world,station))
		switch_clip("base",base_clip())
		var wooded := biome in ["forest","stream","edge"]
		if speed>9: strong_wind=true
		elif speed<7: strong_wind=false
		switch_clip("wind",("0904" if strong_wind else "0659") if wooded else "0908")
	mix_layer("base",delta,1.0)
	mix_layer("wind",delta,0.12+clampf(speed/15,0,1)*0.20)
	if biome=="forest": forest_seconds+=delta
	else: forest_seconds=0
	if elapsed>=wildlife_due and forest_seconds>=60 and not wildlife.playing:
		wildlife.stream=stream_for("3616",false)
		wildlife.play()
		wildlife_due=elapsed+600
	wildlife_gain=move_toward(wildlife_gain,0.18 if biome=="forest" and wildlife.playing else 0.0,delta*.1)
	wildlife.volume_db=linear_to_db(wildlife_gain*volume*HEADROOM) if wildlife_gain*volume*HEADROOM>0.00001 else -80
	if wildlife_gain==0 and biome!="forest": wildlife.stop();wildlife.stream=null
