extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	bots.actors[2].rotation.y = PI * 0.5
	bots._plan(2, Vector3(0, 3.5, 3), 1.2)
	var start_yaw: float = bots.actors[2].rotation.y
	bots.tick_motion(0.5)
	check(absf(wrapf(bots.actors[2].rotation.y - start_yaw, -PI, PI)) > 0.1, "Attacker orients during approach")
	bots.tick_motion(0.4)
	var committed: float = bots.actors[2].rotation.y
	check(bots.motion.plans[2].has("committed_yaw"), "Takeoff commits body facing")
	bots.motion.plans[2].aim_yaw = committed + 1.0
	bots.tick_motion(0.1)
	check(is_equal_approx(bots.actors[2].rotation.y, committed), "Airborne facing cannot turn to a new target")
	lab.ball.position = Vector3(0, 3.5, 3)
	bots.total_contacts = 5
	bots._launch(2)
	var outgoing_yaw := atan2(-lab.ball_velocity.x, -lab.ball_velocity.z)
	check(absf(wrapf(outgoing_yaw - committed, -PI, PI)) <= deg_to_rad(15.01), "Bot spike obeys player horizontal influence limit")
	check(absf(bots.rigs[2].body.get_node("Torso").rotation.y) <= deg_to_rad(7.51), "Swing pose reflects bounded shot direction")
	var station = lab.station
	lab.player.position = station.START
	station.start()
	for index in range(6):
		station.serves_sent = index
		station.serve()
		station.tick(station.TOSS_SECONDS)
		var origin: Vector3 = lab.ball.position
		var velocity: Vector3 = lab.ball_velocity
		var target: Vector3 = station.TARGETS[index]
		var arrival: Vector3 = origin + velocity * station.serve_duration + Vector3.DOWN * lab.GRAVITY * station.serve_duration * station.serve_duration * 0.5
		var net_time: float = -origin.z / velocity.z
		var net_height: float = origin.y + velocity.y * net_time - lab.GRAVITY * net_time * net_time * 0.5
		check(origin.z <= -10 and origin.y >= 3.5 and target.z - origin.z >= 15, "Jump feed starts beyond baseline at elevated contact height")
		check(Vector2(velocity.x, velocity.z).length() >= 22 and Vector2(velocity.x, velocity.z).length() <= 25.01, "Jump feed has driven jump-serve pace")
		check(net_height > 0.105, "Shortened off-court lane feed remains above ground at the old net plane")
		check(arrival.distance_to(target) < 0.001 and velocity.y - lab.GRAVITY * station.serve_duration < 0, "Jump feed descends through receive target")
	lab.player.position = Vector3(20, 0, 6)
	check(not station.in_zone(), "Serve Receive has narrower activation area")
	lab.player.position = Vector3(-20, 0, 10)
	check(not lab.drills.in_spike_zone(), "Spike Trainer has narrower activation area")
	lab.player.position = lab.drills.RUNWAY_START
	check(lab.drills.in_spike_zone(), "Approach runway start is inside trainer")
	lab.drills.start_spike()
	check(is_equal_approx(lab.ball.position.y, lab.athlete.reach() + 1.4), "Suspended spike ball is raised thirty centimeters")
	print("BOT FACING / DRILL LAYOUT: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
