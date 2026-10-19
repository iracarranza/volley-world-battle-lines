extends SceneTree
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
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.moc.enabled = false
	await physics_frame
	var drill = lab.station
	lab.player.position = drill.START
	drill.start()
	check(drill.LENGTH == 13 and drill.WIDTH == 6, "Original full dimensions restored")
	lab.player.position = Vector3(16, 0, 13.1)
	check(not drill.in_zone(), "Beyond original far edge is outside the drill")
	lab.player.position = drill.START
	for index in range(18):
		drill.serve()
		drill.tick(drill.TOSS_SECONDS)
		var target: Vector3 = lab.ball.position + lab.ball_velocity * drill.serve_duration + Vector3.DOWN * lab.GRAVITY * drill.serve_duration * drill.serve_duration * 0.5
		check(target.z > drill.HALF and target.z <= drill.LENGTH and target.x >= 13 and target.x <= 19, "All repeating serves target far half")
	check(drill.landing_points(Vector3(14, 0, 6)) == 1, "Left return quadrant scores one")
	check(drill.landing_points(Vector3(18, 0, 6)) == 2, "Far-right court quadrant scores two")
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
		drill.on_ball_down(Vector3(18, 0, 2.5))
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
	print("SERVE RECEIVE SCORING: %d / %d passed" % [checks-failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
