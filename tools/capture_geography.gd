## Native screenshots, no generated illustration.
extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.set_physics_process(false)
	app.set_process(false)
	var cases := [["saint_die",6200,"saint-die"],["sortie_matin",32000,"sortie-matin"],["oderen_grand_ballon",-1,"grand-ballon"]]
	var arguments := OS.get_cmdline_user_args()
	for item in cases:
		if not arguments.is_empty() and item[0] not in arguments: continue
		app.show_home()
		app.select_circuit(item[0])
		app.start_session()
		app.distance = item[1]
		if app.distance<0:
			var maximum := -INF
			for i in range(app.route.curve.size()):
				if app.route.curve[i].y>maximum:
					maximum = app.route.curve[i].y
					app.distance = maxf(0,i*app.route.spacing-4500)
		app.input.demo_watts = 230
		app.speed = 8
		app.watts = 230
		app.cadence = 85
		app.rider.animate(.2,85,8)
		app.world.update_at(app.distance,true)
		app.position_scene(0,true)
		app.hud.queue_redraw()
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/v0.6.0-"+str(item[2])+".png")
		print("GEOGRAPHY_CAPTURE ",item[0]," station=",app.distance," altitude=",app.route.sample(app.distance).position.y)
	app.queue_free()
	await process_frame
	quit()
