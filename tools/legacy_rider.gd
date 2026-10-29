class_name CyclingLegacyRider
extends Node3D

const S = preload("res://scripts/rider_shapes.gd")
const M = preload("res://scripts/materials.gd")
var limbs: Array[Dictionary] = []
var wheels: Array[Node3D] = []
var crank := 0.0
var crank_parts: Array[Node3D] = []
var upper_body := Node3D.new()
# Retained procedural recipe for the optional Blender authoring tool.
var authoring_source := false
var source_torso: MeshInstance3D
var source_sleeves: Array[MeshInstance3D] = []
var source_pelvis: MeshInstance3D
var jersey_mesh: MeshInstance3D
var pants_mesh: MeshInstance3D
var garment_skeleton: Skeleton3D
const BIB_REST_AXIS := Vector3(0,-.36,-.12)

func _ready() -> void:
	var black := M.toon(Color("18232e"),true)
	var rubber := M.toon(Color("162027"))
	var carbon := M.toon(Color("242c38"),true)
	var silver := S.fabric(Color("879298"),.45)
	var cream := M.toon(Color("f4f5f2"),true)
	var teal := M.toon(Color("414955"))
	# Correct road-bike proportions: 700C wheels, narrow tyres, real fork and stays.
	var rear := Vector3(0,0.35,0.49)
	var front := Vector3(0,0.35,-0.57)
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
	M.rod(self,seat,Vector3(0,1.005,0.29),0.016,silver)
	M.ball(self,Vector3(0,1.01,0.29),Vector3(0.16,0.055,0.29),black)
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
	build_cyclist()
	animate(0,0,0)

const TORSO_PROFILE = [[0,.16,.105],[.18,.172,.119],[.4,.186,.137],[.63,.218,.143],[.80,.224,.12],[.91,.167,.087],[1,.072,.058]]
var torso_path := S.path([Vector3(0,1.16,.23),Vector3(0,1.29,.03),Vector3(0,1.385,-.17),Vector3(0,1.40,-.29)])

func back_point(t: float, angle: float, lift: float = .002) -> Vector3:
	var r := S.radii(TORSO_PROFILE,t)+Vector2.ONE*lift
	return S.frame(torso_path,t)*Vector3(r.x*cos(angle),0,r.y*sin(angle))

func stitch(parent: Node3D, coordinates: Array, material: Material, radius: float = .0012) -> void:
	S.tube(parent,coordinates,radius,material)

