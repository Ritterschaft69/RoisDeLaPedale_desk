class_name CyclingLanePlanner
extends RefCounted

const DEFAULT_LATERAL := 1.55 # metres to the right of the GPX centreline
const EDGE_LIMIT := 2.55
const RIDER_RADIUS := 0.32
const CLEARANCE := 0.30
const MAX_LATERAL_SPEED := 0.90
const LATERAL_ACCELERATION := 1.6
var lateral := DEFAULT_LATERAL
var velocity := 0.0
var target := DEFAULT_LATERAL
var locked_until_s := -INF
var blocked := false
var avoiding := false

func reset() -> void:
	lateral = DEFAULT_LATERAL
	velocity = 0
	target = DEFAULT_LATERAL
	locked_until_s = -INF
	blocked = false
	avoiding = false

func forecast(candidate: float, seconds: float) -> float:
	var x := lateral
	var v := velocity
	var remaining := minf(seconds,6)
	while remaining > 0.00001:
		var step := minf(0.1,remaining)
		v = move_toward(v,clampf((candidate-x)*2,-MAX_LATERAL_SPEED,MAX_LATERAL_SPEED),LATERAL_ACCELERATION*step)
		x = clampf(x+v*step,-EDGE_LIMIT,EDGE_LIMIT)
		remaining -= step
	return x

func step(station: float, speed: float, dt: float, observations: Array) -> Dictionary:
	var relevant: Array = []
	var lookahead := maxf(18,speed*4.5+3)
	for obstacle in observations:
		var delta: float = obstacle.s-station
		var radius: float = obstacle.get("radius",0.45)
		if delta < -radius-1.4 or delta > lookahead: continue
		var arrival := clampf(maxf(delta,0)/maxf(speed,1),0,6)
		var predicted: float = obstacle.get("predicted_lateral",obstacle.lateral+obstacle.get("velocity_lateral",0)*arrival)
		var roadside_limit := 3.3+radius+RIDER_RADIUS+CLEARANCE
		if absf(predicted)>roadside_limit and absf(float(obstacle.lateral))>roadside_limit: continue
		relevant.append({"s":obstacle.s,"delta":delta,"radius":radius,"arrival":arrival,"lateral":predicted})
	var candidates: Array[float] = [DEFAULT_LATERAL,0.35,2.5,-0.85,-2.35,target]
	var best := INF
	var selected := target
	var found := false
	for candidate in candidates:
		var safe := true
		for obstacle in relevant:
			var x := forecast(candidate,obstacle.arrival)
			if absf(x-float(obstacle.lateral)) < RIDER_RADIUS+float(obstacle.radius)+CLEARANCE:
				safe = false
				break
		if not safe: continue
		var cost := absf(candidate-DEFAULT_LATERAL)+absf(candidate-lateral)*0.15
		if station < locked_until_s: cost += absf(candidate-target)*4
		if cost < best:
			found = true
			best = cost
			selected = candidate
	blocked = not found
	if found:
		if absf(selected-DEFAULT_LATERAL)>0.15:
			for obstacle in relevant:
				if absf(float(obstacle.lateral)-DEFAULT_LATERAL)<RIDER_RADIUS+float(obstacle.radius)+CLEARANCE:
					locked_until_s = maxf(locked_until_s,float(obstacle.s)+float(obstacle.radius)+2.0)
		target = selected
	# Smooth, acceleration-limited lateral motion; never teleport across lanes.
	var steering_limit := minf(MAX_LATERAL_SPEED,maxf(speed,0)*0.30)
	velocity = clampf(move_toward(velocity,clampf((target-lateral)*2,-steering_limit,steering_limit),LATERAL_ACCELERATION*dt),-steering_limit,steering_limit)
	lateral = clampf(lateral+velocity*dt,-EDGE_LIMIT,EDGE_LIMIT)
	avoiding = absf(lateral-DEFAULT_LATERAL)>0.12 or absf(target-DEFAULT_LATERAL)>0.12
	return {"lateral":lateral,"blocked":blocked,"avoiding":avoiding,"target":target}
