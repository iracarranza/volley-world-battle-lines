extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.moc.enabled = false
	lab.player.position = Vector3(3,0.03,15)
	lab.camera_rig.view_pitch = 0.39
	lab.camera_rig.view_yaw = 0.2
	lab.camera_rig.update_aim()
	lab.hud.toggle_debug_volumes()
	for action in [0,1,2]:
		lab.selected = action
		lab.locked_action = action
		lab.locked_charge = 0.75
		lab.armed = true
		lab.ball_active = true
		lab.confirm_duration = 0
		lab.committed_intent = {}
		var shape: Dictionary = lab._raw_hurtbox_definition(action)
		var point: Vector3 = shape.center
		if action == 1:
			point.y += shape.radius*0.5
		elif action == 2:
			point += lab.Geometry.sector_point(shape,0.74,67.5,0)
		else:
			point.x += 0.25
		lab.ball.position = lab.player.position + point.rotated(Vector3.UP,lab.camera_rig.facing_yaw)
		lab.ball_velocity = Vector3(0,-5,3)
		for view in [lab.ViewMode.ATHLETE,lab.ViewMode.BALL]:
			lab.camera_rig.set_mode(view)
			lab.animation.update()
			lab.camera_rig.update(2)
			lab._update_preview()
			lab.hud.update()
			var hint: Dictionary = lab.last_trajectory_preview
			if not hint.is_empty():
				var visible_points := 0
				for p in hint.points:
					if lab.camera.is_position_in_frustum(p):
						visible_points += 1
				print("HINT ", action, " / ", view, " visible=", visible_points, " of ", hint.points.size())
			else:
				print("HINT EMPTY ",action," / ",view)
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/trajectory-%d-%d.png" % [action,view])
	lab.queue_free()
	await process_frame
	quit()
