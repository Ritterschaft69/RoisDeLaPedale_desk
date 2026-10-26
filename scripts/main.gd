extends Node3D

const Physics = preload("res://scripts/physics.gd")
const Route = preload("res://scripts/route.gd")
const World = preload("res://scripts/world.gd")
const Rider = preload("res://scripts/rider.gd")
const HUD = preload("res://scripts/hud.gd")
const InputAdapter = preload("res://scripts/trainer_input.gd")
const Recorder = preload("res://scripts/recorder.gd")
const CameraFollow = preload("res://scripts/camera_follow.gd")
const LanePlanner = preload("res://scripts/lane_planner.gd")

var route := Route.new()
var circuits: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/routes/catalog.json"))
var selected_circuit: Dictionary = circuits[0]
var physics := Physics.new()
var input := InputAdapter.new()
var recorder := Recorder.new()
var lane := LanePlanner.new()
var world := World.new()
var rider := Rider.new()
var camera := Camera3D.new()
var camera_follow := CameraFollow.new()
var hud := HUD.new()
var overlay := Control.new()
var screen := "home"
var speed := 0.0
var distance := 0.0
var previous_distance := 0.0
var previous_lateral := 1.55
var elapsed := 0.0
var watts := 0.0
var cadence := 0.0
var rider_mass := 75.0
var terrain_kind := 0
var settings := ConfigFile.new()
var error_label: Label
var smoke_frames := -1

