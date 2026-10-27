## Reject non-triangulable source footprints explicitly, without moving them.
extends SceneTree
func _initialize() -> void:
	var restore := "--restore-rejected" in OS.get_cmdline_user_args()
	for id in OS.get_cmdline_user_args():
		if id.begins_with("--"): continue
		var directory := "res://assets/geodata/circuits/"+id+"/"
		var path := directory+"world.json"
		var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var valid: Array = []
		var rejected: Array = []
		var candidates: Array = world.buildings.duplicate()
		if restore and FileAccess.file_exists(directory+"rejected_buildings.json"):
			candidates.append_array(JSON.parse_string(FileAccess.get_file_as_string(directory+"rejected_buildings.json")).buildings)
		var seen: Dictionary = {}
		for building in candidates:
			if seen.has(building.id): continue
			seen[building.id] = true
			var polygon := PackedVector2Array()
			var center := Vector2(building.center[0],building.center[1])
			# Match the renderer: local coordinates avoid cancellation in polygon
			# area tests tens of kilometres from the route origin.
			for p in building.footprint: polygon.append(Vector2(p[0],p[1])-center)
			if Geometry2D.triangulate_polygon(polygon).is_empty(): rejected.append(building)
			else: valid.append(building)
		world.buildings = valid
		world.skipped_buildings["native_triangulation"] = rejected.size()
		var output := FileAccess.open(path,FileAccess.WRITE)
		output.store_string(JSON.stringify(world));output.close()
		output = FileAccess.open(directory+"rejected_buildings.json",FileAccess.WRITE)
		output.store_string(JSON.stringify({"reason":"Source footprint cannot be triangulated by Godot; excluded from rendering, geometry retained here", "buildings":rejected}));output.close()
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"manifest.json"))
		manifest.counts.rendered_buildings = valid.size()
		manifest.counts.rejected_triangulation = rejected.size()
		output = FileAccess.open(directory+"manifest.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(manifest));output.close()
		print("WORLD_VALIDATED ",id," valid=",valid.size()," rejected=",rejected.size())
	quit()
