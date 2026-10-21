extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	await physics_frame
	for net_index in range(3):
		for side in [-1.0,1.0]:
			lab._reset()
			lab.select_net(net_index)
			var center: Vector3 = lab.primary_nets[net_index].position
			lab.player.position = center+Vector3(0,0.03,side*(lab.court_half_depth+0.4))
			lab.camera_rig.facing_yaw = 0 if side > 0 else PI
			lab.camera_rig.view_yaw = lab.camera_rig.facing_yaw
			lab.camera_rig.update_aim()
			lab.animation.update()
			lab.serve.input_press()
			for frame in range(130):
				lab._tick_ball(1.0/120)
				if lab.serve.state == lab.serve.State.FLIGHT: break
			check(lab.serve.state == lab.serve.State.FLIGHT and lab.serve.main_court,"Held serve works from either side of primary net %d" % (net_index+1))
			var shot: Dictionary = lab.serve.evidence
			if not shot.has("target"): continue
			check(absf(shot.target.x-center.x)<lab.court_half_width and shot.target.z*side<0,"Serve targets its own opposing court, not the Middle Net")
			check(shot.net_height >= lab.net_height+lab.Geometry.BALL_RADIUS+0.19,"Serve clears the selected net's actual height")
			check(lab.training_bots.is_enabled(0,-side),"Serve summons receiver on its opposing team")
		lab._reset()
		lab.select_net(net_index)
		var bots = lab.training_bots
		for slot in range(bots.settings.size()): bots.dismiss(slot)
		var receiver: int = bots.summon(false,net_index,0,1)
		var setter: int = bots.summon(false,net_index,1,2)
		bots.set_mode(receiver,0)
		lab.ball_active = true
		lab.ball.position = lab.court_center+Vector3(0,3,5)
		lab.ball_velocity = Vector3(0,-1,0)
		bots.replan()
		check(bots.active_slot == receiver,"Assigned receiver plans on its selected net")
		var plan: Dictionary = bots.preparation.state_for(receiver)
		for frame in range(500):
			lab._tick_ball(1.0/120)
			if bots.total_contacts > 0 or not lab.ball_active: break
		check(bots.total_contacts > 0 and bots.last_action == 0,"Actual receive uses the common contact resolver at Net %d" % (net_index+1))
		check(absf(lab.ball.position.x-lab.court_center.x)<lab.court_half_width+1,"Bot stays near its assigned court")
		check(bots.setter_direction(receiver,bots.actors[receiver].position).dot((bots.actors[setter].position-bots.actors[receiver].position).normalized())>0.99,"Receiver aims at its same-net setter")
	for net_index in range(3):
		lab._reset()
		lab.select_net(net_index)
		lab.ball_active = true
		lab.ball.position = lab.court_center+Vector3(0,lab.net_height,0.4)
		lab.ball_velocity = Vector3(0,0,-12)
		lab._tick_ball(0.04)
		check(lab.ball_active and lab.net_response.last_contact == "tape","Each primary net uses physical tape response at its actual height")
	lab.select_net(0)
	check(lab.athlete_touches_net(lab.primary_nets[2].position+Vector3(0,0,0.1),lab.primary_nets[2].position+Vector3(0,0,-0.1)),"Midline fault checks include primary nets outside the active rally court")
	lab.queue_free()
	await process_frame
	print("MAP COURT PLAY: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
