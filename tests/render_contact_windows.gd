extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.player.position = Vector3(15, 0.03, 20)
	lab.view_yaw = 0.5
	lab.facing_yaw = 0
	lab.view_pitch = 0.12
	lab.debug_volumes_visible = true
	for action in [2, 3]:
		lab.locked_action = action
		lab.selected = action
		lab.armed = true
		lab._update_aim()
		lab._confirm_action()
		lab._update_pose()
		lab._update_camera(2)
		for age in [0.02, 0.22]:
			lab.confirm_window = lab.confirm_duration - age
			lab._update_hurtbox_visual(0)
			lab._update_ui()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/contact-%d-%d.png" % [action, roundi(age * 100)])
	lab.queue_free()
	await process_frame
	quit()