func _ready() -> void:
	settings.load("user://settings.cfg")
	var saved_circuit: String = settings.get_value("route","selected_id","saint_die")
	for circuit in circuits:
		if circuit.id == saved_circuit: selected_circuit = circuit
	route = Route.new(selected_circuit.data)
	route.start_m = selected_circuit.get("start_m",0.0)
	distance = route.start_m
	input.demo_watts = settings.get_value("rider","demo_watts",180.0)
	rider_mass = settings.get_value("rider","mass_kg",75.0)
	world.quality = settings.get_value("graphics","quality",1)
	add_child(world)
	world.setup(route)
	world.update_at(0,true)
	add_child(rider)
	add_child(camera)
	camera.fov = 48
	camera.far = 2200
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.app = self
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_theme()
	position_scene(0,true)
	show_home()
	if settings.get_value("graphics","fullscreen",false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	for argument in OS.get_cmdline_user_args():
		if argument == "--smoke":
			start_session()
			smoke_frames = 160
		if argument == "--screenshot":
			start_session()
			distance = 1200 if "--geo-screenshot" in OS.get_cmdline_user_args() else 6200
			world.update_at(distance,true)
			position_scene(0,true)
			smoke_frames = 100

func apply_theme() -> void:
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/OpenSans-Regular.ttf")
	theme.default_font_size = 16
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("283e39")
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = Color("3d564a")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("596b4c")
	theme.set_stylebox("normal","Button",normal)
	theme.set_stylebox("hover","Button",hover)
	theme.set_stylebox("pressed","Button",pressed)
	theme.set_color("font_color","Label",Color("f3f1df"))
	theme.set_color("font_color","Button",Color("f3f1df"))
	overlay.theme = theme

func clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()

func card(title: String, subtitle: String, wide: bool = false) -> VBoxContainer:
	clear_overlay()
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.position = Vector2(32,65) if screen in ["home","circuits"] else Vector2(440,185)
	panel.custom_minimum_size = Vector2(510 if not wide else 650,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045,0.09,0.085,0.96)
	style.set_corner_radius_all(18)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	panel.add_child(column)
	var eyebrow := Label.new()
	eyebrow.text = "ROIS DE LA PÉDALE  /  0.2"
	eyebrow.add_theme_font_size_override("font_size",12)
	eyebrow.modulate = Color("efbe76")
	column.add_child(eyebrow)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font",preload("res://assets/fonts/OpenSans-Semibold.ttf"))
	heading.add_theme_font_size_override("font_size",36)
	column.add_child(heading)
	var caption := Label.new()
	caption.text = subtitle
	caption.add_theme_font_size_override("font_size",14)
	caption.modulate = Color("b3c4b7")
	column.add_child(caption)
	return column

func label_in(parent: Node, text: String, small: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 446
	if small: label.add_theme_font_size_override("font_size",13)
	parent.add_child(label)
	return label

func button_in(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	if primary:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("d8b47a")
		box.set_corner_radius_all(9)
		button.add_theme_stylebox_override("normal",box)
		button.add_theme_color_override("font_color",Color("182c28"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func show_home() -> void:
	hud.show()
	overlay.show()
	screen = "home"
	var column := card("Prenez la route.",str(selected_circuit.short_name)+"\nTrois circuits installés, disponibles hors ligne.")
	label_in(column,"%.1f km   ·   %s points GPS   ·   D+ brut %.0f m" % [route.length_m/1000,route.points.size(),route.ascent_m])
	button_in(column,"Choisir un circuit  ·  3 parcours",show_circuits)
	var power_label := label_in(column,"Puissance démo : %d W" % input.demo_watts)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 500
	slider.step = 5
	slider.value = input.demo_watts
	slider.custom_minimum_size.y = 26
	slider.value_changed.connect(func(value: float):
		input.demo_watts = value
		power_label.text = "Puissance démo : %d W" % value)
	column.add_child(slider)
	button_in(column,"Démarrer en mode démo  →",start_session,true)
	button_in(column,"Périphériques",show_devices)
	button_in(column,"Paramètres",show_settings)
	button_in(column,"Activités enregistrées",show_history)
	var scenery := "IGN : 3 premiers km ; au-delà, décor illustratif." if not world.geographic.data.is_empty() else "Décor illustratif ; données IGN non installées pour ce circuit."
	label_in(column,"Puissance simulée · D+ brut non filtré\n"+scenery,true)
	button_in(column,"Quitter",func(): save_settings(); get_tree().quit())

func show_circuits() -> void:
	screen = "circuits"
	var column := card("Choisissez un circuit.","Le tracé, la pente et la progression suivent le GPX choisi.")
	for circuit in circuits:
		var circuit_id: String = circuit.id
		var chosen: bool = circuit_id == str(selected_circuit.id)
		var text := ("✓  " if chosen else "")+str(circuit.short_name)+"\n%.1f km  ·  D+ brut %.0f m" % [float(circuit.length_m)/1000,float(circuit.ascent_raw_m)]
		var button := button_in(column,text,func(): select_circuit(circuit_id),chosen)
		button.name = "Circuit_"+circuit_id
		button.custom_minimum_size.y = 72
		label_in(column,circuit.description,true)
	button_in(column,"Retour à l’accueil",show_home)

func select_circuit(circuit_id: String) -> bool:
	# A circuit can only change outside an active or paused session.
	if screen in ["ride","paused"]: return false
	var entry: Dictionary = {}
	for circuit in circuits:
		if circuit.id == circuit_id: entry = circuit
	if entry.is_empty(): return false
	if circuit_id != str(selected_circuit.id):
		selected_circuit = entry
		route = Route.new(entry.data)
		route.start_m = entry.get("start_m",0.0)
		world.set_route(route)
		lane.reset()
		distance = route.start_m
		speed = 0
		elapsed = 0
		watts = 0
		cadence = 0
		world.update_at(0,true)
		position_scene(0,true)
	save_settings()
	show_home()
	return true

func show_devices() -> void:
	var column := card("Périphériques", "Le mode démo est disponible sans matériel.")
	label_in(column,"Bluetooth FTMS : adaptateur natif non intégré.\nAucun appareil découvert ni connecté.\nANT+ FE-C : extension future.\nAucune commande de résistance n’est envoyée.")
	label_in(column,"L’intégration et la validation sur home trainer réel\nnécessitent un lot matériel dédié.",true)
	button_in(column,"Retour",show_home)

func show_settings() -> void:
	var column := card("À votre rythme.","Préférences enregistrées localement.")
	label_in(column,"Masse du cycliste (kg) · vélo + équipement : 9 kg")
	var mass := SpinBox.new()
	mass.min_value = 30
	mass.max_value = 180
	mass.value = rider_mass
	mass.value_changed.connect(func(value: float): rider_mass = value)
	column.add_child(mass)
	label_in(column,"Qualité du décor")
	var quality := OptionButton.new()
	quality.add_item("Légère · visibilité 260 m")
	quality.add_item("Standard · visibilité 450 m")
	quality.select(world.quality)
	quality.item_selected.connect(func(index: int): world.quality = index; world.update_at(distance,true))
	column.add_child(quality)
	label_in(column,"Surface simulée (paramètre de test, pas une donnée IGN)",true)
	var surface := OptionButton.new()
	for text in ["Asphalte", "Gravier", "Asphalte mouillé"]: surface.add_item(text)
	surface.select(terrain_kind)
	surface.item_selected.connect(func(index: int): terrain_kind = index)
	column.add_child(surface)
	button_in(column,"Basculer plein écran  ·  F11",toggle_fullscreen)
	label_in(column,"Audio : non intégré à ce premier lot.\nLes réglages ne nécessitent aucun compte.",true)
	button_in(column,"Enregistrer et revenir",func(): save_settings(); show_home(),true)

func show_history() -> void:
	var column := card("Vos sorties", "Activités locales · les sessions démo sont identifiées.")
	var dir := DirAccess.open("user://activities")
	if dir == null:
		label_in(column,"Aucune activité enregistrée.")
	else:
		var files := dir.get_files()
		files.sort()
		files.reverse()
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(446,240)
		column.add_child(scroll)
		var entries := VBoxContainer.new()
		entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entries.add_theme_constant_override("separation",16)
		scroll.add_child(entries)
		var count := 0
		for path in files:
			if not path.ends_with(".json"): continue
			var activity = JSON.parse_string(FileAccess.get_file_as_string("user://activities/"+path))
			if not activity is Dictionary: continue
			label_in(entries,"%s\n%s · %.2f km · %.0f W · DÉMO" % [activity.get("route_name","Boucle de Saint-Dié-des-Vosges"),str(activity.get("started_at_utc","")).replace("T"," "),float(activity.get("distance_m",0))/1000,float(activity.get("average_watts",0))],true)
			count += 1
			if count == 6: break
	label_in(column,"Dossier :\n"+ProjectSettings.globalize_path("user://activities"),true)
	button_in(column,"Retour",show_home)

func start_session() -> void:
	save_settings()
	distance = route.start_m
	elapsed = 0
	speed = 0
	watts = 0
	input.samples.clear()
	lane.reset()
	world.life.set_route(world)
	physics.mass_kg = rider_mass+9
	physics.effective_mass_kg = physics.mass_kg+2
	recorder.begin(route.sample(route.start_m).position.y)
	recorder.route_id = selected_circuit.id
	recorder.route_name = selected_circuit.name
	recorder.route_source_sha256 = route.data.source_sha256
	recorder.route_start_m = route.start_m
	screen = "ride"
	clear_overlay()
	world.update_at(0,true)
	position_scene(0,true)
	show_ride_controls()

func show_ride_controls() -> void:
	var pause_button := button_in(overlay,"Ⅱ  Pause",toggle_pause)
	pause_button.position = Vector2(740,60)
	pause_button.custom_minimum_size.x = 115
	var power_box := HBoxContainer.new()
	overlay.add_child(power_box)
	power_box.position = Vector2(32,195)
	button_in(power_box,"− 25 W",func(): input.demo_watts = maxf(0,input.demo_watts-25))
	button_in(power_box,"+ 25 W",func(): input.demo_watts = minf(500,input.demo_watts+25))
	button_in(power_box,"Roue libre",func(): input.demo_watts = 0)

func toggle_pause() -> void:
	if screen == "ride":
		hud.show()
		overlay.show()
		screen = "paused"
		var column := card("Une respiration.","La simulation et le chronomètre sont en pause.")
		button_in(column,"Reprendre  →",resume_session,true)
		button_in(column,"Terminer et enregistrer",finish_session)
	elif screen == "paused": resume_session()

func resume_session() -> void:
	screen = "ride"
	clear_overlay()
	show_ride_controls()

func finish_session() -> void:
	var result := recorder.save(distance-route.start_m,distance >= route.length_m)
	screen = "summary"
	var column := card("Belle échappée.",str(selected_circuit.short_name)+"\nSession démo · aucune puissance mesurée.")
	label_in(column,"%.2f km     %02d:%02d     D+ %.0f m" % [(distance-route.start_m)/1000,int(elapsed)/60,int(elapsed)%60,recorder.ascent_m])
	label_in(column,"%.0f W de moyenne · %.0f W maximum" % [recorder.sum_watts/maxf(elapsed,0.001),recorder.max_watts])
	if result.has("error"):
		label_in(column,result.error)
		button_in(column,"Réessayer l’enregistrement",finish_session)
	else:
		label_in(column,"Activité enregistrée en JSON dans le dossier utilisateur.",true)
		print("ACTIVITY_SAVED ",result.path)
	button_in(column,"Retour à l’accueil",show_home,true)

func save_settings() -> void:
	settings.set_value("route","selected_id",selected_circuit.id)
	settings.set_value("rider","mass_kg",rider_mass)
	settings.set_value("rider","demo_watts",input.demo_watts)
	settings.set_value("graphics","quality",world.quality)
	settings.set_value("graphics","fullscreen",DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	var status := settings.save("user://settings.cfg")
	if status != OK: push_warning("Échec d’enregistrement des paramètres : "+error_string(status))

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	save_settings()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_F11: toggle_fullscreen()
		KEY_H:
			if screen=="ride" and not event.echo:
				hud.visible = not hud.visible
				overlay.visible = hud.visible
		KEY_SPACE,KEY_ESCAPE:
			if screen == "ride" or screen == "paused": toggle_pause()
		KEY_UP: input.demo_watts = minf(500,input.demo_watts+10)
		KEY_DOWN: input.demo_watts = maxf(0,input.demo_watts-10)

func _physics_process(dt: float) -> void:
	if screen != "ride": return
	previous_distance = distance
	previous_lateral = lane.lateral
	var observation := input.read(Time.get_ticks_msec())
	watts = observation.watts
	cadence = observation.cadence
	var rolling := 0.005
	if terrain_kind == 1: rolling = 0.0095
	if terrain_kind == 2: rolling *= 1.12
	world.life.step(dt,distance,speed,lane.lateral)
	lane.step(distance,speed,dt,world.life.observations(distance,speed))
	var smoothed := input.smooth(watts)
	var braking := physics.effective_mass_kg*3.5 if lane.blocked else 0.0
	var result := physics.step(speed,0.0 if lane.blocked else smoothed,route.grade(distance),dt,0,rolling,0,braking)
	speed = result.speed
	distance = minf(route.length_m,distance+result.distance)
	elapsed += dt
	recorder.tick(dt,distance-route.start_m,speed,watts,cadence,route.sample_raw(distance),lane.lateral)
	if distance >= route.length_m: finish_session()

func position_scene(dt: float, immediate: bool = false) -> void:
	if immediate:
		previous_distance = distance
		previous_lateral = lane.lateral
	var station := distance
	var lateral := lane.lateral
	# Interpolate the fixed 50 Hz simulation at the monitor's refresh rate.
	# Physics/obstacle decisions always use the current authoritative state.
	if not immediate and screen == "ride" and is_physics_processing() and absf(distance-previous_distance)<maxf(1,speed*.04):
		var fraction := Engine.get_physics_interpolation_fraction()
		station = lerpf(previous_distance,distance,fraction)
		lateral = lerpf(previous_lateral,lane.lateral,fraction)
	rider.position = world.roadside(station,lateral)+Vector3.UP*0.065
	var forward := route.direction(station)
	var right := Vector3(-forward.z,0,forward.x).normalized()
	var steering := forward+right*(lane.velocity/maxf(speed,2))
	var desired_rotation := atan2(-steering.x,-steering.z)
	rider.rotation.y = desired_rotation if immediate else lerp_angle(rider.rotation.y,desired_rotation,1-exp(-dt*6))
	var bend := forward.cross(route.direction(minf(route.length_m,station+6))).y
	rider.rotation.z = lerpf(rider.rotation.z,clampf(bend*0.8-lane.velocity*0.10,-0.13,0.13),1-exp(-dt*5))
	rider.rotation.x = atan(clampf(route.grade(station),-0.25,0.25))
	if immediate or screen == "ride":
		camera.transform = camera_follow.step(route,station,lateral,speed,dt,immediate)

func _process(dt: float) -> void:
	position_scene(dt)
	if screen == "ride": rider.animate(dt,cadence,speed)
	world.update_at(distance)
	hud.queue_redraw()
	if smoke_frames > 0:
		smoke_frames -= 1
		if smoke_frames == 0:
			if "--screenshot" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/session.png")
			finish_session()
			print("SMOKE_OK distance_m=",distance," speed_mps=",speed," elapsed_s=",elapsed)
			get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if screen in ["ride","paused"]: recorder.save(distance-route.start_m,false)
		save_settings()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "ride" and smoke_frames < 0:
		toggle_pause()
