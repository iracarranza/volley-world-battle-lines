extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	bots.enabled[0] = true
	for speed in [0.0, 2.0, 12.0]:
		lab._reset()
		bots.set_mode(0, 2)
		bots.set_move_speed(0, speed)
		var start: Vector3 = bots.actors[0].position
		lab.ball_active = true
		lab.ball.position = Vector3(3, 5, 5)
		lab.ball_velocity = Vector3(0, -1, 0)
		bots.replan()
		check(bots.active_action == 0 and bots.actors[0].position == start, "Move planning never teleports receiver")
		bots.tick_motion(0.1)
		check(bots.actors[0].position.distance_to(start) <= speed * 0.1 + 0.001, "Move speed caps ground displacement")
		if speed > 0:
			check(bots.actors[0].position.x > start.x, "Move heads toward assigned contact")
		for frame in range(180):
			if not lab.ball_active or bots.total_contacts > 0:
				break
			lab._tick_ball(1.0 / 120)
		check((bots.total_contacts > 0) == (speed == 12), "Only a sufficiently quick moving bot reaches this feed")
	lab._reset()
	bots.set_mode(2, 2)
	bots.set_move_speed(2, 1)
	var attack_start: Vector3 = bots.actors[2].position
	bots._plan(2, Vector3(-4, 3.5, 4), 1.0)
	check(bots.actors[2].position == attack_start, "Move attacker does not teleport to approach start")
	bots.tick_motion(0.1)
	check(Vector2(bots.actors[2].position.x - attack_start.x, bots.actors[2].position.z - attack_start.z).length() <= 0.101, "Attack approach obeys Move slider")
	for side in [0, 1]:
		lab._reset()
		bots.enabled[1] = side == 0
		bots.away_enabled[1] = side == 1
		var receiver := 0 if side == 0 else 4
		var setter := receiver + 1
		var sign_side := 1.0 if side == 0 else -1.0
		var origin := Vector3(0, 1, 5 * sign_side)
		for distance in [3.0, 30.0]:
			bots.actors[setter].position = origin + Vector3(distance, -1, 0)
			lab.ball.position = origin
			bots._launch(0)
			check(lab.ball_velocity.x > 0 and absf(lab.ball_velocity.z) < 0.001, "Receive aims toward same-side setter even out of range")
			var duration: float = (lab.ball_velocity.y + sqrt(lab.ball_velocity.y * lab.ball_velocity.y + 2 * lab.GRAVITY * (origin.y - 0.105))) / lab.GRAVITY
			check(lab.ball_velocity.x * duration < 20, "Setter targeting does not grant unlimited receive distance")
	lab._reset()
	bots.enabled[0] = true
	bots.enabled[1] = true
	bots.away_enabled.fill(false)
	bots.set_following(0, true)
	bots.actors[1].position = Vector3(4, 0, 4)
	bots.set_mode(1, 1)
	bots.set_contact_order(1, 3)
	lab.ball_active = true
	lab.ball.position = Vector3(0, 5, 5)
	lab.ball_velocity = Vector3(0, -1, 0)
	bots.replan()
	for frame in range(240):
		if bots.total_contacts > 0 or not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120)
	var actual_direction := Vector3(lab.ball_velocity.x, 0, lab.ball_velocity.z).normalized()
	var setter_direction: Vector3 = bots.setter_direction(0, lab.ball.position)
	check(bots.last_action == 0 and actual_direction.dot(setter_direction) > 0.9999, "Actual receive preserves setter heading after geometry and execution effects")
	bots.set_mode(0, 2)
	bots.reset()
	check(bots.moves[0] and bots.move_speeds[0] == 12, "Reset preserves movement settings")
	print("BOT MOVE / SETTER AIM: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
