extends RefCounted

const REFERENCE_HEIGHT := 1.86
const EDGE_ZONE := 0.78
const COLORS := {"CLEAN": Color("67f3a3"), "FAIR": Color("ffcf70"), "WEAK": Color("f69c69"), "SOUR SPOT": Color("ee617b")}
# A vertically extruded forward half-ellipse, not an ellipsoid. All dimensions
# scale uniformly with height; future Platform Quality profiles own proportions.
static func definition(height: float, dive: bool, platform_quality: float = 0.0) -> Dictionary:
	var scale := height / REFERENCE_HEIGHT
	return {"shape": "receive_fan", "receive_platform": true, "center": Vector3(0, 0.35 if dive else 0.95, -0.65) * scale, "size": Vector3(2.30, 1.10 if dive else 1.60, 1.85) * scale, "side_reach": 1.15 * scale, "forward_reach": 1.85 * scale, "edge_zone": EDGE_ZONE,"platform_quality":platform_quality}

static func contains(shape: Dictionary, local_ball: Vector3, ball_radius: float = 0.105) -> bool:
	# No rear grace: even a ball whose center is behind the body cannot be hit.
	if local_ball.z > 0:
		return false
	var x := local_ball.x / (float(shape.side_reach) + ball_radius)
	var front := -local_ball.z / (float(shape.forward_reach) + ball_radius)
	return x * x + front * front <= 1.0 and absf(local_ball.y - float(shape.center.y)) <= float(shape.size.y) * 0.5 + ball_radius

static func coordinates(shape: Dictionary, local_ball: Vector3) -> Vector3:
	return Vector3(local_ball.x / float(shape.side_reach), (local_ball.y - float(shape.center.y)) / (float(shape.size.y) * 0.5), (local_ball.z - float(shape.center.z)) / (float(shape.forward_reach) * 0.5))

static func posture(shape: Dictionary, local_ball: Vector3, speed: float) -> String:
	var side := absf(local_ball.x) / float(shape.side_reach)
	var front := maxf(-local_ball.z / float(shape.forward_reach), 0)
	var angle := absf(atan2(local_ball.x / float(shape.side_reach), maxf(front, 0.0001)))
	if side >= 0.40 and angle >= deg_to_rad(35):
		return "off-axis"
	if front >= 0.68:
		return "reaching"
	return "moving" if speed > 0.45 else "planted"

# Grading and pose are separate: a moving central pass can still be clean.
static func evaluate(shape: Dictionary, point: Vector3) -> Dictionary:
	var local_ball := point + Vector3(shape.center)
	var coord := coordinates(shape, local_ball)
	var front := -local_ball.z / float(shape.forward_reach)
	var radius := Vector2(coord.x, front).length()
	var angle := absf(rad_to_deg(atan2(coord.x, maxf(front, 0.0001))))
	var overlap := clampf(float(shape.get("platform_quality",0))/100.0,0,0.30)
	var graded_radius := maxf(0,radius-overlap)
	var graded_angle := maxf(0,angle-overlap*45.0)
	var graded_y := maxf(0,absf(coord.y)-overlap)
	var zone := "SOUR SPOT"
	var quality := 0.40
	if radius >= maxf(0,0.10-overlap) and graded_radius <= 0.56 and graded_angle <= 35 and graded_y <= 0.50:
		zone = "CLEAN"
		quality = 1.0
	elif graded_radius <= 0.75 and graded_angle <= 58 and graded_y <= 0.75:
		zone = "FAIR"
		quality = 0.84
	elif graded_radius <= 0.88 and graded_angle <= 72 and graded_y <= 0.90:
		zone = "WEAK"
		quality = 0.58
	var edge := absf(coord.x) >= EDGE_ZONE+overlap
	if edge:
		zone = "SOUR SPOT"
		quality = 0.40
	var contact_posture := posture(shape, local_ball, 0)
	return {"hit": true, "zone": zone, "quality": quality, "strength": 1.0, "edge": edge, "band": contact_posture.to_upper(), "posture": contact_posture, "platform_coord": coord}

