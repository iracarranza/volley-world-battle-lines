extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.camera_rig.update_aim()
	lab.camera_rig.update(2)
	var view = lab.hud.athlete_hud.timeline
	view.set_process(false)
	for action in range(4):
		lab._reset()
		lab.locked_action = action
		lab.armed = true
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration - (lab.Execution.SPIKE_PEAK if action == 2 else 0.24)
		view.advance(0)
		lab.hud.update()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/action-timeline-%d.png" % action)
	lab.queue_free()
	await process_frame
	quit()
