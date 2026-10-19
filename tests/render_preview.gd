extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.auto_feed = false
	await physics_frame
	await physics_frame
	if "--bots" in OS.get_cmdline_user_args():
		lab.training_bots.toggle_all()
	lab._feed()
	lab.ball.position = Vector3(0, 3.7, 3.5)
	lab.ball_velocity = Vector3(0, -2, 3)
	lab.selected = 1
	lab.locked_action = 1
	lab.locked_charge = 0.65
	lab.armed = true
	lab.set_physics_process(false)
	lab.set_process(false)
	if "--station" in OS.get_cmdline_user_args():
		lab.player.position = Vector3(13, 0, 8)
		lab.station.start()
		lab.station.serve()
		lab.ball.position = Vector3(14.5, 2.6, 5.5)
		lab.selected = 0
		lab.locked_action = 0
		lab.view_yaw = -0.30
		lab.facing_yaw = -0.30
	elif "--approach" in OS.get_cmdline_user_args():
		lab.selected = 2
		lab.locked_action = 2
		lab.jump_charge = 0.56
		lab.approach_action = 2
		lab.approach_phase_name = lab.Approach.STEP_NAMES[1]
		lab.approach_direction = Vector3.FORWARD
	lab.camera_mode = lab.ViewMode.BALL if "--ball" in OS.get_cmdline_user_args() else lab.ViewMode.ATHLETE
	if "--spike" in OS.get_cmdline_user_args():
		lab.selected = 2
		lab.locked_action = 2
	lab._update_aim()
	lab._update_pose()
	if "--bots" in OS.get_cmdline_user_args():
		lab.training_bots.replan()
	if not "--approach" in OS.get_cmdline_user_args():
		lab._confirm_action()
	lab._update_camera(2.0)
	lab._update_preview()
	lab._update_ui()
	if "--box" in OS.get_cmdline_user_args():
		lab.player.position = lab.drills.BOX_START
		lab.drills.start_box()
		lab._update_pose()
		lab._update_ui()
		lab.camera.position = Vector3(-28, 7.5, 13)
		lab.camera.look_at(Vector3(-36, 5.0, 4))
	elif "--trainer" in OS.get_cmdline_user_args():
		lab.player.position = lab.drills.SPIKE_START
		lab.drills.start_spike()
		lab._update_pose()
		lab._update_ui()
		lab.camera.position = Vector3(-8, 9, 19)
		lab.camera.look_at(Vector3(-16, 1.5, 6))
	if "--creator" in OS.get_cmdline_user_args():
		lab.creator.open()
	if "--avi" in OS.get_cmdline_user_args():
		lab.body_type = "Avi"
		lab._rebuild_visual()
	await process_frame
	await RenderingServer.frame_post_draw
	var filename := "contact-lab-ball" if lab.camera_mode == lab.ViewMode.BALL else "contact-lab-athlete"
	if "--station" in OS.get_cmdline_user_args():
		filename = "serve-receive-station"
	elif "--approach" in OS.get_cmdline_user_args():
		filename = "stepped-approach"
	if "--spike" in OS.get_cmdline_user_args():
		filename = "spike-sector-zones"
	elif "--creator" in OS.get_cmdline_user_args():
		filename = "athlete-creator"
	elif "--avi" in OS.get_cmdline_user_args():
		filename = "avi-contact-lab"
	if "--box" in OS.get_cmdline_user_args():
		filename = "box-jump-parkour"
	elif "--trainer" in OS.get_cmdline_user_args():
		filename = "spike-trainer"
	root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")
	quit()
