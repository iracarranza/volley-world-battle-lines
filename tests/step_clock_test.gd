extends "res://tests/support/test_case.gd"
## The step clock record equals the scales MoC produced before the record existed, in every mode and toggle; it is immutable.
const Clock := preload("res://scripts/moment_of_contact.gd")
var now := 1000000

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var moc = lab.moc
	moc.clock = func(): return now
	for mode in [Clock.Mode.CURRENT_SLOWDOWN, Clock.Mode.TUNED_SLOWDOWN, Clock.Mode.TRAJECTORY_STEERING, Clock.Mode.NONE]:
		for toggles in [[true, true], [true, false], [false, true], [false, false]]:
			lab._reset()
			moc.set_mode(mode)
			moc.affect_ball = toggles[0]
			moc.affect_actor = toggles[1]
			moc.begin({"id": "m%d%s" % [mode, toggles], "actor": "training_bot_2", "action": 2, "physical_hit": true, "outgoing_velocity": Vector3(0, 8, -10), "incoming_velocity": Vector3(0, -6, 24)})
			now += 30000
			var effect: float = moc._effect_scale()
			var expected_ball: float = effect if toggles[0] else 1.0
			var record = moc.clock_record()
			var label := "mode %d toggles %s" % [mode, toggles]
			check(is_equal_approx(record.ball(), expected_ball), "Ball scale matches (%s)" % label)
			check(is_equal_approx(record.actor("training_bot_2"), effect if toggles[1] and moc.acting_actor == "training_bot_2" else 1.0), "Acting actor scale matches (%s)" % label)
			check(record.actor("player") == 1.0, "Other actors keep full speed (%s)" % label)
			check(is_equal_approx(record.bot("training_bot_2"), minf(expected_ball, record.actor("training_bot_2"))), "Bot scale is the slower of ball and actor (%s)" % label)
			check(is_equal_approx(record.real_now(), float(now) / 1000000.0), "real_now is the injected real clock (%s)" % label)
			check(record.ball() == moc.simulation_scale() and record.actor("training_bot_2") == moc.actor_scale("training_bot_2") and record.bot("training_bot_2") == moc.bot_scale("training_bot_2"), "The wrappers read the record (%s)" % label)
			var ball: float = record.ball()
			var bot: float = record.bot("training_bot_2")
			now += 2000000
			moc.clear()
			check(record.ball() == ball and record.bot("training_bot_2") == bot, "A record does not change after MoC moves on (%s)" % label)
	print("STEP CLOCK: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
