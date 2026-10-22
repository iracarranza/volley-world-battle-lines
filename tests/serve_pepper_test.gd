extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
# `offset` is seconds from the ideal press: the swing takes Swing.PEAK to reach the point the falling toss passes through the hurtbox centre.
func toss_trial(lab: Node3D, offset: float) -> Dictionary:
	lab._reset()
	lab.camera_rig.view_pitch = 0.27
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab.camera_rig.update(2)
	lab._serve()
	var wait_time: float = lab.serve.time_to_center() - lab.serve.Swing.PEAK + offset
	for frame in range(roundi(wait_time * 120)):
		lab._tick_ball(1.0 / 120)
	lab._serve()
	for frame in range(60):
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
	check(not lab.training_bots.settings[(0) + 4].enabled, "Toss does not spawn court receiver yet")
	var early: Dictionary = await toss_trial(lab, -0.06)
	var late: Dictionary = await toss_trial(lab, 0.0)
	check(not early.is_empty() and not late.is_empty(), "Both early and late swings can meet the physical toss")
	if not early.is_empty() and not late.is_empty():
		check(early.incoming_velocity.y > late.incoming_velocity.y and early.angle_degrees > late.angle_degrees + 2, "Identical aim produces a higher arc on a ball struck earlier in its fall")
		check(early.has("zone") and early.has("form") and late.has("zone"), "A serve is struck in the serving hurtbox and graded by zone and swing time")
		check(lab.training_bots.settings[(0) + 4].enabled, "Successful main-Net strike enables away receiver")
	lab._reset()
	lab._serve()
	for frame in range(18):
		lab._tick_ball(1.0 / 120)
	lab.player.position.x += 4
	lab.animation.update()
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
	lab.hud.toggle_debug_volumes()
	check(not lab.hurtbox_root.visible and not lab.body_collision_view.visible and not lab.reach_ring.visible, "Debug toggle hides player volumes")
	check(not lab.training_bots.contact_boxes[0].visible, "Debug toggle hides bot volumes")
	lab.hud.toggle_debug_volumes()
	check(lab.hurtbox_root.visible and lab.training_bots.contact_boxes[0].visible, "Debug toggle restores volumes without losing confirmation")
	lab._reset()
	lab.camera_rig.update(2)
	check(absf(lab.camera.position.distance_to(lab.camera_rig.camera_anchor) - lab.camera_tuning.distance) < 0.01, "Athlete View uses shorter fixed distance")
	var position: Vector3 = lab.camera.position
	lab.ball_active = true
	lab.ball.position = lab.player.position + Vector3(0, 12, -2)
	lab.camera_rig.set_mode(lab.ViewMode.BALL)
	lab.camera_rig.update(2)
	check(lab.camera.is_position_in_frustum(lab.ball.position), "Ball View frames high ball automatically")
	lab.ball.position.x += 10
	lab.camera_rig.rotate_view(Vector2(0, -50))
	lab.camera_rig.update(2)
	check(absf(lab.camera.unproject_position(lab.camera_rig.ball_frame_pivot).x - lab.get_viewport().get_visible_rect().size.x * 0.5) < 0.1, "Ball View retains athlete at bottom center")
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
		lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
		lab.camera_rig.view_yaw = 0
		lab.camera_rig.facing_yaw = 0
		lab.camera_rig.view_pitch = 0.7 if index == 0 else -0.12
		lab.camera_rig.update_aim()
		lab.animation.update()
		lab.camera_rig.update(2)
		lab._serve()
		for frame in range(roundi((lab.serve.time_to_center() - lab.serve.Swing.PEAK) * 120)): # the arm takes Swing.PEAK to reach the ball
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
