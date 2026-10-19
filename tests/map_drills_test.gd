extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func settle(lab: Node3D) -> void:
	for i in range(12):
		lab._physics_process(1.0 / 60)
		await physics_frame
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
# One attack-approach climb onto deck `index`: take the run-up along the deck below, charge an attack, hold the jump straight
# up through the deck above. Alternate directions so each deck is run from the end the last one finished at.
func landed(lab: Node3D) -> void:
	var still := 0
	for frame in range(240):
		lab._physics_process(1.0 / 60)
		await physics_frame
		if frame > 4 and lab.player.is_on_floor() and absf(lab.player.velocity.y) < 0.2:
			still += 1
			if still >= 4:
				return
		else:
			still = 0
func attack_climb(lab: Node3D, drills: Node3D, index: int, charge: float) -> void:
	var course: Array = drills.course_tops()
	var below_y: float = 0.0 if index == 0 else course[index - 1].y
	var run_dir := -1.0 if index % 2 == 0 else 1.0
	var start_z: float = drills.TOWER_Z - run_dir * (drills.DECK_SIZE.y * 0.5 - 0.3)
	lab.athlete.stamina = 100.0
	lab.athlete.exhausted = false
	lab.player.velocity = Vector3.ZERO
	lab.player.position = Vector3(drills.TOWER_X, below_y + 0.03, start_z)
	for i in range(8):
		lab._physics_process(1.0 / 60)
		await physics_frame
	lab.camera_rig.view_yaw = 0.0 if run_dir < 0.0 else PI
	lab.selected = 2
	lab.locked_action = 2
	lab.armed = true
	lab.locked_charge = 0.7
	key(KEY_W, true)
	await process_frame
	lab.motion.begin_jump()
	var released := false
	var took_off := false
	for frame in range(420):
		if not released and lab.motion.jump_charge >= charge:
			lab.motion.takeoff()
			released = true
		lab._physics_process(1.0 / 60)
		await physics_frame
		took_off = took_off or lab.motion.jumped
		if took_off and lab.player.is_on_floor() and not lab.motion.jumped:
			break
	key(KEY_W, false)
	await process_frame
	lab.armed = false
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await settle(lab)
	for action in range(4):
		lab._reset()
		await settle(lab)
		lab.armed = true
		lab.locked_action = action
		lab.locked_charge = 0.82
		lab.selected = (action + 1) % 4
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = true
		lab._unhandled_input(space)
		check(not lab.motion.generic_jump and lab.motion.approach_action == action, "Prepared action must choose its sporting approach without a live ball")
		lab.motion.jump_charge = 0.16 if action == 0 else 0.7
		lab.motion.takeoff()
		check(lab.motion.jumped and lab.motion.airborne_action == action and lab.locked_charge == 0.82, "Jump must retain prepared action and original charge")
		if action == 0:
			check(lab.confirm_window > 0 and lab.motion.last_jump_height < 0.4, "Charged Receive plus Space must auto-confirm a dive")
	lab._reset()
	await settle(lab)
	lab.selected = 0
	lab.charging = true
	lab.charge = 0.72
	lab.motion.begin_jump()
	check(lab.armed and not lab.charging and lab.motion.approach_action == 0 and lab.locked_charge == 0.72, "Space during mouse charge must commit and preserve the charge")
	lab._reset()
	lab.player.position = Vector3(13, 0.03, 6)
	lab.station.start()
	lab.station.serve()
	check(lab.station.state == lab.station.State.TOSS, "Drill telegraphs the toss before striking")
	lab.station.strike_feed()
	var velocity: Vector3 = lab.ball_velocity
	check(Vector2(velocity.x, velocity.z).length() > 12 and velocity.y < 3, "Receive feeds must be driven hard on a flat arc")
	var arrival: Vector3 = lab.ball.position + velocity * lab.station.serve_duration + Vector3.DOWN * lab.GRAVITY * lab.station.serve_duration * lab.station.serve_duration * 0.5
	check(arrival.distance_to(lab.station.TARGETS[0]) < 0.001, "Flatter serve retains intended receive destination")
	lab._reset()
	var drills = lab.drills
	lab.player.position = drills.BOX_START + Vector3.UP * 0.03
	await settle(lab)
	drills.start_box()
	var before: int = drills.earned_xp
	check(drills.box_state == drills.State.ACTIVE, "Box Jump starts only in its walkable course")
	# Execute the whole course with real release velocities, gravity and solid boxes.
	var course: Array = drills.course_tops()
	for index in range(course.size()):
		await attack_climb(lab, drills, index, float(drills.layer_charges[index]) + 0.03)
		await landed(lab)
	check(drills.box_state == drills.State.COMPLETE and drills.box_progress == course.size() and course.size() == 4, "All four layers must be physically reachable, each with an attack jump released at that layer's charge")
	check(drills.earned_xp == before + 35, "Box completion rewards once at the top")
	drills.tick(0.2)
	check(drills.earned_xp == before + 35, "Idle completion cannot duplicate rewards")
	lab._reset()
	lab.player.position = drills.SPIKE_START + Vector3.UP * 0.03
	await settle(lab)
	lab.camera_rig.view_pitch = -0.06 # Aim the driven spike downward into the floor target.
	drills.start_spike()
	check(drills.holding_ball() and lab.selected == 2, "Spike Trainer suspends an Attack-height ball")
	var held: Vector3 = lab.ball.position
	lab._tick_ball(0.5)
	check(lab.ball.position == held, "Suspended trainer ball remains fixed until confirmed contact")
	# Use the actual spike sector and shot flight; require airborne hit then target landing.
	before = drills.earned_xp
	for hit in range(3):
		var shape: Dictionary = lab._raw_hurtbox_definition(2)
		var local: Vector3 = shape.center + lab.Geometry.sector_point(shape, 0.74, 67.5, 0)
		lab.player.position = held - local
		lab.motion.jumped = true
		lab.motion.airborne_action = 2
		lab.motion.airborne_aim = Vector3.FORWARD
		lab.camera_rig.facing_yaw = 0
		lab.aim = drills.SPIKE_GOAL
		lab.locked_action = 2
		lab.locked_charge = 0.65
		lab.armed = true
		lab.elapsed += 1
		lab._contact()
		check(drills.spike_state == drills.State.RETURNING, "Successful airborne Attack releases suspended ball")
		for frame in range(600):
			if not lab.ball_active or drills.spike_state != drills.State.RETURNING:
				break
			lab._tick_ball(1.0 / 120)
		held = lab.ball.position
	check(drills.spike_state == drills.State.COMPLETE and drills.spike_progress == 3, "Three real spike trajectories into goal complete trainer")
	check(drills.earned_xp == before + 30, "Spike Trainer completion grants lab rewards")
	# Failure and retry paths must not grant completion rewards.
	lab.player.position = drills.BOX_START + Vector3.UP * 0.03
	lab.player.velocity = Vector3.ZERO
	lab.motion.jumped = false
	await settle(lab)
	drills.start_box()
	drills.box_progress = 2
	drills.tick(0.01)
	check(drills.box_state == drills.State.FAILED and drills.box_progress == 0, "Falling to ground loses the box sequence")
	lab.player.position = drills.SPIKE_START + Vector3.UP * 0.03
	await settle(lab)
	drills.start_spike()
	lab.motion.jumped = false
	drills.on_contact(2)
	check(drills.spike_state == drills.State.FAILED, "Grounded attacks cannot pass a jump-spike drill")
	drills.start_spike()
	lab.motion.jumped = true
	lab.motion.airborne_action = 2
	drills.on_contact(2)
	lab.ball.position = drills.SPIKE_GOAL + Vector3.RIGHT * 5
	drills.on_ball_down()
	check(drills.spike_state == drills.State.FAILED, "Missing the target fails the spike sequence")
	print("MAP DRILLS CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
