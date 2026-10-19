extends RefCounted
const Influence := preload("res://scripts/directional_influence.gd")

static func resolve(base: Vector3, assessment: Dictionary, world_input: Vector3, facing: Vector3, keep_intent: bool = false) -> Dictionary:
	facing = Vector3(facing.x, 0, facing.z).normalized()
	if facing.length_squared() < 0.001:
		facing = Vector3.FORWARD
	var offset := float(assessment.get("spike_lateral_offset", 0.0))
	var geometry_degrees := clampf(offset * 28.0, -20.0, 20.0)
	if assessment.get("rescue", false):
		geometry_degrees = 0.0
	var facing_yaw := atan2(-facing.x, -facing.z)
	var horizontal := Vector2(base.x, base.z).length()
	var intent_degrees := 0.0
	if keep_intent and horizontal > 0.001:
		intent_degrees = clampf(rad_to_deg(wrapf(atan2(-base.x, -base.z) - facing_yaw, -PI, PI)), -15, 15)
	var direction := facing.rotated(Vector3.UP, deg_to_rad(intent_degrees - geometry_degrees))
	var biased := direction * horizontal + Vector3.UP * base.y
	var result := Influence.resolve(biased, 2, world_input, facing, float(assessment.get("quality", 0))).duplicate(true)
	var lateral: float = result.axes.x
	var agreement := signf(geometry_degrees) * lateral
	var severity := clampf(absf(offset) / 0.70, 0, 1)
	var speed_factor := 1.0
	if not assessment.get("rescue", false):
		speed_factor += agreement * severity * (0.18 if agreement >= 0 else 0.22)
		if agreement >= 0:
			speed_factor = minf(speed_factor, maxf(1.0, 1.0 / maxf(float(assessment.get("strength", 1.0)), 0.1)))
		# Contrary influence corrects toward facing without crossing into an
		# unrelated opposite-side swing once the geometry bias is cancelled.
		if agreement < 0 and absf(intent_degrees) < 0.001:
			var current: Vector3 = result.velocity
			var yaw := rad_to_deg(wrapf(atan2(-current.x, -current.z) - facing_yaw, -PI, PI))
			var corrected := clampf(yaw, minf(0, -geometry_degrees), maxf(0, -geometry_degrees))
			var corrected_direction := facing.rotated(Vector3.UP, deg_to_rad(corrected))
			result["velocity"] = corrected_direction * Vector2(current.x, current.z).length() + Vector3.UP * current.y
	result["velocity"] = Vector3(result.velocity) * speed_factor
	result["geometry_yaw_degrees"] = -geometry_degrees
	result["geometry_lateral_offset"] = offset
	result["speed_factor"] = speed_factor
	result["shot_yaw_radians"] = wrapf(atan2(-result.velocity.x, -result.velocity.z) - facing_yaw, -PI, PI)
	result.make_read_only()
	return result
