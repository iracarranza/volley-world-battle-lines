extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func toss_trial(lab: Node3D, wait_time: float) -> Dictionary:
	lab._reset()
	lab.view_pitch = 0.27
	lab._update_aim()
	lab._update_pose()
	lab._update_camera(2)
	lab._serve()
	for frame in range(roundi(wait_time * 120)):
		lab._tick_ball(1.0 / 120)
	lab._serve()
	for frame in range(40):
		if lab.serve.state == lab.serve.State.FLIGHT or not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120)
	return lab.serve.evidence
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab._serve()
	check(lab.serve.tossing() and lab.ball_active and not lab.outgoing and lab.ball_velocity.y > 0, "First E tosses without automatically serving")
	check(not lab.training_bots.away_enabled[0], "Toss does not spawn court receiver yet")
	var early: Dictionary = await toss_trial(lab, 0.15)
	var late: Dictionary = await toss_trial(lab, 0.6)
	check(not early.is_empty() and not late.is_empty(), "Both early and late swings can meet the physical toss")
	if not early.is_empty() and not late.is_empty():
		check(early.incoming_velocity.y > 0 and late.incoming_velocity.y < 0 and early.angle_degrees > late.angle_degrees + 8, "Identical aim produces higher arc on rising contact")
		check(early.point.distance_to(early.hand) <= lab.serve.HAND_RADIUS + lab.Geometry.BALL_RADIUS + 0.06, "Serve meets actual striking hand")
		check(lab.training_bots.away_enabled[0], "Successful main-Net strike enables away receiver")
	lab._reset()
	lab._serve()
	for frame in range(18):
		lab._tick_ball(1.0 / 120)
	lab.player.position.x += 4
	lab._update_pose()
	lab._serve()
	for frame in range(35):
		lab._tick_ball(1.0 / 120)
	check(lab.serve.evidence.is_empty() and not lab.outgoing, "Second E cannot hit a ball outside the hand's sweep")
	lab._reset()
	lab.player.position = Vector3(-29, 3.5, 4)
	lab._serve()
	check(lab.serve.tossing() and lab.ball.position.y > 4, "Serving works from elevated map locations")
	lab._reset()
	lab.locked_action = 1
	lab.armed = true
	lab._confirm_action()
	lab._toggle_debug_volumes()
	check(not lab.hurtbox_root.visible and not lab.body_collision_view.visible and not lab.reach_ring.visible, "Debug toggle hides player volumes")
	check(not lab.training_bots.contact_boxes[0].visible, "Debug toggle hides bot volumes")
	lab._toggle_debug_volumes()
	check(lab.hurtbox_root.visible and lab.training_bots.contact_boxes[0].visible, "Debug toggle restores volumes without losing confirmation")
	lab._reset()
	lab._update_camera(2)
	check(absf(lab.camera.position.distance_to(lab.camera_anchor) - lab.ATHLETE_CAMERA_DISTANCE) < 0.01, "Athlete View uses shorter fixed distance")
	var position: Vector3 = lab.camera.position
	lab.ball_active = true
	lab.ball.position = lab.player.position + Vector3(0, 12, -2)
	lab._set_camera_mode(lab.ViewMode.BALL)
	lab._update_camera(2)
	check(lab.camera.is_position_in_frustum(lab.ball.position), "Ball View frames high ball automatically")
	lab.ball.position.x += 10
	lab._rotate_view(Vector2(0, -50))
	lab._update_camera(2)
	check(absf(lab.camera.unproject_position(lab.ball_frame_pivot).x - lab.get_viewport().get_visible_rect().size.x * 0.5) < 0.1, "Ball View retains athlete at bottom center")
	check(lab.pepper.actors.size() == 3 and lab.pepper.actors[0].position.y == 3.5, "Three opponents include box level 3")
	for index in range(3):
		lab._reset()
		var spot: Vector3 = lab.pepper.SPOTS[index]
		lab.player.position = spot + Vector3(0, 0, 8)
		lab.serve.state = lab.serve.State.FLIGHT
		lab.serve.main_court = false
		lab.ball_active = true
		lab.ball.position = spot + Vector3(0, 4, -4)
		lab.ball_velocity = Vector3(0, 0, 6)
		for frame in range(900):
			if not lab.ball_active or lab.pepper.exchanges > 0:
				break
			lab._tick_ball(1.0 / 120)
		check(lab.pepper.partner == index, "Serve entering each opponent radius starts Pepper")
		check(lab.pepper.exchanges == 1 and lab.ball_active, "Each Pepper partner receives, sets and returns a physical ball")
		check(lab.station.earned_xp == 0 and lab.drills.earned_xp == 0, "Pepper awards no rewards")
		check(lab.selected == 1 and lab.pepper.player_action == 1, "Partner receive requires the player to Set")
	for index in range(3):
		lab._reset()
		var spot: Vector3 = lab.pepper.SPOTS[index]
		lab.player.position = Vector3(spot.x, 0.03, spot.z + 9)
		lab.camera_mode = lab.ViewMode.ATHLETE
		lab.view_yaw = 0
		lab.facing_yaw = 0
		lab.view_pitch = 1.0 if index == 0 else -0.12
		lab._update_aim()
		lab._update_pose()
		lab._update_camera(2)
		lab._serve()
		for frame in range(18):
			lab._tick_ball(1.0 / 120)
		lab._serve()
		for frame in range(1000):
			if not lab.ball_active or lab.pepper.exchanges > 0:
				break
			lab._tick_ball(1.0 / 120)
		check(lab.pepper.partner == index and lab.pepper.exchanges > 0, "Actual toss/strike can target each scattered partner")
	print("SERVE / PEPPER / CAMERA: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
