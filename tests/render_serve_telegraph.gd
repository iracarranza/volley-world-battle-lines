extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.player.position = lab.station.START
	lab.station.start()
	lab.station.serve()
	lab.camera.position = Vector3(20, 5.2, -5)
	lab.camera.look_at(Vector3(16,2.8,-10))
	for frame in range(36):
		lab.station.tick(1.0 / 120)
		lab._tick_ball(1.0 / 120)
	for phase in ["toss", "strike"]:
		if phase == "strike":
			for frame in range(37):
				lab.station.tick(1.0 / 120)
				lab._tick_ball(1.0 / 120)
		lab.hud.update()
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/serve-feeder-%s.png" % phase)
	lab.queue_free()
	await process_frame
	quit()
