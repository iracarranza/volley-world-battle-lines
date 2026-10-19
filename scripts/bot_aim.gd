extends RefCounted

# Deliberate execution scatter, separate from tracking/physique/contact quality.
# Error is measured at the ballistic floor intercept; gravity/vertical pace stay intact.
const MAX_ERROR_METERS := 2.5
static func apply(origin: Vector3, velocity: Vector3, accuracy: float, gravity: float, random: RandomNumberGenerator, preserve_heading: bool = false) -> Dictionary:
	accuracy = clampf(accuracy, 0, 100)
	var output := velocity
	var offset := Vector3.ZERO
	var duration := (velocity.y + sqrt(maxf(0, velocity.y * velocity.y + 2 * gravity * maxf(origin.y - 0.105, 0)))) / gravity
	duration = maxf(duration, 0.15)
	if accuracy < 100:
		var radius := MAX_ERROR_METERS * (1.0 - accuracy / 100.0)
		var forward := Vector3(velocity.x, 0, velocity.z).normalized()
		if forward.length_squared() < 0.001:
			forward = Vector3.FORWARD
		if preserve_heading:
			var speed := maxf(0.1, Vector2(velocity.x, velocity.z).length() + random.randf_range(-radius, radius) / duration)
			output = forward * speed + Vector3.UP * velocity.y
			offset = (output - velocity) * duration
		else:
			var angle := random.randf_range(0, TAU)
			var distance := sqrt(random.randf()) * radius
			offset = (forward.cross(Vector3.UP) * cos(angle) + forward * sin(angle)) * distance
			output += offset / duration
	var result := {"velocity": output, "offset": offset, "accuracy": accuracy, "floor_time": duration}
	result.make_read_only()
	return result
