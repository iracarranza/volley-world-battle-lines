extends SceneTree
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.auto_feed = false
	await physics_frame
	lab.view_pitch = 0.27 # Parallel to floor preserves calibrated arcs.
	var a = lab.athlete
	for build in a.BUILDS:
		a.build = build.duplicate()
		for height in [0.5, 1.0, 1.6]:
			var old_charge: float = 0.35 + float(build.power) / 250.0
			var old_distance: Dictionary = lab.Flight.solve_flight(5.0 + old_charge * 5.5, 60.0, height - 0.105)
			var old_launch: Dictionary = lab.Flight.solve_between(old_distance.range_meters, 76.0, height, 0.105)
			var old_upward := float(old_launch.required_speed_mps) * sin(deg_to_rad(76.0))
			var old_tap_peak: float = height + old_upward * old_upward / (2 * lab.GRAVITY)
			var full: Vector3 = lab._shot_velocity(Vector3(0, height, 5), 0, 1.0)
			var full_peak: float = height + full.y * full.y / (2 * lab.GRAVITY)
			var tapped: Vector3 = lab._shot_velocity(Vector3(0, height, 5), 0, old_charge)
			check(absf(full_peak - old_tap_peak) < 0.001, "Full bump must peak at exactly the former tapped bump height")
			check(tapped.y < full.y, "Recalibrated tapped bump must remain below the full-charge ceiling")
		var set_launch: Vector3 = lab._shot_velocity(Vector3(0, 2.1, 5), 1, 1.0)
		var set_peak: float = 2.1 + set_launch.y * set_launch.y / (2 * lab.GRAVITY)
		check(absf(set_peak - (2.1 + (lab._bump_ceiling(1.0) - 2.1) * lab.SET_RISE_FACTOR * lab.GROUND_SET_RISE_FACTOR)) < 0.001, "Full Set uses the flatter calibrated rise")
	lab.athlete.build = a.BUILDS[0].duplicate()
	lab._rebuild_visual()
	lab._reset()
	# The setter samples once, then hits that same descending-flight destination.
	lab.player.position = Vector3(2.4, 0, 4.2)
	lab.training_bots.toggle(1)
	var fixed: Vector3 = lab.training_bots.set_target
	lab.player.position = Vector3(-2, 0, 7)
	for contact_count in [0, 3, 8]:
		lab.training_bots.total_contacts = contact_count
		var origin := Vector3(-1, 2.25, 3)
		lab.ball.position = origin
		lab.training_bots._launch(1)
		var velocity: Vector3 = lab.ball_velocity
		var time: float = (velocity.y + sqrt(velocity.y * velocity.y + 2 * lab.GRAVITY * (origin.y - fixed.y))) / lab.GRAVITY
		var arrival: Vector3 = origin + velocity * time + Vector3.DOWN * lab.GRAVITY * time * time * 0.5
		check(arrival.distance_to(fixed) < 0.001, "Setter must repeat the captured destination despite player movement and contact count")
	lab.training_bots.toggle(1)
	lab._reset()
	var sector: Dictionary = lab._hurtbox_definition(2)
	check(sector.shape == "sector" and lab._hurtbox_definition(0).shape == "receive_fan" and lab._hurtbox_definition(3).shape == "block_columns", "Actions must use genuinely distinct geometric shapes")
	var samples := [{"r": 0.74, "angle": 67.5, "zone": "SWEET SPOT"}, {"r": 0.70, "angle": 35.0, "zone": "FAIR"}, {"r": 0.70, "angle": 115.0, "zone": "WEAK"}, {"r": 0.96, "angle": 67.5, "zone": "SOUR SPOT"}, {"r": 0.15, "angle": 67.5, "zone": "SOUR SPOT"}, {"r": 0.70, "angle": 5.0, "zone": "SOUR SPOT"}]
	var speeds: Array[float] = []
	for sample in samples:
		lab._reset()
		lab.athlete.build.accuracy = 99
		lab.armed = true
		lab.locked_action = 2
		lab.locked_charge = 0.6
		lab.ball_active = true
		lab.aim = Vector3(0, 0, -6)
		lab.facing_yaw = 0
		var point: Vector3 = sector.center + lab.Geometry.sector_point(sector, sample.r, sample.angle, 0)
		lab.ball.position = lab.player.position + point
		check(lab._can_contact(), "Ball inside every named spike zone must be hittable")
		lab._contact()
		var spatial: Dictionary = lab.Geometry.evaluate(sector, point)
		check(lab.last_quality == ("STRETCHED SPIKE" if spatial.get("rescue_only", false) else sample.zone), "Spike grading respects physical reach even at high ACC")
		speeds.append(lab.ball_velocity.length())
	check(speeds[0] > speeds[1] and speeds[1] > speeds[2] and speeds[1] > speeds[3], "Sweet, fair, weak and sour spots must produce strictly ordered output strength")
	check(speeds[3] < speeds[0] and speeds[4] < speeds[0] * 0.5, "Edge and base sour spots must produce genuinely weak contacts")
	lab._reset()
	lab.dominant_hand = "Right"
	var right: Dictionary = lab._hurtbox_definition(2)
	var right_sweet: Vector3 = right.center + lab.Geometry.sector_point(right, 0.74, 67.5, 0)
	lab.dominant_hand = "Left"
	var left: Dictionary = lab._hurtbox_definition(2)
	var left_sweet: Vector3 = left.center + lab.Geometry.sector_point(left, 0.74, 67.5, 0)
	check(absf(right_sweet.x + left_sweet.x) < 0.001 and absf(right_sweet.y - left_sweet.y) < 0.001, "Dominant arm must mirror both shoulder pivot and sweetspot")
	check(lab.Geometry.evaluate(left, left_sweet).zone == "SWEET SPOT", "Left dominant sweetspot must be authoritative")
	var old_radius: float = left.radius
	lab.athlete.build.span += 0.2
	lab._rebuild_visual()
	check(lab._hurtbox_definition(2).radius > old_radius, "Longer actual arm reach must increase sector radius")
	lab.dominant_hand = "Right"
	lab.athlete.build = a.BUILDS[0].duplicate()
	lab._rebuild_visual()
	for action in range(4):
		lab._reset()
		lab.locked_action = action
		lab.selected = action
		lab.armed = true
		lab.locked_charge = 0.4
		lab.ball_active = true
		var definition: Dictionary = lab._hurtbox_definition(action)
		lab.ball.position = lab.player.position + definition.center
		if action == 2:
			lab.ball.position += lab.Geometry.sector_point(definition, 0.74, 67.5, 0)
		lab._confirm_action()
		lab._contact()
		check(lab.selected == (action + 1) % 4, "Each successful rally contact must select the next action on the wheel")
		check(lab.locked_action == action and lab.hurtbox_action == action, "Auto-next selection must preserve the completed action and its lingering hurtbox")
	lab._reset()
	lab.player.position = Vector3(13, 0, 6)
	lab.station.start()
	lab.station.serve()
	lab.locked_action = 0
	lab.selected = 0
	lab.ball.position = lab.player.position + lab._hurtbox_definition(0).center
	lab._contact()
	check(lab.selected == 0 and lab.station.streak == 1, "Serve Receive drill must keep Receive selected despite successful contact")
	lab._reset()
	lab.jumped = true
	lab.airborne_action = 0
	lab.locked_action = 0
	lab._confirm_action()
	var dive_size: Vector3 = lab._hurtbox_definition(0).size
	lab.jumped = false
	check(lab._hurtbox_definition(0).size.is_equal_approx(dive_size), "Confirmed dive geometry must remain identical to the displayed volume through its landing follow-through")
	lab.confirm_window = 0
	check(lab._hurtbox_definition(0).size.y > dive_size.y, "Next grounded receive must use grounded geometry after the dive window ends")
	print("CONTACT ZONE CHECKS: %d passed / %d total" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
