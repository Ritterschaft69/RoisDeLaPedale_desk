extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false);app.smoke_frames=1
 app.show_devices()
 var deadline:=Time.get_ticks_msec()+15000
 while app.bluetooth.peer==null and Time.get_ticks_msec()<deadline:await process_frame
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/v0.7.0-bluetooth-ready.png")
 app.bluetooth.scan()
 deadline=Time.get_ticks_msec()+15000
 while app.bluetooth.scanning and Time.get_ticks_msec()<deadline:await process_frame
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/v0.7.0-bluetooth-no-adapter.png")
 app.free();await process_frame;quit()
