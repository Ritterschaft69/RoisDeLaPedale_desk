class_name IGNTerrain
extends RefCounted

# Numeric LiDAR MNT/MNH caches. The engine never contacts a geographic service.
const DIRECTORY := "res://assets/geodata/circuits/terrain/"
var tiles: Dictionary = {}
var loaded: Dictionary = {}
var recent: Array[String] = []
var transform: Dictionary = {}
var horizon: Dictionary = {}
var horizon_values := PackedFloat32Array()

func _init(projection: Dictionary) -> void:
	transform = projection
	var path := DIRECTORY+"index.json"
	if not FileAccess.file_exists(path): return
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for tile in index.tiles: tiles[str(tile.key)] = tile
	horizon = index.get("horizon",{})
	if not horizon.is_empty():
		var file := FileAccess.open(DIRECTORY+str(horizon.file),FileAccess.READ)
		if file != null: horizon_values = file.get_buffer(file.get_length()).to_float32_array()

func horizon_height(p: PackedFloat64Array) -> float:
	if horizon.is_empty() or horizon_values.is_empty(): return NAN
	var width := int(horizon.width)
	var rows := int(horizon.height)
	var u := (p[0]-float(horizon.x))/float(horizon.resolution_m)-.5
	var v := (float(horizon.y)+rows*float(horizon.resolution_m)-p[1])/float(horizon.resolution_m)-.5
	var i := floori(u)
	var j := floori(v)
	if i<0 or j<0 or i>=width-1 or j>=rows-1: return NAN
	var a := horizon_values[j*width+i]
	var b := horizon_values[j*width+i+1]
	var c := horizon_values[(j+1)*width+i]
	var d := horizon_values[(j+1)*width+i+1]
	for value in [a,b,c,d]:
		if not is_finite(value) or value < -100 or value>5000: return NAN
	return lerpf(lerpf(a,b,u-i),lerpf(c,d,u-i),v-j)

func lambert(at: Vector2) -> PackedFloat64Array:
	var x := at.x/10000.0
	var z := at.y/10000.0
	var terms := [1.0,x,z,x*x,x*z,z*z,x*x*x,x*x*z,x*z*z,z*z*z]
	var east := 0.0
	var north := 0.0
	# Accumulate the small corrections before adding the large Lambert origin.
	for i in range(1,10):
		east += float(transform.x[i])*terms[i]
		north += float(transform.y[i])*terms[i]
	# Lambert northings are ~6.8 million metres: Vector2's float32 would round
	# them to half metres. Keep the projected coordinates in float64.
	return PackedFloat64Array([east+float(transform.x[0]),north+float(transform.y[0])])

func values(tile: Dictionary, product: String) -> PackedFloat32Array:
	var key := str(tile.key)+product
	if loaded.has(key): return loaded[key]
	var path: String = DIRECTORY+str(tile.sources[product].file)
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return PackedFloat32Array()
	var packed := file.get_buffer(file.get_length()).to_float32_array()
	if packed.size()!=int(tile.size)*int(tile.size): return PackedFloat32Array()
	loaded[key] = packed
	recent.append(key)
	# Bound working memory even during circuit changes and long sessions.
	if recent.size()>32: loaded.erase(recent.pop_front())
	return packed

func pixel(tile: Dictionary, i: int, j: int, product: String) -> float:
	var n := int(tile.size)
	if i>=0 and j>=0 and i<n and j<n:
		var packed := values(tile,product)
		if packed.is_empty(): return NAN
		return packed[j*n+i]
	var x := float(tile.x)+(i+.5)*float(tile.resolution_m)
	var y := float(tile.y)+2000-(j+.5)*float(tile.resolution_m)
	var key := "%d_%d" % [floori(x/2000),floori(y/2000)]
	if not tiles.has(key): return horizon_height(PackedFloat64Array([x,y])) if product=="mnt" else NAN
	var other: Dictionary = tiles[key]
	if not other.sources.has(product): return NAN
	var oi := clampi(floori((x-float(other.x))/float(other.resolution_m)),0,int(other.size)-1)
	var oj := clampi(floori((float(other.y)+2000-y)/float(other.resolution_m)),0,int(other.size)-1)
	return pixel(other,oi,oj,product)

func height(at: Vector2, product: String = "mnt") -> float:
	if transform.is_empty(): return NAN
	var p := lambert(at)
	var key := "%d_%d" % [floori(p[0]/2000),floori(p[1]/2000)]
	if not tiles.has(key): return horizon_height(p) if product=="mnt" else NAN
	var tile: Dictionary = tiles[key]
	if not tile.sources.has(product): return NAN
	var u := (p[0]-float(tile.x))/float(tile.resolution_m)-.5
	var v := (float(tile.y)+2000-p[1])/float(tile.resolution_m)-.5
	var i := floori(u)
	var j := floori(v)
	var a := pixel(tile,i,j,product)
	var b := pixel(tile,i+1,j,product)
	var c := pixel(tile,i,j+1,product)
	var d := pixel(tile,i+1,j+1,product)
	for value in [a,b,c,d]:
		if not is_finite(value) or value < -100 or value>5000: return NAN
	return lerpf(lerpf(a,b,u-i),lerpf(c,d,u-i),v-j)
