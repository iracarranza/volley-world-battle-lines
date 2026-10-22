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
	lab.camera_rig.update_aim()
	lab.camera_rig.update(2)
	var entry: Vector3 = lab.camera.position
	var facing: float = lab.camera_rig.facing_yaw
	var loft: float = lab.camera_rig.view_pitch
	lab.camera_rig.set_mode(lab.ViewMode.BALL)
	lab.ball_active = true
	var movement: Vector3 = lab.camera_rig.movement_direction(Vector3.FORWARD)
	for ball_offset in [Vector3(3, 8, -2), Vector3(-5, 3, 8), Vector3(0, 15, 0)]:
		lab.ball.position = lab.player.position + ball_offset
		lab.camera_rig.update_aim()
		lab.camera_rig.update(2)
		check(lab.camera.unproject_position(lab.camera_rig.ball_frame_pivot).x > 719 and lab.camera.unproject_position(lab.camera_rig.ball_frame_pivot).x < 721, "Automatic framing keeps athlete horizontally centered")
		check(lab.camera.is_position_in_frustum(lab.ball.position), "Ball is framed including above and behind")
		check(lab.camera_rig.facing_yaw == facing and lab.camera_rig.view_pitch == loft, "Tracking cannot rotate athlete or alter contact loft")
		var toward := Vector3(ball_offset.x, 0, ball_offset.z)
		var current: Vector3 = lab.camera_rig.movement_direction(Vector3.FORWARD)
		if toward.length_squared() > 0.001:
			check(current.distance_to(toward.normalized()) < 0.001, "Forward tracks horizontal athlete-to-ball direction")
		else:
			check(current.distance_to(movement) < 0.001, "Overhead ball retains last horizontal movement reference")
		check(lab.camera_rig.movement_direction(Vector3.BACK).distance_to(-current) < 0.001, "Backward moves away from ball")
		check(lab.camera_rig.movement_direction(Vector3.RIGHT).distance_to(current.cross(Vector3.UP)) < 0.001, "Right strafes perpendicular to ball")
		check(lab.camera_rig.movement_direction(Vector3.LEFT).distance_to(-current.cross(Vector3.UP)) < 0.001, "Left strafes perpendicular to ball")
		movement = current
	lab.camera_rig.rotate_view(Vector2(200, -80))
	lab.camera_rig.update(2)
	check(absf(lab.camera_rig.facing_yaw - facing + 200 * lab.camera_tuning.mouse_sensitivity) < 0.0001, "Mouse turns athlete at normal sensitivity")
	check(lab.camera_rig.view_pitch > loft, "Mouse vertical changes deliberate loft")
	check(lab.camera_rig.facing_yaw != facing, "Aiming remains independent of automatic framing")
	check(lab.camera_rig.movement_direction(Vector3.FORWARD).distance_to(movement) < 0.001, "Mouse aiming cannot redirect ball-relative movement")
	check(lab.facing_arrow.visible and absf(lab.facing_arrow.rotation.y - lab.camera_rig.facing_yaw) < 0.001, "Facing arrow represents independent heading")
	var deliberate_loft: float = lab.camera_rig.view_pitch
	lab.ball.position.y += 10
	lab.camera_rig.update(2)
	check(lab.camera_rig.view_pitch == deliberate_loft, "High ball cannot increase shot loft automatically")
	var offset: Vector3 = lab.camera.position - lab.camera_rig.camera_anchor
	var camera_before_move: Vector3 = lab.camera.position
	var displacement := Vector3(2, 3, 1)
	lab.player.position += displacement
	lab.camera_rig.update(0)
	check((lab.camera.position - camera_before_move).distance_to(displacement) < 0.001, "Ball View follows the exact player displacement within one frame")
	check((lab.camera.position - lab.camera_rig.camera_anchor).distance_to(offset) < 0.001, "Camera follows translation/jump with fixed offset")
	lab.motion.jumped = true
	lab.motion.airborne_action = 1
	lab.motion.airborne_aim = Vector3(-sin(lab.camera_rig.facing_yaw), 0, -cos(lab.camera_rig.facing_yaw))
	var airborne_before: Vector3 = lab.motion.airborne_aim
	lab.camera_rig.rotate_view(Vector2(80, 0))
	check(lab.motion.airborne_aim.distance_to(airborne_before) > 0.1, "Jump setter can orient before confirming contact")
	lab.locked_action = 1
	lab.locked_charge = 0.6
	lab._confirm_action()
	var committed: Vector3 = lab.motion.airborne_aim
	lab.camera_rig.rotate_view(Vector2(100, 0))
	check(lab.motion.airborne_aim == committed, "Confirmed airborne contact retains committed direction")
	lab.motion.jumped = false
	var exit_facing: float = lab.camera_rig.facing_yaw
	lab.camera_rig.set_mode(lab.ViewMode.ATHLETE)
	lab.camera_rig.update_aim()
	check(lab.camera_rig.facing_yaw == exit_facing and lab.camera_rig.view_yaw == exit_facing, "Returning to Athlete View preserves chosen facing")
	lab.camera_rig.update_aim()
	check(not lab.facing_arrow.visible, "Ball View facing indicator hides in Athlete View")
	lab._reset()
	lab.camera_rig.update_aim()
	lab.camera_rig.update(2)
	lab.camera_rig.set_mode(lab.ViewMode.BALL)
	lab.camera_rig.rotate_view(Vector2(200, 0))
	var serve_facing := Vector3(-sin(lab.camera_rig.facing_yaw), 0, -cos(lab.camera_rig.facing_yaw))
	lab._serve()
	for frame in range(roundi((lab.serve.time_to_center() - lab.serve.Swing.PEAK) * 120)): # the arm takes Swing.PEAK to reach the toss
		lab._tick_ball(1.0 / 120)
		lab.camera_rig.update(1.0 / 120)
	lab._serve()
	for frame in range(40):
		if not lab.serve.evidence.is_empty():
			break
		lab._tick_ball(1.0 / 120)
		lab.camera_rig.update(1.0 / 120)
	check(not lab.serve.evidence.is_empty(), "Ball View can physically toss and strike")
	if not lab.serve.evidence.is_empty():
		var outgoing: Vector3 = lab.serve.evidence.outgoing_velocity
		outgoing.y = 0
		check(outgoing.normalized().dot(serve_facing) > 0.999, "Ball View serve follows deliberate facing rather than tracking camera")
	print("BALL VIEW CONTROLS: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
