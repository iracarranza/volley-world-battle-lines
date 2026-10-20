extends "res://tests/support/test_case.gd"
const Clock = preload("res://scripts/moment_of_contact.gd")
func _initialize() -> void:
	call_deferred("run")
func event(id: String,action: int,sweet: bool = true, rescue: bool = false) -> Dictionary:
	return {"id":id,"action":action,"physical_hit":true,"sweet":sweet,"rescue":rescue,"point":Vector3(0,2,5),"incoming_velocity":Vector3(0,-5,15),"outgoing_velocity":Vector3(0,5,-25)}
func expire(clock: Node) -> void:
	clock._end_usec = Time.get_ticks_usec()-1
	clock._process(0)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	await physics_frame
	var clock = lab.moc
	check(clock.mode == Clock.Mode.CURRENT_SLOWDOWN and lab.hud.moc_button.text.contains("CURRENT"), "Existing MoC is default baseline")
	clock.begin(event("baseline",2))
	check(Engine.time_scale == 1.0 and clock.simulation_scale() == 0.60 and clock.simulation_scale() > 0.0, "Baseline keeps 60% speed behavior")
	lab.hud.toggle_moc_mode()
	check(clock.mode == Clock.Mode.TUNED_SLOWDOWN and not clock.active and Engine.time_scale == 1 and lab.hud.moc_button.text.contains("TUNED"), "Toggle safely restores clock and selects new mode")
	for action in range(5):
		var parts := Clock.tuned_parts(event("parts",action))
		check(is_equal_approx(parts.total,0.2 if action == 2 else 0.0), "Only spikes get a fixed 200ms observation window")
		for sweet in [false,true]:
			check(is_equal_approx(Clock.tuned_parts(event("quality",action,sweet,true)).total,parts.total), "Timing quality does not change the observation window")
	var soft := event("soft",1,false)
	soft.incoming_velocity = Vector3.ZERO
	soft.outgoing_velocity = Vector3.UP
	check(Clock.tuned_parts(soft).total == 0, "Soft ordinary contact does not interrupt play")
	lab.ball_active = true
	lab.ball.position = Vector3(0,2,5)
	lab.ball_velocity = Vector3(0,5,-25)
	var scale_before: Vector3 = lab.ball.scale
	var point: Vector3 = lab.ball.position
	clock.begin(event("hold",2))
	clock._end_usec = Time.get_ticks_usec()+500000 # Keep deterministic assertions within one held interval.
	check(clock.simulation_scale() > 0.0 and Engine.time_scale == 1.0 and clock.simulation_scale() == 0.10, "Tuned mode slows rather than pauses")
	var simulation_time: float = lab.elapsed
	lab._physics_process(0.004)
	lab._tick_ball(0.004)
	check(lab.ball.position != point and lab.elapsed > simulation_time, "Ball and simulation continue during slowdown")

	check(lab.ball.scale == scale_before, "Slowdown does not freeze or compress ball")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	lab._unhandled_input(click)
	check(lab.charging, "Gameplay input remains immediate")
	expire(clock)
	check(not clock.active and Engine.time_scale == 1, "Expiry restores full speed")
	lab._reset()
	check(clock.mode == Clock.Mode.TUNED_SLOWDOWN, "Lab reset preserves selected comparison mode")
	var before_count: int = lab.impact_visual.emitted
	clock.begin(soft)
	check(not clock.active and lab.impact_visual.emitted == before_count+1, "Zero-hold contacts still emit physical impact visuals")
	clock.clear()
	clock.begin(event("cancel",2))
	clock._end_usec = Time.get_ticks_usec()+500000

	lab._unhandled_input(click)
	lab.hud.toggle_moc_mode()
	check(Engine.time_scale == 1 and not clock.active and lab.ball.scale == scale_before, "Mode switch cancels hold and pending actions safely")
	clock.begin(event("slow-again",2))
	check(clock.mode == Clock.Mode.NONE and clock.simulation_scale() == 1.0, "Third mode disables slowdown")
	lab.hud.toggle_moc_mode()
	check(clock.mode == Clock.Mode.TRAJECTORY_STEERING,"Next toggle selects trajectory steering")
	lab.hud.toggle_moc_mode()
	clock.begin(event("current-again",2))
	check(clock.mode == Clock.Mode.CURRENT_SLOWDOWN and clock.simulation_scale() == 0.60, "Next toggle restores original slowdown")
	clock.clear()
	lab.hud.toggle_moc_mode()
	clock.begin(event("pause",2))
	clock._end_usec = Time.get_ticks_usec()+500000

	lab.paused = true
	clock._process(0)
	check(not clock.active and Engine.time_scale == 1 and lab.ball.scale == scale_before, "Pause releases hold cleanly")
	lab.paused = false
	lab._reset()
	for action in range(4):
		lab._reset()
		lab.moc.enabled = true
		lab.ball_active = true
		lab.armed = true
		lab.locked_action = action
		lab.selected = action
		lab.locked_charge = 0.65
		lab.camera_rig.update_aim()
		var shape: Dictionary = lab._raw_hurtbox_definition(action)
		var point_local: Vector3 = shape.center
		if action == 1:
			point_local.y += shape.radius*0.5
		elif action == 2:
			point_local += lab.Geometry.sector_point(shape,0.74,67.5,0)
		elif action == 3:
			point_local = Vector3(shape.hand_x,shape.palm,shape.center.z)
		lab.ball.position = lab.player.position+point_local
		lab.ball_velocity = Vector3(0,-5,15)
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration-0.22
		lab.animation.update()
		lab._contact()
		check(clock.active == (action == 2) and clock.last_event.sweet and clock.last_event.moc_mode == "Tuned Slowdown", "Actual sweet contact selects hold tuning for action %d" % action)
		clock._end_usec = Time.get_ticks_usec()+500000
		var contact_point: Vector3 = lab.ball.position
		var resolved_velocity: Vector3 = lab.ball_velocity

		lab._tick_ball(0.016)
		if action != 2:
			check(lab.ball.position != contact_point and not clock.active, "Actual Set launches without MoC")
		else:
			check(lab.ball.position != contact_point and Engine.time_scale == 1.0 and clock.simulation_scale() == 0.10, "Actual spike continues moving at 10% speed")
		clock.clear()
	lab._reset()
	print("MOC MODES: %d / %d passed" % [checks-failures,checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
