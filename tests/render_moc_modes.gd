extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	for mode in [lab.MoC.Mode.CURRENT_SLOWDOWN,lab.MoC.Mode.TUNED_SLOWDOWN]:
		if lab.moc.mode != mode:
			lab.hud.toggle_moc_mode()
		lab.camera_rig.update_aim()
		lab.animation.update()
		lab.camera_rig.update(2)
		lab.hud.update()
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/moc-mode-%d.png" % mode)
	lab.queue_free()
	await process_frame
	quit()
