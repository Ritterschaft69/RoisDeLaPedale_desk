extends SceneTree
func _initialize():call_deferred("run")
func run():
 var stage:=Node3D.new();root.add_child(stage)
 var rider=load("res://scripts/rider.gd").new();rider.set_variant("tricolour");stage.add_child(rider)
 rider.crank=.85;rider.animate(0,0,0)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("cbd8df")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6
 stage.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);sun.light_energy=1.0;stage.add_child(sun)
 var floor:=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(20,20)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("cbd8df");floor.material_override=mat;stage.add_child(floor)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0;stage.add_child(camera)
 for item in [["side",Vector3(3,1.05,0)],["rear",Vector3(0,1.15,3)],["front",Vector3(0,1.15,-3)],["three-quarter",Vector3(2.3,1.3,-2.3)]]:
  camera.position=item[1];camera.look_at(Vector3(0,.78,0),Vector3.UP)
  sun.rotation_degrees.y=rad_to_deg(atan2(item[1].x,item[1].z))-30
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/v0.6.8-tricolour-"+item[0]+".png")
 camera.position=Vector3(3,1.05,0);camera.look_at(Vector3(0,.78,0),Vector3.UP)
 for phase in range(4):
  rider.crank=phase*TAU/4;rider.animate(0,0,0)
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/v0.6.8-tricolour-pedal-"+str(phase)+".png")
 rider.crank=.85;rider.animate(0,0,0)
 camera.size=.55;camera.position=Vector3(.9,1.48,-1.4);camera.look_at(Vector3(0,1.416,-.38),Vector3.UP)
 for i in range(3):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/v0.6.8-tricolour-portrait.png")
 stage.free();await process_frame
 var app=load("res://main.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.set_physics_process(false);app.rider.set_variant("tricolour");app.start_session()
 app.distance=6200;app.speed=8;app.watts=230;app.cadence=85
 app.world.update_at(app.distance,true);app.rider.crank=.85;app.rider.animate(0,0,0)
 for view in [0,2]:
  app.camera_follow.set_view(view);app.position_scene(0,true);app.hud.queue_redraw()
  for i in range(3):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/v0.6.8-tricolour-ride-"+str(view)+".png")
 app.free();await process_frame;quit()
