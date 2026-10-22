extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.camera_rig.view_pitch = lab.NEUTRAL_VIEW_PITCH
	check(lab.hurtbox_pitch() == 0.0, "At the neutral view the hurtboxes are level")
	lab.ball.position = lab.player.position + Vector3(0.3, 1.8, -0.7).rotated(Vector3.UP, lab._contact_yaw())
	var level: Vector3 = lab._local_contact_position()
	lab.camera_rig.view_pitch = lab.NEUTRAL_VIEW_PITCH + 0.4
	check(is_equal_approx(lab.hurtbox_pitch(), 0.4), "Raising the aim tilts the hurtbox by the same angle")
	var tilted: Vector3 = lab._local_contact_position()
	check(tilted.distance_to(level) > 0.05, "A tilted hurtbox sees the same ball at a different place")
	for action in [0, 1, 2, 3]:
		var centre: Vector3 = lab._raw_hurtbox_definition(action).center
		lab.ball.position = lab.player.position + lab.hurtbox_center_local(centre).rotated(Vector3.UP, lab._contact_yaw())
		check(lab._local_contact_position().distance_to(centre) < 0.0001, "A ball at the tilted centre is at the centre of action %d" % action)
	lab.rotate_hurtboxes = false
	check(lab.hurtbox_pitch() == 0.0 and lab.hurtbox_center_local(Vector3(0, 1, -1)) == Vector3(0, 1, -1), "With the setting off the boxes stay level")
	lab.rotate_hurtboxes = true
	lab.camera_rig.view_pitch = 5.0
	check(lab.hurtbox_pitch() == lab.MAX_HURTBOX_PITCH, "The tilt is bounded")
	check(lab.hud.rotate_button != null and lab.hud.rotate_button.text.begins_with("TILT BOXES"), "The setting has a toolbar button")
	lab.hud.toggle_rotating_hurtboxes()
	check(not lab.rotate_hurtboxes and lab.hud.rotate_button.text.ends_with("OFF"), "The button turns it off")
	lab.queue_free()
	await process_frame
	print("HURTBOX TILT: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
