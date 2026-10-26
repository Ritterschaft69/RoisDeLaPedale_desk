class_name CyclingRider
extends Node3D

const M = preload("res://scripts/materials.gd")
var legs: Array[MeshInstance3D] = []
var shoes: Array[MeshInstance3D] = []
var crank := 0.0
var wheels: Array[Node3D] = []

func _ready() -> void:
	var ink := M.toon(Color("17282d"), true)
	var steel := M.toon(Color("96a8a6"))
	var orange := M.toon(Color("ec6a38"), true)
	var skin := M.toon(Color("e8b68d"), true)
	var white := M.toon(Color("f7f2da"), true)
	var frame := M.toon(Color("78b5ad"), true)
	var rear := Vector3(0, 0.35, 0.64)
	var front := Vector3(0, 0.35, -0.64)
	var bottom := Vector3(0, 0.36, 0.06)
	var saddle := Vector3(0, 0.89, 0.28)
	var headtube := Vector3(0, 0.86, -0.45)
	for center in [rear, front]:
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = center
		wheels.append(pivot)
		var tire := TorusMesh.new()
		tire.inner_radius = 0.30
		tire.outer_radius = 0.35
		tire.rings = 32
		tire.ring_segments = 10
		M.mesh(pivot, tire, ink, Vector3.ZERO).rotation.z = PI / 2
		for i in range(12):
			var angle := i * TAU / 12
			M.rod(pivot, Vector3.ZERO, Vector3(0, sin(angle), cos(angle))*0.315, 0.003, steel)
	for pair in [[rear,bottom],[rear,saddle],[bottom,saddle],[saddle,headtube],[bottom,headtube],[headtube,front]]:
		M.rod(self, pair[0], pair[1], 0.025, frame)
	M.rod(self, saddle, Vector3(0, 1.02, 0.29), 0.023, steel)
	M.ball(self, Vector3(0,1.04,0.29), Vector3(0.20,0.07,0.32), ink)
	M.rod(self, headtube, Vector3(0,1.05,-0.5), 0.025, steel)
	M.rod(self, Vector3(-0.24,1.05,-0.5), Vector3(0.24,1.05,-0.5), 0.024, ink)
	for side in [-1,1]:
		M.rod(self, Vector3(side*0.24,1.05,-0.5), Vector3(side*0.24,0.97,-0.62),0.025,ink)
	# Leaning silhouette, fitted jersey, bib shorts and vented helmet.
	var torso := M.ball(self, Vector3(0,1.33,-0.05), Vector3(0.47,0.61,0.34),orange)
	torso.rotation.x = -0.54
	M.ball(self, Vector3(0,1.1,0.22), Vector3(0.40,0.27,0.29),ink)
	M.ball(self, Vector3(0,1.69,-0.40), Vector3(0.20,0.25,0.20),skin)
	M.ball(self, Vector3(0,1.80,-0.41), Vector3(0.30,0.19,0.31),white)
	for x in [-0.085,0.0,0.085]:
		M.ball(self, Vector3(x,1.882,-0.42),Vector3(0.035,0.02,0.17),ink)
	# Reflective stripe and original jersey badge.
	M.ball(self,Vector3(0,1.32,0.132),Vector3(0.47,0.055,0.026),white)
	M.ball(self,Vector3(0,1.49,0.10),Vector3(0.075,0.075,0.028),white)
	for side in [-1,1]:
		var shoulder := Vector3(side*0.235,1.49,-0.23)
		var elbow := Vector3(side*0.32,1.20,-0.39)
		var hand := Vector3(side*0.24,1.03,-0.57)
		M.rod(self, shoulder, shoulder.lerp(elbow,0.52),0.09,orange)
		M.rod(self, shoulder.lerp(elbow,0.45),elbow,0.067,skin)
		M.rod(self,elbow,hand,0.055,skin)
		M.ball(self,hand,Vector3(0.09,0.09,0.1),ink)
		legs.append(M.rod(self,Vector3.ZERO,Vector3.UP,0.10,ink))
		legs.append(M.rod(self,Vector3.ZERO,Vector3.UP,0.068,skin))
		shoes.append(M.ball(self,Vector3.ZERO,Vector3(0.13,0.09,0.25),white))
	animate(0,0,0)

func animate(dt: float, cadence: float, speed: float) -> void:
	crank += dt * cadence * TAU / 60
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var phase := crank + i*PI
		var hip := Vector3(side*0.12,1.10,0.25)
		var foot := Vector3(side*0.13,0.40+cos(phase)*0.17,0.06+sin(phase)*0.17)
		var middle := (hip + foot)*0.5
		# Two-segment inverse kinematics, knee points forward.
		var axis := (foot-hip).normalized()
		var forward := Vector3(0,0,-1)
		var perpendicular := (forward-axis*forward.dot(axis)).normalized()
		var leg_length := 0.45
		var knee := middle + perpendicular * sqrt(maxf(0,leg_length*leg_length-hip.distance_squared_to(foot)*0.25))
		M.place_rod(legs[i*2],hip,knee)
		M.place_rod(legs[i*2+1],knee,foot)
		shoes[i].position = foot
	for wheel in wheels:
		wheel.rotation.x -= speed * dt / 0.35
