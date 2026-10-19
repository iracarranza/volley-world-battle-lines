extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var pepper = lab.pepper
	for action in range(3):
		lab._reset()
		var spot: Vector3 = pepper.SPOTS[1]
		lab.player.position = spot + Vector3(0, 0, 6)
		lab.ball_active = true
		pepper.partner = 1
		pepper.npc_turn = true
		pepper.stage = action
		lab.ball.position = spot + Vector3(0, [1.0, 2.25, 3.2][action] + 2.0, 0.5)
		lab.ball_velocity = Vector3(0, -1, 0)
		pepper.tick(1.0) # Give baseline charging time before the incoming shot.
		pepper.plan()
		for frame in range(240):
			if pepper.exchanges > 0 or not lab.ball_active:
				break
			lab._tick_ball(1.0 / 120)
		check(pepper.exchanges == 1 and not pepper.npc_turn and not pepper.planned, "Partner returns after one contact, never a self-pass sequence")
		var expected := (action + 1) % 3
		check(pepper.player_action == expected and lab.selected == expected, "Good receive requires Set; good Set requires Attack; Attack requires Receive")
		var delivery: Dictionary = pepper.last_delivery
		var arrival: Vector3 = delivery.origin + delivery.velocity * delivery.duration + Vector3.DOWN * lab.GRAVITY * delivery.duration * delivery.duration * 0.5
		# Spikes retain their real arm-intersection bias rather than homing to the target.
		check(arrival.distance_to(delivery.target) < (0.4 if action == 2 else 0.12), "Partner aims at player within physical contact deviation")
		check(Vector2(delivery.target.x - lab.player.position.x, delivery.target.z - lab.player.position.z).length() < 0.001, "Delivery targets current player rather than spawn or partner")
		if action == 0:
			var old_count: int = lab._contact_event_serial
			lab.locked_action = 0
			lab._contact()
			check(lab._contact_event_serial == old_count, "Accurate Receive cannot be answered with another Receive")
			lab.camera_rig.facing_yaw = 0
			lab.locked_action = 1
			lab.locked_charge = 0.55
			lab.camera_rig.view_pitch = 0.27
			lab.armed = true
			var shape: Dictionary = lab._hurtbox_definition(1)
			lab.ball.position = lab.player.position + Vector3(shape.center) + Vector3.UP * shape.radius * 0.55
			lab.aim = spot
			lab._contact()
			check(pepper.npc_turn and pepper.stage == 2, "Player's accurate Set requires partner Attack next")
			old_count = lab._contact_event_serial
			lab._contact()
			check(lab._contact_event_serial == old_count, "Player cannot take consecutive Pepper contacts")
			for frame in range(480):
				if not lab.ball_active or pepper.exchanges >= 2:
					break
				lab._tick_ball(1.0 / 120)
			check(pepper.exchanges == 2 and pepper.last_delivery.action == 2 and pepper.player_action == 0, "Partner physically attacks the player's Set back for a Receive")
	check(pepper.next_action(0, 0.6) == 0 and pepper.next_action(1, 0.6) == 0, "Poor Receive/Set require recovery Receive")
	pepper.partner = 1
	pepper.npc_turn = false
	pepper.player_action = 2
	lab.ball.position = lab.player.position + Vector3(0, 1.3, -1)
	lab.ball_velocity = Vector3.DOWN * 2
	check(pepper.required_player_action() == 0, "Delivery dropping below overhead reach becomes recovery Receive")
	lab._reset()
	lab.camera_rig.update(2)
	lab.camera_rig.set_mode(lab.ViewMode.BALL)
	lab.ball_active = true
	for offset in [Vector3(4, 3, -8), Vector3(-8, 5, -12), Vector3(0, 20, 0)]:
		lab.ball.position = lab.player.position + offset
		lab.camera_rig.update(2)
		check(lab.camera.is_position_in_frustum(lab.ball.position), "Ball View frames ball")
		check(lab.camera.unproject_position(lab.camera_rig.ball_frame_pivot).distance_to(Vector2(720, 900 * lab.camera_rig.ball_frame_screen_y)) < 0.1, "Camera frames athlete at bottom center")
		if offset.y < 10:
			check(lab.camera.is_position_in_frustum(lab.ball.position), "Orbit angle keeps ordinary ball flight on screen")
		else:
			check(lab.camera.is_position_in_frustum(lab.ball.position), "Ball View follows extreme overhead balls by rotation")
	print("PEPPER SEQUENCE / FRAMING: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
