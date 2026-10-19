extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func event(recovery: String, x: float = 0.0, factor: float = 1.0) -> Dictionary:
	return {"actor": "player", "recovery": recovery, "recovery_seconds": 0.95, "recovery_penalty_seconds": 0.25 * factor, "receive_outcome": {"platform_coord": Vector3(x, 0, 0), "penalty_factor": factor}}
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.auto_feed = false
	lab.animation.pose_smoothing = false
	await physics_frame
	lab.player.position = Vector3(0, 0.03, 6)
	for name in ["knee", "knocked_away", "collapse", "blown_away", "shrug"]:
		lab.animation.floor_recovery_time = -1.0
		lab.receive_resolved.emit(event(name, 0.5))
		check(lab.animation.floor_recovery_time == 0.0 and lab.animation.floor_recovery_name == name, "%s starts on the event" % name)
		var start: Vector3 = lab.player.position
		var locked_seen := false
		var steps := 0
		while lab.animation.floor_recovery_time >= 0.0 and steps < 400:
			locked_seen = locked_seen or lab.animation.floor_input_locked()
			lab._physics_process(1.0 / 60.0)
			lab.animation.update()
			steps += 1
		check(lab.animation.floor_recovery_time < 0.0, "%s ends" % name)
		check(locked_seen, "%s locks input at first" % name)
		var expected: float = load("res://scripts/floor_recovery.gd").duration(name)
		check(absf(steps / 60.0 - expected) < 0.1, "%s lasts its VWM time (%.2f vs %.2f)" % [name, steps / 60.0, expected])
		var moved: Vector3 = lab.player.position - start
		if name == "blown_away" or name == "shrug":
			check(moved.z > 0.1, "%s staggers back (%.2f)" % [name, moved.z])
		if name == "collapse":
			check(moved.z < -0.3 and moved.x > 0.1, "%s goes forward, leaning to the contact side (%.2f, %.2f)" % [name, moved.z, moved.x])
		if name == "knocked_away":
			check(moved.z > 0.1 and moved.x < -0.05, "%s steps back and away from the contact side (%.2f, %.2f)" % [name, moved.z, moved.x])
	# Ignored cases
	lab.receive_resolved.emit(event(""))
	check(lab.animation.floor_recovery_time < 0.0, "No recovery, no playback")
	var bot := event("knee")
	bot.actor = "training_bot_1"
	lab.receive_resolved.emit(bot)
	check(lab.animation.floor_recovery_time < 0.0, "Bots do not move the player")
	lab.motion.jumped = true
	lab.receive_resolved.emit(event("knee"))
	check(lab.animation.floor_recovery_time < 0.0, "No floor recovery in the air")
	lab.motion.jumped = false
	lab.receive_resolved.emit(event("knee", 0.0, 0.65))
	var fast: float = lab.animation.floor_recovery_total()
	lab.animation.floor_recovery_time = -1.0
	lab.receive_resolved.emit(event("knee", 0.0, 1.35))
	check(lab.animation.floor_recovery_total() > fast * 1.9, "Helpful DI shortens and contrary DI stretches the recovery")
	print("floor_recovery_lab: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
