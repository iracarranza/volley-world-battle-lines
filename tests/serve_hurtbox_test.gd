extends "res://tests/support/test_case.gd"
const Serve := preload("res://scripts/interactive_serve.gd")
const Swing := preload("res://scripts/swing_clock.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# The arm's angle on the swing clock
	check(Swing.arm_angle_at(0.0) == Swing.ANGLE_COCKED and is_equal_approx(Swing.arm_angle_at(Swing.PEAK), Swing.ANGLE_EXTENDED), "The arm starts cocked and is extended at the clock's peak")
	check(is_equal_approx(Swing.arm_angle_at(Swing.power_end()), Swing.ANGLE_FOLLOW), "It has followed through by the time the power window closes")
	var previous := 999.0
	var falling := true
	for step in range(0, 40):
		var angle := Swing.arm_angle_at(float(step) / 40.0 * Swing.power_end())
		falling = falling and angle <= previous + 0.0001
		previous = angle
	check(falling, "The arm only ever sweeps forward")
	check(is_equal_approx(Swing.age_reaching(Swing.ANGLE_EXTENDED), Swing.PEAK), "A ball at the sweet angle is reached at the peak")
	check(Swing.age_reaching(120.0) < Swing.PEAK and Swing.age_reaching(40.0) > Swing.PEAK, "A ball further back is reached sooner, one further forward later")
	check(Swing.form_at(Swing.age_reaching(145.0)) == "roll" and Swing.form_at(Swing.age_reaching(30.0)) == "power" and Swing.form_at(Swing.power_end() + 0.01) == "push", "Reached very early it is a roll; the central window is a power swing; after it, a push")
	# The serving hurtbox is most effective at the centre
	check(Serve.serve_zone(0.05) == "SWEET SPOT" and Serve.serve_zone(0.25) == "FAIR" and Serve.serve_zone(0.45) == "WEAK" and Serve.serve_zone(0.58) == "SOUR SPOT" and Serve.serve_zone(0.9) == "MISS", "Radially less effective toward the outside")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab._reset()
	lab.camera_rig.view_pitch = lab.NEUTRAL_VIEW_PITCH
	lab._serve()
	var shape: Dictionary = lab._raw_hurtbox_definition(2)
	var center: Vector3 = lab.serve.serve_center(shape)
	# The toss is released over the hurtbox's centre.
	var local: Vector3 = lab.local_contact_position_at(lab.ball.position)
	check(absf(local.x - center.x) < 0.01 and absf(local.z - center.z) < 0.01, "The toss comes down through the serving hurtbox")
	# A ball held at the centre is struck when the arm gets there, not before, and as a sweet power swing.
	lab.ball_velocity = Vector3.ZERO
	lab.ball.position = lab.player.position + (center).rotated(Vector3.UP, lab._contact_yaw())
	lab.serve.press()
	check(lab.serve.state == lab.serve.State.SWING, "The second press starts the swing")
	var struck_at := -1.0
	for frame in range(60):
		lab.ball_velocity = Vector3.ZERO
		lab._tick_ball(1.0 / 120)
		if lab.serve.state == lab.serve.State.FLIGHT:
			struck_at = float(lab.serve.evidence.swing_time)
			break
	check(struck_at > 0.0 and absf(struck_at - Swing.PEAK) < 0.02, "A ball at the arm's extension is struck when the arm gets there (%.3f s)" % struck_at)
	check(lab.serve.evidence.zone == "SWEET SPOT" and lab.serve.evidence.form == "power" and lab.serve.evidence.sweet, "Centre contact at the extension is a sweet power serve")
	lab.queue_free()
	await process_frame
	print("SERVE HURTBOX: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
