extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var args := OS.get_cmdline_user_args()
	lab.player.position = Vector3(8, 0.03, 14)
	lab.view_pitch = -0.12
	if "--box" in args:
		lab.player.position = Vector3(-29, 0.03, 12)
		lab.view_pitch = 1.0
	lab._update_aim()
	lab._update_pose()
	lab._update_camera(2)
	lab._serve()
	for frame in range(18):
		lab._tick_ball(1.0 / 120)
	lab._serve()
	if "--pepper" in args or "--box" in args:
		for frame in range(800):
			if not lab.ball_active or lab.pepper.exchanges > 0:
				break
			lab._tick_ball(1.0 / 120)
	else:
		for frame in range(6):
			lab._tick_ball(1.0 / 120)
	if "--ball" in args:
		lab._set_camera_mode(lab.ViewMode.BALL)
	if "--hidden" in args:
		lab._toggle_debug_volumes()
	lab._update_pose()
	lab._update_camera(2)
	lab._update_ui()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "box" if "--box" in args else ("pepper" if "--pepper" in args else "serve")
	root.get_texture().get_image().save_png("/tmp/rally-freeplay-" + suffix + ".png")
	print("Freeplay capture / ", suffix)
	lab.queue_free()
	await process_frame
	quit()
