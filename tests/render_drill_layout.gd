extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	for scene in ["spike", "receive"]:
		if scene == "spike":
			lab.player.position = lab.drills.SPIKE_START
			lab.drills.start_spike()
			lab.camera.position = Vector3(-10, 10, 18)
			lab.camera.look_at(Vector3(-16, 0.5, 7))
		else:
			lab.drills.reset()
			lab.player.position = lab.station.START
			lab.station.start()
			lab.station.serve()
			lab.camera.position = Vector3(24, 11, 18)
			lab.camera.look_at(Vector3(16, 0.5, 2))
		lab._update_pose()
		lab._update_ui()
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rally-drill-%s.png" % scene)
	lab.queue_free()
	await process_frame
	quit()
