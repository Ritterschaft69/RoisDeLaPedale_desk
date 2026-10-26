## Reproducible native camera capture: manual 50 Hz simulation, 20 rendered frames/s.
## python tools/run_cloud.py --fixed-fps 60 --script res://tools/capture_camera.gd
extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var app = load("res://main.tscn").instantiate()
 root.add_child(app)
 app.set_physics_process(false)
 app.select_circuit("saint_die")
 app.start_session()
 app.set_process(false)
 app.input.demo_watts = 220
 app.distance = 55
 app.speed = 8
 app.world.update_at(app.distance,true)
 app.position_scene(0,true)
 var accumulator := 0.0
 for frame in range(96):
  accumulator+=.05
  while accumulator>=.02-.000001:
   app._physics_process(.02)
   accumulator-=.02
  app.position_scene(.05)
  app.rider.animate(.05,app.cadence,app.speed)
  app.world.update_at(app.distance)
  app.hud.queue_redraw()
  for i in range(2): await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/camera_stable_%03d.png" % frame)
 print("CAMERA_CAPTURE_COMPLETE station=",app.distance," lateral=",app.lane.lateral)
 quit()
