extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var drills = lab.drills
	lab.player.position = drills.SPIKE_START + Vector3(0, 0.03, 0)
	drills.start_spike()
	check(drills.spike_state == drills.State.ACTIVE, "The Spike Trainer starts")
	check(absf(lab.ball.position.z - 0.5) < 0.001 and lab.ball.position.z > 0.0, "The ball hangs half a metre from the Net on the home side (z %.2f)" % lab.ball.position.z)
	check(drills.RUNWAY_END.z > 0.5 and drills.RUNWAY_END.z < 2.0 and drills.RUNWAY_START.z > drills.RUNWAY_END.z, "The approach guide runs up to just short of the ball")
	check(drills.SPIKE_START.z >= drills.RUNWAY_END.z and drills.in_spike_zone(), "The start is on the guide, inside the trainer")
	# The small circle sits inside the gold one, and moves
	var seen := {}
	for i in range(30):
		drills.move_bonus_circle()
		var centre: Vector2 = drills.spike_bonus_center
		var from_goal := centre.distance_to(Vector2(drills.SPIKE_GOAL.x, drills.SPIKE_GOAL.z))
		check(from_goal + drills.BONUS_RADIUS <= drills.GOAL_RADIUS + 0.001, "The small circle always fits inside the gold circle (%.2f)" % from_goal)
		seen[snappedf(centre.x, 0.01)] = true
	check(seen.size() > 10, "The small circle changes place")
	check(drills.spike_bonus.visible, "It is shown while the drill runs")
	# Landing in it is worth one more point
	drills.spike_points = 0
	drills.spike_progress = 0
	drills.start_spike()
	drills.spike_state = drills.State.RETURNING
	lab.ball.position = Vector3(drills.spike_bonus_center.x, 0.1, drills.spike_bonus_center.y) + drills.spike_anchor
	drills.on_ball_down()
	check(drills.spike_points == 2 and drills.spike_progress == 1, "Landing in the small circle scores two (gold circle and the bonus)")
	drills.spike_state = drills.State.RETURNING
	var centre: Vector2 = drills.spike_bonus_center
	var away: Vector2 = Vector2(drills.SPIKE_GOAL.x, drills.SPIKE_GOAL.z) + (Vector2(drills.SPIKE_GOAL.x, drills.SPIKE_GOAL.z) - centre).normalized() * (drills.GOAL_RADIUS - 0.1)
	lab.ball.position = Vector3(away.x, 0.1, away.y) + drills.spike_anchor
	var in_gold_only: bool = away.distance_to(centre) > drills.BONUS_RADIUS
	drills.on_ball_down()
	check(not in_gold_only or drills.spike_points == 3, "Landing in the gold circle only scores one")
	print("SPIKE TRAINER: %d checks" % checks)
	quit(1 if failures > 0 else 0)
