extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false)
 app.camera_follow.set_view(0)
 for id in ["original","tricolour"]:
  app.show_home();app.select_rider(id);app.rider.crank=.85;app.rider.animate(0,0,0);app.position_scene(0,true)
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/v0.6.8-choice-"+id+".png")
 app.show_home()
 for i in range(3):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/v0.6.8-home.png")
 app.free();await process_frame;quit()
