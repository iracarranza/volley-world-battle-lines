extends SceneTree
# Renders the spike swing as a strip of frames: godot --path . --script res://tests/render_spike_strip.gd
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(900, 700)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.jumped = true
	lab.airborne_action = 2
	lab.jump_charge = -1
	lab.spike_flight_time = 0.6
	lab.armed = true
	lab.locked_action = 2
	lab.locked_charge = 0.8
	var images: Array[Image] = []
	# Takeoff and loading with no click, then the click: the strike, contact, and the follow-through.
	var frames := [[0.05, -1.0, -1.0], [0.2, -1.0, -1.0], [0.45, -1.0, -1.0], [0.45, 0.06, -1.0], [0.45, 0.11, -1.0], [0.45, 0.14, 0.14], [0.45, 0.29, 0.14], [0.45, 0.44, 0.14]]
	var ball_side := 0.3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ball="):
			ball_side = float(a.substr(7))
	lab.ball_active = true
	for i in range(8):
		lab.spike_air_time = float(frames[i][0])
		lab.spike_swing_time = float(frames[i][1])
		lab.spike_hit_time = float(frames[i][2])
		lab.ball.position = lab.player.position + lab.body.global_basis * Vector3(ball_side, 2.3, -0.4)
		lab._update_pose()
		lab.player.position.y = 0.9 * sin(PI * minf(float(frames[i][0]) / 0.6, 1.0))
		lab.body.position.y = 0.0
		lab.camera.position = lab.player.position + Vector3(-2.8, 0.9, -1.2)
		lab.camera.look_at(lab.player.position + Vector3(0, 1.1, -0.1))
		await process_frame
		await RenderingServer.frame_post_draw
		images.append(root.get_texture().get_image())
	var cell := Vector2i(450, 350)
	var strip := Image.create(cell.x * 4, cell.y * 2, false, Image.FORMAT_RGBA8)
	for i in range(8):
		var small := images[i].duplicate() as Image
		small.resize(cell.x, cell.y)
		strip.blit_rect(small, Rect2i(0, 0, cell.x, cell.y), Vector2i((i % 4) * cell.x, (i / 4) * cell.y))
	strip.save_png("res://artifacts/spike-strip%s.png" % ("-ball%s" % str(ball_side) if ball_side != 0.3 else ""))
	quit()
