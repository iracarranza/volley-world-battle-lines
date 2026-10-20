extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var bots = lab.training_bots
	# Placing a helper at your position keeps what kind of helper it is
	lab._reset()
	for slot in [0, 1, 2]:
		bots.settings[slot].enabled = true
	bots.set_mode(0, 2)
	bots.set_mode(1, 1)
	bots.set_mode(2, 0)
	lab.player.position = Vector3(2.5, 0.0, 3.0)
	for slot in [0, 1, 2]:
		bots.place_at_player(slot)
	check(bots.settings[0].follows_ball and bots.settings[0].moves, "A move helper is still a move helper after being placed at you")
	check(not bots.settings[1].follows_ball and not bots.settings[1].moves, "A static helper is still static after being placed at you")
	check(bots.settings[2].follows_ball and not bots.settings[2].moves, "A follow helper is still a follow helper after being placed at you")
	check(bots.settings[0].fixed_position.distance_to(Vector3(2.5, 0, 3)) < 0.01 and bots.actors[0].position.distance_to(Vector3(2.5, 0, 3)) < 0.01, "It stands at your position and that is its placed spot")
	# A move helper walks back to its placed spot
	bots.settings[0].move_speed = 4.0
	bots.actors[0].position = Vector3(-3.0, 0, 6.0)
	var start_gap: float = bots.actors[0].position.distance_to(bots.settings[0].fixed_position)
	bots.tick_motion(0.25)
	check(bots.actors[0].position.distance_to(bots.settings[0].fixed_position) < start_gap - 0.9 and bots.actors[0].position.distance_to(bots.settings[0].fixed_position) > start_gap - 1.1, "A displaced move helper walks home at its move speed")
	for frame in range(300):
		bots.tick_motion(0.05)
	check(bots.actors[0].position.distance_to(bots.settings[0].fixed_position) < 0.05, "It gets all the way back to the placed spot")
	# A static and a follow helper do not wander home
	bots.actors[1].position = Vector3(-3.0, 0, 6.0)
	bots.actors[2].position = Vector3(-3.0, 0, 6.0)
	for frame in range(20):
		bots.tick_motion(0.05)
	check(bots.actors[1].position == Vector3(-3.0, 0, 6.0) and bots.actors[2].position == Vector3(-3.0, 0, 6.0), "Only move helpers return")
	# After a contact a move helper heads back
	lab._reset()
	bots.settings[0].enabled = true
	bots.set_mode(0, 2)
	bots.set_move_speed(0, 12.0)
	var home: Vector3 = bots.actors[0].position
	bots.settings[0].fixed_position = home
	lab.ball_active = true
	lab.ball.position = Vector3(3, 5, 5)
	lab.ball_velocity = Vector3(0, -1, 0)
	bots.replan()
	for frame in range(240):
		if not lab.ball_active or bots.total_contacts > 0:
			break
		lab._tick_ball(1.0 / 120.0)
	check(bots.total_contacts > 0, "The move helper made the contact")
	var after_contact: Vector3 = bots.actors[0].position
	check(after_contact.distance_to(home) > 0.5, "The contact took it away from its spot (%.2f m)" % after_contact.distance_to(home))
	lab.ball_active = false
	bots.active_action = -1
	bots.move_targets.clear()
	bots.motion.plans.clear()
	for frame in range(60):
		bots.tick_motion(1.0 / 60.0)
	check(bots.actors[0].position.distance_to(home) < maxf(0.05,after_contact.distance_to(home) - 3.0), "After the contact it begins returning to the placed spot (%.2f to %.2f)" % [after_contact.distance_to(home), bots.actors[0].position.distance_to(home)])
	# Off the net
	for side in [1.0, -1.0]:
		lab._reset()
		bots.settings[0].enabled = true
		bots.settings[4].enabled = true
		bots.set_mode(0, 0)
		bots.set_mode(4, 0)
		lab.ball_active = true
		lab.ball.position = Vector3(0.3, 1.9, 1.4 * side)
		lab.ball_velocity = Vector3(0.0, 0.4, -6.0 * side)
		lab.ball_shot = {}
		var touched := false
		var replanned_after := false
		for frame in range(600):
			lab._tick_ball(1.0 / 120.0)
			if lab.net_response.last_contact != "":
				touched = true
			if touched and bots.net_rebound and bots.active_action == 0:
				replanned_after = true
			if not lab.ball_active or bots.total_contacts > 0:
				break
		check(touched, "The ball touched the net (%s)" % ("home" if side > 0 else "away"))
		check(bots.net_rebound or bots.total_contacts > 0, "Helpers looked again once it came off the net")
		check(replanned_after or bots.total_contacts > 0, "A receiver was assigned to the rebound")
		check(bots.total_contacts > 0, "A receiver bot received the ball that came off the net (%s)" % ("home" if side > 0 else "away"))
	print("BOT NET / RETURN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
