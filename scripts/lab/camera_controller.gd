class_name LabCamera
extends RefCounted

## Owns camera rig state. LabSession schedules updates and composes peers.
const BallFraming := preload("res://scripts/ball_camera_framing.gd")
enum ViewMode { ATHLETE, BALL }
const REFERENCE_HEIGHT := 1.86

var lab: LabSession
var ball_frame_pivot := Vector3.ZERO
var ball_frame_screen_y := 0.78
var ball_movement_yaw := 0.0
var ball_camera_offset := Vector3.ZERO
var ball_camera_offset_ready := false
var ball_view_entry_pitch := 0.0
var camera_mode := ViewMode.ATHLETE
var camera_anchor := Vector3.ZERO
var camera_anchor_ready := false
var camera_transition := 0.0
var view_yaw := 0.0
var view_pitch := -0.12
var facing_yaw := 0.0
var ball_orbit := 0.0
var _camera_frame_usec := 0

func rotate_view(relative: Vector2) -> void:
	var yaw_delta := -relative.x * lab.camera_tuning.mouse_sensitivity
	if camera_mode == ViewMode.ATHLETE:
		view_yaw += yaw_delta
		# Looking in the air is independent of committed athlete aim.
		if lab.motion.jumped:
			var locked_yaw := atan2(-lab.motion.airborne_aim.x, -lab.motion.airborne_aim.z)
			view_yaw = locked_yaw + clampf(wrapf(view_yaw - locked_yaw, -PI, PI), -0.65, 0.65)
	else:
		# Ball tracking owns the camera; mouse yaw owns the athlete.
		if not lab.motion.jumped or (lab.confirm_window <= 0 and lab.committed_intent.is_empty()):
			facing_yaw += yaw_delta
			if lab.motion.jumped:
				lab.motion.airborne_aim = Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	view_pitch = clampf(view_pitch - relative.y * lab.camera_tuning.mouse_sensitivity, lab.camera_tuning.minimum_pitch, lab.camera_tuning.maximum_pitch)
	# Apply the exact mouse delta immediately; smoothing belongs to camera translation.
	update_aim()
	lab.animation.update()

func set_mode(mode: int) -> void:
	if not camera_anchor_ready:
		update(0)
	camera_mode = mode
	camera_transition = 0.18
	if camera_mode == ViewMode.ATHLETE:
		view_yaw = facing_yaw
	else:
		ball_movement_yaw = view_yaw
		ball_orbit = 0.0
		ball_camera_offset = lab.camera.position - (lab.player.position + Vector3.UP * float(lab.athlete.build.height) * 0.55)
		ball_camera_offset_ready = true
		ball_view_entry_pitch = view_pitch
	lab._message("ATHLETE VIEW / mouse controls facing" if camera_mode == ViewMode.ATHLETE else "BALL VIEW / camera tracks ball · mouse turns athlete / adjusts loft")

func movement_direction(local: Vector3) -> Vector3:
	if camera_mode == ViewMode.BALL and lab.ball_active:
		var toward_ball := Vector3(lab.ball.position.x - lab.player.position.x, 0, lab.ball.position.z - lab.player.position.z)
		if toward_ball.length_squared() > 0.001:
			ball_movement_yaw = atan2(-toward_ball.x, -toward_ball.z)
	var yaw := view_yaw if camera_mode == ViewMode.ATHLETE else ball_movement_yaw
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	return (right * local.x - forward * local.z).normalized()

func update_aim() -> void:
	if lab.is_benched():
		lab.aim_marker.hide()
		lab.reach_ring.hide()
		lab.facing_arrow.hide()
		return
	lab.aim_marker.visible = lab.debug_volumes_visible
	lab.reach_ring.visible = lab.debug_volumes_visible
	if not lab.motion.jumped:
		if camera_mode == ViewMode.ATHLETE:
			facing_yaw = view_yaw
		var facing := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
		lab.aim = Vector3(lab.player.position.x, 0, lab.player.position.z) + facing * 9.0
	else:
		lab.aim = Vector3(lab.player.position.x, 0, lab.player.position.z) + lab.motion.airborne_aim * 9.0
	lab.aim_marker.position = Vector3(lab.aim.x, 0.035, lab.aim.z)
	lab.reach_ring.position = Vector3(lab.player.position.x, 0.04, lab.player.position.z)
	if is_instance_valid(lab.facing_arrow):
		lab.facing_arrow.position = lab.player.position + Vector3.UP * 0.045
		lab.facing_arrow.rotation.y = lab._contact_yaw()
		lab.facing_arrow.visible = camera_mode == ViewMode.BALL

