extends RefCounted
## Cosmetic possession layer. It never moves the live ball or spends/duplicates inventory.
const Library := preload("res://scripts/pose_library.gd")
const Feet := preload("res://scripts/athlete_pose.gd")
const RADIUS := 0.105
const SETTLE := 0.7
const CYCLE := 10.0
const DRIBBLE_START := 6.05
const DRIBBLE_END := 7.65
var idle_age := 0.0
var moving := false
var visual: MeshInstance3D
var last_frame := -1
var last_body := 0
var pickup_serial := -1
var pickup_age := -1.0
var pickup_kind := ""
var pickup_point := Vector3.ZERO
var pickup_hands: Array[Vector3] = []
var evidence := {}

static func blend_fraction(value: float) -> float:
	var t := clampf(value,0,1)
	return t*t*t*(10+t*(-15+6*t))

func hide_visual() -> void:
	if is_instance_valid(visual): visual.hide()

func reset() -> void:
	idle_age = 0
	pickup_age = -1
	last_frame = -1
	hide_visual()

# Timeline entries describe whole poses, so ball and both hands share each transition.
static func phase(age: float) -> Dictionary:
	if age < SETTLE: return {"from":"moving","to":"tuck","weight":blend_fraction(age/SETTLE),"bounce":-1.0}
	var t := fposmod(age-SETTLE,CYCLE)
	if t < 2.5: return {"from":"tuck","to":"tuck","weight":0.0,"bounce":-1.0}
	if t < 3.35: return {"from":"tuck","to":"hips","weight":blend_fraction((t-2.5)/0.85),"bounce":-1.0}
	if t < 5.35: return {"from":"hips","to":"hips","weight":0.0,"bounce":-1.0}
	if t < DRIBBLE_START: return {"from":"hips","to":"dribble","weight":blend_fraction((t-5.35)/0.7),"bounce":-1.0}
	if t < DRIBBLE_END: return {"from":"dribble","to":"dribble","weight":0.0,"bounce":fposmod((t-DRIBBLE_START)/0.8,1.0)}
	if t < 8.45: return {"from":"dribble","to":"tuck","weight":blend_fraction((t-DRIBBLE_END)/0.8),"bounce":-1.0}
	return {"from":"tuck","to":"tuck","weight":0.0,"bounce":-1.0}

func _landmarks(body: Node3D) -> Dictionary:
	var scale: float = body.global_basis.get_scale().x
	var torso := body.get_node("Torso") as MeshInstance3D
	var box := torso.mesh.get_aabb()
	var transform := body.global_transform.affine_inverse()*torso.global_transform
	var minimum := Vector3(INF,INF,INF)
	var maximum := -minimum
	for i in range(8):
		var point: Vector3 = transform*box.get_endpoint(i)
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return {"radius":RADIUS/scale,"front":minimum.z,"width":maxf(absf(minimum.x),absf(maximum.x)),"torso_y":(minimum.y+maximum.y)*0.5,"hip_y":float(body.get_node("LeftLeg").position.y),"shoulder_y":float(body.get_node("RightArm").position.y)}

func _pose(kind: String,body: Node3D,hand: float,marks: Dictionary) -> Dictionary:
	var r: float = marks.radius
	var center := Vector3(0,marks.torso_y,marks.front-r-0.04)
	if kind == "tuck": center = Vector3(hand*(marks.width+r*0.8),marks.shoulder_y-r*1.8,marks.front-r*0.2)
	if kind in ["hips","dribble"]:
		var arm := body.get_node("RightArm") as Node3D
		var reach: float = arm.get_node("Elbow").position.length()+arm.get_node("Elbow/Wrist").position.length()
		center.y = maxf(marks.hip_y+r*0.9,marks.shoulder_y-reach*0.78)
	if kind == "dribble": center.x = hand*(marks.width+r*0.9)
	var hands := [center+Vector3(-r*0.9,-r*0.15,0),center+Vector3(r*0.9,-r*0.15,0)]
	if kind in ["tuck","dribble"]:
		var dominant := 0 if hand < 0 else 1
		hands[dominant] = center+Vector3(0,-r*0.9,0) if kind == "tuck" else center+Vector3.UP*r
		var arm := body.get_node("RightArm" if dominant == 0 else "LeftArm") as Node3D
		hands[1-dominant] = Vector3(arm.position.x*1.04,maxf(marks.hip_y+0.02,marks.shoulder_y-(arm.get_node("Elbow").position.length()+arm.get_node("Elbow/Wrist").position.length())*0.9),-0.07)
	return {"ball":center,"left":hands[0],"right":hands[1],"bend":3.0 if kind == "dribble" else 0.0,"neck":10.0 if kind == "dribble" else 0.0}

