extends SceneTree
var passed := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
 if ok: passed+=1; print("PASS ",message)
 else: failures.append(message); push_error(message)
func _initialize():
 var Route = load("res://scripts/route.gd")
 var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/routes/catalog.json"))
 for circuit in catalog:
  var route = Route.new(circuit.data,false)
  var bounded := true
  var continuous := true
  var finite := true
  for i in range(1,route.curve.size()-1):
   var s: float = i*route.spacing
   var p: Vector3 = route.smooth_position(s)
   var raw: Vector3 = route.sample_raw(s).position
   if Vector2(p.x,p.z).distance_to(Vector2(raw.x,raw.z))>1.5: bounded=false
   var before: Vector3 = route.tangent(s-.001)
   var after: Vector3 = route.tangent(s+.001)
   # Analytic one-sided derivatives agree at every spline join.
   if before.distance_to(after)>.05: continuous=false
   if not p.is_finite() or not route.direction(s).is_finite(): finite=false
  check(bounded,"local spline stays within 1.5 m of source station: "+circuit.id)
  check(continuous and finite,"continuous finite tangents across resampling knots: "+circuit.id)
  check(route.smooth_position(0).distance_to(route.sample_raw(0).position)<.001 and route.smooth_position(route.length_m).distance_to(route.sample_raw(route.length_m).position)<.01,"source endpoints anchored: "+circuit.id)
  check(route.direction(0).length()>.99 and route.direction(route.length_m).length()>.99,"endpoint lookahead extrapolates a finite tangent: "+circuit.id)
  check(route.smooth_position(-100)==route.smooth_position(-12),"geometric extrapolation bounded to 12 metres: "+circuit.id)
 # Synthetic jitter makes attenuation measurable independently of the real GPX.
 var fixture := {"length_m":40.0,"ascent_raw_m":4.0,"points":[]}
 for i in range(21):
  fixture.points.append({"s":i*2.0,"x":i*2.0,"z":.2 if i%2==0 else -.2,"alt":366+(.2 if i%2==0 else -.2),"lat":48.0,"lon":7.0})
 var file := FileAccess.open("user://smoothing_fixture.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(fixture)); file.close()
 var synthetic = Route.new("user://smoothing_fixture.json")
 var jitter := 0.0
 for i in range(3,18): jitter=maxf(jitter,absf(synthetic.sample(i*2.0).position.z))
 check(jitter<.02,"spatial filter suppresses alternating GPS jitter by more than 90 percent")
 check(absf(synthetic.sample_raw(10).position.z+.2)<.0001,"filter never changes authoritative source samples")
 print("RESULT_SMOOTHING passed=",passed," failed=",failures.size())
 quit(0 if failures.is_empty() else 1)
