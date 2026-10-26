class_name CyclingPhysics
extends RefCounted

const G := 9.80665
var mass_kg := 84.0
var effective_mass_kg := 86.0 # +2 kg equivalent wheel inertia, estimate
var efficiency := 0.975
var cda := 0.34
var crr := 0.005
var rho := 1.2
var maximum_force := 500.0 # standing-start traction limit (N)

func resistance(v: float, grade: float, headwind: float, rolling: float, drafting: float) -> Dictionary:
	var theta := atan(grade)
	var relative_air := v + headwind # positive wind opposes rider
	return {"gravity": mass_kg * G * sin(theta),
		"rolling": rolling * mass_kg * G * cos(theta),
		"aero": 0.5 * rho * cda * (1.0 - clampf(drafting, 0, 0.45)) * relative_air * absf(relative_air)}

func step(speed: float, watts: float, grade: float, dt: float, headwind: float = 0.0,
	rolling: float = -1.0, drafting: float = 0.0, brake_force: float = 0.0) -> Dictionary:
	assert(dt > 0.0 and dt <= 0.1)
	var wheel_power := maxf(watts, 0.0) * efficiency
	var coefficient := crr if rolling < 0.0 else rolling
	# Implicit midpoint solves momentum and work consistently. At zero speed,
	# propulsion is force-capped. No division by zero, no artificial stop downhill.
	var low := 0.0
	var high := speed + dt * (maximum_force + mass_kg * G + 2000.0) / effective_mass_kg
	for i in range(36):
		var candidate := (low + high) * 0.5
		var midpoint := (speed + candidate) * 0.5
		var forces := resistance(midpoint, grade, headwind, coefficient, drafting)
		var prop := minf(maximum_force, wheel_power / maxf(midpoint, 0.000001))
		var residual: float = effective_mass_kg * (candidate - speed) / dt - prop + forces.gravity + forces.rolling + forces.aero + maxf(brake_force,0)
		if residual > 0: high = candidate
		else: low = candidate
	var next_speed := (low + high) * 0.5
	if next_speed < 0.000001: next_speed = 0.0
	var mean_speed := (speed + next_speed) * 0.5
	var forces := resistance(mean_speed, grade, headwind, coefficient, drafting)
	forces["propulsion"] = minf(maximum_force, wheel_power / maxf(mean_speed, 0.000001))
	forces["braking"] = maxf(brake_force,0)
	return {"speed": next_speed, "distance": mean_speed * dt,
		"acceleration": (next_speed - speed) / dt, "forces": forces}