func build_cyclist() -> void:
	var ink := S.fabric(Color("18202b"))
	var hair := S.fabric(Color("302723"))
	var orange := S.ink(S.fabric(Color("e74610")))
	var seam := S.fabric(Color("ba3a10"))
	var navy := S.ink(S.fabric(Color("242b3d")))
	var skin := S.ink(S.fabric(Color("d67e55"),.85),.0008)
	var white := S.ink(S.fabric(Color("f4f3ee")),.0008)
	var lens := S.fabric(Color("172936"),.22)
	add_child(upper_body)
	if authoring_source:
		source_torso = S.curved_sweep(upper_body,TORSO_PROFILE,torso_path,orange)
		source_pelvis = S.ellipsoid(self,Vector3(0,1.095,.23),Vector3(.39,.255,.32),navy)
	else:
		jersey_mesh = M.mesh(upper_body,load("res://assets/models/jersey.res"),orange,Vector3.ZERO)
		jersey_mesh.name = "ContinuousJersey"
		build_bib_rig(navy)
	# Garment construction follows the actual surface of the sloping torso.
	for angle in [.72,1.28,1.86,2.42]:
		var points: Array = []
		for i in range(11): points.append(back_point(lerpf(.10,.38,float(i)/10),angle))
		stitch(upper_body,points,seam)
	for t in [.10,.38]:
		var points: Array = []
		for i in range(25): points.append(back_point(t,lerpf(.72,2.42,float(i)/24)))
		stitch(upper_body,points,seam)
	# Tailoring and short folds at the waist, conforming to the curved surface.
	for side in [-1,1]:
		var side_seam: Array = []
		for i in range(25):
			var t := lerpf(.09,.81,float(i)/24)
			side_seam.append(back_point(t,0.0 if side==1 else PI,.003))
		stitch(upper_body,side_seam,seam,.0009)
		for fold in range(3):
			var crease: Array = []
			for i in range(12):
				var u := float(i)/11
				crease.append(back_point(.11+fold*.055+sin(u*PI)*.025,(0.0 if side==1 else PI)+lerpf(-.45,.38,u),.003))
			stitch(upper_body,crease,seam,.0008)
	var zipper: Array = []
	for i in range(40): zipper.append(back_point(lerpf(.05,.99,float(i)/39),-PI/2))
	stitch(upper_body,zipper,ink,.0015)
	S.ellipsoid(upper_body,back_point(.91,-PI/2,.004),Vector3(.008,.018,.006),ink)
	# Small original chevrons, matching the reference's placement and contrast.
	for t in [.27,.70]:
		stitch(upper_body,[back_point(t,1.43,.004),back_point(t+.035,PI/2,.004),back_point(t,1.71,.004)],white,.003)
	stitch(upper_body,[back_point(.67,-1.0,.004),back_point(.72,-.97,.004),back_point(.67,-.82,.004),back_point(.67,-1.0,.004)],white,.0025)
	var collar := S.sweep(upper_body,[[0,.074,.061],[1,.071,.059]],orange,8)
	M.place_rod(collar,Vector3(0,1.40,-.29),Vector3(0,1.425,-.318))
	M.tapered(upper_body,Vector3(0,1.415,-.31),Vector3(0,1.445,-.42),.049,.047,skin)
	var head_root := Node3D.new()
	upper_body.add_child(head_root)
	head_root.position = Vector3(0,-.055,.035)
	# Jaw, cheeks, brow and cranium are one continuous surface.
	var face := S.face(head_root,skin)
	face.position = Vector3(0,1.505,-.49)
	stitch(head_root,[Vector3(-.022,1.451,-.569),Vector3(0,1.448,-.571),Vector3(.022,1.451,-.569)],seam,.0012)
	S.ellipsoid(head_root,Vector3(0,1.568,-.46),Vector3(.19,.102,.19),hair)
	for side in [-1,1]:
		S.ellipsoid(head_root,Vector3(side*.093,1.512,-.468),Vector3(.026,.049,.032),skin)
		var glass := S.ellipsoid(head_root,Vector3(side*.045,1.547,-.573),Vector3(.092,.057,.035),lens)
		glass.rotation.z = side*.12
		stitch(head_root,[Vector3(side*.089,1.551,-.572),Vector3(side*.101,1.548,-.485)],ink,.004)
		stitch(head_root,[Vector3(side*.106,1.59,-.43),Vector3(side*.086,1.455,-.465),Vector3(side*.076,1.585,-.57)],ink,.003)
	M.rod(head_root,Vector3(-.012,1.552,-.585),Vector3(.012,1.552,-.585),.005,ink)
	S.ellipsoid(head_root,Vector3(0,1.613,-.49),Vector3(.255,.085,.32),ink)
	S.helmet(head_root,Vector3(0,1.60,-.49),white)
	var rim: Array = []
	for i in range(65):
		var a := TAU*i/64
		rim.append(Vector3(.131*cos(a),1.60,-.49+.165*sin(a)))
	stitch(head_root,rim,white,.007)
	# Profiled arms retain slight elbow flexion and natural shoulder volume.
	for side in [-1.0,1.0]:
		var shoulder := Vector3(side*.205,1.355,-.24)
		var elbow := Vector3(side*.255,1.135,-.38)
		var hand := Vector3(side*.225,.99,-.57)
		var sleeve_end := shoulder.lerp(elbow,.48)
		if authoring_source:
			var sleeve := S.sweep(upper_body,[[0,.070,.076],[.28,.081,.08],[.65,.076,.071],[1,.064,.061]],orange,24)
			M.place_rod(sleeve,shoulder,sleeve_end)
			source_sleeves.append(sleeve)
			# Fill the clavicle/deltoid transition before offline surface union.
			var deltoid := S.ellipsoid(upper_body,shoulder+Vector3(-side*.022,.012,.035),Vector3(.18,.205,.19),orange)
			source_sleeves.append(deltoid)
		var arm_path := S.path([sleeve_end,elbow,hand])
		S.curved_sweep(upper_body,[[0,.059,.058],[.17,.060,.061],[.34,.045,.046],[.53,.052,.055],[.78,.04,.044],[1,.029,.032]],arm_path,skin,48,32)
		S.ellipsoid(upper_body,hand,Vector3(.067,.057,.096),ink)
		# Exposed fingers curl over the brake hoods.
		for finger in range(3):
			S.ellipsoid(upper_body,hand+Vector3(side*.012,.002,-.032-finger*.009),Vector3(.054,.019,.017),skin)
		var thigh := S.muscle(self,[[0,.088,.088],[.3,.09,.09],[.7,.079,.077],[1,.064,.063]],skin,side)
		var bib: Node3D
		if authoring_source:
			bib = S.sweep(self,[[0,.105,.105],[.3,.117,.115],[.7,.113,.11],[1,.098,.097]],navy)
		else:
			bib = Node3D.new()
			add_child(bib)
		S.badge(bib,Vector3(side*.119,.03,0),Vector3(0,0,-side*.012),Vector3(0,.07,0),white)
		var calf := S.muscle(self,[[0,.059,.058],[.25,.064,.065],[.57,.072,.077],[.86,.059,.065],[1,.049,.057]],skin,side,true)
		var sock := S.sweep(self,[[0,.034,.039],[.3,.039,.044],[.75,.052,.058],[1,.061,.066]],white,24)
		var stripe := S.sweep(self,[[0,.057,.063],[1,.059,.065]],orange,4)
		var cuff := M.tapered(self,Vector3.ZERO,Vector3.UP,.063,.063,white)
		var knee := S.ellipsoid(self,Vector3.ZERO,Vector3(.128,.13,.129),skin)
		var shoe := Node3D.new()
		add_child(shoe)
		for layer in [0,1]:
			var profile := [[0,.004,.003],[.1,.032,.006],[.3,.05,.007],[.7,.054,.006],[.94,.034,.005],[1,.004,.002]] if layer==0 else [[0,.004,.005],[.1,.029,.032],[.25,.044,.045],[.45,.052,.046],[.7,.053,.031],[.92,.039,.022],[1,.004,.004]]
			var shell := S.sweep(shoe,profile,ink if layer==0 else white,32)
			shell.position.y = -.027 if layer==0 else 0
			shell.quaternion = Quaternion(Vector3.UP,Vector3.FORWARD)
			shell.scale.y = .25
		for z in [-.015,-.065]:
			S.ellipsoid(shoe,Vector3(side*.032,.044,z),Vector3(.019,.009,.019),ink)
			M.rod(shoe,Vector3(-.029,.044,z),Vector3(.029,.044,z-.012),.002,ink)
		limbs.append({"side":side,"thigh":thigh,"bib":bib,"calf":calf,"sock":sock,"stripe":stripe,"cuff":cuff,"knee":knee,"shoe":shoe})
		crank_parts.append(M.rod(self,Vector3.ZERO,Vector3.UP,.012,S.fabric(Color("b4c0be"))))

