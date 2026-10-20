extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var bots = lab.training_bots
	for index in [0,2]:
		lab._reset()
		lab.select_net(index)
		for slot in range(bots.settings.size()): bots.dismiss(slot)
		for action in [0,1,2]: bots.summon(true,index,action,action+1)
		lab.player.position = lab.court_center+Vector3(0,0.03,lab.court_half_depth+0.4)
		lab.camera_rig.view_yaw = 0
		lab.camera_rig.facing_yaw = 0
		lab.camera_rig.update_aim()
		lab.animation.update()
		lab.serve.press()
		lab.serve.basic_strike()
		var actions: Array[int] = []
		var previous := 0
		for frame in range(1400):
			if not lab.ball_active: break
			lab._tick_ball(1.0/120)
			if bots.total_contacts > previous:
				previous = bots.total_contacts
				actions.append(bots.last_action)
				if actions.size() == 3: break
		check(actions == [0,1,2],"Configurable Move bots receive, jump set and attack on Net %d (%s)" % [index+1,actions])
		check(lab.moc.last_event.actor == "training_bot_2" if actions.size() == 3 else false,"Attack resolves against its assigned identity rather than a legacy action slot")
	lab.queue_free()
	await process_frame
	print("MAP BOT RALLY: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
