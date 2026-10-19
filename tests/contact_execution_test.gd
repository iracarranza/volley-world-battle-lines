extends SceneTree
const Geometry = preload("res://scripts/contact_geometry.gd")
const Execution = preload("res://scripts/contact_execution.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var sweet_points: Array[Vector3] = []
	for action in range(4):
		var shape: Dictionary = lab._raw_hurtbox_definition(action)
		var point: Vector3 = shape.center
		if action == 1:
			point.y += shape.radius * 0.5
		elif action == 2:
			point += Geometry.sector_point(shape, 0.74, 67.5, 0)
		elif action == 3:
			point.x += shape.column_x
		sweet_points.append(point)
		var spatial := Geometry.evaluate(shape, point)
		var fresh := Execution.assess(spatial, 0.22, false, action)
		var rescue := Execution.assess(spatial, 0.46, false, action)
		check(fresh.hit and fresh.sweet and not fresh.rescue, "Action %d initially awards spatial sweet contact" % action)
		check(rescue.hit and rescue.rescue and not rescue.sweet, "Action %d remains hittable after sweet expires" % action)
		check(not Execution.assess(spatial, 0.56).hit, "Action %d expires entirely" % action)
		check(not Execution.assess(spatial, 0.01, true).sweet, "Past overlap cannot retroactively become sweet")
		var incoming := Vector3(3, -7, 12)
		var outgoing := Vector3(1, 8, -9)
		var low := Execution.velocity(action, outgoing, incoming, Vector3.FORWARD, fresh, 10, Vector3(0, 8, -9))
		var high := Execution.velocity(action, outgoing, incoming, Vector3.FORWARD, fresh, 95, Vector3(0, 8, -9))
		match action:
			0: check(absf(high.x) < absf(low.x), "Timing stabilizes sweet receive toward intended flight")
			1: check(high.distance_to(outgoing) < low.distance_to(outgoing), "Timing improves sweet set precision")
			2: check(high.length() > low.length(), "Timing increases sweet spike power")
			3: check(high.y < low.y and absf(high.x) < absf(low.x), "Timing absorbs incoming block force and redirects down")
		if action in [0, 2]:
			var pushed := Execution.velocity(action, outgoing, incoming, Vector3.RIGHT, rescue, 99)
			check(pushed.x > 0 and absf(pushed.z) < 0.001 and pushed.length() < outgoing.length(), "Rescue is a weak facing-only push")
	lab._reset()
	lab.view_pitch = 0.27
	lab.aim = Vector3(0, 0, -10)
	lab.jumped = true
	var driven: Vector3 = lab._shot_velocity(Vector3(0, 4, 0), 2, 0.6)
	var old_speed := (6.0 + 0.6 * 7.0 + 65.0 * 0.02) * 1.5
	check(driven.length() > old_speed * 1.35, "Spike travels faster than former pushed trajectory")
	check(absf(rad_to_deg(atan2(driven.y, Vector2(driven.x, driven.z).length()))) < 4, "Neutral spike is a nearly level drive")
	var eight_meter_time := 8.0 / Vector2(driven.x, driven.z).length()
	check(0.5 * lab.GRAVITY * eight_meter_time * eight_meter_time < 0.7, "Driven spike has little gravity curvature across eight meters")
	lab.jumped = false
	var set_velocity: Vector3 = lab._shot_velocity(Vector3(0, 2.1, 0), 1, 0.6)
	var time_to_floor: float = (set_velocity.y + sqrt(set_velocity.y * set_velocity.y + 2 * lab.GRAVITY * (2.1 - 0.105))) / lab.GRAVITY
	var old_set: Dictionary = lab.Flight.solve_flight(5.5 + 0.6 * 4.5, 76, 2.1 - 0.105)
	check(Vector2(set_velocity.x, set_velocity.z).length() * time_to_floor > old_set.range_meters * 1.35, "Default set reaches farther")
	var former_rise: float = (maxf(2.45, lab._bump_ceiling(1.0)) - 2.1) * 1.12 * lerpf(0.65, 1.0, 0.6)
	check(set_velocity.y * set_velocity.y / (2 * lab.GRAVITY) < former_rise * 0.75, "Default set has a flatter lower arc")
	var rescue_receive := Execution.velocity(0, Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, {"rescue": true}, 65)
	check(is_equal_approx(rescue_receive.y, 6.0) and is_equal_approx(rescue_receive.z, -3.8), "Rescue receive has higher loft and retains forward speed")
	var spike: Dictionary = lab._raw_hurtbox_definition(2)
	var margin: Vector3 = spike.center + Geometry.sector_point(spike, 1.06, 67.5, 0)
	var margin_result := Execution.assess(Geometry.evaluate(spike, margin), 0.22, false, 2)
	check(margin_result.hit and not margin_result.rescue and not margin_result.sweet, "Moderate extra reach remains a non-sweet spike")
	var block: Dictionary = lab._raw_hurtbox_definition(3)
	check(block.column_x > block.column_radius, "Block columns have a physical gap")
	check(is_equal_approx(Geometry.BALL_RADIUS, 0.13125), "Ball contact radius is 25 percent larger")
	check(Geometry.evaluate(block, block.center + Vector3(block.column_x, block.size.y * 0.49, 0)).zone == "SOUR SPOT", "Block fingertips are sour")
	check(Geometry.evaluate(block, block.center + Vector3(block.column_x + block.column_radius * 0.95, 0, 0)).zone == "SOUR SPOT", "Block sides are sour")
	var set_shape: Dictionary = lab._raw_hurtbox_definition(1)
	check(Geometry.contains(set_shape, Vector3(0.2, lab.athlete.build.height * 0.78, 0)), "Shoulder-height sets connect")
	check(Geometry.evaluate(set_shape, Vector3(0, lab.athlete.build.height * 0.78, 0)).zone != "SWEET SPOT", "Low set extension is not sweet")
	for action in [0, 2]:
		for age in [0.22, 0.46]:
			lab._reset()
			lab.locked_action = action
			lab.selected = action
			lab.armed = true
			lab.ball_active = true
			lab.locked_charge = 0.6
			lab.facing_yaw = 0
			lab.aim = lab.player.position + Vector3(5, 1, -5)
			lab.ball.position = lab.player.position + sweet_points[action]
			lab.ball_velocity = Vector3(2, -5, 4)
			lab._confirm_action()
			lab.confirm_window = lab.confirm_duration - age
			lab._update_hurtbox_visual(0)
			check(lab.sweet_visual_expired == (age > Execution.SWEET_DELAY + Execution.sweet_seconds(action)), "Debug sweet state follows live window")
			lab._contact()
			check(lab.last_contact_result.rescue == (not Execution.sweet_active(action, age) and (action != 2 or age >= Execution.SPIKE_RESCUE_SECONDS)), "Actual contact records temporal rescue")
			if action == 0 and not Execution.sweet_active(0, age):
				check(absf(lab.ball_velocity.x) < 0.001 and lab.ball_velocity.z < 0, "Actual rescue ignores off-axis intended target")
	lab._reset()
	lab.locked_action = 0
	lab.armed = true
	lab.ball_active = true
	lab.ball.position = lab.player.position + sweet_points[0]
	lab._remember_contacts(0)
	lab.ball.position.x += 5
	lab._confirm_action()
	check(lab._contact_assessment(0).rescue and not lab._contact_assessment(0).sweet, "Late confirmation only rescues remembered contact")
	print("CONTACT EXECUTION: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
