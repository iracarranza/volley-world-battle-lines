extends "res://tests/support/test_case.gd"
const Clock := preload("res://scripts/moment_of_contact.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var clock := Clock.new()
	check(is_equal_approx(clock.charge_duration({"action":4,"charge":1}),0.1),"Standing serve has 100 ms MoC")
	for action in [0,2,3,5]:
		var field := "incoming_shot" if action in [0,5] else "outgoing_shot"
		check(is_equal_approx(clock.charge_duration({"action":action,field:{"kind":"attack","charge":1}}),0.4),"Full ball charge has 400 ms at stage %d"%action)
		check(is_equal_approx(clock.charge_duration({"action":action,field:{"kind":"attack","charge":0}}),0.05),"Minimum ball charge has 50 ms at stage %d"%action)
		check(is_equal_approx(clock.charge_duration({"action":action,field:{"kind":"attack","charge":0.5}}),0.225),"Half charge interpolates duration at stage %d"%action)
	check(is_equal_approx(clock.charge_duration({"action":0,"incoming_shot":{"kind":"serve","charge":1}}),0.1),"Receiving a serve uses its 100 ms profile")
	clock.free()
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	await physics_frame
	lab.moc.set_mode(Clock.Mode.TRAJECTORY_STEERING)
	lab.ball_active = true
	lab.ball.position = Vector3(2,0.11,5)
	lab.ball_velocity = Vector3(4,-12,-3)
	lab.ball_shot = {"kind":"attack","charge":1}
	lab._tick_ball(0.02)
	check(not lab.ball_active and lab.ground_balls.balls.size() == 1,"First floor contact ends rally once and starts a visible dead ball")
	check(lab.moc.active and is_equal_approx(lab.moc.last_event.duration_seconds,0.4),"Landing restarts charge-based slowdown after rally cleanup")
	var entry: Dictionary = lab.ground_balls.balls[0]
	check(entry.velocity.y > 0 and not lab.ball.visible,"Ground impact bounces upward without a duplicate live ball")
	lab.moc.set_mode(Clock.Mode.NONE)
	var start: Vector3 = entry.mesh.global_position
	for index in range(400): lab.ground_balls.tick(lab,0.01)
	check(entry.mesh.global_position.distance_to(start) > 0.5,"Dead ball continues moving after the rally")
	check(is_zero_approx(entry.velocity.y) and entry.velocity.length() < 0.1,"Bounces settle into a friction-damped roll")
	lab.ball_active = true
	lab.ball.position = Vector3(0,8,3)
	lab.ground_balls.tick(lab,0.01)
	check(lab.ground_balls.balls.size() == 1 and lab.ball.position == Vector3(0,8,3),"A new feed is independent of the old rolling ball")
	lab._reset()
	check(lab.ground_balls.balls.is_empty() and lab.ball.visible,"Reset removes dead balls and restores the playable ball")
	lab.queue_free()
	await process_frame
	print("MOC CHARGE / GROUND: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
