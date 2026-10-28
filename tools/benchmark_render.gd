## Native comparative benchmark; software rendering is not a Windows GPU estimate.
extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate()
 root.add_child(app);app.set_process(false);app.set_physics_process(false)
 if "--light" in OS.get_cmdline_user_args():
  app.world.quality=0;app.apply_graphics()
 for item in [["oderen_grand_ballon",32000],["sortie_matin",32000]]:
  app.show_home();app.select_circuit(item[0]);app.start_session();app.distance=item[1];app.speed=8
  app.world.update_at(app.distance,true);app.position_scene(0,true)
  for i in range(5):await process_frame
  var times:Array[float]=[];var calls:=0;var primitives:=0
  for i in range(12):
   var start=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
   times.append((Time.get_ticks_usec()-start)/1000.)
   calls+=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
   primitives+=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
  times.sort()
  print("RENDER_BENCH ",item[0]," median_ms=",times[6]," draw_calls=",calls/12," primitives=",primitives/12)
 app.free();await process_frame;quit()
