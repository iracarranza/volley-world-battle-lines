extends "res://tests/support/test_case.gd"
const Aim := preload("res://scripts/bot_aim.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1234
	var origin := Vector3(0, 3, 0)
	var base := Vector3(0, -2, -20)
	var random_before := random.state
	var perfect := Aim.apply(origin, base, 100, 9.81, random)
	check(perfect.velocity == base and perfect.offset == Vector3.ZERO and random.state == random_before, "100% adds no scatter and consumes no random samples")
	var scatter_total := Vector2.ZERO
	for index in range(40):
		var error := Aim.apply(origin, base, 0, 9.81, random)
		check(Vector3(error.offset).length() <= 2.5001 and error.velocity.y == base.y, "Aim scatter is bounded and preserves vertical flight")
		scatter_total += Vector2(absf(error.offset.x), absf(error.offset.z))
	check(scatter_total.x > 1 and scatter_total.y > 1, "Low accuracy produces both lateral and depth error")
	random.seed = 42
	var half := Aim.apply(origin, base, 50, 9.81, random)
	random.seed = 42
	var none := Aim.apply(origin, base, 0, 9.81, random)
	check(Vector3(half.offset).distance_to(Vector3(none.offset) * 0.5) < 0.001, "Intermediate slider scales error continuously")
	var toward_setter := Aim.apply(origin, Vector3(8, 6, 0), 0, 9.81, random, true)
	check(toward_setter.velocity.x > 0 and absf(toward_setter.velocity.z) < 0.001, "Setter-directed receives keep heading and vary depth")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	bots.enabled[1] = true
	bots.contact_order[1] = 1
	var outputs: Array[Vector3] = []
	for rating in [100.0, 0.0]:
		lab._reset()
		bots.set_aiming_accuracy(1, rating)
		bots.aim_random.seed = 42
		lab.ball_active = true
		lab.ball.position = Vector3(0, 2.25, 5)
		lab.ball_velocity = Vector3(0, -1, 0)
		bots._plan(1, lab.ball.position, 0.01)
		var position_before: Vector3 = bots.actors[1].position
		var plan_before: float = bots.remaining
		bots.set_aiming_accuracy(1, rating)
		check(bots.actors[1].position == position_before and bots.remaining == plan_before, "Changing aiming accuracy does not replan or reposition")
		check(bots.tick(0.02) and bots.last_action == 1, "Actual setter contact resolves with aim setting")
		outputs.append(lab.ball_velocity)
	check(outputs[0].distance_to(outputs[1]) > 0.1 and outputs[0].y == outputs[1].y, "Actual bot contact applies shot scatter independently of arc")
	check(bots.tracking_accuracy[1] == 100 and bots.physique.build.accuracy == 65, "Aim slider does not change tracking or athlete Accuracy")
	bots.reset()
	check(bots.aiming_accuracy[1] == 0, "Aim settings persist across reset")
	bots.set_aiming_accuracy(1, -20)
	bots.set_aiming_accuracy(5, 120)
	check(bots.aiming_accuracy[1] == 0 and bots.aiming_accuracy[5] == 100, "Independent home/away settings clamp safely")
	lab.pepper.set_aiming_accuracy(0, 30)
	check(lab.pepper.aiming_accuracy[0] == 30 and lab.pepper.aiming_accuracy[1] == 100, "Pepper partners have separate aiming settings")
	print("BOT AIMING ACCURACY: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
