extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var bots = lab.training_bots
	lab.select_net(0)
	var receiver: int = bots.summon_generic(true,0,{1:0},false)
	var setter: int = bots.summon_generic(true,0,{2:1},false)
	var attacker: int = bots.summon_generic(true,0,{3:2},false)
	bots._place(receiver,lab.court_center+Vector3(0,0,-5))
	bots._place(setter,lab.court_center+Vector3(-1,0,-2))
	bots._place(attacker,lab.court_center+Vector3(-3,0,-3))
	lab.player.position = lab.court_center+Vector3(0,0.03,lab.court_half_depth+0.4)
	lab.camera_rig.view_yaw = 0
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab.serve.press()
	lab.serve.basic_strike()
	var actions: Array[int] = []
	var previous := 0
	for frame in range(1800):
		if not lab.ball_active: break
		lab._tick_ball(1.0/120)
		if bots.total_contacts > previous:
			previous = bots.total_contacts
			actions.append(bots.last_action)
			if actions.size() == 3: break
	check(actions == [0,1,2],"Generic responsibility bots physically receive, jump set and attack (%s)" % [actions])
	lab._finish("test")
	for slot in range(bots.settings.size()): bots.dismiss(slot)
	var blockers: Array[int] = []
	for index in range(5):
		var slot: int = bots.summon_generic(true,0,{},true)
		bots._place(slot,lab.court_center+Vector3((index-2)*0.65,0,-0.42))
		blockers.append(slot)
	lab.ball_active = true
	lab.ball.position = lab.court_center+Vector3(0,3.6,2)
	lab.ball_velocity = Vector3(0,0,-6)
	lab.side_contacts.fill(0)
	lab.ball_shot = {"kind":"attack","actor":"player"}
	lab.motion.approach_action = 2
	lab.motion.jump_charge = 0.5
	lab.motion.generic_jump = false
	lab.player.position = lab.court_center+Vector3(0,0,2)
	bots.replan()
	bots.tick_motion(0.001)
	check(bots.blocks.committed.size() == 5,"All five bots may independently commit to blocking")
	var positions := {}
	for slot in blockers:
		positions[bots.motion.plans[slot].ground.x] = true
	check(positions.size() == 5,"Block group has distinct coverage lanes")
	var touched := false
	for frame in range(150):
		if not lab.ball_active: break
		lab._tick_ball(1.0/120)
		if bots.last_action == 3:
			touched = true
			break
	check(touched,"Coordinated blockers make a physical block")
	check(lab.side_contacts[1] == 0,"Block does not consume an ordinary team contact")
	lab.queue_free()
	await process_frame
	print("GENERIC BOT RALLY: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
