extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.player.position = Vector3(15, 0.03, 20)
	for i in range(6):
		lab.player.velocity = Vector3.DOWN * 2
		lab.player.move_and_slide()
		await physics_frame
	lab.locked_action = 0
	lab.armed = true
	lab._confirm_action()
	check(lab.receive_planted(), "Receive confirmation plants grounded feet")
	var start: Vector3 = lab.player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	for frame in range(6):
		lab.motion.tick(1.0/60.0, 1.0)
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(Vector2(lab.player.position.x-start.x,lab.player.position.z-start.z).length() < 0.001, "Held movement shifts the platform without moving the planted athlete")
	check(lab.receive_plant.lean.x > 0.1, "Physical D input builds lateral lean")
	lab.receive_plant.lean = Vector2.ZERO
	var tilt: float = lab.hurtbox_pitch()
	var yaw: float = lab._contact_yaw()
	lab.camera_rig.view_pitch += 0.3
	lab.camera_rig.facing_yaw += 0.3
	check(lab.hurtbox_pitch() == tilt and lab._contact_yaw() == yaw, "Receive captures platform aim at input")
	var center: Vector3 = lab._hurtbox_definition(0).center
	var original: Vector3 = lab.hurtbox_center_local(center)
	lab.receive_plant.tick(0.2, Vector3(1,0,-1), true)
	var shifted: Vector3 = lab.hurtbox_center_local(center)
	check(shifted.distance_to(original) > 0.2, "Forward and side lean move the contact volume")
	var world: Vector3 = lab.player.position + shifted.rotated(Vector3.UP, yaw)
	check(lab.local_contact_position_at(world).distance_to(center) < 0.0001, "Collision and visible center share the lean transform")
	check(lab.contact_request(0).directional_input == Vector3.ZERO, "Precontact lean does not grant DI grading discounts")
	lab.receive_plant.tick(0.2, Vector3(0,0,1), true)
	check(lab.receive_plant.lean.y == 0, "S retracts forward lean to neutral")
	lab.receive_plant.contacted = true
	check(not lab.receive_planted(), "Impact releases the receive movement lock")
	var frozen: Vector2 = lab.receive_plant.lean
	lab.receive_plant.tick(0.1, Vector3.RIGHT, false)
	check(lab.receive_plant.lean == frozen, "Impact freezes platform lean for follow-through")
	lab.receive_plant.begin(yaw, tilt)
	lab.receive_plant.tick(0.4, Vector3.ZERO, true)
	lab.receive_plant.pose(lab.body)
	var arm: float = lab.arms[0].rotation.x
	lab.receive_plant.tick(0.4, Vector3.ZERO, false)
	lab.receive_plant.pose(lab.body)
	check(absf(lab.arms[0].rotation.x - arm) > 0.05, "No-ball receive completes its arm push and recovery")
	lab.receive_plant.tick(0.1, Vector3.ZERO, false)
	check(not lab.receive_plant.active(), "No-ball animation expires independently of contact")
	lab.locked_action = 2
	lab._confirm_action()
	check(not lab.receive_planted(), "Spike confirmation leaves movement available")
	lab.queue_free()
	await process_frame
	print("RECEIVE PLANT: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
