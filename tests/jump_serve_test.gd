extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func strike_at_center(lab: Node3D, jumped: bool) -> Dictionary:
	lab._reset()
	lab.camera_rig.view_pitch = lab.NEUTRAL_VIEW_PITCH
	lab.camera_rig.update_aim()
	lab._serve()
	var center: Vector3 = lab.serve.serve_center(lab._raw_hurtbox_definition(2))
	lab.motion.jumped = jumped
	lab.ball_velocity = Vector3.ZERO
	lab.ball.position = lab.player.position + center.rotated(Vector3.UP, lab._contact_yaw())
	lab.serve.press()
	for frame in range(80):
		lab.ball_velocity = Vector3.ZERO
		lab._tick_ball(1.0 / 120)
		if lab.serve.state == lab.serve.State.FLIGHT:
			break
	lab.motion.jumped = false
	return lab.serve.evidence
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	# What counts as a high toss: its predicted apex and how long it stays worth jumping for
	lab._reset()
	lab._serve()
	check(not lab.serve.jump_serve_ready(), "The lowest toss is not worth jumping for")
	lab._reset()
	lab.serve._begin_toss(8.6)
	var high: Dictionary = lab.serve.toss_prediction()
	check(float(high.apex) > float(high.target) and float(high.time_above) >= lab.serve.JUMP_SERVE_MIN_TIME and lab.serve.jump_serve_ready(), "A full-charge toss peaks well above reach and stays there long enough")
	lab._reset()
	lab.serve._begin_toss(7.0)
	check(not lab.serve.jump_serve_ready() or float(lab.serve.toss_prediction().time_above) >= lab.serve.JUMP_SERVE_MIN_TIME, "The test follows its own prediction")
	# Jumping after a high toss is a run-up
	lab._reset()
	lab.serve._begin_toss(8.6)
	lab.motion.begin_jump()
	check(lab.motion.approach_action == 2 and not lab.motion.generic_jump, "Jumping after a high toss starts an approach run")
	lab._reset()
	lab._serve()
	lab.motion.begin_jump()
	check(lab.motion.approach_action != 2, "Jumping after a low toss is not a serving run-up")
	# The strike
	var ground := strike_at_center(lab, false)
	var jump := strike_at_center(lab, true)
	check(not ground.jump and jump.jump, "The evidence records a jump serve")
	check(float(jump.angle_degrees) > float(ground.angle_degrees) + 9.0, "A jump serve leaves higher")
	var speed: float = Vector3(jump.outgoing_velocity).length()
	var expected: float = float(jump.spike_reference_speed) * lab.serve.JUMP_SERVE_PACE * float(jump.contact_factor)
	check(absf(speed - expected) < 0.001, "A jump serve is 65%% of the equivalent clean spike (%.2f of %.2f)" % [speed, float(jump.spike_reference_speed)])
	check(speed > Vector3(ground.outgoing_velocity).length(), "...which is faster than a standing serve")
	# Serve Velocity adds effective charge before the 65%
	lab.athlete.gameplay_effects["serve_velocity"] = 8.0
	var boosted := strike_at_center(lab, true)
	var gained: float = Vector3(boosted.outgoing_velocity).length() - speed
	var per_charge: float = 7.0 * lab.ATTACK_DRIVE_FACTOR * lab.SPIKE_SPEED_MULTIPLIER * lab.serve.JUMP_SERVE_PACE
	check(absf(gained - 0.08 * per_charge * float(boosted.contact_factor)) < 0.01, "Serve Velocity adds effective charge before the 65%% (gained %.2f m/s)" % gained)
	lab.queue_free()
	await process_frame
	print("JUMP SERVE: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
