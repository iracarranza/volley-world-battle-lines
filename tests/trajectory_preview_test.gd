extends "res://tests/support/test_case.gd"
const Hint = preload("res://scripts/trajectory_preview.gd")
func _initialize() -> void:
	call_deferred("run")
func ready(lab: Node3D,action: int) -> void:
	lab._reset()
	lab.auto_feed = false
	lab.moc.enabled = false
	lab.athlete.trait_ids.clear()
	lab.selected = action
	lab.locked_action = action
	lab.locked_charge = 0.65
	lab.armed = true
	lab.ball_active = true
	lab.rotate_hurtboxes = false # these cases place the ball in the level box; tilting is covered by hurtbox_tilt_test
	lab.camera_rig.view_pitch = 0.27
	lab.camera_rig.update_aim()
	var shape: Dictionary = lab._raw_hurtbox_definition(action)
	var point: Vector3 = shape.center
	if action == 1:
		point.y += float(shape.radius)*0.5
	elif action == 2:
		point += lab.Geometry.sector_point(shape,0.74,67.5,0)
	elif action == 3:
		point = Vector3(shape.hand_x,shape.palm,shape.center.z)
	lab.ball.position = lab.player.position+point
	lab.ball_velocity = Vector3(2,-4,8)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	for action in range(4):
		ready(lab,action)
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration-0.22
		var hp: float = lab.athlete.hp
		var stamina: float = lab.athlete.stamina
		var incoming: Vector3 = lab.ball_velocity
		var events: int = lab._contact_event_serial
		var hint := Hint.predict(lab)
		check(not hint.is_empty() and hint.contact_ready, "Charged nearby action previews actual contact geometry")
		check(hint.points[0] == lab.ball.position and hint.origin == lab.ball.position, "Hint starts at ball rather than synthetic hand")
		check(hint.duration <= hint.full_flight_time*0.35+0.00001 and hint.duration <= 0.70, "Hint only shows initial fraction of flight")
		check(lab.athlete.hp == hp and lab.athlete.stamina == stamina and lab.ball_velocity == incoming and lab._contact_event_serial == events, "Prediction never mutates live gameplay")
		lab._update_preview()
		check(lab.preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > hint.points.size()*3, "Preview uses visible ribbon geometry")
		lab._contact()
		check(lab.ball_velocity.distance_to(hint.velocity) < 0.0001, "Preview matches actual ideal contact flight for action %d" % action)
	ready(lab,1)
	var level := Hint.predict(lab)
	lab.camera_rig.view_pitch += 0.6
	var high := Hint.predict(lab)
	check(high.velocity.y > level.velocity.y, "Camera ascent changes predicted set arc")
	lab.camera_rig.view_yaw += 0.5
	lab.camera_rig.update_aim()
	var turned := Hint.predict(lab)
	check(turned.velocity.distance_to(high.velocity) > 0.3, "Current camera/player facing changes live hint")
	ready(lab,2)
	var center: Vector3 = lab.ball.position
	lab.ball.position.x += 0.17
	var right := Hint.predict(lab)
	lab.ball.position = center-Vector3.RIGHT*0.17
	var left := Hint.predict(lab)
	check(right.velocity.x > 0 and left.velocity.x < 0, "Spike intersection side changes predicted swing direction")
	lab.ball.position = center
	lab.locked_charge = 0.2
	var low := Hint.predict(lab)
	lab.locked_charge = 1
	var full := Hint.predict(lab)
	check(full.velocity.length() > low.velocity.length(), "Current spike charge changes preview pace")
	lab.directional_input.sample(Vector3.RIGHT,0.08)
	check(Hint.predict(lab).velocity.distance_to(full.velocity) > 0.1, "Buffered directional influence appears in hint")
	ready(lab,0)
	lab.ball.position.x += 0.6
	var side_receive := Hint.predict(lab)
	check(side_receive.velocity.x > 0, "Receive platform intersection deflects hint")
	lab.ball.position = lab.player.position+Vector3(0,1,1)
	check(Hint.predict(lab).is_empty(), "No impossible backward receive hint")
	ready(lab,1)
	lab.ball.position = lab.player.position+Vector3(0,3.8,-0.5)
	var hovering := Hint.predict(lab)
	check(not hovering.is_empty() and not hovering.contact_ready, "Nearby ball outside reach gets a hypothetical hint")
	lab.ball.position += Vector3.RIGHT*20
	check(Hint.predict(lab).is_empty(), "Far ball hides preview")
	ready(lab,0)
	lab.armed = false
	check(Hint.predict(lab).is_empty(), "No preparation hides preview")
	lab.charging = true
	lab.charge = 0.5
	check(not Hint.predict(lab).is_empty(), "Preview updates while charging")
	lab.ball_active = false
	check(Hint.predict(lab).is_empty(), "No ball hides preview")
	ready(lab,0)
	lab.serve.state = lab.serve.State.TOSS
	check(Hint.predict(lab).is_empty(), "Serving toss does not show unrelated receive trajectory")
	lab.serve.clear()
	lab.hud.toggle_debug_volumes()
	lab._update_preview()
	check(lab.preview.mesh != null, "Contact hint remains with debug hurtboxes hidden")
	lab.bench.enter()
	check(Hint.predict(lab).is_empty(), "Benched athlete has no action preview")
	print("TRAJECTORY PREVIEW: %d / %d passed" % [checks-failures,checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
