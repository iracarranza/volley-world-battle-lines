extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	lab.select_net(0)
	var bots = lab.training_bots
	var slot: int = bots.summon_generic(true,0,{1:0,2:1,3:2},true)
	bots._place(slot,lab.court_center+Vector3(0,0,-5))
	lab.player.position = lab.court_center+Vector3(0,0.03,lab.court_half_depth+0.4)
	lab.camera_rig.view_yaw = 0
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab.serve.press()
	lab.serve.basic_strike()
	var actions: Array[int] = []
	var previous := 0
	var jumped_to_block := false
	for frame in range(1800):
		if not lab.ball_active: break
		lab._tick_ball(1.0/120)
		jumped_to_block = jumped_to_block or bots.blocks.committed.has(slot)
		if bots.total_contacts > previous:
			previous = bots.total_contacts
			actions.append(bots.last_action)
			if actions.size() >= 3: break
	check(actions == [0,1,2],"A multi-responsibility blocker receives, sets to self and attacks (%s)" % [actions])
	check(not jumped_to_block,"Self-set and own attack approach never trigger the bot's block")
	lab.queue_free()
	await process_frame
	print("SELF SET BLOCK: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
