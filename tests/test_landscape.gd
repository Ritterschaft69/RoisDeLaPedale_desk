extends SceneTree
const Geo=preload("res://scripts/geoworld.gd")
const M=preload("res://scripts/materials.gd")
var passed:=0
var failed:=0
func check(ok: bool,message: String) -> void:
 if ok:passed+=1;print("PASS ",message)
 else:failed+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var geo=Geo.new("res://assets/geodata/circuits/home_sweet_home/world.json")
 var fixture={"id":"fixture","seed":4,"footprint":[[0,0],[18,0],[18,12],[0,12]],"center":[9,6],"base_render":300,"height":9}
 var house:=Node3D.new();root.add_child(house);geo.build(house,fixture,true)
 var triangles:=0;var textured:=0;var valid_uv:=true
 for item in house.get_child(0).get_children():
  if not item is MeshInstance3D:continue
  for surface in range(item.mesh.get_surface_count()):
   var arrays=item.mesh.surface_get_arrays(surface)
   triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
   if item.material_override==M.facade():
    textured+=1
    valid_uv=valid_uv and arrays[Mesh.ARRAY_TEX_UV]!=null and arrays[Mesh.ARRAY_TEX_UV2]!=null
 check(triangles<100,"a detailed two-storey building needs fewer than 100 triangles including chimney")
 check(textured==1 and valid_uv,"windows use the wall surface UVs rather than separate window geometry")
 check(M.facade()==M.facade() and M.facade().next_pass==null,"facades share one opaque material without an extra outline pass")
 house.free()
 var route=preload("res://scripts/route.gd").new("res://assets/routes/home_sweet_home.json")
 var center:Vector3=route.smooth_position(3000)
 var first:=Node3D.new();root.add_child(first)
 geo.forest_masses(first,center,0,func(_p: Vector2):return 100.0)
 check(first.get_child_count()>0 and first.get_child_count()<70 and geo.last_forest_triangles<30000,"forest parcels use a bounded set of shared sector meshes")
 var valid:=true
 for node in first.get_children():
  if not node is MeshInstance3D:valid=false;continue
  var arrays=node.mesh.surface_get_arrays(0)
  for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),17):
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
   if arrays[Mesh.ARRAY_NORMAL][i].y>.05 and (p.y<101.3 or p.y>128):valid=false
 check(valid,"canopy is rooted on the displayed ground instead of floating above the IGN mesh")
 var cached:int=geo.forest_cache.size();var second:=Node3D.new();root.add_child(second)
 geo.forest_masses(second,center,0,func(_p: Vector2):return 200.0)
 var moved:=false
 if first.get_child_count()>0 and second.get_child_count()>0:
  var a:Vector3=first.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
  var b:Vector3=second.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
  moved=absf(b.y-a.y-100)<.001
 check(moved and geo.forest_cache.size()==cached,"cached forest data can be reprojected onto a new terrain chunk")
 check(geo.forest_cache.size()<=192,"forest geometry cache remains bounded")
 check(not "ALPHA" in M.forest_canopy().shader.code,"forest envelopes are opaque and avoid stacked transparent foliage")
 first.free();second.free();await process_frame
 print("RESULT_LANDSCAPE passed=",passed," failed=",failed)
 quit(0 if failed==0 else 1)
