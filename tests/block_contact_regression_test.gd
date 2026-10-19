extends "res://tests/support/test_case.gd"
const Execution = preload("res://scripts/contact_execution.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	for rate in [30, 60, 120]:
		for speed in [12.0, 24.0, 40.0]:
			lab._reset()
			var bots = lab.training_bots
			bots.away_enabled[3] = true
			lab.ball_active = true
			lab.ball.position = Vector3(0, 3.6, 2)
			lab.ball_velocity = Vector3(0, -2, -speed)
			bots.incoming_action = 2
			bots.replan()
			check(bots.active_action == 3, "Driven attack schedules block")
			for frame in range(rate * 2):
				if not lab.ball_active or bots.last_action == 3:
					break
				lab._tick_ball(1.0 / rate)
			check(bots.last_action == 3 and bots.total_contacts == 1, "Bot physically blocks driven attack at %d Hz / %.0f m/s" % [rate, speed])
			check(lab.ball_velocity.z > 2 and lab.ball_velocity.y < 0, "Bot block returns ball downward without stalling")
	for rate in [30, 60, 120]:
		lab._reset()
		lab.training_bots.away_enabled.fill(false)
		lab.player.position = Vector3(0, 1.1, 0.9)
		lab.camera_rig.facing_yaw = 0
		lab.motion.jumped = true
		lab.motion.airborne_action = 3
		lab.motion.airborne_aim = Vector3.FORWARD
		lab.locked_action = 3
		lab.armed = true
		lab.locked_charge = 0.6
		lab.contacts = 3
		lab.side_contacts[0] = 3
		lab.side_contacts[1] = 0
		lab.ball_active = true
		var shape: Dictionary = lab._raw_hurtbox_definition(3)
		var point: Vector3 = lab.player.position + Vector3(shape.center) + Vector3(shape.column_x, 0, 0)
		lab.ball.position = point - Vector3(0, 0, 0.7)
		lab.ball_velocity = Vector3(0, -0.2, 70)
		lab._confirm_action()
		var serial: int = lab._contact_event_serial
		for frame in range(5):
			if lab._contact_event_serial > serial:
				break
			lab.elapsed += 1.0 / rate
			lab._tick_ball(1.0 / rate)
		check(lab._contact_event_serial == serial + 1 and lab.ball_active, "Player swept block catches fast ball and keeps rally active")
		check(lab.contacts == 3 and lab.side_contacts[0] == 3, "Player block does not consume ordinary team touches")
		check(lab.ball_velocity.z < -2 and lab.confirm_window == 0, "Player block returns ball and consumes confirmation")
		for frame in range(rate):
			lab._physics_process(1.0 / rate)
		check(not "Missed timing" in lab.feedback, "Successful block cannot later report a timing miss")
	lab._reset()
	lab.locked_action = 3
	lab.armed = true
	lab._confirm_action()
	lab._finish("Net fault test")
	for frame in range(70):
		lab._physics_process(1.0 / 120)
	check(lab.feedback == "Net fault test" and lab.confirm_window == 0, "Rally end cancels pending confirmation without overwriting the cause")
	print("BLOCK CONTACT REGRESSIONS: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
