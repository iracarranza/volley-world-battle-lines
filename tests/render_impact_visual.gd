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
	lab._toggle_debug_volumes()
	lab.player.position = Vector3(3,0.03,15)
	lab.facing_yaw = 0.2
	lab.view_yaw = 0.2
	lab.view_pitch = 0.27
	lab._update_aim()
	lab._update_camera(2)
	for sweet in [false,true]:
		lab.impact_visual.clear()
		lab.selected = 2
		lab.locked_action = 2
		lab.armed = true
		lab._update_pose()
		var shape: Dictionary = lab._raw_hurtbox_definition(2)
		var local: Vector3 = shape.center+lab.Geometry.sector_point(shape,0.74,67.5,0)
		var point: Vector3 = lab.player.position+local.rotated(Vector3.UP,lab.facing_yaw)
		lab.ball.position = point+Vector3(0,0,-1)
		lab.impact_visual.play({"id":"render-%s" % sweet,"physical_hit":true,"sweet":sweet,"action":2,"point":point,"incoming_velocity":Vector3(0,-4,8),"outgoing_velocity":Vector3(2,-2,-28)})
		lab.impact_visual.tick(0.035)
		lab._update_ui()
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/impact-%s.png" % ("sweet" if sweet else "ordinary"))
	lab.queue_free()
	await process_frame
	quit()
