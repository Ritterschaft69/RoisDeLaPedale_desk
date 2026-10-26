class_name CyclingHUD
extends Control

var app: Node
var regular: Font = preload("res://assets/fonts/OpenSans-Regular.ttf")
var bold: Font = preload("res://assets/fonts/OpenSans-Semibold.ttf")
const CREAM := Color("f3f1df")
const MUTED := Color("a8bcb3")
const GOLD := Color("efbe76")
var panel_style := StyleBoxFlat.new()
var cached_route: CyclingRoute
var map_bounds := Rect2()
var map_points := PackedVector2Array()
var profile_points := PackedVector2Array()

func ensure_route_cache() -> void:
	if cached_route == app.route: return
	cached_route = app.route
	map_points.clear()
	profile_points.clear()
	map_bounds = Rect2(Vector2(cached_route.points[0].x,cached_route.points[0].z),Vector2(0.01,0.01))
	var minimum := INF
	var maximum := -INF
	for p in cached_route.points:
		map_bounds = map_bounds.expand(Vector2(p.x,p.z))
		minimum = minf(minimum,p.alt)
		maximum = maxf(maximum,p.alt)
	var stride := maxi(1,ceili(cached_route.points.size()/700.0))
	for i in range(0,cached_route.points.size(),stride):
		var p: Dictionary = cached_route.points[i]
		map_points.append(Vector2(p.x,p.z))
		profile_points.append(Vector2(p.s/cached_route.length_m,1-(p.alt-minimum)/maxf(1,maximum-minimum)))
	var last: Dictionary = cached_route.points[-1]
	map_points.append(Vector2(last.x,last.z))
	profile_points.append(Vector2(1,1-(last.alt-minimum)/maxf(1,maximum-minimum)))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_style.bg_color = Color(0.045,0.095,0.095,0.93)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_color = Color(0.8,0.9,0.8,0.12)
	panel_style.set_border_width_all(1)

func text_at(at: Vector2, value: String, size_px: int, color: Color = CREAM, strong: bool = false) -> void:
	draw_string(bold if strong else regular,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func panel(rect: Rect2) -> void:
	draw_style_box(panel_style,rect)

func _draw() -> void:
	if app == null: return
	ensure_route_cache()
	var w := size.x
	var h := size.y
	# Calm masthead and explicit data provenance.
	text_at(Vector2(32,35),"R / P",20,GOLD,true)
	text_at(Vector2(105,35),"LES VOSGES À VÉLO",14,CREAM,true)
	var source_note := "DÉMO · GPX RÉEL · DÉCOR ILLUSTRATIF HORS DE LA TRANCHE IGN"
	if app.world.geographic.covers(app.distance):
		source_note = "DÉMO · IGN BD TOPO® / RGE ALTI® · TOITURES ET FAÇADES ESTIMÉES · RACCORDEMENT VERTICAL AU GPX"
	draw_rect(Rect2(24,h-38,w-48,28),Color(0.045,0.095,0.095,0.9))
	text_at(Vector2(32,h-21),source_note,11,CREAM)
	if app.screen in ["home","circuits"]:
		panel(Rect2(w-325,65,293,330))
		text_at(Vector2(w-303,98),"LE PARCOURS",12,MUTED,true)
		draw_map(Rect2(w-303,118,248,220))
		text_at(Vector2(w-303,371),"%.1f km   /   D+ brut %.0f m" % [app.route.length_m/1000,app.route.ascent_m],15,CREAM,true)
		return
	if app.screen == "summary": return
	if app.lane.blocked:
		panel(Rect2(460,190,480,37))
		text_at(Vector2(478,215),"Passage bloqué · freinage de sécurité",14,GOLD,true)
	elif app.lane.avoiding:
		panel(Rect2(510,190,325,37))
		text_at(Vector2(528,215),"Contournement de l’obstacle",14,CREAM,true)
	var stats := [["PUISSANCE",str(roundi(app.watts)),"W",GOLD],
		["VITESSE","%.1f" % (app.speed*3.6),"km/h",Color("85d1bb")],
		["CADENCE",str(roundi(app.cadence)),"tr/min",Color("9fceec")],
		["PENTE","%+.1f" % (app.route.grade(app.distance)*100),"%",Color("d4dcb4")]]
	for i in range(4):
		var x := 32.0+i*174
		panel(Rect2(x,60,160,120))
		text_at(Vector2(x+16,84),stats[i][0],11,MUTED,true)
		text_at(Vector2(x+16,133),stats[i][1],37,stats[i][3],true)
		text_at(Vector2(x+17,158),stats[i][2],12,MUTED)
		for b in range(10):
			draw_rect(Rect2(x+76+b*6,151,4,9),stats[i][3] if b < int(app.watts/40) else Color(1,1,1,0.12))
	panel(Rect2(w-286,60,254,265))
	text_at(Vector2(w-267,86),str(app.selected_circuit.short_name).to_upper(),12,CREAM,true)
	draw_map(Rect2(w-266,101,214,168))
	text_at(Vector2(w-267,303),"%.1f km restants" % ((app.route.length_m-app.distance)/1000),16,CREAM,true)
	# Keep the centre of the screen free so the rider and wheels remain visible.
	panel(Rect2(32,h-147,320,104))
	text_at(Vector2(53,h-119),str(app.selected_circuit.short_name).to_upper(),12,MUTED,true)
	text_at(Vector2(53,h-89),"%.2f / %.1f km" % [(app.distance-app.route.start_m)/1000,(app.route.length_m-app.route.start_m)/1000],21,CREAM,true)
	text_at(Vector2(53,h-62),"%02d:%02d   ·   %.0f m d’altitude" % [int(app.elapsed)/60,int(app.elapsed)%60,app.route.sample(app.distance).position.y],13,MUTED)
	panel(Rect2(w-286,338,254,94))
	text_at(Vector2(w-266,363),"PROFIL DU CIRCUIT",11,MUTED,true)
	draw_profile(Rect2(w-266,376,214,39))
	panel(Rect2(w-338,h-147,306,104))
	text_at(Vector2(w-318,h-118),"MODE DÉMO · %d W" % app.input.demo_watts,12,GOLD,true)
	text_at(Vector2(w-318,h-91),"↑ ↓  Puissance     Espace  Pause",12,CREAM)
	text_at(Vector2(w-318,h-66),"F11  Plein écran     H  Interface",12,MUTED)
	if app.screen == "paused":
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.07,0.07,0.38))

