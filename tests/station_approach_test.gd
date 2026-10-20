extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	call_deferred("run")

func settle(lab: Node3D) -> void:
	for frame in range(12):
		lab._physics_process(1.0 / 60.0)
		await physics_frame

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.auto_feed = false
	await settle(lab)
	var drill = lab.station
	drill.start()
	check(not drill.running(), "Drill cannot start remotely from main court")
	# The station is reachable using normal movement through the shared world.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	for frame in range(300):
		if drill.in_zone():
			break
		lab._physics_process(1.0 / 60.0)
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(lab.player.position.x > 10 and drill.in_zone(), "Athlete must be able to walk from court into the station")
	drill.start()
	check(drill.running() and drill.streak == 0, "Interaction starts a fresh consecutive-receive sequence")
	drill.tick(1.6)
	check(lab.ball_active and drill.state == drill.State.TOSS, "Station telegraphs a live toss")
	drill.tick(drill.TOSS_SECONDS)
	drill.on_ball_down()
	check(drill.state == drill.State.FAILED and drill.streak == 0, "Missed serve must fail and reset the streak")
	drill.start()
	drill.serve()
	drill.tick(drill.TOSS_SECONDS)
	drill.on_contact(2)
	check(drill.state == drill.State.FAILED, "Attack cannot count as a successful Serve Receive")
	# Complete eight scoring serves using physical ball motion and the actual contact volume.
	drill.start()
	lab.selected = 0
	lab.locked_action = 0
	lab.locked_charge = 0.15
	lab.athlete.hp = 55
	lab.athlete.stamina = 90
	var xp_before: int = drill.earned_xp
	for serve_index in range(8):
		drill.force_next_feed = serve_index % 6
		drill.serve()
		drill.tick(drill.TOSS_SECONDS)
		lab.locked_charge = float(lab.ball_shot.charge) + 0.05
		for frame in range(360):
			lab.elapsed += 1.0 / 120.0
			lab._tick_ball(1.0 / 120.0)
			# Place the athlete beneath the incoming ball to test the drill's
			# actual receive contact integration, rather than bypassing its rules.
			if lab.ball_active and lab.ball_velocity.y < 0 and lab.ball.position.y < 1.4 and lab.ball.position.y > 0.7:
				lab.player.position = Vector3(lab.ball.position.x, 0, lab.ball.position.z + 0.45)
				lab.camera_rig.facing_yaw = 0
				lab.camera_rig.view_yaw = 0
				lab.camera_rig.update_aim()
				lab.armed = true
				lab._confirm_action()
				if lab._can_contact():
					lab._contact()
					break
		check(drill.points == serve_index and drill.state == drill.State.RETURNING, "Physical receive waits for landing before scoring")
		drill.cleared = true   # this test places the receiver where the ball is, so the height barrier is covered in serve_receive_scoring_test
		drill.on_ball_down(Vector3(14, 0.105, 2))
	check(drill.state == drill.State.COMPLETE and drill.earned_xp == xp_before + 25, "Eight landing points must award completion and lab XP")
	check(lab.athlete.hp > 35, "Completion must grant the resource reward after contact costs")
	# A step-based root-motion profile must visibly pause and drive every step.
	for progress in [0.0, 0.50, 0.72]:
		check(lab.Approach.speed_scale(progress) < 0.15, "Each approach step must contain a loading/plant pause")
	check(lab.Approach.speed_scale(0.22) > 0.5 and lab.Approach.speed_scale(0.62) > 0.7, "Approach steps must contain distinct drive impulses")
	check(lab.Approach.jump_factor(1, 0.1) == lab.Approach.jump_factor(1, 1.0), "Jump Set must not gain a full-approach bonus")
	check(lab.Approach.jump_factor(3, 0.1) == lab.Approach.jump_factor(3, 1.0), "Block Jump must not gain a full-approach bonus")
	check(lab.Approach.jump_factor(2, 1.0) > lab.Approach.jump_factor(2, 0.1) * 1.8, "Spike must strongly reward completing the full approach")
	var early_set: float = await jump_height(lab, 1, 0.1, 0.2)
	var full_set: float = await jump_height(lab, 1, 1.0, 2.0)
	check(full_set > early_set, "Direct Jump Set gains height from jump charge")
	var early_block: float = await jump_height(lab, 3, 0.1, 0.2)
	var full_block: float = await jump_height(lab, 3, 1.0, 2.0)
	check(full_block > early_block, "Direct Block Jump gains height from jump charge")
	var early_spike: float = await jump_height(lab, 2, 0.1, 0.2)
	var full_spike: float = await jump_height(lab, 2, 1.0, 2.0)
	var standing_spike: float = await jump_height(lab, 2, 1.0, 0.0)
	check(full_spike > early_spike * 1.8, "Actual full-run spike must jump substantially higher than an early release")
	check(full_spike > standing_spike * 1.8, "Standing charge cannot earn a completed running-approach bonus")
	lab._reset()
	await settle(lab)
	lab.motion.approach_direction = Vector3.RIGHT
	lab.selected = 0
	lab.motion.approach_action = 0
	lab.motion.jump_charge = 0.16
	lab.motion.takeoff()
	var timed_speed: float = Vector2(lab.player.velocity.x, lab.player.velocity.z).length()
	check(lab.motion.jumped and lab.confirm_window > 0 and lab.hurtbox_root.visible, "Move + Space release must dive and confirm Receive without a click")
	check(lab.player.velocity.x > 0 and absf(lab.player.velocity.z) < 0.001, "Dive must follow movement direction instead of camera aim")
	lab._reset()
	await settle(lab)
	lab.motion.approach_direction = Vector3.RIGHT
	lab.selected = 0
	lab.motion.approach_action = 0
	lab.motion.jump_charge = 0.8
	lab.motion.takeoff()
	var late_speed: float = Vector2(lab.player.velocity.x, lab.player.velocity.z).length()
	check(timed_speed > late_speed * 1.5, "Correct first-step release must create a substantially faster/farther dive")
	lab._reset()
	for action in range(4):
		lab.locked_action = action
		lab.armed = true
		lab._confirm_action()
		lab._update_hurtbox_visual(0)
		var definition: Dictionary = lab._hurtbox_definition(action)
		var expected_mesh: bool = (definition.shape in ["sector", "set_sector", "block_columns"] and lab.hurtbox_mesh.mesh is ImmediateMesh) or (definition.get("receive_platform", false) and lab.hurtbox_mesh.mesh is ImmediateMesh) or (definition.shape == "ellipsoid" and lab.hurtbox_mesh.mesh is SphereMesh) or (definition.shape == "box" and lab.hurtbox_mesh.mesh is BoxMesh)
		check(lab.hurtbox_root.visible and expected_mesh, "Confirmed action must reveal its actual distinct geometric contact shape")
		lab.ball.position = lab.hurtbox_root.position + (Vector3.UP * float(definition.radius) * 0.55 if definition.shape == "set_sector" else Vector3.ZERO)
		check(lab._overlaps_contact(action), "Ball in visible hurtbox must pass the authoritative contact test")
		lab.ball.position = lab.hurtbox_root.position + Vector3(4, 0, 0)
		check(not lab._overlaps_contact(action), "Ball well outside visible hurtbox must fail the contact test")
	lab.confirm_window = 0
	lab._update_hurtbox_visual(2.0)
	check(not lab.hurtbox_root.visible, "Hurtbox overlay must expire after confirmation and brief linger")
	lab._reset()
	lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
	await settle(lab)
	lab.selected = 2
	key.pressed = true
	Input.parse_input_event(key)
	lab.motion.begin_approach()
	var travel: Array[float] = [0.0, 0.0, 0.0]
	var ticks: Array[int] = [0, 0, 0]
	for frame in range(100):
		if lab.motion.jump_charge < 0:
			break
		var step: int = mini(lab.Approach.step_index(lab.motion.jump_charge), 2)
		var before: Vector3 = lab.player.position
		lab._physics_process(1.0 / 60.0)
		travel[step] += Vector2(lab.player.position.x - before.x, lab.player.position.z - before.z).length()
		ticks[step] += 1
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(travel[0] > travel[1] * 1.7 and travel[0] > travel[2] * 2.0, "Actual first-step root travel must be much longer than both short steps")
	check(travel[1] > travel[2] * 1.1, "Second and third steps must have different actual travel distances")
	check(ticks[0] > ticks[1] * 1.7 and ticks[1] > ticks[2], "Actual step rhythm must be long, quick, then sharper")
	check(lab.motion.jumped and lab.player.velocity.y > 0 and lab.motion.approach_phase_name == lab.Approach.STEP_NAMES[3], "The fourth phase must launch upward instead of adding a forward stride")
	lab._reset()
	lab.camera_rig.update_aim()
	lab.motion.jump_charge = 0.89
	lab.motion.approach_action = 2
	lab.motion.approach_direction = Vector3.FORWARD
	lab.animation.update()
	check(lab.Approach.lead_foot(0) == 1 and lab.Approach.lead_foot(2) == 1, "Right-foot lead must remain fixed until handedness is implemented")
	check(lab.legs[1].position.x < 0.09 and lab.legs[1].rotation.y > 0.15, "Third right foot must close inward and turn to square the plant")
	check(lab.approach_footprints.size() == 4, "Projection must include three ground strides and an upward-launch marker")
	var standing_launch: Vector3 = await launch_velocity(lab, 2, Vector3.ZERO)
	var moving_launch: Vector3 = await launch_velocity(lab, 2, Vector3(3, 0, 4))
	check(Vector2(moving_launch.x, moving_launch.z).length() < 0.11, "Attack jump must remove almost all lateral takeoff speed")
	check(moving_launch.y > standing_launch.y, "Attack approach momentum must become additional upward lift")
	check(absf(moving_launch.x / moving_launch.z - 0.75) < 0.001, "Tiny residual Attack drift must preserve the approach direction")
	for action in [1, 3]:
		var still: Vector3 = await launch_velocity(lab, action, Vector3.ZERO)
		var moving: Vector3 = await launch_velocity(lab, action, Vector3(3, 0, 4))
		check(absf(Vector2(moving.x, moving.z).length() - 0.75) < 0.001, "Set/Block without held movement brake most lateral carry")
		check(absf(still.y - moving.y) < 0.001, "Set/Block must not receive the Attack momentum-to-lift conversion")
	print("STATION / APPROACH CHECKS: %d passed / %d total" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)

func jump_height(lab: Node3D, action: int, progress: float, distance: float) -> float:
	lab._reset()
	await settle(lab)
	lab.selected = action
	lab.motion.approach_action = action
	lab.motion.approach_distance = distance
	lab.motion.jump_charge = progress
	lab.motion.takeoff()
	return lab.motion.last_jump_height

func launch_velocity(lab: Node3D, action: int, velocity: Vector3) -> Vector3:
	lab._reset()
	await settle(lab)
	lab.selected = action
	lab.motion.approach_action = action
	lab.motion.approach_distance = 2.0
	lab.motion.jump_charge = 0.9
	lab.player.velocity = velocity
	lab.motion.takeoff()
	return lab.player.velocity
