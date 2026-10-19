extends "res://tests/support/test_case.gd"
func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.keycode = KEY_D
	event.pressed = pressed
	Input.parse_input_event(event)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.auto_feed = false
	await physics_frame
	lab.player.position = Vector3(15, 0.03, 20)
	for frame in range(6):
		lab.player.velocity = Vector3.DOWN * 2
		lab.player.move_and_slide()
		await physics_frame
	lab.locked_action = 0
	lab.armed = true
	lab.player.velocity.x = 5
	lab._confirm_action()
	check(lab.ground_contact_locked() and lab.player.velocity.x == 0, "Confirmation immediately stops grounded momentum")
	var start: Vector3 = lab.player.position
	key(true)
	for frame in range(8):
		lab._physics_process(1.0 / 120)
		await physics_frame
	check(Vector2(lab.player.position.x - start.x, lab.player.position.z - start.z).length() < 0.001, "Grounded confirmation does not translate athlete")
	check(lab.directional_input.value().x > 0.5, "Movement input still supplies contact DI while locomotion is locked")
	lab.motion.begin_jump()
	check(lab.motion.jump_charge < 0, "Jump preparation cannot move athlete out of confirmed grounded action")
	lab.ball_active = true
	lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(0).center
	lab.ball_velocity = Vector3(0, -1, 2)
	lab._contact()
	check(lab.ground_contact_locked() and lab.confirm_window == 0, "Contact ends confirmation but retains follow-through lock")
	for frame in range(30):
		lab._physics_process(1.0 / 120)
		await physics_frame
	check(not lab.ground_contact_locked(), "Transition recovery releases movement lock")
	lab._physics_process(1.0 / 60)
	await physics_frame
	check(lab.player.position.x > start.x, "Held movement resumes after successful contact")
	lab.ball_active = false
	lab.armed = true
	lab._confirm_action()
	lab.confirm_window = 0.001
	lab._physics_process(1.0 / 60)
	await physics_frame
	check(not lab.ground_contact_locked(), "Miss/expiry releases movement lock")
	var after_expiry: Vector3 = lab.player.position
	lab._physics_process(1.0 / 60)
	await physics_frame
	check(lab.player.position.x > after_expiry.x, "Locomotion resumes after expiry")
	key(false)
	print("CONFIRMATION MOVEMENT LOCK: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
