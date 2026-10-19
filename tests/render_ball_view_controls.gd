extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.player.position = Vector3(0, 0.03, 3)
	lab._update_aim()
	lab._update_pose()
	lab._update_camera(2)
	lab._set_camera_mode(lab.ViewMode.BALL)
	lab.ball_active = true
	lab.ball.position = Vector3(0.5, 5.5, 1.5)
	lab.ball_velocity = Vector3(0, -2, 0)
	lab.selected = 1
	lab.locked_action = 1
	lab.locked_charge = 0.6
	lab.armed = true
	lab._rotate_view(Vector2(300, -80))
	lab._update_camera(2)
	lab._toggle_debug_volumes()
	lab._update_pose()
	lab._update_ui()
	lab._message("BALL VIEW / tracking receive / mouse aims toward your attacker")
	lab._update_ui()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/rally-ball-view-controls.png")
	lab.queue_free()
	await process_frame
	quit()
