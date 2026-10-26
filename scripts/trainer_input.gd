class_name TrainerInput
extends RefCounted

var mode := "demo"
var demo_watts := 180.0
var demo_cadence := 82.0
var last_observation_ms := -1
var measured_watts := 0.0
var measured_cadence := 0.0
var samples: Array[float] = []

func observe(watts: float, cadence: float, now_ms: int) -> bool:
	if not is_finite(watts) or watts < 0 or watts > 2500 or not is_finite(cadence) or cadence < 0 or cadence > 250:
		return false
	measured_watts = watts
	measured_cadence = cadence
	last_observation_ms = now_ms
	return true

func read(now_ms: int) -> Dictionary:
	var stale := last_observation_ms < 0 or now_ms-last_observation_ms > 2000
	var watts := demo_watts if mode == "demo" else (0.0 if stale else measured_watts)
	var cadence := (demo_cadence if demo_watts > 0 else 0.0) if mode == "demo" else (0.0 if stale else measured_cadence)
	return {"watts": watts, "cadence": cadence, "stale": stale and mode != "demo", "source": mode}

func smooth(watts: float) -> float:
	# Fixed 50 Hz simulation, 25 samples = 0.5 seconds, independent of BLE rate.
	samples.append(watts)
	if samples.size() > 25: samples.pop_front()
	var total := 0.0
	for value in samples: total += value
	return total / samples.size()
