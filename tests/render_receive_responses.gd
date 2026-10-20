extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	for entry in [
		["bottom-early", 0.03, 0.0, 0.52, 0.10],
		["side-late", 0.55, 0.65, 0.02, 0.10],
		["high-late", 0.95, 0.65, 0.02, 0.10],
		["matched", 0.50, 0.0, 0.22, 0.82],
	]:
		lab._reset()
		lab.player.position = Vector3(16, 0.03, 10)
		lab.station.start()
		lab.station.serves_sent = 5
		lab.station.force_next_feed = 5
		lab.station.serve()
		lab.station.strike_feed()
		var feed_origin: Vector3 = lab.ball.position
		var feed_velocity: Vector3 = lab.ball_velocity
		var shape: Dictionary = lab._raw_hurtbox_definition(0)
		var local := Vector3(float(entry[2]) * float(shape.side_reach), float(shape.center.y) + (float(entry[1]) - 0.5) * float(shape.size.y), -0.65)
		lab.ball.position = lab.player.position + local
		var travel_time: float = (lab.ball.position.z - feed_origin.z) / feed_velocity.z
		lab.ball_velocity = feed_velocity + Vector3.DOWN * lab.GRAVITY * travel_time
		lab.locked_action = 0
		lab.selected = 0
		lab.armed = true
		lab.locked_charge = float(entry[4])
		lab.camera_rig.update_aim()
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration - float(entry[3])
		lab._contact()
		var points: Array[Vector3] = [lab.ball.position]
		for step in range(1, 101):
			var t := float(step) * 0.02
			var p: Vector3 = lab.ball.position + lab.ball_velocity * t + Vector3.DOWN * lab.GRAVITY * t * t * 0.5
			if p.y < lab.Geometry.VISUAL_BALL_RADIUS:
				break
			points.append(p)
		lab._draw_line(lab.trail, points)
		lab.animation.update()
		lab.camera_rig.view_yaw = 0.35
		lab.camera_rig.view_pitch = -0.12
		lab.camera_rig.update(2)
		lab.hud.update()
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/receive-response-%s.png" % entry[0])
		print("DRILL RESPONSE ", entry[0], " velocity=", lab.ball_velocity, " input=", lab.locked_charge, " ball=", lab.ball_shot.charge)
	lab.queue_free()
	await process_frame
	quit()
