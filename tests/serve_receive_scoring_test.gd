extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.moc.enabled = false
	await physics_frame
	var drill = lab.station
	lab.player.position = drill.START
	drill.start()
	check(drill.LENGTH == 9 and drill.WIDTH == 6, "The pad is 9 m long, from the Net to the home endline")
	lab.player.position = Vector3(16, 0, 9.1)
	check(not drill.in_zone(), "Beyond original far edge is outside the drill")
	lab.player.position = drill.START
	for index in range(18):
		drill.serve()
		drill.tick(drill.TOSS_SECONDS)
		var target: Vector3 = lab.ball.position + lab.ball_velocity * drill.serve_duration + Vector3.DOWN * lab.GRAVITY * drill.serve_duration * drill.serve_duration * 0.5
		check(target.z > drill.HALF and target.z <= drill.LENGTH and target.x >= 13 and target.x <= 19, "All repeating serves target far half")
	check(drill.landing_points(Vector3(14, 0, 4)) == 1, "Left return quadrant scores one")
	check(drill.landing_points(Vector3(18, 0, 4)) == 1, "The near-right part of the scoring half now scores one")
	check(drill.landing_points(Vector3(18, 0, 2.2)) == 2 and drill.landing_points(Vector3(16.1, 0, 0.1)) == 2, "Far-right quadrant scores two")
	check(drill.landing_points(Vector3(18, 0, 2.3)) == 1 and drill.landing_points(Vector3(15.9, 0, 1)) == 1, "Outside the quadrant scores one")
	check(is_equal_approx(drill.TWO_LENGTH, drill.HALF * 0.5), "The +2 area is half as long as before")
	for point in [Vector3(18, 0, 8), Vector3(12.99, 0, 2), Vector3(19.01, 0, 2), Vector3(18, 0, -0.01)]:
		check(drill.landing_points(point) == 0, "Own half and out-of-bounds score zero")
	drill.start()
	drill.serve()
	drill.tick(drill.TOSS_SECONDS)
	drill.on_contact(0, false)
	check(drill.state == drill.State.RETURNING and drill.points == 0 and lab.ball_active, "Shank remains live and contact alone earns no points")
	drill.tick(4)
	check(drill.state == drill.State.RETURNING, "Long flight is not prematurely advanced")
	drill.on_ball_down(Vector3(18, 0, 8))
	check(drill.state == drill.State.WAITING and drill.points == 0, "Missed return target continues at zero points")
	for index in range(4):
		drill.serve()
		drill.tick(drill.TOSS_SECONDS)
		drill.on_contact(0, index != 0)
		drill.on_ball_down(Vector3(18, 0, 2.0))
		check(drill.points == (index + 1) * 2, "Landing scores exactly two even following shank")
	check(drill.state == drill.State.COMPLETE and drill.earned_xp == 25, "Eight points completes and awards once")
	drill.on_ball_down(Vector3(18, 0, 2))
	check(drill.earned_xp == 25 and drill.points == 8, "Duplicate ball-down cannot award again")
	drill.start()
	drill.serve()
	drill.tick(drill.TOSS_SECONDS)
	drill.on_contact(0)
	lab.ball.position = Vector3(14, 0.2, 2)
	lab.ball_velocity = Vector3(0, -4, 0)
	lab._tick_ball(0.05)
	check(drill.points == 1 and drill.state == drill.State.WAITING, "Real simulated floor landing scores")
	drill.serve()
	drill.tick(drill.TOSS_SECONDS)
	drill.on_ball_down()
	check(drill.state == drill.State.FAILED, "Untouched serve still ends attempt")
	# Height gate: crossing the half line below the barrier scores nothing
	drill.start()
	drill.serve()
	drill.tick(drill.TOSS_SECONDS)
	lab.ball.position = Vector3(18, 2.0, 5.2) + drill.origin
	drill.on_contact(0)
	check(drill.barrier != null and drill.barrier.get_child_count() > 0, "The red holographic barrier is built")
	drill.previous_ball = lab.ball.position
	lab.ball.position = Vector3(18, 1.6, 4.0) + drill.origin
	drill._track_height()
	check(drill.crossed and not drill.cleared and drill.cross_height < drill.CLEARANCE_HEIGHT, "A low receive is recorded as under the barrier (%.2f m)" % drill.cross_height)
	drill.on_ball_down(Vector3(18, 0, 2) + drill.origin)
	check(drill.last_points == 0, "A receive under the barrier scores nothing even in the +2 area")
	drill.state = drill.State.WAITING
	drill.timer = 0.0
	drill.serve()
	drill.tick(drill.TOSS_SECONDS)
	lab.ball.position = Vector3(18, 3.6, 5.2) + drill.origin
	drill.on_contact(0)
	drill.previous_ball = lab.ball.position
	lab.ball.position = Vector3(18, 3.4, 4.1) + drill.origin
	drill._track_height()
	check(drill.crossed and drill.cleared, "A receive over the barrier clears it (%.2f m)" % drill.cross_height)
	drill.on_ball_down(Vector3(18, 0, 2) + drill.origin)
	check(drill.last_points == 2, "A cleared receive scores in the +2 quadrant")
	drill.state = drill.State.WAITING
	drill.serve()
	drill.tick(drill.TOSS_SECONDS)
	lab.ball.position = Vector3(18, 1.0, 3.5) + drill.origin
	drill.on_contact(0)
	check(drill.crossed and not drill.cleared, "Received from inside the scoring half, the height at contact counts")
	# Feed order: a shuffled bag, never repeating until every spot has been served
	var order := []
	drill.start()
	drill.rng.seed = 12345
	for i in range(30):
		order.append(drill.next_feed())
		drill.serves_sent += 1
		drill.feed_index = order[i]
	for bag in range(5):
		var seen := order.slice(bag * 6, bag * 6 + 6)
		seen.sort()
		check(seen == [0, 1, 2, 3, 4, 5], "Every spot is served once in each run of six (run %d)" % bag)
	var repeats := 0
	for i in range(1, order.size()):
		if order[i] == order[i - 1]:
			repeats += 1
	check(repeats == 0, "No spot is ever served twice in a row, even across runs")
	check(order.slice(0, 6) != [0, 1, 2, 3, 4, 5] or order.slice(6, 12) != [0, 1, 2, 3, 4, 5], "The order is shuffled")
	drill.force_next_feed = 3
	check(drill.next_feed() == 3 and drill.force_next_feed == -1, "A test can force the next spot once")
	var nearest := 99.0
	for target in drill.TARGETS:
		nearest = minf(nearest, target.z)
		check(target.z > drill.HALF + 2.0 and target.z < drill.LENGTH, "Every serve spot is well back from the scoring half (z %.1f)" % target.z)
	print("SERVE RECEIVE SCORING: %d / %d passed" % [checks-failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
