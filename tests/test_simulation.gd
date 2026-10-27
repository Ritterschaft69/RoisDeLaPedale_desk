extends SceneTree

const Physics = preload("res://scripts/physics.gd")
const Route = preload("res://scripts/route.gd")
const Adapter = preload("res://scripts/trainer_input.gd")
const Recorder = preload("res://scripts/recorder.gd")
var passed := 0
var failures: Array[String] = []

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ",description)
	else:
		failures.append(description)
		push_error("FAIL "+description)

func simulate(watts: float, grade: float, seconds: float, start: float = 0.0, wind: float = 0.0, crr: float = 0.005) -> float:
	var engine := Physics.new()
	var speed := start
	for i in range(roundi(seconds/0.02)):
		speed = engine.step(speed,watts,grade,0.02,wind,crr).speed
	return speed

func _init() -> void:
	var engine := Physics.new()
	var first := engine.step(0,200,0,0.02)
	check(is_finite(first.speed) and first.speed > 0,"standing start is finite and moves")
	check(engine.step(0,0,0.1,0.02).speed == 0,"no reverse drift at rest uphill")
	var equilibrium := simulate(200,0,240)
	print("EQUILIBRIUM_KMH ",equilibrium*3.6)
	# The specification's 30.3 km/h example is inconsistent with its own
	# coefficients: 0.204*v^3 + 4.118793*v = 195 gives 33.0073 km/h.
	check(absf(equilibrium*3.6-33.0073) < 0.01,"200 W / 84 kg equilibrium matches independent force balance")
	check(absf(0.204*pow(equilibrium,3)+84*9.80665*0.005*equilibrium-195) < 0.01,"equilibrium consumes exactly 195 wheel watts")
	var coasting := simulate(0,0,60,8)
	check(coasting >= 0 and coasting < 8,"coasting on flat decelerates progressively")
	check(simulate(0,0,180,8) == 0,"rolling resistance eventually stops a coasting rider")
	check(simulate(200,0.06,120) < equilibrium,"same power is slower uphill")
	check(simulate(0,-0.06,20) > 3,"zero-watt downhill can accelerate")
	check(simulate(200,0,150,0,0,0.0095) < equilibrium,"gravel increases rolling resistance")
	check(simulate(200,0,150,0,0,0.005*1.12) < equilibrium,"wet asphalt increases rolling resistance")
	check(simulate(200,0,150,0,3) < equilibrium,"headwind reduces speed")
	check(simulate(200,0,150,0,-3) > equilibrium,"tailwind increases speed")
	var solo := engine.resistance(8,0.04,0,0.005,0)
	var draft := engine.resistance(8,0.04,0,0.005,0.32)
	check(is_equal_approx(draft.aero,solo.aero*0.68) and draft.rolling == solo.rolling and draft.gravity == solo.gravity,"drafting changes aerodynamic drag only")
	var result := engine.step(8,200,0,0.02)
	var energy: float = 0.5*engine.effective_mass_kg*(result.speed*result.speed-64)
	var losses: float = (result.forces.gravity+result.forces.rolling+result.forces.aero)*result.distance
	check(absf(energy+losses-200*engine.efficiency*0.02) < 0.000001,"midpoint integration conserves wheel work")
	var outcomes: Array[float] = []
	for fps in [30,60,144]:
		var accumulator := 0.0
		var velocity := 0.0
		for frame in range(fps*20):
			accumulator += 1.0/fps
			while accumulator >= 0.02-0.00000001:
				velocity = engine.step(velocity,200,0,0.02).speed
				accumulator -= 0.02
		outcomes.append(velocity)
	check(absf(outcomes[0]-outcomes[1]) < 0.0000001 and absf(outcomes[1]-outcomes[2]) < 0.0000001,"fixed simulation agrees at 30 / 60 / 144 render FPS")
	var route := Route.new()
	check(route.sample_raw(0).position.is_equal_approx(Vector3(0,366.2,0)),"original GPX point and altitude remain accessible separately")
	check(route.sample(route.length_m).index == route.source_points.size()-2,"route endpoint clamps correctly in original GPX mapping")
	var a: float = route.sample(1000).position.y
	var b: float = route.sample(1012).position.y
	check(absf(route.grade(1006)-(b-a)/12) < 0.000001,"grade is sampled over 12 spatial metres")
	var adapter := Adapter.new()
	adapter.mode = "ftms"
	check(adapter.observe(250,85,1000),"valid trainer observations accepted")
	check(not adapter.observe(10000,85,1100),"implausible observations rejected")
	check(adapter.read(2000).watts == 250 and adapter.read(3001).watts == 0,"stale trainer watts zero after two seconds")
	for i in range(25): adapter.smooth(100)
	var smoothed := adapter.smooth(200)
	check(absf(smoothed-104) < 0.001,"0.5 s power window at 50 Hz")
	var recorder := Recorder.new()
	recorder.geographic_route = not route.geography.is_empty()
	recorder.begin(route.sample(0).position.y)
	for i in range(100): recorder.tick(0.02,i*0.1,5,200,80,route.sample(i*0.1))
	var activity := recorder.save(10,false)
	check(not activity.has("error") and FileAccess.file_exists(activity.path),"activity JSON persisted locally")
	if activity.has("path"):
		var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(activity.path))
		check(stored.samples.size() >= 1 and stored.input_source == "demo" and absf(stored.average_watts-200)<0.001,"recorded samples, average watts and demo provenance are correct")
		DirAccess.remove_absolute(activity.path)
	print("RESULT passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
