extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
 if ok: passed+=1; print("PASS ",message)
 else: failed+=1;push_error(message)
func _initialize(): call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate()
 root.add_child(app);app.set_process(false);app.set_physics_process(false)
 app.select_circuit("oderen_grand_ballon")
 var geo=app.world.geographic
 var center:Vector3=app.route.smooth_position(32000)
 var candidates:Array=geo.nearby_buildings(Vector2(center.x,center.z),420)
 var missing:=0
 for i in range(geo.data.buildings.size()):
  var b:Dictionary=geo.data.buildings[i]
  if Vector2(b.center[0],b.center[1]).distance_to(Vector2(center.x,center.z))<=420 and not candidates.has(i): missing+=1
 check(missing==0,"spatial query retains every nearby building")
 check(candidates.size()<geo.data.buildings.size()/4,"spatial query excludes distant buildings")
 var exact:=true
 for i in candidates.slice(0,30):
  var ring:PackedVector2Array=geo.building_bounds[i].ring
  var p:Vector2=ring[0].lerp(ring[1],.5)
  var brute:=false
  for item in geo.building_bounds:
   if item.bounds.has_point(p) and Geometry2D.is_point_in_polygon(p,item.ring): brute=true;break
  if geo.building_at(p)!=brute: exact=false
 check(exact,"indexed footprint collision matches polygon reference")
 app.world.update_at(31900,true)
 var old=app.world.generated
 app.world.update_at(32000)
 check(app.world.generated==old and old.is_inside_tree(),"streaming keeps previous scenery visible")
 var frames:=0
 while app.world.streaming and frames<600: await process_frame;frames+=1
 check(not app.world.streaming and app.world.generated!=old,"streaming completes and swaps scenery")
 check(geo.geometry_cache.size()<=2048,"building geometry cache stays bounded")
 app.world.update_at(32100);await process_frame
 app.select_circuit("sortie_matin");var correct=app.world.generated
 for i in range(50):await process_frame
 check(correct==app.world.generated and not app.world.streaming,"circuit switch cancels obsolete streaming")
 app.world.quality=0;app.apply_graphics()
 var shadows:=false
 for child in app.world.get_children():
  if child is DirectionalLight3D: shadows=child.shadow_enabled
 check(not shadows,"light quality disables expensive shadow passes")
 app.free();await process_frame
 print("RESULT_PERFORMANCE passed=",passed," failed=",failed)
 quit(0 if failed==0 else 1)
