class_name CyclingRider
extends Node3D

const M = preload("res://scripts/materials.gd")
var limbs: Array[Dictionary] = []
var wheels: Array[Node3D] = []
var crank := 0.0
var crank_parts: Array[Node3D] = []
var upper_body := Node3D.new()

func _ready() -> void:
	var black := M.toon(Color("18232e"),true)
	var rubber := M.toon(Color("162027"))
	var carbon := M.toon(Color("273942"),true)
	var silver := M.toon(Color("b4c0be"))
	var jersey := M.toon(Color("d95821"),true)
	var dark_jersey := M.toon(Color("a53d18"))
	var skin := M.toon(Color("dca079"),true)
	var cream := M.toon(Color("eee9dc"),true)
	var shorts := M.toon(Color("253143"),true)
	var teal := M.toon(Color("7aafaa"))
	# Correct road-bike proportions: 700C wheels, narrow tyres, real fork and stays.
	var rear := Vector3(0,0.35,0.64)
	var front := Vector3(0,0.35,-0.65)
	var bracket := Vector3(0,0.29,0.06)
	var seat := Vector3(0,0.82,0.26)
	var headset := Vector3(0,0.79,-0.46)
	for center in [rear,front]:
		var wheel := Node3D.new()
		add_child(wheel)
		wheel.position = center
		wheels.append(wheel)
		var tyre := TorusMesh.new()
		tyre.inner_radius = 0.318
		tyre.outer_radius = 0.349
		tyre.rings = 64
		tyre.ring_segments = 12
		M.mesh(wheel,tyre,rubber,Vector3.ZERO).rotation.z = PI/2
		var rim := TorusMesh.new()
		rim.inner_radius = 0.299
		rim.outer_radius = 0.319
		rim.rings = 64
		rim.ring_segments = 8
		M.mesh(wheel,rim,carbon,Vector3.ZERO).rotation.z = PI/2
		for j in range(24):
			var angle := j*TAU/24
			var side := -1.0 if j%2 == 0 else 1.0
			M.rod(wheel,Vector3(side*0.024,0,0),Vector3(0,sin(angle),cos(angle))*0.31,0.0017,silver)
		M.rod(wheel,Vector3(-0.045,0,0),Vector3(0.045,0,0),0.018,silver)
		var disc := TorusMesh.new()
		disc.inner_radius = 0.055
		disc.outer_radius = 0.075
		disc.rings = 32
		M.mesh(wheel,disc,silver,Vector3(-0.035,0,0)).rotation.z = PI/2
	for pair in [[bracket,seat],[seat,headset],[bracket,headset]]:
		M.tapered(self,pair[0],pair[1],0.027,0.023,carbon)
	for side in [-1,1]:
		var drop := rear+Vector3(side*0.035,0,0)
		M.tapered(self,bracket,drop,0.017,0.012,carbon)
		M.tapered(self,seat,drop,0.015,0.011,carbon)
		M.tapered(self,headset+Vector3(side*0.035,0,0),front+Vector3(side*0.035,0,0),0.019,0.011,carbon)
	# Original frame accents, bottle cage, chain, cassette and derailleur.
	M.rod(self,bracket.lerp(headset,0.25),bracket.lerp(headset,0.64),0.028,teal)
	M.rod(self,seat,Vector3(0,0.945,0.29),0.016,silver)
	M.ball(self,Vector3(0,0.95,0.29),Vector3(0.16,0.055,0.29),black)
	M.ball(self,Vector3(0,0.58,-0.11),Vector3(0.072,0.20,0.072),cream).rotation.x = -0.65
	M.rod(self,headset,Vector3(0,0.96,-0.51),0.020,carbon)
	M.rod(self,Vector3(-0.225,0.96,-0.51),Vector3(0.225,0.96,-0.51),0.019,black)
	for side in [-1,1]:
		var last := Vector3(side*0.225,0.96,-0.51)
		for j in range(1,13):
			var t := float(j)/12
			var next := Vector3(side*0.225,0.89+0.085*cos(t*PI),-0.56-0.10*sin(t*PI))
			M.rod(self,last,next,0.019,black)
			last = next
		M.ball(self,Vector3(side*0.225,0.95,-0.57),Vector3(0.05,0.07,0.12),black)
		M.rod(self,Vector3(side*0.225,0.97,-0.60),Vector3(side*0.225,0.89,-0.64),0.008,silver)
	M.rod(self,Vector3(0.052,0.33,0.12),rear+Vector3(0.052,0.04,0),0.004,carbon)
	M.rod(self,Vector3(0.052,0.24,0.06),rear+Vector3(0.052,-0.03,0),0.004,carbon)
	for i in range(5):
		var gear := TorusMesh.new()
		gear.inner_radius = 0.025+i*0.004
		gear.outer_radius = 0.045+i*0.005
		gear.rings = 24
		M.mesh(self,gear,silver,rear+Vector3(0.045+i*0.005,0,0)).rotation.z = PI/2
	M.rod(self,rear+Vector3(0.075,-0.01,0),rear+Vector3(0.075,-0.13,0.04),0.011,carbon)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.065
	ring.outer_radius = 0.095
	ring.rings = 40
	M.mesh(self,ring,silver,bracket+Vector3(0.055,0,0)).rotation.z = PI/2
	# Contoured clothing, rather than a sphere used as a torso.
	add_child(upper_body)
	M.loft(upper_body,[
		{"center":Vector3(0,1.10,0.22),"width":0.145,"depth":0.10},
		{"center":Vector3(0,1.16,0.15),"width":0.18,"depth":0.115},
		{"center":Vector3(0,1.29,0.00),"width":0.20,"depth":0.135},
		{"center":Vector3(0,1.47,-0.20),"width":0.235,"depth":0.145},
		{"center":Vector3(0,1.54,-0.31),"width":0.21,"depth":0.12},
		{"center":Vector3(0,1.57,-0.34),"width":0.085,"depth":0.07}
	],jersey,32)
	var pelvis := M.loft(self,[
		{"center":Vector3(0,0.99,0.23),"width":0.13,"depth":0.11},
		{"center":Vector3(0,1.09,0.25),"width":0.185,"depth":0.145},
		{"center":Vector3(0,1.17,0.18),"width":0.17,"depth":0.125}
	],shorts,32)
	pelvis.position.y = -0.07
	# Jersey hem, back pockets and fine seam lines.
	M.loft(upper_body,[{"center":Vector3(0,1.17,0.14),"width":0.184,"depth":0.119},{"center":Vector3(0,1.195,0.11),"width":0.188,"depth":0.124}],dark_jersey)
	for x in [-0.12,0.0,0.12]:
		M.rod(upper_body,Vector3(x,1.22,0.21),Vector3(x,1.31,0.13),0.0024,dark_jersey)
	M.box(upper_body,Vector3(0,1.23,0.205),Vector3(0.25,0.012,0.006),cream).rotation.x = -0.65
	M.ball(upper_body,Vector3(0,1.43,-0.041),Vector3(0.044,0.046,0.009),cream)
	var head_root := Node3D.new()
	upper_body.add_child(head_root)
	head_root.position.y = -0.08
	M.tapered(head_root,Vector3(0,1.53,-0.34),Vector3(0,1.69,-0.49),0.055,0.05,skin)
	M.ball(head_root,Vector3(0,1.72,-0.52),Vector3(0.21,0.255,0.215),skin)
	for side in [-1,1]:
		M.ball(head_root,Vector3(side*0.095,1.72,-0.51),Vector3(0.026,0.055,0.035),skin)
	# Aerodynamic helmet shell and dark ventilation channels.
	M.ball(head_root,Vector3(0,1.83,-0.53),Vector3(0.27,0.17,0.315),cream)
	for x in [-0.083,-0.041,0.0,0.041,0.083]:
		var last := Vector3(x,1.85,-0.675)
		for j in range(1,10):
			var z := lerpf(-0.675,-0.395,float(j)/9)
			var y := 1.842+0.067*sqrt(maxf(0,1-pow((z+0.535)/0.15,2)))*sqrt(maxf(0,1-pow(x/0.135,2)))
			var next := Vector3(x,y,z)
			M.rod(head_root,last,next,0.009,black)
			last = next
	M.rod(head_root,Vector3(-0.095,1.78,-0.49),Vector3(-0.07,1.64,-0.54),0.0045,black)
	M.rod(head_root,Vector3(0.095,1.78,-0.49),Vector3(0.07,1.64,-0.54),0.0045,black)
	M.box(head_root,Vector3(0,1.755,-0.619),Vector3(0.18,0.043,0.024),black)
	for side in [-1.0,1.0]:
		var shoulder := Vector3(side*0.225,1.48,-0.23)
		var elbow := Vector3(side*0.275,1.21,-0.42)
		var hand := Vector3(side*0.225,1.035,-0.57)
		var sleeve_end := shoulder.lerp(elbow,0.48)
		M.tapered(upper_body,shoulder,sleeve_end,0.082,0.070,jersey)
		M.tapered(upper_body,sleeve_end,elbow,0.061,0.050,skin)
		M.ball(upper_body,elbow,Vector3(0.10,0.10,0.10),skin)
		M.tapered(upper_body,elbow,hand,0.052,0.035,skin)
		M.ball(upper_body,hand,Vector3(0.068,0.058,0.10),black)
		var thigh := M.tapered(self,Vector3.ZERO,Vector3.UP,0.088,0.073,skin)
		var bib := M.tapered(self,Vector3.ZERO,Vector3.UP,0.099,0.083,shorts)
		var calf := M.tapered(self,Vector3.ZERO,Vector3.UP,0.068,0.035,skin)
		var sock := M.tapered(self,Vector3.ZERO,Vector3.UP,0.041,0.048,cream)
		var knee := M.ball(self,Vector3.ZERO,Vector3(0.145,0.15,0.145),skin)
		var shoe := M.ball(self,Vector3.ZERO,Vector3(0.112,0.075,0.255),cream)
		var sole := M.box(shoe,Vector3(0,-0.28,0),Vector3(0.88,0.14,0.96),black)
		sole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		limbs.append({"side":side,"thigh":thigh,"bib":bib,"calf":calf,"sock":sock,"knee":knee,"shoe":shoe})
		crank_parts.append(M.rod(self,Vector3.ZERO,Vector3.UP,0.012,silver))
	animate(0,0,0)