func update(lab: Node3D,frame_dt: float) -> void:
	if not lab.inventory.enabled or not lab.inventory.held or lab.is_benched() or lab.serve.tossing():
		reset()
		return
	var frame := Engine.get_process_frames()
	var dt := frame_dt if frame != last_frame else 0.0
	last_frame = frame
	if last_body != lab.body.get_instance_id():
		last_body = lab.body.get_instance_id()
		idle_age = 0
	if pickup_serial != lab.inventory.pickup_serial:
		pickup_serial = lab.inventory.pickup_serial
		pickup_kind = lab.inventory.pickup_kind
		pickup_point = lab.inventory.pickup_point
		pickup_hands = [lab.arms[0].get_node("Elbow/Wrist").global_position,lab.arms[1].get_node("Elbow/Wrist").global_position]
		pickup_age = 0.0 if pickup_kind in ["ground","cart"] else -1.0
	var speed := Vector2(lab.player.velocity.x,lab.player.velocity.z).length()
	moving = speed > (0.12 if moving else 0.25) or lab.motion.jumped or lab.motion.jump_charge >= 0 or lab.serve.state == lab.serve.State.TOSS_CHARGE
	if moving:
		idle_age = 0
		pickup_age = -1
	else:
		if pickup_age >= 0: pickup_age += dt
		else: idle_age += dt
	var hand := -1.0 if lab.dominant_hand == "Left" else 1.0
	var marks := _landmarks(lab.body)
	var timeline := phase(idle_age) if not moving else {"from":"moving","to":"moving","weight":0.0,"bounce":-1.0}
	var a := _pose(timeline.from,lab.body,hand,marks)
	var b := _pose(timeline.to,lab.body,hand,marks)
	var pose := {}
	for key in a: pose[key] = a[key].lerp(b[key],timeline.weight) if a[key] is Vector3 else lerpf(a[key],b[key],timeline.weight)
	var flat := Library.read_rig(lab.body)
	flat.thoracic_flexion = float(flat.get("thoracic_flexion",0))+float(pose.bend)
	flat.neck_flexion = float(flat.get("neck_flexion",0))+float(pose.neck)
	var pickup_weight := 0.0
	var duration := 1.05 if pickup_kind == "ground" else 0.7
	if pickup_age >= 0 and pickup_age < duration:
		var p := pickup_age/duration
		pickup_weight = blend_fraction(p/0.42) if p < 0.42 else 1.0-blend_fraction((p-0.42)/0.58)
		var relative: Vector3 = lab.body.to_local(pickup_point)
		var depth := clampf((float(marks.hip_y)-relative.y)/maxf(float(marks.hip_y),0.1),0,1)
		flat.hip_hinge = float(flat.get("hip_hinge",0))+55*depth*pickup_weight
		flat["hip:Left"] = float(flat.get("hip:Left",0))+32*depth*pickup_weight
		flat["hip:Right"] = float(flat.get("hip:Right",0))+32*depth*pickup_weight
		flat["knee:Left"] = float(flat.get("knee:Left",0))-65*depth*pickup_weight
		flat["knee:Right"] = float(flat.get("knee:Right",0))-65*depth*pickup_weight
		flat.neck_flexion += 20*pickup_weight
		# Turn the virtual pelvis toward the actual source; player facing/input remain unchanged.
		flat.hip_yaw = clampf(rad_to_deg(atan2(-relative.x,-relative.z)),-120,120)*pickup_weight
	elif pickup_age >= duration:
		pickup_age = -1
		idle_age = 0
	Library.apply(lab.body,Library.from_flat(flat,false))
	Feet.ground_feet(lab.body)
	var center: Vector3 = lab.body.to_global(pose.ball)
	var left: Vector3 = lab.body.to_global(pose.left)
	var right: Vector3 = lab.body.to_global(pose.right)
	var floor_y: float = lab.player.global_position.y+RADIUS
	if timeline.bounce >= 0:
		var u: float = timeline.bounce
		var arc := 1.0-4.0*pow(minf(u,1-u),2)
		center.y = lerpf(floor_y,center.y,arc)
		var push := 0.07*sin(u*PI)*sin(u*PI)
		if hand < 0: left.y -= push
		else: right.y -= push
	if pickup_weight > 0 or pickup_age == 0:
		var carry_center: Vector3 = lab.body.to_global(_pose("moving",lab.body,hand,marks).ball)
		var p := clampf(pickup_age/duration,0,1)
		center = pickup_point.lerp(carry_center,blend_fraction((p-0.42)/0.58))
		var grip := Vector3.UP*RADIUS*lerpf(0.45,-0.5,blend_fraction((p-0.42)/0.58)) if pickup_kind == "ground" else Vector3.DOWN*RADIUS*0.5
		var dominant := 0 if hand < 0 else 1
		var reach := pickup_hands[dominant].lerp(center+grip,blend_fraction(p/0.42)) if p < 0.42 else center+grip
		if hand < 0: left = reach.lerp(left,blend_fraction((p-0.72)/0.28))
		else: right = reach.lerp(right,blend_fraction((p-0.72)/0.28))
	# Keep the palms on the actual ball using the current rig's limb lengths.
	_solve_arm(lab.body,"Left",left,center)
	_solve_arm(lab.body,"Right",right,center)
	if not is_instance_valid(visual):
		visual = MeshInstance3D.new()
		visual.name = "HeldBallPresentation"
		visual.mesh = lab.ball.mesh
		visual.material_override = lab.ball.material_override
		lab.add_child(visual)
	visual.show()
	visual.global_position = center
	visual.rotate_x(dt*(5.0 if timeline.bounce >= 0 else 0.2))
	evidence = {"state":"pickup:"+pickup_kind if pickup_weight > 0 else ("moving" if moving else timeline.to),"idle_age":idle_age,"pickup_age":pickup_age,"ball":center,"left":left,"right":right,"bounce":timeline.bounce}