func update(dt: float) -> void:
	if lab.is_benched():
		lab.bench.update_camera(dt)
		return
	var stable_target := lab.player.position + Vector3.UP * float(lab.athlete.build.height) * 0.55
	if not camera_anchor_ready:
		camera_anchor = stable_target
		camera_anchor_ready = true
	# Ball View is attached to the athlete, not a lagging world-space pivot.
	camera_anchor = stable_target if camera_mode == ViewMode.BALL else camera_anchor.lerp(stable_target, 1.0 - exp(-dt * lab.camera_tuning.follow_response))
	var anchor := camera_anchor
	var forward := Vector3(-sin(view_yaw), 0, -cos(view_yaw))
	var height_scale := float(lab.athlete.build.height) / REFERENCE_HEIGHT
	var orbit_pitch := view_pitch - 0.27
	var floor_pitch := asin(clampf((anchor.y - lab.camera_tuning.floor_clearance) / (lab.camera_tuning.distance * height_scale), -0.99, 0.99))
	var position_pitch := minf(orbit_pitch, floor_pitch)
	var orbit_forward := forward * cos(position_pitch) + Vector3.UP * sin(position_pitch) * height_scale
	var desired_position := anchor - orbit_forward * lab.camera_tuning.distance
	var look_target := anchor
	if orbit_pitch > floor_pitch:
		look_target = desired_position + (forward * cos(orbit_pitch) + Vector3.UP * sin(orbit_pitch)) * lab.camera_tuning.distance
	if camera_mode == ViewMode.BALL:
		if not ball_camera_offset_ready:
			ball_camera_offset = desired_position - anchor
			ball_camera_offset_ready = true
			ball_view_entry_pitch = view_pitch
		var feet := anchor - Vector3.UP * float(lab.athlete.build.height) * 0.55
		var focus := lab.ball.position if lab.ball_active else feet + Vector3(-sin(ball_movement_yaw), 0, -cos(ball_movement_yaw)) * 8 + Vector3.UP * float(lab.athlete.build.height)
		var frame := BallFraming.frame(feet, float(lab.athlete.build.height), focus, ball_camera_offset, lab.camera_tuning.distance, dt)
		ball_camera_offset = frame.offset
		ball_frame_pivot = frame.pivot
		ball_frame_screen_y = frame.screen_y
		desired_position = anchor + ball_camera_offset
		look_target = BallFraming.look_target(desired_position, ball_frame_pivot, ball_frame_screen_y, lab.camera_tuning.field_of_view)
	var query := PhysicsRayQueryParameters3D.create(anchor, desired_position)
	query.exclude = [lab.player.get_rid()]
	var hit := lab.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired_position = hit.position + hit.normal * 0.25
	desired_position.y = maxf(lab.camera_tuning.floor_clearance, desired_position.y)
	if camera_mode == ViewMode.BALL:
		look_target = BallFraming.look_target(desired_position, ball_frame_pivot, ball_frame_screen_y, lab.camera_tuning.field_of_view)
		if lab.ball_active:
			var net_allowance := (1.0 - smoothstep(1.0, 3.5, absf(lab.player.position.z))) * (1.0 - smoothstep(4.75, 6.0, absf(lab.player.position.x)))
			look_target = BallFraming.net_look_target(desired_position, ball_frame_pivot, lab.ball.position, look_target, net_allowance, lab.camera_tuning.field_of_view)
	camera_transition = maxf(0, camera_transition - dt)
	# Ball View automatically positions around the athlete/ball pair; mouse controls athlete aim.
	lab.camera.position = desired_position
	lab.camera.fov = lab.camera_tuning.field_of_view
	if lab.camera.position.distance_squared_to(look_target) > 0.01:
		var desired_rotation := Transform3D(Basis.IDENTITY, lab.camera.position).looking_at(look_target, Vector3.UP).basis.get_rotation_quaternion()
		lab.camera.quaternion = desired_rotation
	update_edge_indicator()

func update_edge_indicator() -> void:
	if not is_instance_valid(lab.hud.ball_edge_indicator):
		return
	lab.hud.ball_edge_indicator.visible = camera_mode == ViewMode.BALL and lab.ball_active and not lab.camera.is_position_in_frustum(lab.ball.position)
	if not lab.hud.ball_edge_indicator.visible:
		return
	var local := lab.camera.to_local(lab.ball.position)
	var direction := Vector2(local.x, -local.y).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.UP
	var half := lab.get_viewport().get_visible_rect().size * 0.5
	var scale := minf((half.x - 60) / maxf(absf(direction.x), 0.001), (half.y - 40) / maxf(absf(direction.y), 0.001))
	lab.hud.ball_edge_indicator.position = half + direction * scale - Vector2(30, 10)
	lab.hud.ball_edge_indicator.text = "↑ BALL" if direction.y < -0.5 else ("BALL ↓" if direction.y > 0.5 else ("BALL →" if direction.x > 0 else "← BALL"))


func _init(session: LabSession) -> void:
	lab = session