static func bib_rest_axis(side: float) -> Vector3:
	# Keep the two legs apart in the bind pose so voxel union joins only the
	# groin, rather than accidentally bridging the inner thighs.
	return Vector3(side*.045,BIB_REST_AXIS.y,BIB_REST_AXIS.z).normalized()

func build_bib_rig(material: Material) -> void:
	garment_skeleton = Skeleton3D.new()
	garment_skeleton.name = "BibRig"
	add_child(garment_skeleton)
	garment_skeleton.add_bone("Pelvis")
	garment_skeleton.set_bone_rest(0,Transform3D.IDENTITY)
	var skin := Skin.new()
	skin.set_bind_count(3)
	skin.set_bind_bone(0,0)
	skin.set_bind_pose(0,Transform3D.IDENTITY)
	for i in range(2):
		var side := -1 if i==0 else 1
		var rest := Transform3D(Basis.IDENTITY,Vector3(side*.115,1.08,.24))
		garment_skeleton.add_bone("LeftThigh" if i==0 else "RightThigh")
		garment_skeleton.set_bone_parent(i+1,0)
		garment_skeleton.set_bone_rest(i+1,rest)
		skin.set_bind_bone(i+1,i+1)
		skin.set_bind_pose(i+1,rest.affine_inverse())
	garment_skeleton.reset_bone_poses()
	pants_mesh = M.mesh(garment_skeleton,load("res://assets/models/bib.res"),material,Vector3.ZERO)
	pants_mesh.name = "ContinuousBib"
	pants_mesh.skeleton = NodePath("..")
	pants_mesh.skin = skin

func animate(dt: float, cadence: float, speed: float) -> void:
	# A long render stall must not skip most of a turn and appear to reverse
	# (temporal aliasing). At normal frame rates phase follows cadence exactly;
	# below ~9 FPS at 90 RPM, visual pedalling slows rather than reversing.
	var step := clampf(dt*maxf(0,cadence)*TAU/60,0,PI/3)
	crank = fposmod(crank + step,TAU)
	for i in range(limbs.size()):
		var limb: Dictionary = limbs[i]
		var phase := crank+i*PI
		var hip := Vector3(float(limb.side)*0.115,1.08,0.24)
		var foot := Vector3(float(limb.side)*0.135,0.295+cos(phase)*0.17,0.06-sin(phase)*0.17)
		var axis := (foot-hip).normalized()
		var bend := (Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)).normalized()
		var knee := (hip+foot)*0.5+bend*sqrt(maxf(0,0.49*0.49-hip.distance_squared_to(foot)*0.25))
		M.place_rod(limb.thigh,hip.lerp(knee,.55),knee)
		M.place_rod(limb.bib,hip,hip.lerp(knee,0.72))
		if garment_skeleton != null:
			garment_skeleton.set_bone_pose_rotation(i+1,Quaternion(bib_rest_axis(float(limb.side)),(knee-hip).normalized()))
		M.place_rod(limb.calf,knee,foot.lerp(knee,.30))
		M.place_rod(limb.sock,foot,foot.lerp(knee,0.36))
		M.place_rod(limb.stripe,foot.lerp(knee,0.30),foot.lerp(knee,0.32))
		M.place_rod(limb.cuff,foot.lerp(knee,0.34),foot.lerp(knee,0.365))
		limb.knee.position = knee
		limb.shoe.position = foot+Vector3(0,0,-0.025)
		limb.shoe.rotation.x = -sin(phase)*0.12
		M.place_rod(crank_parts[i],Vector3(float(limb.side)*0.065,0.295,0.06),foot)
	for wheel in wheels: wheel.rotation.x -= speed*dt/0.349
	upper_body.position.y = (sin(crank*2)*0.004 if cadence>0 else 0.0)