func draw_map(rect: Rect2) -> void:
	var bounds := map_bounds
	var scale_factor := minf(rect.size.x/bounds.size.x,rect.size.y/bounds.size.y)
	var offset := rect.position+(rect.size-bounds.size*scale_factor)*0.5
	var line := PackedVector2Array()
	for p in map_points:
		line.append(offset+(p-bounds.position)*scale_factor)
	# Actual GPX geometry, north up; no online map tiles or invented map detail.
	for i in range(1,4):
		draw_line(Vector2(rect.position.x,rect.position.y+i*rect.size.y/4),Vector2(rect.end.x,rect.position.y+i*rect.size.y/4),Color(1,1,1,0.035))
	draw_polyline(line,Color(0.5,0.7,0.6,0.15),7,true)
	draw_polyline(line,Color("b9d3a0"),2.5,true)
	var at: Vector3 = app.route.sample(app.distance).position
	var marker := offset+(Vector2(at.x,at.z)-bounds.position)*scale_factor
	draw_circle(marker,8,Color("142c2a"))
	draw_circle(marker,5,GOLD)
	text_at(rect.position+Vector2(rect.size.x-12,12),"N",11,MUTED,true)

func draw_profile(rect: Rect2) -> void:
	var line := PackedVector2Array()
	for p in profile_points:
		var v := rect.position+p*rect.size
		line.append(v)
	# Draw each monotonic strip as explicit triangles. A single closed polygon
	# can be degenerate when GPX points share a distance or touch the baseline.
	var triangles := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in range(1,line.size()):
		var a := line[i-1]
		var b := line[i]
		for vertex in [Vector2(a.x,rect.end.y),a,b,Vector2(a.x,rect.end.y),b,Vector2(b.x,rect.end.y)]:
			indices.append(triangles.size())
			triangles.append(vertex)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),indices,triangles,PackedColorArray([Color(0.55,0.72,0.55,0.20)]))
	draw_polyline(line,Color("92b68e"),1.5,true)
	var x: float = rect.position.x+app.distance/app.route.length_m*rect.size.x
	draw_line(Vector2(x,rect.position.y-5),Vector2(x,rect.end.y),GOLD,2)
