extends "res://tests/support/test_case.gd"
# The map graybox is the Contact Lab hosted on the planned map: the lab's systems stay live, the world under them is the map, the Drills
# sit on it, and the Contact Lab scene itself is untouched.
const Layout := preload("res://scripts/map_layout.gd")
func _initialize() -> void:
	call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func steps(lab: Node3D, count: int) -> void:
	for i in range(count):
		lab._physics_process(1.0 / 60)
		await physics_frame
func stand(lab: Node3D, position_in_world: Vector3) -> void:
	lab.player.velocity = Vector3.ZERO
	lab.player.position = position_in_world
	await steps(lab, 12)
func hit(lab: Node3D, from_point: Vector3, to_point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from_point, to_point, 3, [lab.player.get_rid()])
	return not lab.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func run() -> void:
	# The Contact Lab scene is untouched: still its own script, still its own blockout, no map.
	var plain = load("res://main.tscn").instantiate()
	check(plain.get_script().resource_path == "res://scripts/contact_lab.gd", "main.tscn is still the Contact Lab")
	check(plain.start_position == Vector3(0, 0.03, 5.0) and plain.station_origin == Vector3.ZERO and plain.box_origin == Vector3.ZERO and plain.spike_origin == Vector3.ZERO, "the Contact Lab keeps its own start and Drill positions")
	plain.free()
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	await steps(lab, 20)
	# It is the lab: the athlete, the creator, the bots, the Drills, the serve and Pepper machinery are all there.
	check(lab.get_script().get_base_script().resource_path == "res://scripts/contact_lab.gd", "the graybox script extends the Contact Lab")
	for system in ["athlete", "creator", "training_bots", "station", "drills", "serve", "pepper", "bench", "moc"]:
		check(lab.get(system) != null, "the graybox has the lab's %s" % system)
	check(lab.athlete.build.name != "" and lab.athlete.speed() > 5.0, "the lab's athlete model is in use (%s)" % lab.athlete.build.name)
	check(lab.player.position.distance_to(Vector3(0.0, 0.03, Layout.BASE_Z)) < 0.2 and lab.player.is_on_floor(), "the athlete starts on the Blue base, standing on the floor (%s)" % str(lab.player.position))
	check(lab.camera.current and not lab.overview_camera.current, "the game starts on the athlete's camera, not the overview")
	# The athlete walks with the lab's own movement.
	var start_z: float = lab.player.position.z
	lab.camera_rig.view_yaw = 0.0
	key(KEY_W, true)
	await process_frame
	await steps(lab, 45)
	key(KEY_W, false)
	await process_frame
	check(lab.player.position.z < start_z - 2.0, "the lab's movement walks the athlete toward the net (z %.1f to %.1f)" % [start_z, lab.player.position.z])
	# The Middle Net is the lab's own, at the origin, with the lab's court; the other four are the map's, at their own heights.
	check(hit(lab, Vector3(0, 2.0, -3), Vector3(0, 2.0, 3)), "the Middle Net has a physical webbing band at the origin")
	check(lab.court_half_width > 2.0 and lab.court_half_depth > 4.0, "the Middle Net uses the lab's court sizing (half width %.2f)" % lab.court_half_width)
	var heights := {}
	for net in Layout.nets():
		if net.id == "middle":
			continue
		var x: float = net.position.x
		var below: bool = hit(lab, Vector3(x, float(net.height) - 0.1, -3), Vector3(x, float(net.height) - 0.1, 3))
		var above: bool = hit(lab, Vector3(x, float(net.height) + 0.1, -3), Vector3(x, float(net.height) + 0.1, 3))
		check(below and not above, "%s has the authored net height %.2f m" % [net.id, net.height])
		heights[net.id] = net.height
	check(heights.top > heights.bottom and heights.pit_east == heights.pit_west, "the lane Nets differ in height and the Pit Nets are the standard")
	# The lab's blockout lanes are gone; the map's lanes are there.
	check(Layout.zone_at(Vector3(-36*Layout.SPACING, 0, 15*Layout.SPACING)).begins_with("TOP LANE") and lab.map_world != null and lab.map_world.get_child_count() > 100, "the map is built under the lab")
	# The three Drills sit on the map and work there.
	var drills = lab.drills
	await stand(lab, Vector3(drills.TOWER_X, 0.03, drills.TOWER_Z) + drills.box_anchor)
	check(drills.in_box_zone() and not drills.in_spike_zone() and not lab.station.in_zone(), "the Box Jump tower is beside the top lane and is its own zone (%s)" % Layout.zone_at(lab.player.position))
	drills.start_box()
	check(drills.box_state == drills.State.ACTIVE, "the tower starts where it now stands")
	# One real attack climb of the first layer, with the lab's own approach and jump.
	lab.athlete.stamina = 100.0
	lab.camera_rig.view_yaw = 0.0
	lab.selected = 2
	lab.locked_action = 2
	lab.armed = true
	lab.locked_charge = 0.7
	lab.player.position = Vector3(drills.TOWER_X, 0.03, drills.TOWER_Z + drills.DECK_SIZE.y * 0.5 - 0.3) + drills.box_anchor
	await steps(lab, 8)
	key(KEY_W, true)
	await process_frame
	lab.motion.begin_jump()
	var released := false
	var target: float = float(drills.layer_charges[0]) + 0.03
	for frame in range(300):
		if not released and lab.motion.jump_charge >= target:
			lab.motion.takeoff()
			released = true
		await steps(lab, 1)
		if released and lab.player.is_on_floor() and not lab.motion.jumped and drills.box_progress > 0:
			break
	key(KEY_W, false)
	await process_frame
	check(drills.box_progress >= 1, "the first layer of the tower is climbed with the lab's attack approach (progress %d)" % drills.box_progress)
	drills.reset()
	lab.armed = false
	# Spike Trainer: the ball is hung where the trainer now is.
	await stand(lab, drills.spike_start_world() + Vector3.UP * 0.03)
	check(drills.in_spike_zone() and not drills.in_box_zone(), "the Spike Trainer is outside the bottom lane (%s)" % Layout.zone_at(lab.player.position))
	drills.start_spike()
	check(drills.spike_state == drills.State.ACTIVE and lab.ball_active and lab.ball.position.distance_to(drills.spike_start_world()) < 20.0, "the Spike Trainer hangs its ball near the trainer, not at the old lab location (%s)" % str(lab.ball.position))
	drills.spike_state = drills.State.IDLE
	lab.ball_active = false
	# Serve Receive station in the east Blue jungle sector.
	var station = lab.station
	await stand(lab, station.start_world() + Vector3.UP * 0.03)
	check(station.in_zone() and Layout.zone_at(lab.player.position).contains("JUNGLE"), "the Serve Receive station is in the east Blue jungle (%s)" % Layout.zone_at(lab.player.position))
	station.start()
	station.state = station.State.WAITING
	station.force_next_feed = 0
	station.serve()
	check(lab.ball.position.distance_to(Vector3(16, 0, station.SERVE_BASELINE_Z) + station.origin) < 3.0, "the serve machine tosses from its new place (%s)" % str(lab.ball.position))
	station.strike_feed()
	var arrival: Vector3 = lab.ball.position + lab.ball_velocity * station.serve_duration + Vector3.DOWN * lab.GRAVITY * station.serve_duration * station.serve_duration * 0.5
	check(arrival.distance_to(station.target_world(0)) < 0.05, "the feed lands on the station's own target in the world (%s vs %s)" % [str(arrival), str(station.target_world(0))])
	var scoring_spot := Vector3(17.0, 0.0, 1.8)   # inside the 2-point quarter, in the station's own coordinates
	check(station.landing_points(scoring_spot + station.origin) == 2 and station.landing_points(scoring_spot) == 0, "scoring reads the court where the station is now, not where it used to be")
	station.stop()
	lab.ball_active = false
	# The overview.
	var event := InputEventKey.new()
	event.keycode = KEY_N
	event.physical_keycode = KEY_N
	event.pressed = true
	lab._unhandled_input(event)
	check(lab.overview and lab.overview_camera.current, "N shows the whole map")
	lab._unhandled_input(event)
	check(not lab.overview and lab.camera.current, "and N again returns to the athlete")
	print("MAP LAB CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
