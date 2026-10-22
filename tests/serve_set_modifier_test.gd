extends "res://tests/support/test_case.gd"
const Hint = preload("res://scripts/trajectory_preview.gd")
func _initialize() -> void: call_deferred("run")
func prepare_set(lab: Node3D) -> void:
	lab._reset()
	lab.moc.enabled = false
	lab.auto_feed = false
	lab.selected = 1
	lab.locked_action = 1
	lab.locked_charge = 0.65
	lab.armed = true
	lab.ball_active = true
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.athlete.trait_ids.clear()
	prepare_set(lab)
	lab.toggle_modifier()
	check(not lab.back_set, "Without the Back Set Trait R does nothing")
	lab.athlete.trait_ids.assign(["accuracy_back_set"])
	var origin: Vector3 = lab.player.position + Vector3(0, 2.0, 0)
	lab.camera_rig.view_pitch = 0.27
	lab.camera_rig.update_aim()
	var front: Vector3 = lab._shot_velocity(origin, 1, 0.65)
	lab.toggle_modifier()
	check(lab.back_set, "With the Trait R switches to the back set")
	var back: Vector3 = lab._shot_velocity(origin, 1, 0.65)
	check(Vector2(back.x, back.z).normalized().dot(Vector2(front.x, front.z).normalized()) < -0.99, "The back set leaves in the opposite horizontal direction")
	check(absf(back.y - front.y) < 0.01, "A neutral front aim is a neutral back set")
	for raise in [0.3, -0.3]:
		lab.camera_rig.view_pitch = 0.27 + raise
		lab.back_set = false
		var high_front: Vector3 = lab._shot_velocity(origin, 1, 0.65)
		lab.back_set = true
		var inverse_back: Vector3 = lab._shot_velocity(origin, 1, 0.65)
		lab.camera_rig.view_pitch = 0.27 - raise
		lab.back_set = false
		var opposite_front: Vector3 = lab._shot_velocity(origin, 1, 0.65)
		check(absf(inverse_back.y - opposite_front.y) < 0.01, "A back set takes the inverse of the aimed offset (%+.1f)" % raise)
	lab.camera_rig.view_pitch = 0.27 + 0.4
	lab.back_set = false
	var high_front_set: Vector3 = lab._shot_velocity(origin, 1, 0.65)
	lab.back_set = true
	var low_back_set: Vector3 = lab._shot_velocity(origin, 1, 0.65)
	check(low_back_set.y < high_front_set.y, "A high front set is a low back set")
	check(lab._intent_direction(1, Vector3.FORWARD) == Vector3.BACK and lab._intent_direction(2, Vector3.FORWARD) == Vector3.FORWARD, "Steering a back set is relative to its travel; other actions are unaffected")
	# The preview shows the same backwards trajectory
	prepare_set(lab)
	lab.athlete.trait_ids.assign(["accuracy_back_set"])
	lab.camera_rig.view_pitch = 0.27
	lab.ball.position = lab.player.position + Vector3(0, lab.athlete.reach() - 0.1, -0.2)
	lab.ball_velocity = Vector3(0, -2, 1)
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration - 0.22
	var front_hint := Hint.predict(lab)
	lab.back_set = true
	var back_hint := Hint.predict(lab)
	check(not front_hint.is_empty() and not back_hint.is_empty() and back_hint.velocity.z * front_hint.velocity.z < 0, "The trajectory preview is shown backwards")
	lab._contact()
	check(not lab.back_set, "The back set is used up by the contact")
	prepare_set(lab)
	lab.back_set = true
	lab._reset()
	check(not lab.back_set, "Reset returns to the front set")
	# Float serve
	lab._reset()
	lab.athlete.trait_ids.clear()
	lab._serve()
	lab.toggle_modifier()
	check(not lab.serve.float_mode, "Without the Float Serve Trait R does not float a serve")
	lab.athlete.trait_ids.assign(["acc_float_serve"])
	lab.toggle_modifier()
	check(lab.serve.float_mode, "With the Trait R toggles the float serve")
	lab.toggle_modifier()
	check(not lab.serve.float_mode, "R toggles it back to topspin")
	lab.toggle_modifier()
	var shape: Dictionary = lab._raw_hurtbox_definition(2)
	var center: Vector3 = lab.serve.serve_center(shape)
	var results := {}
	for mode in [false, true]:
		lab._reset()
		lab.athlete.trait_ids.assign(["acc_float_serve"])
		lab.camera_rig.view_pitch = lab.NEUTRAL_VIEW_PITCH
		lab._serve()
		lab.serve.float_mode = mode
		lab.ball_velocity = Vector3.ZERO
		# A little off the centre: outside the topspin sweetspot, inside the float's larger one
		lab.ball.position = lab.player.position + (center + Vector3(0.18, 0, 0)).rotated(Vector3.UP, lab._contact_yaw())
		lab.serve.press()
		for frame in range(80):
			lab.ball_velocity = Vector3.ZERO
			lab._tick_ball(1.0 / 120)
			if lab.serve.state == lab.serve.State.FLIGHT:
				break
		results[mode] = lab.serve.evidence
	check(results[true].zone == "SWEET SPOT" and results[false].zone == "FAIR", "The float's sweetspot is larger")
	check(results[true].float and not results[false].float and results[true].wobble > 0.0, "A centred contact floats, with wobble set by its distance from the true centre")
	check(results[true].contact_factor < 1.0 and results[true].contact_factor >= 0.8 * 0.8, "A float serve costs pace")
	check(not lab.serve.float_mode, "The float choice is used up by the strike")
	lab.queue_free()
	await process_frame
	print("SERVE SET MODIFIER: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
