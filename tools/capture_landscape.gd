extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false);app.smoke_frames=1
 app.world.quality=0;app.apply_graphics()
 for item in [["home_sweet_home",3000],["home_sweet_home",8500],["saint_die",1180],["oderen_grand_ballon",32000],["oderen_grand_ballon",89099]]:
  app.show_home();app.select_circuit(item[0]);app.start_session()
  app.distance=item[1];app.speed=8;app.watts=230;app.cadence=85
  app.camera_follow.set_view(2);app.rider.animate(.2,85,8)
  app.world.update_at(app.distance,true);app.position_scene(0,true);app.hud.queue_redraw()
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/v0.6.9-landscape-"+item[0]+"-"+str(item[1])+".png")
  print("LANDSCAPE ",item[0]," forest_triangles=",app.world.geographic.last_forest_triangles)
 app.free();await process_frame;quit()
