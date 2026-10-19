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
	bots.enabled[1] = true
	bots.contact_order[1] = 1
	bots.set_mode(1, 2)
	bots.set_move_speed(1, 12)
	lab.ball_active = true
	lab.ball.position = Vector3(0, 5, 5)
	lab.ball_velocity = Vector3(0, -1, 0)
	bots.replan()
	check(bots.active_action == 1 and bots.motion.plans.has(1), "Move setter schedules a jump for an overhead ball")
	check(float(bots.motion.plans[1].height) > 0.5, "Jump set targets elevated contact rather than a ground set")
	var airborne := false
	for frame in range(240):
		if not lab.ball_active or bots.total_contacts > 0:
			break
		lab._tick_ball(1.0 / 120)
		airborne = airborne or bots.actors[1].position.y > 0.2
	check(airborne and bots.last_action == 1 and bots.actors[1].position.y > 0.2, "Setter physically contacts ball during jump")
	check(bots.animation.state_for(bots.rigs[1].body).source == "set", "Jump uses shared set animation")
	for action in [1, 2]:
		lab._reset()
		bots.enabled.fill(false)
		bots.enabled[action] = true
		bots.contact_order[action] = 1
		bots.set_mode(action, 2)
		lab.ball_active = true
		lab.ball.position = Vector3(12, 1.0, 5)
		lab.ball_velocity = Vector3(0, -1, 0)
		bots.replan()
		check(bots.motion.plans.has(action) and bots.motion.plans[action].get("fallback", false), "Invalid interception still schedules overhead jump attempt")
		var jumped := false
		for frame in range(90):
			bots.tick_motion(1.0 / 120)
			jumped = jumped or bots.actors[action].position.y > 0.15
		check(jumped and bots.total_contacts == 0, "Failed prediction produces a jump without a fabricated touch")
	var pepper = lab.pepper
	lab._reset()
	pepper.partner = 1
	pepper.stage = 1
	pepper.npc_turn = true
	lab.player.position = pepper.SPOTS[1] + Vector3(0, 0, 7)
	lab.ball_active = true
	lab.ball.position = pepper.SPOTS[1] + Vector3(0, 5, 0.5)
	lab.ball_velocity = Vector3(0, -1, 0)
	pepper.plan()
	check(pepper.planned and pepper.jump_height > 0.5, "Always-Move Pepper setter prefers jump set")
	var pepper_airborne := false
	for frame in range(240):
		if not lab.ball_active or pepper.exchanges > 0:
			break
		lab._tick_ball(1.0 / 120)
		pepper_airborne = pepper_airborne or pepper.actors[1].position.y > 0.2
	check(pepper_airborne and pepper.last_delivery.get("action", -1) == 1, "Pepper partner physically jump sets")
	print("BOT JUMP ATTEMPTS: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
