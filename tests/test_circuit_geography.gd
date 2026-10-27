extends SceneTree
var passed := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS ",message)
	else: failures.append(message); push_error(message)
func _initialize() -> void:
	var Route = preload("res://scripts/route.gd")
	var World = preload("res://scripts/geoworld.gd")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/routes/catalog.json"))
	for circuit in catalog:
		var route = Route.new(circuit.data)
		var directory := "res://assets/geodata/circuits/"+str(circuit.id)+"/"
		var world = World.new(directory+"world.json")
		check(not route.geography.is_empty() and route.spacing<=2 and world.terrain_source!=null,"offline derived OSM/LiDAR assets load for "+str(circuit.id))
		check(route.source_points.size()==int(circuit.point_count) and route.data.source_sha256==world.data.route_source_sha256,"original GPX and per-circuit cache identity retained for "+str(circuit.id))
		check(world.covers(0) and world.covers(route.length_m) and not world.covers(route.length_m+1),"terrain covers the entire simulated circuit "+str(circuit.id))
		var valid := true
		var max_grade := 0.0
		var s := 0.0
		while s<=route.length_m:
			var location: Dictionary = route.sample(s)
			var p: Vector3 = location.position
			if not p.is_finite() or not is_finite(location.lat) or not is_finite(location.lon): valid=false
			if not is_finite(world.terrain_source.height(Vector2(p.x,p.z))): valid=false
			if route.source_station(s)<-.001 or route.source_station(s)>route.source_length_m+.01: valid=false
			max_grade=maxf(max_grade,absf(route.grade(s)))
			s += 50
		check(valid and max_grade<1.0,"finite continuous route, real terrain and source mapping across "+str(circuit.id))
		print("MAX_GRADE ",circuit.id," ",max_grade)
		check(absf(route.source_station(route.length_m)-route.source_length_m)<.00001,"reconstructed endpoint maps to exact GPX endpoint "+str(circuit.id))
		var references_path := directory+"terrain_audit.json"
		if FileAccess.file_exists(references_path):
			var references: Array = JSON.parse_string(FileAccess.get_file_as_string(references_path))
			var error := 0.0
			for reference in references:
				var h: float = world.terrain_source.height(Vector2(reference.x,reference.z))
				if not is_finite(h): error=INF
				else: error=maxf(error,absf(h-float(reference.height_m)))
			check(error<.03,"native tile interpolation agrees with offline numeric IGN audit within 3cm "+str(circuit.id))
		else:
			check(false,"terrain audit references must be packaged for "+str(circuit.id))
		check(world.terrain_source.loaded.size()<=32,"raster cache memory stays bounded over the full circuit "+str(circuit.id))
		var distant: float = world.terrain_source.horizon_height(world.terrain_source.lambert(Vector2(12000,12000)))
		check(is_finite(distant) and not world.terrain_source.horizon_values.is_empty(),"coarse IGN horizon loads independently of near terrain tiles "+str(circuit.id))
	print("RESULT_CIRCUIT_GEOGRAPHY passed=",passed," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
