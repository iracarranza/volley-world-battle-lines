extends RefCounted

# Frame the athlete low in the image and the ball above them. As a receive
# approaches overhead, raise the athlete reference toward the head and move
# the camera closer underneath, deliberately allowing the lower body to crop.
static func frame(feet: Vector3, height: float, ball: Vector3, current_offset: Vector3, distance: float, dt: float) -> Dictionary:
	var delta := ball - (feet + Vector3.UP * height * 0.55)
	var horizontal := Vector2(delta.x, delta.z).length()
	var elevation := atan2(delta.y, horizontal)
	var close := 1.0 - smoothstep(1.5, 10.0, horizontal)
	var overhead := smoothstep(deg_to_rad(20.0), deg_to_rad(70.0), elevation) * close
	var net_allowance := (1.0 - smoothstep(1.0, 3.5, absf(feet.z))) * (1.0 - smoothstep(4.75, 6.0, absf(feet.x)))
	var desired_distance := lerpf(distance, lerpf(0.8, 2.0, net_allowance), overhead)
	var away := Vector3(current_offset.x, 0, current_offset.z).normalized()
	if away.length_squared() < 0.001:
		away = Vector3.BACK
	# Hold heading while the ball is directly overhead; do not flip on tiny X/Z changes.
	if horizontal > 0.65:
		var desired_away := Vector3(-delta.x, 0, -delta.z).normalized()
		var yaw := atan2(away.x, away.z)
		yaw = lerp_angle(yaw, atan2(desired_away.x, desired_away.z), 1 - exp(-dt * 7))
		away = Vector3(sin(yaw), 0, cos(yaw))
	var old_distance := Vector2(current_offset.x, current_offset.z).length()
	var radius := lerpf(old_distance, desired_distance, 1 - exp(-dt * 8))
	var camera_height := height * 0.65
	var vertical := lerpf(current_offset.y, camera_height - height * 0.55, 1 - exp(-dt * 8))
	var offset := away * radius + Vector3.UP * vertical
	var pivot := feet + Vector3.UP * height * lerpf(0.52, 0.95, overhead)
	return {"offset": offset, "pivot": pivot, "screen_y": lerpf(0.78, 0.91, overhead), "overhead": overhead}

static func look_target(position: Vector3, pivot: Vector3, screen_y: float, fov: float) -> Vector3:
	var to_pivot := pivot - position
	var horizontal := Vector3(to_pivot.x, 0, to_pivot.z)
	var elevation := atan2(to_pivot.y, maxf(horizontal.length(), 0.001))
	var relative_angle := atan((1.0 - 2.0 * screen_y) * tan(deg_to_rad(fov) * 0.5))
	var pitch := clampf(elevation - relative_angle, deg_to_rad(-85), deg_to_rad(87))
	return position + (horizontal.normalized() * cos(pitch) + Vector3.UP * sin(pitch)) * 5.0

# Near the net, share vertical framing with the ball instead of insisting on
# the normal athlete screen position. Keep the athlete reference on screen.
static func net_look_target(position: Vector3, pivot: Vector3, ball: Vector3, target: Vector3, allowance: float, fov: float) -> Vector3:
	var direction := (target - position).normalized()
	var horizontal := Vector3(direction.x, 0, direction.z).normalized()
	var pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
	var ball_delta := ball - position
	var ball_pitch := atan2(ball_delta.y, maxf(Vector2(ball_delta.x, ball_delta.z).length(), 0.001))
	var pivot_delta := pivot - position
	var pivot_pitch := atan2(pivot_delta.y, maxf(Vector2(pivot_delta.x, pivot_delta.z).length(), 0.001))
	var max_pitch := pivot_pitch + atan(0.88 * tan(deg_to_rad(fov) * 0.5))
	pitch = minf(lerpf(pitch, ball_pitch, allowance), max_pitch)
	return position + (horizontal * cos(pitch) + Vector3.UP * sin(pitch)) * 5.0
