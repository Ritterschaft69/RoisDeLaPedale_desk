extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false)
 var prefix="v0.6.5"
 if "--before" in OS.get_cmdline_user_args():prefix="before-v0.6.5"
 for item in [["saint_die",1180],["home_sweet_home",1270],["oderen_grand_ballon",2580]]:
  app.show_home();app.select_circuit(item[0]);app.start_session()
  app.distance=item[1];app.speed=8;app.watts=230;app.cadence=85
  app.camera_follow.set_view(2);app.rider.animate(.2,85,8)
  app.world.update_at(app.distance,true);app.position_scene(0,true);app.hud.queue_redraw()
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  var path="res://docs/previews/" if prefix=="v0.6.5" else "res://build/"
  root.get_texture().get_image().save_png(path+prefix+"-roads-"+item[0]+".png")
 app.free();await process_frame;quit()
