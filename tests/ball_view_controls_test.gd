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
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab._update_aim()
	lab._update_camera(2)
	var entry: Vector3 = lab.camera.position
	var facing: float = lab.facing_yaw
	var loft: float = lab.view_pitch
	lab._set_camera_mode(lab.ViewMode.BALL)
	lab.ball_active = true
	var movement: Vector3 = lab._movement_direction(Vector3.FORWARD)
	for ball_offset in [Vector3(3, 8, -2), Vector3(-5, 3, 8), Vector3(0, 15, 0)]:
		lab.ball.position = lab.player.position + ball_offset
		lab._update_aim()
		lab._update_camera(2)
		check(lab.camera.unproject_position(lab.ball_frame_pivot).x > 719 and lab.camera.unproject_position(lab.ball_frame_pivot).x < 721, "Automatic framing keeps athlete horizontally centered")
		check(lab.camera.is_position_in_frustum(lab.ball.position), "Ball is framed including above and behind")
		check(lab.facing_yaw == facing and lab.view_pitch == loft, "Tracking cannot rotate athlete or alter contact loft")
		var toward := Vector3(ball_offset.x, 0, ball_offset.z)
		var current: Vector3 = lab._movement_direction(Vector3.FORWARD)
		if toward.length_squared() > 0.001:
			check(current.distance_to(toward.normalized()) < 0.001, "Forward tracks horizontal athlete-to-ball direction")
		else:
			check(current.distance_to(movement) < 0.001, "Overhead ball retains last horizontal movement reference")
		check(lab._movement_direction(Vector3.BACK).distance_to(-current) < 0.001, "Backward moves away from ball")
		check(lab._movement_direction(Vector3.RIGHT).distance_to(current.cross(Vector3.UP)) < 0.001, "Right strafes perpendicular to ball")
		check(lab._movement_direction(Vector3.LEFT).distance_to(-current.cross(Vector3.UP)) < 0.001, "Left strafes perpendicular to ball")
		movement = current
	lab._rotate_view(Vector2(200, -80))
	lab._update_camera(2)
	check(absf(lab.facing_yaw - facing + 200 * lab.LOOK_SENSITIVITY) < 0.0001, "Mouse turns athlete at normal sensitivity")
	check(lab.view_pitch > loft, "Mouse vertical changes deliberate loft")
	check(lab.facing_yaw != facing, "Aiming remains independent of automatic framing")
	check(lab._movement_direction(Vector3.FORWARD).distance_to(movement) < 0.001, "Mouse aiming cannot redirect ball-relative movement")
	check(lab.facing_arrow.visible and absf(lab.facing_arrow.rotation.y - lab.facing_yaw) < 0.001, "Facing arrow represents independent heading")
	var deliberate_loft: float = lab.view_pitch
	lab.ball.position.y += 10
	lab._update_camera(2)
	check(lab.view_pitch == deliberate_loft, "High ball cannot increase shot loft automatically")
	var offset: Vector3 = lab.camera.position - lab.camera_anchor
	var camera_before_move: Vector3 = lab.camera.position
	var displacement := Vector3(2, 3, 1)
	lab.player.position += displacement
	lab._update_camera(0)
	check((lab.camera.position - camera_before_move).distance_to(displacement) < 0.001, "Ball View follows the exact player displacement within one frame")
	check((lab.camera.position - lab.camera_anchor).distance_to(offset) < 0.001, "Camera follows translation/jump with fixed offset")
	lab.jumped = true
	lab.airborne_action = 1
	lab.airborne_aim = Vector3(-sin(lab.facing_yaw), 0, -cos(lab.facing_yaw))
	var airborne_before: Vector3 = lab.airborne_aim
	lab._rotate_view(Vector2(80, 0))
	check(lab.airborne_aim.distance_to(airborne_before) > 0.1, "Jump setter can orient before confirming contact")
	lab.locked_action = 1
	lab.locked_charge = 0.6
	lab._confirm_action()
	var committed: Vector3 = lab.airborne_aim
	lab._rotate_view(Vector2(100, 0))
	check(lab.airborne_aim == committed, "Confirmed airborne contact retains committed direction")
	lab.jumped = false
	var exit_facing: float = lab.facing_yaw
	lab._set_camera_mode(lab.ViewMode.ATHLETE)
	lab._update_aim()
	check(lab.facing_yaw == exit_facing and lab.view_yaw == exit_facing, "Returning to Athlete View preserves chosen facing")
	lab._update_aim()
	check(not lab.facing_arrow.visible, "Ball View facing indicator hides in Athlete View")
	lab._reset()
	lab._update_aim()
	lab._update_camera(2)
	lab._set_camera_mode(lab.ViewMode.BALL)
	lab._rotate_view(Vector2(200, 0))
	var serve_facing := Vector3(-sin(lab.facing_yaw), 0, -cos(lab.facing_yaw))
	lab._serve()
	for frame in range(18):
		lab._tick_ball(1.0 / 120)
		lab._update_camera(1.0 / 120)
	lab._serve()
	for frame in range(40):
		if not lab.serve.evidence.is_empty():
			break
		lab._tick_ball(1.0 / 120)
		lab._update_camera(1.0 / 120)
	check(not lab.serve.evidence.is_empty(), "Ball View can physically toss and strike")
	if not lab.serve.evidence.is_empty():
		var outgoing: Vector3 = lab.serve.evidence.outgoing_velocity
		outgoing.y = 0
		check(outgoing.normalized().dot(serve_facing) > 0.999, "Ball View serve follows deliberate facing rather than tracking camera")
	print("BALL VIEW CONTROLS: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
