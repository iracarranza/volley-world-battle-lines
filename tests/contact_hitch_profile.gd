extends SceneTree
var failures := 0
var max_render_usec := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.moc.set_mode(lab.MoC.Mode.NONE)
	if "--no-fx" in OS.get_cmdline_user_args():
		lab.moc.impact_started.disconnect(lab.impact_visual.play)
	for frame in range(5):
		await process_frame
		if not DisplayServer.get_name() == "headless":
			await RenderingServer.frame_post_draw
	for mode in ["off","tracking","static"]:
		for slot in range(8):
			lab.training_bots.enabled[slot%4] = mode != "off"
			lab.training_bots.away_enabled[slot%4] = mode != "off"
			lab.training_bots.follows_ball[slot] = mode != "static"
		for action in range(4):
			lab._reset()
			lab.ball_active = true
			lab.locked_action = action
			lab.selected = action
			lab.locked_charge = 0.65
			lab.armed = true
			lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(action).center
			lab.ball_velocity = Vector3(0,-5,15)
			var start := Time.get_ticks_usec()
			lab._confirm_action()
			var confirm := Time.get_ticks_usec()-start
			if not DisplayServer.get_name() == "headless":
				await RenderingServer.frame_post_draw
			print("DRAW confirm %.2fms" % ((Time.get_ticks_usec()-start)/1000.0))
			lab.confirm_window = lab.confirm_duration-0.22
			start = Time.get_ticks_usec()
			lab._contact()
			var contact := Time.get_ticks_usec()-start
			start = Time.get_ticks_usec()
			lab._process(1.0/60)
			if not DisplayServer.get_name() == "headless":
				await RenderingServer.frame_post_draw
			var render := Time.get_ticks_usec()-start
			max_render_usec = maxi(max_render_usec,render)
			if not DisplayServer.get_name() == "headless" and render > 100000:
				failures += 1
				push_error("Contact rendering stalled for over 100ms")
			print("PROFILE %s action=%d confirm=%.2fms contact=%.2fms render=%.2fms" % [mode,action,confirm/1000.0,contact/1000.0,render/1000.0])
	lab.queue_free()
	await process_frame
	print("CONTACT HITCH PROFILE: max contact render %.2fms / failures %d" % [max_render_usec/1000.0,failures])
	quit(1 if failures else 0)
