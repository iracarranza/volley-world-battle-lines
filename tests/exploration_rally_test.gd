extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func settle(lab: Node3D) -> void:
	for frame in range(12):
		lab._physics_process(1.0 / 60)
		await physics_frame
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	# This fixture advances ballistic time without advancing the real MoC clock.
	lab.moc.enabled = false
	await settle(lab)
	check(not lab.auto_feed and not lab.ball_active, "Exploration starts without automatic rallies")
	lab.player.position = Vector3(-30, 0.03, -25)
	await settle(lab)
	check(lab.player.position.x < -29 and lab.player.position.z < -24 and lab.player.is_on_floor(), "Both sides and the wider map have reachable ground")
	lab._serve()
	check(lab.ball_active and lab.serve.tossing(), "E tosses freely across the map")
	lab._reset()
	await settle(lab)
	lab.motion.begin_jump()
	check(lab.motion.generic_jump, "Space uses traversal controls outside rally")
	key(KEY_D, true)
	await process_frame
	lab.motion.jump_charge = 0.5
	lab.player.velocity = Vector3(20, 0, -10)
	lab.motion.takeoff()
	var first: Vector3 = lab.player.velocity
	# An exploration jump rises from 0.6 m to this build's own exploration maximum (a share of its leap, below what an attack approach reaches).
	var half_height: float = lerpf(0.6, maxf(0.6, lab.athlete.explore_jump_max()), 0.5)
	check(absf(lab.motion.last_jump_height - half_height) < 0.001, "Half charge produces the build's half-charge height (%.2f m)" % half_height)
	var flight: float = 2 * first.y / lab.GRAVITY
	check(absf(Vector2(first.x, first.z).length() * flight - 3.5) < 0.001, "Half charge produces preset 3.5m travel distance")
	lab._reset()
	await settle(lab)
	lab.motion.begin_jump()
	lab.motion.jump_charge = 0.5
	lab.player.velocity = Vector3(-30, 0, 15)
	lab.motion.takeoff()
	check(lab.player.velocity.distance_to(first) < 0.001, "Travel launch ignores incoming momentum")
	key(KEY_D, false)
	await process_frame
	lab._reset()
	await settle(lab)
	lab.motion.begin_jump()
	lab.motion.jump_charge = 1.0
	lab.motion.takeoff()
	check(Vector2(lab.player.velocity.x, lab.player.velocity.z).length() < 0.001, "No direction produces straight-up travel jump")
	lab._reset()
	await settle(lab)
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	await process_frame
	lab._physics_process(0.1)
	var exploration_cost: float = 100.0 - lab.athlete.stamina
	lab.athlete.stamina = 100
	lab.ball_active = true
	lab.ball.position = Vector3(0, 20, 5)
	lab.ball_velocity = Vector3.ZERO
	lab._physics_process(0.1)
	var rally_cost: float = 100.0 - lab.athlete.stamina
	check(rally_cost > exploration_cost+0.4, "Sprint is cheaper outside rallies")
	key(KEY_D, false)
	key(KEY_SHIFT, false)
	await process_frame
	lab._reset()
	await settle(lab)
	lab.camera_rig.view_pitch = 0.27
	lab.camera_rig.update(2)
	lab._serve()
	check(lab.serve.tossing(), "First E starts a real toss")
	for frame in range(18):
		lab._tick_ball(1.0 / 120)
	lab._serve()
	for frame in range(40):
		if lab.serve.state == lab.serve.State.FLIGHT:
			break
		lab._tick_ball(1.0 / 120)
	check(lab.ball_active and lab.training_bots.settings[(0) + 4].enabled, "E starts live rally and spawns enemy receiver")
	check(not lab.training_bots.settings[(1) + 4].enabled and not lab.training_bots.settings[0].enabled, "Serving only adds one enemy receiving role")
	check(lab.court_half_width == 2.5 and lab.court_half_depth == 5, "One versus one uses provisional 5 by 10 court")
	lab.motion.begin_jump()
	check(not lab.motion.generic_jump, "Live rally preserves sporting approach controls")
	lab.motion.jump_charge = -1
	for i in range(480):
		if not lab.ball_active or lab.training_bots.total_contacts > 0:
			break
		lab._tick_ball(1.0 / 120)
	check(lab.training_bots.total_contacts > 0, "Served ball clears Net and is physically received by enemy bot")
	lab.training_bots.toggle(1, true)
	lab.training_bots.toggle(2, true)
	check(lab.court_half_width == 3.75 and lab.court_half_depth == 7.5, "Larger away roster determines both court halves")
	lab._finish("test")
	lab.motion.begin_jump()
	check(lab.motion.generic_jump, "Ball down restores traversal controls")
	print("EXPLORATION / RALLY CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
