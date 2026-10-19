extends "res://tests/support/test_case.gd"
# The box jump drill has two kinds of jumps: boxes 1-6 with ordinary exploration jumps and decks 7-9, behind steep
# slanted walls, that only an attack approach climbs. Every build must be able to do both, and an exploration jump
# must not reach the decks.
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _initialize() -> void:
	call_deferred("run")
func settle(lab: Node3D, frames: int = 10) -> void:
	for i in range(frames):
		lab._physics_process(1.0 / 60)
		await physics_frame
func refresh(lab: Node3D) -> void:
	lab.athlete.stamina = 100.0
	lab.athlete.hp = 100.0
	lab.athlete.exhausted = false
# A full-charge exploration jump straight up (no direction held, so a vertical takeoff).
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
# An attack jump up through layer `index` (0 is the first above the floor), run along the deck below and released at `charge`.
# With no `run_up` it stands still instead.
func attack_jump(lab: Node3D, drills: Node3D, index: int, charge: float, run_up: bool = true) -> void:
	refresh(lab)
	var course: Array = drills.course_tops()
	var below_y: float = 0.0 if index == 0 else course[index - 1].y
	var run_dir := -1.0 if index % 2 == 0 else 1.0
	var start_z: float = drills.TOWER_Z - run_dir * (drills.DECK_SIZE.y * 0.5 - 0.3)
	lab.player.velocity = Vector3.ZERO
	lab.player.position = Vector3(drills.TOWER_X, below_y + 0.03, start_z)
	await settle(lab, 8)
	lab.camera_rig.view_yaw = 0.0 if run_dir < 0.0 else PI
	lab.selected = 2
	lab.locked_action = 2
	lab.armed = true
	lab.locked_charge = 0.7
	if run_up:
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
	await landed(lab)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.auto_feed = false
	var drills = lab.drills
	var names := []
	for i in range(lab.athlete.BUILDS.size()):
		lab.athlete.build = lab.athlete.BUILDS[i].duplicate()
		var build_name: String = lab.athlete.build.name
		lab._reset()
		refresh(lab)
		lab.player.position = drills.BOX_START + Vector3.UP * 0.03
		await settle(lab, 12)
		drills.tick(0.0)
		var factors: Array = drills.LAYER_FACTORS
		var steps: Array = drills.layer_steps_for(lab.athlete)
		var charges: Array = drills.layer_charges
		# The charges go up and so do the heights they have to clear.
		var rising := true
		for k in range(1, charges.size()):
			rising = rising and float(charges[k]) > float(charges[k - 1]) + 0.04
		check(rising, "%s: each layer asks for a longer hold than the one before (%s)" % [build_name, str(charges.map(func(c): return snappedf(c, 0.01)))])
		drills.start_box()
		var course: Array = drills.course_tops()
		for k in range(course.size()):
			# Releasing at the previous layer's charge (or standing, for the first) falls short.
			if k == 0:
				await attack_jump(lab, drills, 0, 0.0, false)
			else:
				await attack_jump(lab, drills, k, float(charges[k - 1]))
			check(drills.box_progress == k, "%s: layer %d is not reached with the charge for the one before (progress %d)" % [build_name, k + 1, drills.box_progress])
			# Its own charge clears it.
			await attack_jump(lab, drills, k, float(charges[k]) + 0.03)
			check(drills.box_progress == k + 1, "%s: layer %d is reached at its own charge, %d%% of a full hold (progress %d)" % [build_name, k + 1, roundi(100.0 * float(charges[k]) / 0.91), drills.box_progress])
		check(drills.box_state == drills.State.COMPLETE and drills.box_progress == course.size(), "%s: all %d layers climbed" % [build_name, course.size()])
		await settle(lab, 20)
		check(lab.player.position.y > course[course.size() - 1].y - 0.2, "%s: the top deck holds the player up" % build_name)
		names.append(build_name)
	print("BOX JUMP ROUTES CHECKS: %d passed / %d total (%s)" % [checks - failures, checks, ", ".join(names)])
	quit(1 if failures > 0 else 0)
