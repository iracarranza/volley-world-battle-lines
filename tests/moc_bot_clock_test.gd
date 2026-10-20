extends "res://tests/support/test_case.gd"
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
	check(is_equal_approx(moc.steering_speed,0.05) and is_equal_approx(moc.steering_duration,0.4),"Preferred 5 percent / charge-scaled 400 ms maximum")
	for mode in [Clock.Mode.CURRENT_SLOWDOWN,Clock.Mode.TUNED_SLOWDOWN,Clock.Mode.TRAJECTORY_STEERING,Clock.Mode.NONE]:
		lab._reset()
		moc.set_mode(mode)
		lab.ball_active = true
		lab.ball.position = Vector3(0,10,5)
		lab.ball_velocity = Vector3(0,0,-20)
		moc.begin({"id":"mode%d"%mode,"actor":"player","action":2,"physical_hit":true,"outgoing_velocity":lab.ball_velocity,"incoming_velocity":Vector3(0,0,20)})
		now += 100000
		var scale: float = moc.simulation_scale()
		var bots = lab.training_bots
		bots.settings[0].enabled = true
		bots.preparation.begin(0,0,{"kind":"serve","charge":0.6},1,100,bots.charge_random)
		bots.motion.begin(0,bots.actors[0],Vector3(0,1,3),1,false,lab.GRAVITY)
		bots.active_action = 0
		bots.active_slot = 0
		bots.remaining = 1
		bots.tick_motion(0.1)
		bots.tick_contact(0.1)
		check(is_equal_approx(bots.motion.plans[0].elapsed,0.1*scale),"Court bot jump follows ball clock in mode %d"%mode)
		check(is_equal_approx(bots.preparation.state_for(0).elapsed,0.1*scale),"Court bot charging follows ball clock in mode %d"%mode)
		check(is_equal_approx(bots.remaining,1-0.1*scale),"Court contact countdown follows ball clock in mode %d"%mode)
		var pepper = lab.pepper
		pepper.partner = 0
		pepper.npc_turn = true
		pepper.planned = true
		pepper.stage = 0
		pepper.remaining = 1
		pepper.point = pepper.actors[0].position
		pepper.move_target = pepper.actors[0].position
		pepper.preparation.begin(0,0,{"kind":"serve","charge":0.6},1,100,pepper.charge_random)
		pepper.tick(0.1)
		check(is_equal_approx(pepper.remaining,1-0.1*scale) and is_equal_approx(pepper.preparation.state_for(0).elapsed,0.1*scale),"Pepper motion/contact and charging share ball clock in mode %d"%mode)
		check(Engine.time_scale == 1,"World clock remains normal")
	moc.clear()
	moc.set_mode(Clock.Mode.TUNED_SLOWDOWN)
	moc.affect_ball = false
	moc.begin({"id":"actor-only","actor":"training_bot_0","action":2,"physical_hit":true})
	check(is_equal_approx(moc.bot_scale("training_bot_0"),0.1) and moc.bot_scale("training_bot_1") == 1,"Actor-only toggle slows just the contacting bot")
	moc.clear()
	check(moc.bot_scale("training_bot_0") == 1,"Effect expiry restores bot speed")
	lab.queue_free()
	await process_frame
	print("MOC BOT CLOCK: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