static func _solve_arm(body: Node3D,side: String,target: Vector3,ball: Vector3) -> void:
	var arm := body.get_node(side+"Arm") as Node3D
	var elbow := arm.get_node("Elbow") as Node3D
	var wrist := elbow.get_node("Wrist") as Node3D
	var shoulder := arm.global_position
	var scale: float = body.global_basis.get_scale().x
	var upper: float = elbow.position.length()*scale
	var lower: float = wrist.position.length()*scale
	var direction := (target-shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target),absf(upper-lower)+0.001,upper+lower-0.001)
	var along := (upper*upper-lower*lower+distance*distance)/(2*distance)
	var height := sqrt(maxf(0,upper*upper-along*along))
	var preferred: Vector3 = body.global_basis.orthonormalized()*Vector3(-0.8 if side == "Left" else 0.8,-0.5,0.1)
	var bend := (preferred-direction*preferred.dot(direction)).normalized()
	var elbow_point := shoulder+direction*along+bend*height
	var upper_dir := (elbow_point-shoulder).normalized()
	var lower_dir := (shoulder+direction*distance-elbow_point).normalized()
	var x := upper_dir.cross(lower_dir).normalized()
	if x.length_squared() < 0.01: x = body.global_basis.orthonormalized().x
	var y := -upper_dir
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	arm.basis = body.global_basis.orthonormalized().inverse()*Basis(x,y,z)
	elbow.rotation = Vector3(upper_dir.angle_to(lower_dir),0,0)
	var palm_z := (target-ball).normalized()
	var palm_y := (-lower_dir-palm_z*(-lower_dir).dot(palm_z)).normalized()
	if palm_y.length_squared() > 0.01:
		wrist.basis = elbow.global_basis.orthonormalized().inverse()*Basis(palm_y.cross(palm_z).normalized(),palm_y,palm_z)