static func redirect(base: Vector3, origin: Vector3, yaw: float, incoming: Vector3, assessment: Dictionary, gravity: float, floor_height: float = 0.105) -> Vector3:
	var coord: Vector3 = assessment.get("penalty_platform_coord",assessment.platform_coord)
	var side := clampf(coord.x, -1, 1)
	var along := clampf(coord.z, -1, 1)
	var local_incoming := incoming.rotated(Vector3.UP, -yaw).normalized()
	var glance := local_incoming.x * (1.0 - float(assessment.quality)) * 10.0
	var deflection := deg_to_rad(clampf(side * 28.0 + glance, -38, 38))
	var direction := Vector3(sin(deflection), 0, -cos(deflection)).rotated(Vector3.UP, yaw)
	# Far-forward contacts are flatter than nearer contacts; the centered platform
	# retains the exact calibrated ceiling. Re-solve lateral pace to keep range.
	var rise_factor := clampf(1.0 - 0.28 * absf(along) + 0.10 * along - 0.14 * absf(side) - 0.12 * absf(coord.y), 0.50, 1.0)
	var upward := maxf(base.y, 0.0) * sqrt(rise_factor)
	var drop := maxf(origin.y - floor_height, 0.0)
	var original_time := (base.y + sqrt(base.y * base.y + 2 * gravity * drop)) / gravity
	var new_time := (upward + sqrt(upward * upward + 2 * gravity * drop)) / gravity
	var distance := Vector2(base.x, base.z).length() * original_time
	return direction * distance / maxf(new_time, 0.01) + Vector3.UP * upward

static func mesh(shape: Dictionary, wire: bool = false) -> ImmediateMesh:
	var result := ImmediateMesh.new()
	result.surface_begin(Mesh.PRIMITIVE_LINES if wire else Mesh.PRIMITIVE_TRIANGLES)
	var radial := [0.0, 0.10, 0.56, 0.68, 0.75, 0.88, 1.0]
	var angles: Array[float] = []
	for degrees in range(-90, 91, 5):
		angles.append(deg_to_rad(degrees))
	for ring in range(radial.size() - 1):
		for segment in range(angles.size() - 1):
			var r0: float = radial[ring]
			var r1: float = radial[ring + 1]
			var a0: float = angles[segment]
			var a1: float = angles[segment + 1]
			var sample := _point(shape, (r0 + r1) * 0.5, (a0 + a1) * 0.5, 0)
			var grade := evaluate(shape, sample - Vector3(shape.center))
			var color: Color = COLORS[grade.zone]
			color.a = 0.82 if wire else 0.075
			result.surface_set_color(color)
			if wire:
				var first := _point(shape, r1, a0, 0)
				var second := _point(shape, r1, a1, 0)
				result.surface_add_vertex(first - Vector3(shape.center))
				result.surface_add_vertex(second - Vector3(shape.center))
				if segment % 7 == 0:
					result.surface_add_vertex(_point(shape, r0, a0, 0) - Vector3(shape.center))
					result.surface_add_vertex(first - Vector3(shape.center))
			else:
				for height_sign in [-1.0, 1.0]:
					var points := [_point(shape, r0, a0, height_sign), _point(shape, r1, a0, height_sign), _point(shape, r1, a1, height_sign), _point(shape, r0, a1, height_sign)]
					_quad(result, points, Vector3(shape.center))
				if ring == radial.size() - 2:
					_quad(result, [_point(shape, r1, a0, -1), _point(shape, r1, a1, -1), _point(shape, r1, a1, 1), _point(shape, r1, a0, 1)], Vector3(shape.center))
				if segment == 0:
					_quad(result, [_point(shape, r0, a0, -1), _point(shape, r1, a0, -1), _point(shape, r1, a0, 1), _point(shape, r0, a0, 1)], Vector3(shape.center))
				if segment == angles.size() - 2:
					_quad(result, [_point(shape, r0, a1, -1), _point(shape, r1, a1, -1), _point(shape, r1, a1, 1), _point(shape, r0, a1, 1)], Vector3(shape.center))
	result.surface_end()
	return result

static func _point(shape: Dictionary, radius: float, angle: float, height_sign: float) -> Vector3:
	return Vector3(float(shape.side_reach) * radius * sin(angle), float(shape.center.y) + height_sign * float(shape.size.y) * 0.5, -float(shape.forward_reach) * radius * maxf(cos(angle), 0.0))

static func _quad(result: ImmediateMesh, points: Array, center: Vector3) -> void:
	for index in [0, 1, 2, 0, 2, 3]:
		result.surface_add_vertex(Vector3(points[index]) - center)
