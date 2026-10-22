extends "res://tests/support/test_case.gd"
const Clock := preload("res://scripts/moment_of_contact.gd")
const Steering := preload("res://scripts/moc_steering.gd")
const Preview := preload("res://scripts/trajectory_preview.gd")
var usec := 1000000
func _initialize() -> void: call_deferred("run")
func contact(id: String = "steer",action: int = 2) -> Dictionary:
	return {"id":id,"actor":"player","action":action,"physical_hit":true,"quality":1.0,"outgoing_velocity":Vector3(0,4,-20),"incoming_velocity":Vector3(0,-5,15),"steering":{"facing":Vector3.FORWARD}}
func run() -> void:
	var first := Steering.new()
	first.begin(contact(),0)
	first.step(Vector3.RIGHT,0.2,1.25,10,100)
	var second := Steering.new()
	second.begin(contact(),0)
	for index in range(20): second.step(Vector3.RIGHT,0.01,1.25,10,100)
	check(first.velocity.is_equal_approx(second.velocity) and is_equal_approx(first.spent,second.spent),"DI accumulation is independent of frame rate")
	check(first.axes.length() < 1 and first.spent > 0,"Steering grows gradually and costs HP")
	var held := first.axes
	first.step(Vector3.ZERO,0.2,1.25,10,100)
	check(first.axes == held,"Releasing direction retains the chosen trajectory")
	var limited := Steering.new()
	limited.begin(contact(),0)
	limited.step(Vector3.RIGHT,1,1.25,10,1)
	check(limited.spent <= 1.00001 and limited.axes.length() < 0.11,"Insufficient HP caps steering without overdraft")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var moc = lab.moc
	moc.clock = func(): return usec
	moc.set_mode(Clock.Mode.TRAJECTORY_STEERING)
	lab.ball_active = true
	lab.ball.position = Vector3(0,3,3)
	lab.ball_velocity = contact().outgoing_velocity
	lab.athlete.hp = 100
	moc.begin(contact())
	check(moc.simulation_scale() == 1,"New mode begins at normal motion speed")
	usec += 100000
	check(is_equal_approx(moc.simulation_scale(),0.05) and Engine.time_scale == 1,"Only local clocks ramp to five percent speed")
	check(moc.actor_scale("training_bot_0") == 1 and is_equal_approx(moc.actor_scale("player"),0.05),"Other athletes remain at full speed")
	var neutral := Preview.predict(lab)
	check(not neutral.is_empty() and neutral.steering and neutral.points.size() > 2,"Unarmed post-contact preview remains visible")
	var hp: float = lab.athlete.hp
	moc.steer(0.2,Vector3.RIGHT)
	var altered := Preview.predict(lab)
	check(lab.athlete.hp < hp and altered.velocity.x > neutral.velocity.x,"Real-time DI changes actual flight and spends HP")
	check(altered.color.r > neutral.color.r and altered.color.b < neutral.color.b,"Lane shifts from blue toward red with DI")
	var bar = lab.hud.athlete_hud
	bar.hp_bar.value = 100
	bar.update_hp_feedback(0.05)
	var fill: StyleBoxFlat = bar.hp_bar.get_theme_stylebox("fill")
	check(fill.bg_color != bar.HP_COLOR and fill.bg_color != bar.HP_RED,"HP fill blends color rather than swapping")
	check(fill.shadow_size > 0 and bar.hp_bar.value < 100,"HP bar glows and drains during steering")
	var before: Vector3 = lab.ball.position
	lab._tick_ball(0.1)
	check(before.distance_to(lab.ball.position) > 0 and before.distance_to(lab.ball.position) < 0.2,"Ball moves slowly instead of pausing")
	usec += 1000000
	check(moc.simulation_scale() == 1 and not moc.active and Preview.predict(lab).is_empty(),"Window expiry restores normal flight and removes post-contact preview")
	for action in range(4):
		moc.begin(contact("contact%d"%action,action))
		check(moc.active,"Experimental mode supports contact %d"%action)
		moc.clear()
	lab.hud.moc_menu.steering_duration.value = 1500
	lab.hud.moc_menu.steering_speed.value = 0.5
	check(moc.steering_duration == 1.5 and moc.steering_speed == 0.005,"Menu edits real duration and fractional speed")
	moc.set_mode(Clock.Mode.NONE)
	lab.athlete.hp = 100
	bar.hp_previous = 100
	bar.hp_bar.value = 100
	lab.athlete.spend(0,5)
	bar.update_hp_feedback(0.02)
	check(bar.hp_warmth > 0 and bar.hp_warmth < 1,"Ordinary HP expenditure also fades toward red")
	lab._reset()
	moc.set_mode(Clock.Mode.TRAJECTORY_STEERING)
	lab.locked_action = 2
	lab.selected = 2
	lab.armed = true
	lab.locked_charge = 0.6
	lab.ball_active = true
	lab.directional_input.sample(Vector3.RIGHT,0.08)
	check(lab.contact_request(2).directional_input == Vector3.ZERO,"Experimental confirmation defers instant DI")
	var shape: Dictionary = lab._raw_hurtbox_definition(2)
	lab.ball.position = lab.player.position+Vector3(shape.center)+lab.Geometry.sector_point(shape,0.74,67.5,0)
	lab.ball_velocity = Vector3(0,-4,10)
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration - (preload("res://scripts/contact_execution.gd").SPIKE_PEAK if lab.locked_action == 2 else 0.22)
	lab._contact()
	check(moc.steering_active() and lab.last_contact_result.physical_hit,"Real spike starts steering only after physical contact")
	check(not Preview.predict(lab).is_empty() and not lab.armed,"Real contact keeps trajectory visible after preparation ends")
	lab.queue_free()
	await process_frame
	print("MOC STEERING: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
