extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false)
 app.select_circuit("saint_die");app.start_session()
 app.distance=6200;app.speed=8;app.cadence=85;app.watts=230
 app.rider.animate(.2,85,8);app.world.update_at(app.distance,true)
 for view in range(3):
  app.camera_follow.set_view(view);app.position_scene(0,true);app.hud.queue_redraw()
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/v0.6.4-view-"+str(view)+".png")
 app.free();await process_frame;quit()
