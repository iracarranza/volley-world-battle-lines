extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await physics_frame
	var bots = lab.training_bots
	bots.toggle(0, true)
	bots.toggle(3, true)
	for scenario in [[60, 6.0], [120, 6.0], [60, 24.0], [120, 24.0]]:
		var rate: int = scenario[0]
		lab._reset()
		lab.ball_active = true
		lab.ball.position = Vector3(0, 3.6, 2)
		lab.ball_velocity = Vector3(0, -5.0 if float(scenario[1]) > 6 else 0.0, -float(scenario[1]))
		bots.incoming_action = 2
		bots.replan()
		check(bots.active_action == 3, "Block attempts the incoming attack")
		# Deterministic positioning miss, independent of random tracking samples.
		bots.motion.plans[7].start.x += 4
		bots.motion.plans[7].ground.x += 4
		var fallback := false
		var received := false
		for frame in range(rate * 3):
			if not lab.ball_active:
				break
			lab._tick_ball(1.0 / rate)
			if not fallback and bots.active_action == 0 and bots.intercept.z < 0:
				fallback = true
				check(lab.side_contacts[1] == 0, "Missed block does not consume first touch")
			if bots.total_contacts > 0:
				received = bots.last_action == 0 and lab.ball.position.z < 0
				break
		check(fallback, "Missed block hands flight to away receiver")
		check(received and bots.total_contacts == 1 and lab.side_contacts[1] == 1, "Away receiver makes first real contact after block miss")
	print("BLOCK FALLBACK: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
