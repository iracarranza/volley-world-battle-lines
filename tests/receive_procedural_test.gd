extends SceneTree
const Library := preload("res://scripts/pose_library.gd")
const ReceivePose := preload("res://scripts/receive_pose.gd")
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func prepared_pose(lab, speed: float, ball: Vector3 = Vector3.INF) -> Dictionary:
	lab._reset()
	lab.selected = 0
	lab.locked_action = 0
	lab.armed = true
	lab.animation.pose_smoothing = false
	lab.motion.gait_cycle = 0.6
	lab.player.velocity = Vector3(0, 0, -speed)
	lab.ball_active = ball != Vector3.INF
	if lab.ball_active:
		lab.ball.position = ball
	lab.animation.update()
	return Library.read_rig(lab.body)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	for i in 20:
		await physics_frame
	var top: float = lab.athlete.speed()
	var still := prepared_pose(lab, 0.0)
	var jog := prepared_pose(lab, top * 0.25)
	var run := prepared_pose(lab, top * 0.95)
	var near := prepared_pose(lab, top * 0.95, lab.player.position + Vector3(0, 1.2, -1.8))
	check(float(still["shoulder_pitch:Left"]) > 40.0, "Standing with a receive prepared holds the platform (%.0f)" % float(still["shoulder_pitch:Left"]))
	check(float(jog["shoulder_pitch:Left"]) > 30.0, "Shuffling slowly keeps the platform (%.0f)" % float(jog["shoulder_pitch:Left"]))
	check(float(run["shoulder_pitch:Left"]) < float(still["shoulder_pitch:Left"]) - 20.0 and float(run["shoulder_pitch:Right"]) < float(still["shoulder_pitch:Right"]) - 20.0, "Running with a receive prepared brings the arms down (%.0f vs %.0f)" % [float(run["shoulder_pitch:Left"]), float(still["shoulder_pitch:Left"])])
	check(float(near["shoulder_pitch:Left"]) > float(run["shoulder_pitch:Left"]) + 15.0, "The platform comes back when the ball is close (%.0f vs %.0f)" % [float(near["shoulder_pitch:Left"]), float(run["shoulder_pitch:Left"])])
	# Postures follow the ball
	var body := lab.body as Node3D
	for contact_x in [1.2, -1.2]:
		Library.apply(body, Library.load_pose("ready_stance"), 1.0)
		ReceivePose.apply(body, "reaching", Vector3(contact_x, 0.9, -1.5), 1.0)
		var lead_name := "RightLeg" if contact_x > 0.0 else "LeftLeg"
		var trail_name := "LeftLeg" if contact_x > 0.0 else "RightLeg"
		check((body.get_node(lead_name) as Node3D).rotation.x > 0.3 and (body.get_node(trail_name) as Node3D).rotation.x < 0.0, "A reaching receive lunges with the leg on the ball's side (%s)" % lead_name)
	var yaws := []
	for contact_x in [1.2, -1.2]:
		for posture in ["moving", "reaching", "off-axis"]:
			Library.apply(body, Library.load_pose("ready_stance"), 1.0)
			ReceivePose.apply(body, posture, Vector3(contact_x, 0.9, -1.5), 1.0)
			yaws.append((body.get_node("RightArm") as Node3D).rotation.y)
	check(yaws[0] * yaws[3] < 0.0 and yaws[1] * yaws[4] < 0.0 and yaws[2] * yaws[5] < 0.0, "Moving, reaching and off-axis all turn the platform toward the ball, either side")
	check(absf(yaws[2]) > absf(yaws[1]) and absf(yaws[1]) > absf(yaws[0]), "Off-axis turns it most, then reaching, then moving")
	print("receive_procedural: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
