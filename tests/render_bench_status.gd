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
	lab.athlete.spend(100)
	lab.athlete.recover(1,true)
	lab.athlete.spend(100)
	lab.training_bots.toggle(0)
	lab.training_bots.toggle(1)
	lab.ball_active = true
	lab.ball.position = Vector3(0,5,4)
	lab._check_bench()
	for phase in ["return", "seated", "spectate"]:
		if phase == "return":
			lab.bench.tick(0.5)
		elif phase == "seated":
			lab.bench.tick(0.6)
		else:
			lab.bench.toggle_spectate()
		lab._update_pose()
		lab._update_camera(2)
		lab._update_ui()
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/bench-%s.png" % phase)
	lab.queue_free()
	await process_frame
	quit()