func animate(dt: float, cadence: float, speed: float) -> void:
	crank += dt*cadence*TAU/60
	for i in range(limbs.size()):
		var limb: Dictionary = limbs[i]
		var phase := crank+i*PI
		var hip := Vector3(float(limb.side)*0.115,1.02,0.24)
		var foot := Vector3(float(limb.side)*0.135,0.295+cos(phase)*0.17,0.06+sin(phase)*0.17)
		var axis := (foot-hip).normalized()
		var bend := (Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)).normalized()
		var knee := (hip+foot)*0.5+bend*sqrt(maxf(0,0.46*0.46-hip.distance_squared_to(foot)*0.25))
		M.place_rod(limb.thigh,hip,knee)
		M.place_rod(limb.bib,hip,hip.lerp(knee,0.72))
		M.place_rod(limb.calf,knee,foot+Vector3.UP*0.025)
		M.place_rod(limb.sock,foot,foot.lerp(knee,0.32))
		limb.knee.position = knee
		limb.shoe.position = foot+Vector3(0,0,-0.025)
		limb.shoe.rotation.x = sin(phase)*0.12
		M.place_rod(crank_parts[i],Vector3(float(limb.side)*0.065,0.295,0.06),foot)
	for wheel in wheels: wheel.rotation.x -= speed*dt/0.349
	upper_body.position.y = -0.07+(sin(crank*2)*0.004 if cadence>0 else 0.0)
