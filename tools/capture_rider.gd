## Native render evidence: python tools/run_cloud.py --fixed-fps 60 --script res://tools/capture_rider.gd
extends SceneTree
func _initialize(): call_deferred("run")
func run():
 root.size = Vector2i(1200,900)
 var stage := Node3D.new()
 root.add_child(stage)
 var rider = load("res://scripts/rider.gd").new()
 stage.add_child(rider)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(.65,.68,.72)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = .30
 stage.add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-35,-30,0)
 sun.light_energy = .8
 sun.shadow_enabled = true
 stage.add_child(sun)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-20,140,0)
 fill.light_energy = .25
 stage.add_child(fill)
 var floor_mesh := MeshInstance3D.new()
 floor_mesh.mesh = PlaneMesh.new()
 floor_mesh.mesh.size = Vector2(200,200)
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color(.65,.68,.72)
 floor_mesh.material_override = mat
 stage.add_child(floor_mesh)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 2.03
 stage.add_child(camera)
 camera.current = true
 rider.crank=.85+PI
 rider.animate(0,0,0)
 for item in [["side",Vector3(3,1.05,0)],["rear",Vector3(0,1.15,3)],["front",Vector3(0,1.15,-3)]]:
  sun.rotation_degrees.y = rad_to_deg(atan2(item[1].x,item[1].z))-30
  fill.rotation_degrees.y = sun.rotation_degrees.y+140
  camera.position = item[1]
  camera.look_at(Vector3(0,.85,0),Vector3.UP)
  for i in range(3): await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/v051_"+item[0]+".png")
  print("CAPTURE ",item[0])
 # Detail views expose the garment joins instead of hiding them in the full shot.
 for item in [["shoulders",Vector3(2,1.65,1.1),Vector3(0,1.32,-.13)],["hips",Vector3(2,1.35,1.3),Vector3(0,1.04,.18)]]:
  camera.size = .76
  camera.position = item[1]
  camera.look_at(item[2],Vector3.UP)
  sun.rotation_degrees.y = rad_to_deg(atan2(item[1].x,item[1].z))-30
  fill.rotation_degrees.y = sun.rotation_degrees.y+140
  for i in range(3): await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/v051_"+item[0]+".png")
 camera.size = 2.03
 var canvas := CanvasLayer.new()
 stage.add_child(canvas)
 var label := Label.new()
 label.text = "Sens de marche →    •    pédalage vers l’avant · 60 tr/min"
 label.position = Vector2(220,24)
 label.add_theme_color_override("font_color",Color("253143"))
 label.add_theme_font_size_override("font_size",24)
 canvas.add_child(label)
 sun.rotation_degrees.y = 60
 fill.rotation_degrees.y = 200
 camera.position = Vector3(3,1.05,0)
 camera.look_at(Vector3(0,.85,0),Vector3.UP)
 for i in range(32):
  rider.crank=TAU*float(i)/32
  rider.animate(1.0/32,0,4)
  for j in range(2): await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/v051_pedal_%02d.png" % i)
 print("PEDAL_CAPTURE_COMPLETE")
 camera.size = .90
 camera.position = Vector3(1,1.30,2.4)
 camera.look_at(Vector3(0,1.02,.18),Vector3.UP)
 sun.rotation_degrees.y = -5
 fill.rotation_degrees.y = 135
 label.text = "Jonctions bassin / cuisses — cycle complet de pédalage"
 for i in range(32):
  rider.crank = TAU*float(i)/32
  rider.animate(0,0,0)
  for j in range(2): await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/v051_joint_%02d.png" % i)
 print("JOINT_CAPTURE_COMPLETE")
 stage.queue_free()
 await process_frame
 var app = load("res://main.tscn").instantiate()
 root.add_child(app)
 app.set_physics_process(false)
 app.select_circuit("saint_die")
 app.start_session()
 app.set_process(false)
 app.distance = 6200
 app.world.update_at(app.distance,true)
 app.position_scene(0,true)
 app.rider.crank = .85+PI
 app.rider.animate(0,0,0)
 app.camera.current = true
 for i in range(4): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/v051_ride.png")
 print("RIDE_CAPTURE_COMPLETE")
 quit()
