extends "res://tests/support/test_case.gd"
const Clock = preload("res://scripts/moment_of_contact.gd")
func _initialize() -> void:
	call_deferred("run")
func wait_real(seconds: float) -> void:
	var until := Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec() < until:
		await process_frame
func event(id: String,action: int,sweet: bool) -> Dictionary:
	return {"id":id,"action":action,"physical_hit":true,"sweet":sweet,"point":Vector3(0,2,5),"incoming_velocity":Vector3(0,0,30),"outgoing_velocity":Vector3(0,0,-30)}
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var clock = lab.moc
	for mode in [Clock.Mode.CURRENT_SLOWDOWN,Clock.Mode.TUNED_SLOWDOWN]:
		clock.set_mode(mode)
		for action in range(5):
			for sweet in [false,true]:
				clock.clear()
				var e := event("duration-%d-%d-%s" % [mode,action,sweet],action,sweet)
				var old_seconds := (0.18 if sweet else 0.14) if mode == Clock.Mode.CURRENT_SLOWDOWN else ((3.0/60 if action == 0 else 5.0/60) if sweet else 1.0/60)
				var expected := 0.0 if action == 1 else old_seconds+0.100
				var measured: float = Clock.duration_for(action,e.incoming_velocity,e.outgoing_velocity,sweet) if mode == Clock.Mode.CURRENT_SLOWDOWN else Clock.tuned_parts(e).total
				check(absf(measured-expected) < 0.000001,"Every non-Set duration is exactly previous tuning +100ms")
				var visual_count: int = lab.impact_visual.emitted
				clock.begin(e)
				check(absf(clock.last_event.duration_seconds-expected) < 0.000001,"Runtime event exposes expected duration")
				check(lab.impact_visual.emitted == visual_count+1,"Sets retain physical impact visuals")
				check(absf(clock.last_event.velocity_duration_seconds+clock.last_event.sweet_duration_seconds+clock.last_event.duration_extension_seconds-expected) < 0.000001,"Duration components remain additive")
				if action == 1:
					check(not clock.active and Engine.time_scale == 1 and clock.simulation_scale() > 0.0,"Even a sweet fast Set never starts either MoC mode")
				else:
					check(absf(float(clock._end_usec-clock._chain_start_usec)/1000000-expected) < 0.00001,"Increased caps do not clip the extra 100ms")
		clock.clear()
		clock.begin(event("timed-%d" % mode,2,true))
		var duration: float = clock.last_event.duration_seconds
		await wait_real(duration-0.025)
		check(clock.active,"Actual effect remains active until its extended real-time deadline")
		await wait_real(0.05)
		check(not clock.active and Engine.time_scale == 1,"Extended effect releases and restores time scale")
		clock.clear()
		clock.begin(event("anchor-%d" % mode,2,true))
		var end_before: int = clock._end_usec
		clock.begin(event("set-during-%d" % mode,1,true))
		check(not clock.active and clock._end_usec == 0 and Engine.time_scale == 1,"Set clears an existing MoC")
		clock.clear()
	for mode in [Clock.Mode.CURRENT_SLOWDOWN,Clock.Mode.TUNED_SLOWDOWN]:
		for airborne in [false,true]:
			lab._reset()
			clock.set_mode(mode)
			lab.ball_active = true
			lab.motion.jumped = airborne
			lab.motion.airborne_action = 1 if airborne else -1
			lab.player.position.y = 1.2 if airborne else 0.03
			lab.selected = 1
			lab.locked_action = 1
			lab.locked_charge = 0.65
			lab.armed = true
			var shape: Dictionary = lab._raw_hurtbox_definition(1)
			lab.ball.position = lab.player.position+shape.center+Vector3.UP*float(shape.radius)*0.5
			lab.ball_velocity = Vector3(0,-5,15)
			lab._confirm_action()
			lab.confirm_window = lab.confirm_duration-0.22
			lab._contact()
			check(lab.last_contact_result.sweet and not clock.active and clock.last_event.duration_seconds == 0,"Actual sweet ground/jump Sets have no MoC in either mode")
		lab._reset()
		clock.set_mode(mode)
		var bots = lab.training_bots
		bots.settings[1].enabled = true
		bots.settings[1].contact_order = 1
		lab.ball_active = true
		lab.ball.position = Vector3(0,2.25,5)
		lab.ball_velocity = Vector3(0,-1,0)
		bots._plan(1,lab.ball.position,0.01)
		check(bots.tick(0.02) and clock.last_event.action == 1 and not clock.active,"Actual bot Set also has no MoC")
		bots.settings[1].enabled = false
	check(Clock.tuned_parts({"action":2,"physical_hit":true,"incoming_velocity":Vector3.ZERO,"outgoing_velocity":Vector3.UP}).total == 0,"Previously zero-hold soft contacts remain zero")
	print("MOC DURATION EXTENSION: %d / %d passed" % [checks-failures,checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
