extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://drill_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.athlete.build["statistics"] = {}
	var migrated: Dictionary = preload("res://scripts/athlete_store.gd").migrate({"stat_version":3,"power":65,"statistics":{"core_strength":73}})
	check(migrated.statistics.core_strength == 73, "Core strength survives roster migration")
	var ladder = lab.activities.by_name.salmon_ladder
	lab.drills = ladder
	lab.player.position = ladder.anchor
	ladder.interact()
	lab.athlete.build.statistics.core_strength = 50
	check(ladder.attempt_quality(1, 0.25, 1) >= 0.88, "Base core can climb with a well-timed kip")
	check(ladder.attempt_quality(1, 1, 1) < 0.88, "An expired kip cannot propel the bar")
	var weak: float = ladder.attempt_quality(1, 0.5, 1)
	lab.athlete.build.statistics.core_strength = 99
	check(ladder.attempt_quality(1, 0.5, 1) > weak, "Core makes late releases more forgiving")
	ladder.pull = 1
	ladder.kip_power = 1
	ladder.kip_age = 0.25
	ladder.propel()
	check(ladder.steps_done == 0 and ladder.target_rung == 2, "Two-notch launch is pending until the bar actually catches")
	ladder.drill_motion(0.2, Vector3.ZERO)
	lab.animation.update()
	var hand: Vector3 = lab.arms[0].get_node("Elbow/Wrist").global_position
	check(absf(hand.y - ladder.bar.global_position.y) < 0.05, "Hanging hands remain on the animated bar")
	check(ladder.bar_height > 2.5, "The bar rises during the launch")
	ladder.drill_motion(ladder.FLIGHT_SECONDS, Vector3.ZERO)
	check(ladder.steps_done == 2 and is_equal_approx(ladder.bar_height, 3.5), "Successful catch physically seats the bar at notch two")
	ladder.drill_motion(1.01, Vector3.ZERO)
	ladder.pull = 0.1
	ladder.kip_power = 0
	ladder.propel()
	ladder.drill_motion(0.4, Vector3.ZERO)
	check(ladder.bar_height > 3.5 and ladder.bar_height < 4.0, "Failed launch visibly rises but falls short of the next notch")
	ladder.drill_motion(ladder.FLIGHT_SECONDS, Vector3.ZERO)
	check(ladder.steps_done == 2 and is_equal_approx(ladder.bar_height, 3.5), "Failed bar lands back on its old notch")
	ladder.reset()
	var slope = lab.activities.by_name.inclined_obstacles
	lab.drills = slope
	var midpoint: Vector3 = slope.footholds[1].lerp(slope.footholds[2], 0.5)
	lab.player.position = midpoint
	lab.athlete.build.statistics.explosiveness = 50
	lab.player.velocity = Vector3(0, 0, -2)
	slope.terrain_motion(0.1, Vector3.FORWARD, true)
	var slow: float = lab.player.velocity.z
	lab.athlete.build.statistics.explosiveness = 99
	lab.player.velocity = Vector3(0, 0, -2)
	slope.terrain_motion(0.1, Vector3.FORWARD, true)
	check(lab.player.velocity.z < slow, "Explosiveness improves uphill traction and speed")
	var before: float = lab.athlete.stamina
	lab.athlete.spend_resolved(2)
	check(is_equal_approx(before - lab.athlete.stamina, 10), "Uphill terrain multiplies every resolved stamina cost")
	lab.athlete.terrain_stamina_multiplier = 1
	lab.player.position.x += 2
	lab.player.velocity = Vector3(0, 0, -2)
	slope.terrain_motion(0.1, Vector3.FORWARD, true)
	check(lab.player.velocity.z > slow, "Leaving the route loses sprint grip")
	var spike = lab.activities.by_name.spike_trainer
	lab.drills = spike
	lab.armed = true
	lab.charging = true
	lab.charge = 0.72
	lab.locked_charge = 0.61
	spike.load_spike(true)
	spike.distributor.activate("player")
	lab.player.position = spike.spike_to_world(Vector3(0, 0, 30))
	spike._sync_parking()
	check(spike.parked and lab.charging, "Stepping off the runway parks the ball without clearing charge")
	lab.player.position = spike.spike_to_world(Vector3(-16, 0, 1.5))
	spike._sync_parking()
	check(not spike.parked, "Returning to the runway resumes the parked ball")
	check(lab.armed and lab.charging and lab.charge == 0.72 and lab.locked_charge == 0.61, "Resuming a parked spike preserves action preparation")
	var ball = lab.activities.by_name.balance_ball_setting
	lab.drills = ball
	lab.inventory.enabled = false
	lab.player.position = ball.anchor
	ball.interact()
	var yaw: float = lab.camera_rig.view_yaw
	ball.drill_motion(0.1, Vector3.ZERO)
	lab.camera_rig.update_aim()
	check(lab.camera_rig.view_yaw != yaw, "Gyroscopic rotation survives camera aim updates")
	ball.feed()
	ball.on_contact(1)
	lab.ball.position = ball.wall_target + Vector3(0, 0, -0.2)
	check(ball.sweep_ball(ball.wall_target + Vector3(0, 0, 0.2), 0.1) and ball.progress == 1, "A set crossing the wall target scores")
	ball.lean = Vector2(0.7, 0)
	ball.drill_motion(0.01, Vector3.ZERO)
	check(not ball.running() and not ball.mounted, "Excessive lean ends the non-economy attempt in a fall")
	ball.reset()
	check(ball.lean == Vector2.ZERO, "Reset removes ball lean")
	lab.queue_free()
	await process_frame
	print("DRILL MECHANICS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
