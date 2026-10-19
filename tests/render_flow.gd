extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab._toggle_debug_volumes()
	lab._update_camera(2)
	for amount in [25.0,100.0]:
		lab.athlete.flow = amount
		lab.contact_flow.tick_visuals()
		lab._update_ui()
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/flow-%d.png"%int(amount))
	lab.queue_free()
	await process_frame
	quit()
