extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.player.position = Vector3(15, 0.03, 20)
	lab.camera_rig.update_aim()
	lab.camera_rig.update(2)
	lab.camera_rig.set_mode(lab.ViewMode.BALL)
	lab.ball_active = true
	var facing: float = lab.camera_rig.facing_yaw
	var loft: float = lab.camera_rig.view_pitch
	var far_radius := 0.0
	for offset in [Vector3(0, 2, -12), Vector3(5, 6, -6), Vector3(0, 8, -1), Vector3(0, 20, 0), Vector3(-5, 4, 4)]:
		lab.ball.position = lab.player.position + offset
		lab.camera_rig.update(2)
		var athlete_pixel: Vector2 = lab.camera.unproject_position(lab.camera_rig.ball_frame_pivot)
		var ball_pixel: Vector2 = lab.camera.unproject_position(lab.ball.position)
		check(athlete_pixel.distance_to(Vector2(720, 900 * lab.camera_rig.ball_frame_screen_y)) < 0.1, "Athlete framing reference remains bottom center")
		check(lab.camera.is_position_in_frustum(lab.ball.position) and absf(ball_pixel.x - 720) < 0.1, "Both athlete and ball stay centrally framed")
		check(lab.camera.position.y < lab.player.position.y + lab.athlete.build.height, "Camera remains below athlete head")
		check(lab.camera_rig.facing_yaw == facing and lab.camera_rig.view_pitch == loft, "Automatic framing never changes facing or loft")
		var radius := Vector2(lab.camera.position.x - lab.player.position.x, lab.camera.position.z - lab.player.position.z).length()
		if offset.z == -12:
			far_radius = radius
		if offset.y == 20:
			check(radius < far_radius * 0.4 and lab.camera_rig.ball_frame_screen_y > 0.88, "Extreme overhead view moves underneath and crops to upper body/head")
	var old: Vector3 = lab.camera.position
	lab.player.position += Vector3(1, 2, 0)
	lab.ball.position += Vector3(1, 2, 0)
	lab.camera_rig.update(0)
	check((lab.camera.position - old).distance_to(Vector3(1, 2, 0)) < 0.001, "Automatic camera stays anchored during player movement and jumping")
	# Physical net collision must still preserve the low athlete screen framing.
	lab.player.position = Vector3(0, 0.03, 1)
	lab.ball.position = Vector3(0, 5, 5)
	lab.camera_rig.update(2)
	var athlete_pixel: Vector2 = lab.camera.unproject_position(lab.camera_rig.ball_frame_pivot)
	check(absf(athlete_pixel.x - 720) < 0.1 and athlete_pixel.y <= 846.1, "Near-net framing keeps athlete visible below ball")
	var regular_target: Vector3 = lab.BallFraming.look_target(lab.camera.position, lab.camera_rig.ball_frame_pivot, lab.camera_rig.ball_frame_screen_y, 65.0)
	var actual_rotation: Vector3 = lab.camera.rotation
	var actual_ball_y: float = lab.camera.unproject_position(lab.ball.position).y
	lab.camera.look_at(regular_target)
	check(absf(actual_ball_y - 450) <= absf(lab.camera.unproject_position(lab.ball.position).y - 450) + 0.1, "Near-net allowance moves ball toward screen center")
	lab.camera.rotation = actual_rotation
	print("BALL PAIR FRAMING: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
