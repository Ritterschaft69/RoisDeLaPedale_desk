## Authoring step: export the procedural garment recipe for offline union.
extends SceneTree
const M = preload("res://scripts/materials.gd")
func _initialize(): call_deferred("run")
func part(instance: MeshInstance3D) -> Dictionary:
 var a := instance.mesh.surface_get_arrays(0)
 var vertices: Array = []
 for v in a[Mesh.ARRAY_VERTEX]:
  var p: Vector3 = instance.global_transform*v
  vertices.append([p.x,p.y,p.z])
 var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
 if indices.is_empty():
  for i in range(vertices.size()): indices.append(i)
 return {"vertices":vertices,"indices":Array(indices)}
func run():
 var rider = load("res://tools/legacy_rider.gd").new()
 rider.authoring_source = true
 root.add_child(rider)
 var shirt: Array = [part(rider.source_torso)]
 for sleeve in rider.source_sleeves: shirt.append(part(sleeve))
 var pants: Array = [part(rider.source_pelvis)]
 for limb in rider.limbs:
  var hip := Vector3(float(limb.side)*.115,1.08,.24)
  M.place_rod(limb.bib,hip,hip+rider.bib_rest_axis(float(limb.side))*.49*.72)
  pants.append(part(limb.bib))
 var file := FileAccess.open("res://build/rider_parts.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"jersey":shirt,"bib":pants}))
 file.close()
 rider.queue_free()
 await process_frame
 quit()
