extends "res://tests/support/test_case.gd"
const Field := preload("res://scripts/block_field.gd")
const State := preload("res://scripts/block_state.gd")
const Request := preload("res://scripts/contact/contact_request.gd")
const Resolver := preload("res://scripts/contact/contact_resolver.gd")
const Athlete := preload("res://scripts/athlete.gd")
func request_at(point: Vector3,age: float = -1.0):
	var request := Request.new()
	request.athlete = Athlete.new()
	request.action = 3
	request.shape = Field.definition(1.86,request.athlete.reach())
	request.local_point = point
	request.incoming = Vector3(0,-6,20)
	request.incoming_shot = {"kind":"attack","charge":0.4}
	request.facing = Vector3.FORWARD
	request.block_confirmation_age = age
	return request
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var shape := Field.definition(1.86,2.26)
	var palm := Vector3(shape.hand_x,shape.palm,shape.center.z)
	var req = request_at(palm)
	var passive := Resolver.assess(req)
	check(passive.hit and not passive.sweet and not passive.rescue,"Passive block remains valid without confirmation")
	check(is_equal_approx(passive.block_response.capacity/passive.block_response.auto_reference,0.75),"Best passive capacity is 75 percent of Auto")
	req.block_confirmation_age = 0
	var confirmed := Resolver.assess(req)
	check(confirmed.sweet and is_equal_approx(confirmed.block_response.capacity,passive.block_response.capacity*2),"Confirmation immediately doubles the sweetspot capacity")
	req.block_confirmation_age = 0.25
	var decaying := Resolver.assess(req)
	check(decaying.block_response.capacity < confirmed.block_response.capacity and decaying.block_response.capacity > passive.block_response.capacity,"Confirmation boost decays rather than disappearing")
	req.block_confirmation_age = 0.5
	check(is_equal_approx(Resolver.assess(req).block_response.capacity,passive.block_response.capacity),"After half a second strength returns to passive")
	req.block_confirmation_age = 4
	check(Resolver.assess(req).hit,"Block does not expire with the generic confirmation window")
	var torso_y := float(shape.bottom)+0.30
	var torso := Field.grade(shape,Vector3(Field.width(shape,torso_y),torso_y,shape.center.z))
	var arm := Field.grade(shape,Vector3(Field.width(shape,shape.palm),shape.palm,shape.center.z))
	var tips := Field.grade(shape,Vector3(0,shape.top,shape.center.z))
	check(torso.block_capacity > arm.block_capacity and arm.block_capacity > tips.block_capacity,"Torso boundary, arm boundary and fingertips have decreasing tolerance")
	check(Field.contains(shape,Vector3(0,shape.bottom+0.1,shape.center.z),0),"Triangle extends down the front torso")
	check(not Field.contains(shape,Vector3(0,shape.palm,0.5),0),"Block field does not extend behind the body")
	var lower = request_at(Vector3(Field.width(shape,torso_y),torso_y,shape.center.z))
	var low_result := Resolver.resolve(lower,Resolver.assess(lower))
	check(low_result.velocity.x > 0,"Lower side contact sheds the ball outwards")
	var upper = request_at(Vector3(0,shape.top-0.01,shape.center.z))
	upper.incoming = Vector3(0,-18,20)
	upper.incoming_shot.charge = 1
	var falling := Resolver.resolve(upper,Resolver.assess(upper))
	upper.incoming.y = 10
	var rising := Resolver.resolve(upper,Resolver.assess(upper))
	check(falling.velocity.z > 0,"Upper sourspot permits a deflection behind the blocker")
	check(not falling.velocity.is_equal_approx(rising.velocity),"Incoming vertical velocity affects block output")
	check(falling.separation_offset.length() > 0,"Block contact separates the ball from its platform")
	upper.incoming_shot.charge = 0.02
	var soft_back := Resolver.resolve(upper,Resolver.assess(upper))
	check(soft_back.velocity.z > 0 and soft_back.velocity.length() < upper.incoming.length()*0.4,"Matched upper touch can send a useful soft ball behind the blocker")
	lower.incoming_shot.charge = 0.02
	var soft_side := Resolver.resolve(lower,Resolver.assess(lower))
	var core = request_at(palm,0)
	core.incoming_shot.charge = 0.02
	var core_result := Resolver.resolve(core,Resolver.assess(core))
	check(soft_side.velocity.x > 0 and soft_side.velocity.length() < core_result.velocity.length(),"Outward touch redirects with less force than central block")
	core.incoming_shot.charge = 0.65
	core.block_charge_reference = 0.2
	var weak_press := Resolver.assess(core)
	core.block_charge_reference = 1.0
	var strong_press := Resolver.assess(core)
	check(weak_press.block_response.severity > strong_press.block_response.severity,"Confirmed block strength respects chosen charge")
	core.block_confirmation_age = -1
	var passive_high := Resolver.assess(core)
	core.block_charge_reference = 0.2
	check(is_equal_approx(passive_high.block_response.capacity,Resolver.assess(core).block_response.capacity),"Passive block stays at its Auto reference independently of manual effort")
	var state := State.new()
	state.start()
	check(state.active and state.confirmation_age < 0,"Takeoff establishes passive coverage")
	check(state.confirm() and not state.confirm(),"Only one confirmation is allowed per jump")
	state.tick(0.5)
	check(state.active and state.confirmation_age == 0.5,"Expired press leaves passive field active")
	state.land()
	check(not state.active,"Landing removes coverage")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	lab.player.position = Vector3(0,1,5)
	lab.motion.jumped = true
	lab.motion.airborne_action = 3
	lab.motion.airborne_aim = Vector3.FORWARD
	lab.begin_passive_block()
	lab.ball_active = true
	var field: Dictionary = lab._hurtbox_definition(3)
	lab.ball.position = lab.player.position+Vector3(field.hand_x,field.palm,field.center.z)-Vector3(0,0,0.7)
	lab.ball_velocity = Vector3(0,-1,50)
	lab.ball_shot = {"kind":"attack","charge":0.4}
	var serial: int = lab._contact_event_serial
	lab._tick_ball(0.02)
	check(lab._contact_event_serial == serial+1 and lab.block_state.active and lab.armed,"Airborne passive block contacts without input and retains preparation")
	lab._tick_ball(0.001)
	check(lab._contact_event_serial == serial+1,"A departing ball cannot be repeatedly blocked while overlapping")
	lab._confirm_action()
	check(lab.block_state.used_confirmation,"Passive contact does not consume the jump's confirmation")
	lab.end_passive_block()
	check(not lab.armed and not lab.block_state.active and lab.hurtbox_linger == 0,"Landing clears hurtbox and expends preparation")
	lab.player.position = Vector3(0,0.03,5)
	lab.player.velocity = Vector3.ZERO
	lab.motion.jumped = false
	for frame in range(5): lab.motion.tick(0.016,1.0)
	lab.armed = true
	lab.locked_action = 3
	lab.selected = 3
	lab.motion.approach_action = 3
	lab.motion.jump_charge = 0.5
	lab.motion.takeoff()
	check(lab.motion.jumped and lab.block_state.active,"Actual block takeoff opens passive coverage")
	for frame in range(180): lab.motion.tick(0.016,1.0)
	check(not lab.motion.jumped and not lab.block_state.active and not lab.armed,"Actual landing consumes the passive preparation")
	var bots = lab.training_bots
	var blocker: int = bots.summon_generic(true,1,{1:0},true)
	bots.set_execution_action(blocker,3)
	bots.actors[blocker].position = Vector3(0,1,-2)
	bots.actors[blocker].rotation.y = PI
	bots.block_state_for(blocker).start()
	bots.preparation.state_for(blocker).phase = "charging"
	bots.active_action = 3
	bots.active_slot = blocker
	bots.remaining = 0.5
	lab.ball_active = true
	lab.ball_shot = {"kind":"attack","charge":0.4}
	lab.ball.position = bots.actors[blocker].position+bots.contact_anchor(blocker).rotated(Vector3.UP,PI)
	lab.ball_velocity = Vector3(0,-3,-15)
	bots.intercept = lab.ball.position # this fixture installs the passive plan directly
	check(bots.tick_contact(0.01),"Bot passive field contacts before scheduled confirmation")
	check(bots.block_state_for(blocker).latched and not bots.block_state_for(blocker).used_confirmation,"Bot passive contact latches without consuming its press")
	lab.queue_free()
	await process_frame
	print("BLOCK FIELD: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
