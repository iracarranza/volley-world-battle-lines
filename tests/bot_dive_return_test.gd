extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var bots = lab.training_bots
	lab._reset()
	bots.settings[0].enabled = true
	bots.settings[0].moves = true
	bots.settings[0].move_speed = 4
	bots.settings[0].tracking_accuracy = 100
	bots.settings[0].charge_accuracy = 100
	bots.actors[0].position = Vector3(0,0,5)
	bots.settings[0].fixed_position = bots.actors[0].position
	bots.actors[0].rotation.y = 0
	lab.ball_active = true
	lab.ball.position = Vector3(2.5,2.5,4.5)
	lab.ball_velocity = Vector3(0,-7,0)
	lab.ball_shot = {"kind":"attack","charge":0.3}
	bots.replan()
	check(bots.dives.active(0),"Receiver selects dive when running cannot reach the standing intercept")
	check(float(bots.contact_shape(0).center.y) < 0.5,"Dive uses player's low receiving platform")
	var start: Vector3 = bots.actors[0].position
	bots.tick_motion(0.01)
	check(bots.actors[0].position.distance_to(start) < 0.2,"Dive moves physically rather than teleporting to intercept")
	check(bots.animation.state_for(bots.rigs[0].body).source == "dive","Bot supplies shared dive animation context")
	for frame in range(180):
		if bots.total_contacts > 0 or not lab.ball_active: break
		lab._tick_ball(1.0/120)
	check(bots.total_contacts == 1,"Diving bot earns a real contact through its platform")
	check(bots.dives.busy(0) and bots.returns.contains(0),"Contact queues return after dive recovery")
	lab.ball_active = false
	bots.active_slot = -1
	bots.active_action = -1
	for frame in range(600): bots.tick_motion(1.0/120)
	check(not bots.dives.busy(0),"Dive completes recovery before resuming ordinary movement")
	check(bots.actors[0].position.distance_to(bots.settings[0].fixed_position) < 0.03,"Diving receiver returns to saved position")
	# A routine nearby ball should be received standing.
	bots._plan(0,Vector3(0,1,4.35),1.0,0)
	check(not bots.dives.busy(0),"Reachable standing receive does not trigger a dive")
	bots.active_slot = -1
	bots.move_targets.clear()
	for slot in range(4):
		bots.settings[slot].enabled = true
		bots.settings[slot].moves = false
		bots.settings[slot].follows_ball = slot%2 == 0
		bots.settings[slot].fixed_position = Vector3(slot,0,5)
		bots.actors[slot].position = Vector3(slot+2,0,7)
		bots.return_after_contact(slot)
	for frame in range(240): bots.tick_motion(1.0/120)
	for slot in range(4):
		check(bots.actors[slot].position.distance_to(bots.settings[slot].fixed_position) < 0.03,"Contact return applies to each action and Static/Follow modes")
	# A new task supersedes a queued return.
	bots.return_after_contact(0)
	bots._plan(0,Vector3(1,1,5),0.5,0)
	check(not bots.returns.contains(0),"New contact responsibility interrupts return")
	lab.queue_free()
	await process_frame
	var map = load("res://map_graybox.tscn").instantiate()
	root.add_child(map)
	map.set_process(false)
	map.set_physics_process(false)
	map.moc.enabled = false
	var roster = map.training_bots
	var slot: int = roster.summon_generic(false,1,{1:0,2:1},false)
	roster.settings[slot].moves = true
	roster.actors[slot].position += Vector3(2,0,2)
	var displaced: Vector3 = roster.actors[slot].position
	roster.support_targets[slot] = displaced
	roster.motion.begin(slot,roster.actors[slot],Vector3(displaced.x,1,displaced.z),0.4,false,map.GRAVITY,6,0,1,2)
	roster.return_after_contact(slot)
	check(not roster.support_targets.has(slot),"Generic contact clears obsolete support destination")
	roster.tick_motion(0.1)
	check(roster.returns.pending.has(slot) and is_equal_approx(roster.actors[slot].position.x,displaced.x),"Return waits for airborne motion instead of dragging a jumper home")
	for frame in range(240): roster.tick_motion(1.0/120)
	check(roster.actors[slot].position.distance_to(roster.settings[slot].fixed_position) < 0.03,"Generic rally bot returns after landing")
	map.queue_free()
	await process_frame
	print("BOT DIVE / CONTACT RETURN: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
