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
	var pepper = lab.pepper
	lab._reset()
	var spot: Vector3 = pepper.SPOTS[1]
	lab.player.position = spot + Vector3(0, 0, 8)
	pepper.partner = 1
	pepper.player_action = 0
	pepper.npc_turn = false
	lab.ball_active = true
	lab.locked_action = 0
	lab.selected = 0
	lab.armed = true
	lab.locked_charge = 0.90
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.view_pitch = 0.27
	lab.aim = spot
	lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(0).center
	lab.ball_velocity = Vector3(0, -5, 10)
	lab._confirm_action()
	lab._contact()
	check(pepper.stage == 1 and pepper.npc_turn and pepper.planned, "Good actual player Receive schedules NPC Set")
	check(pepper.MOVEMENT_MODE == "Move", "Pepper partners always use Move")
	var before: Vector3 = pepper.actors[1].position
	pepper.plan()
	check(pepper.actors[1].position == before, "Pepper planning does not teleport")
	var travelled := 0.0
	for frame in range(360):
		if pepper.exchanges > 0 or not lab.ball_active:
			break
		var prior: Vector3 = pepper.actors[1].position
		lab._tick_ball(1.0 / 120)
		var distance := Vector2(pepper.actors[1].position.x - prior.x, pepper.actors[1].position.z - prior.z).length()
		travelled += distance
		check(distance <= pepper.MOVE_SPEED / 120 + 0.001, "Pepper movement respects ground speed")
	check(pepper.exchanges == 1 and pepper.last_delivery.action == 1 and pepper.player_action == 2, "NPC physically sets the received ball back for a player Attack")
	check(travelled > 0.1, "Partner travelled to its Set contact")
	lab._reset()
	pepper.partner = 1
	pepper.stage = 1
	pepper.npc_turn = true
	lab.player.position = spot + Vector3(0, 0, 7)
	lab.ball_active = true
	lab.ball.position = spot + Vector3(0, 1.8, 0)
	lab.ball_velocity = Vector3(0, 0, 0)
	pepper.plan()
	check(pepper.stage == 1 and pepper.planned, "Low shoulder-height set is planned instead of silently falling back to Receive")
	for pitch in [-0.12, 0.0, 0.27]:
		lab._reset()
		lab.camera_rig.view_pitch = pitch
		lab.aim = Vector3(0, 0, -12)
		var origin := Vector3(0, 2.1, 0)
		var ground: Vector3 = lab._shot_velocity(origin, 1, 1.0)
		var receive_height := 1.86 * 0.8
		var t: float = (ground.y + sqrt(ground.y * ground.y + 2 * lab.GRAVITY * (origin.y - receive_height))) / lab.GRAVITY
		var range_at_hands := Vector2(ground.x, ground.z).length() * t
		check(range_at_hands > pepper.RADIUS * 2, "Full ground set reaches partner hands across two circle radii even at low aim")
		lab.motion.jumped = true
		var jump: Vector3 = lab._shot_velocity(origin, 1, 1.0)
		check(ground.y < jump.y, "Ground sets trade height for travel without lowering jump sets")
	print("PEPPER MOVE / SETS: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
