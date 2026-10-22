extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func player_touch(lab: Node3D, action: int) -> void:
	lab.locked_action = action
	lab.selected = action
	lab.locked_charge = 0.61
	lab.armed = true
	lab.motion.jumped = false
	var shape: Dictionary = lab._hurtbox_definition(action)
	var point: Vector3 = shape.center
	lab.ball.position = lab.player.position + point.rotated(Vector3.UP, lab.camera_rig.facing_yaw)
	lab.ball_velocity = Vector3(0, -1, 0)
	lab.confirm_duration = lab.Execution.CONTACT_SECONDS
	lab.confirm_window = lab.Execution.CONTACT_SECONDS - 0.245
	lab._contact()
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	await physics_frame
	for home in [true, false]:
		lab._reset()
		var side := 0 if home else 1
		var sign_z := 1.0 if home else -1.0
		var opponent := "training_bot_7" if home else "training_bot_3"
		var blocker := "training_bot_3" if home else "training_bot_7"
		lab.player.position = Vector3(0, 0, 4 * sign_z)
		lab.camera_rig.facing_yaw = 0 if home else PI
		lab.camera_rig.view_yaw = lab.camera_rig.facing_yaw
		lab.camera_rig.update_aim()
		lab.ball_active = true
		lab.contacts = 3
		lab.side_contacts.assign([3, 3])
		# Resolve both touches inside the crossing clearance. No ball tick or
		# net-cross reset occurs between the opponent's attack and our block.
		lab.ball.position = Vector3(0, 3, 0.05 * sign_z)
		lab.ball_shot = {"kind":"attack","charge":0.6,"actor":opponent}
		lab._emit_external_impact(opponent, 2, Vector3.ZERO, {"hit":true,"quality":1.0})
		check(lab.side_contacts[side] == 0 and lab.contacts == 0, "Opponent attack renews our contacts before any net crossing")
		lab.ball_shot = {"kind":"block","charge":0.4,"actor":blocker}
		lab._emit_external_impact(blocker, 3, Vector3.ZERO, {"hit":true,"quality":1.0})
		check(lab.side_contacts[side] == 0, "Teammate block leaves all three contacts available")
		check(lab.rally_rules.last_touch_side == side, "Block still counts as last touch for point attribution")
		player_touch(lab, 0)
		check(lab.ball_active and lab.side_contacts[side] == 1, "Receive after teammate block is legal first contact")
		player_touch(lab, 1)
		player_touch(lab, 1)
		check(lab.ball_active and lab.side_contacts[side] == 3, "Two further contacts remain after the receive")
		player_touch(lab, 1)
		check(not lab.ball_active and "Three-contact" in lab.feedback, "Fourth ordinary team contact still faults")
	# A same-team touch does not manufacture a fresh allowance.
	lab._reset()
	lab.player.position = Vector3(0, 0, 4)
	lab.side_contacts.assign([2, 1])
	lab._emit_external_impact("training_bot_3", 3, Vector3.ZERO, {"hit":true,"quality":1.0})
	check(lab.side_contacts[0] == 2, "Same-side block does not erase its own existing contacts")
	lab.queue_free()
	await process_frame
	print("BLOCK FOLLOW-UP CONTACTS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
