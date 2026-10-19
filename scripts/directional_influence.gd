extends RefCounted

const WINDOW := 0.080
const YAW_LIMITS := [12.0, 20.0, 15.0]
const RANGE_LIMITS := [0.10, 0.15]
var samples: Array[Dictionary] = []
var duration := 0.0

func clear() -> void:
	samples.clear()
	duration = 0.0

# World-space intended movement, never athlete velocity. Keep an exact trailing
# real-time window so varying simulation rates and MoC do not change input weight.
func sample(world_input: Vector3, real_dt: float) -> void:
	if real_dt <= 0:
		return
	world_input.y = 0
	samples.append({"input": world_input.limit_length(1.0), "duration": minf(real_dt, WINDOW)})
	duration += minf(real_dt, WINDOW)
	while duration > WINDOW and not samples.is_empty():
		var trim := minf(duration - WINDOW, float(samples[0].duration))
		samples[0].duration -= trim
		duration -= trim
		if float(samples[0].duration) < 0.000001:
			samples.pop_front()

func value() -> Vector3:
	var result := Vector3.ZERO
	for entry in samples:
		result += Vector3(entry.input) * float(entry.duration)
	# Unfilled history is neutral, preventing a one-frame flick from getting full DI.
	return (result / WINDOW).limit_length(1.0)

static func resolve(base: Vector3, action: int, world_input: Vector3, contact_forward: Vector3, quality: float) -> Dictionary:
	contact_forward.y = 0
	contact_forward = contact_forward.normalized() if contact_forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right := contact_forward.cross(Vector3.UP)
	world_input.y = 0
	world_input = world_input.limit_length(1.0)
	var axes := Vector2(world_input.dot(right), world_input.dot(contact_forward)).limit_length(1.0)
	var authority := clampf(quality, 0, 1)
	var output := base
	var yaw := 0.0
	var range_factor := 1.0
	var pitch_change := 0.0
	if action in [0, 1, 2] and axes.length_squared() > 0.0000001 and base.length_squared() > 0.0000001:
		yaw = -axes.x * float(YAW_LIMITS[action]) * authority
		output = base.rotated(Vector3.UP, deg_to_rad(yaw))
		if action in [0, 1]:
			range_factor = 1.0 + axes.y * float(RANGE_LIMITS[action]) * authority
			output.x *= range_factor
			output.z *= range_factor
		else:
			var horizontal := Vector3(output.x, 0, output.z)
			var pitch := atan2(output.y, horizontal.length())
			pitch_change = (-10.0 if axes.y >= 0 else -8.0) * axes.y * authority
			var new_pitch := clampf(pitch + deg_to_rad(pitch_change), deg_to_rad(-65.0), deg_to_rad(70.0))
			# Lateral-only influence must never clamp an otherwise unchanged arc.
			if absf(axes.y) > 0.000001:
				pitch_change = rad_to_deg(new_pitch - pitch)
				output = horizontal.normalized() * cos(new_pitch) * base.length() + Vector3.UP * sin(new_pitch) * base.length()
	var result := {"velocity": output, "world_input": world_input, "axes": axes, "authority": authority, "yaw_degrees": yaw, "range_factor": range_factor, "pitch_degrees": pitch_change}
	result.make_read_only()
	return result

# Bot intent uses the same maximum horizontal attack influence as player input.
static func constrain_attack(velocity: Vector3, facing_yaw: float) -> Vector3:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal < 0.0001:
		return velocity
	var desired_yaw := atan2(-velocity.x, -velocity.z)
	var offset := clampf(wrapf(desired_yaw - facing_yaw, -PI, PI), -deg_to_rad(YAW_LIMITS[2]), deg_to_rad(YAW_LIMITS[2]))
	return Vector3(-sin(facing_yaw + offset) * horizontal, velocity.y, -cos(facing_yaw + offset) * horizontal)
