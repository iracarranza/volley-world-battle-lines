extends RefCounted

# Upward spherical sector, clipped above the head. The sweet column is centered
# on the athlete's vertical axis; Ball Control changes only its radius.
static func definition(height: float, reach: float, ball_control: float) -> Dictionary:
	var center := Vector3(0, height * 0.85, 0)
	var radius := maxf(0.65, reach - center.y + 0.55)
	var column := lerpf(0.16, 0.42, clampf(ball_control / 100.0, 0, 1)) * height / 1.86
	return {"shape": "set_sector", "center": center, "radius": radius, "size": Vector3(radius * 2, radius, radius * 2), "min_y": -height * 0.12, "half_angle": deg_to_rad(70.0), "column_radius": column, "ball_control": ball_control}

static func contains(shape: Dictionary, local_ball: Vector3, ball_radius: float) -> bool:
	var p := local_ball - Vector3(shape.center)
	var horizontal := Vector2(p.x, p.z).length()
	return p.y >= float(shape.min_y) - ball_radius and p.length() <= float(shape.radius) + ball_radius and horizontal <= maxf(p.y + float(shape.radius) * 0.32, 0) * tan(float(shape.half_angle)) + ball_radius / cos(float(shape.half_angle))

static func grade(shape: Dictionary, point: Vector3) -> Dictionary:
	var horizontal := Vector2(point.x, point.z).length()
	var outside := maxf(0, horizontal - float(shape.column_radius))
	var falloff := clampf(outside / maxf(0.01, float(shape.radius) - float(shape.column_radius)), 0, 1)
	var quality := (1.0 - 0.75 * falloff) * lerpf(0.72, 1.0, smoothstep(0.0, float(shape.radius) * 0.20, point.y))
	var sweet := point.y >= float(shape.radius) * 0.20 and horizontal <= float(shape.column_radius) + 0.00001
	return {"hit": true, "zone": "SWEET SPOT" if sweet else ("FAIR" if quality >= 0.75 else "WEAK"), "quality": quality, "strength": 1.0, "column_distance": horizontal, "ball_control": shape.ball_control}

static func outer_radius(shape: Dictionary, y: float) -> float:
	return minf(sqrt(maxf(0, pow(float(shape.radius), 2) - y * y)), maxf(0, y + float(shape.radius) * 0.32) * tan(float(shape.half_angle)))

static func mesh(shape: Dictionary, lines: bool = false) -> ImmediateMesh:
	var result := ImmediateMesh.new()
	result.surface_begin(Mesh.PRIMITIVE_LINES if lines else Mesh.PRIMITIVE_TRIANGLES)
	var rings := 20
	var slices := 48
	for ring in range(rings):
		var y0 := lerpf(float(shape.min_y), float(shape.radius), float(ring) / rings)
		var y1 := lerpf(float(shape.min_y), float(shape.radius), float(ring + 1) / rings)
		for slice in range(slices):
			var a := TAU * slice / slices
			var b := TAU * (slice + 1) / slices
			var p := [Vector3(cos(a) * outer_radius(shape, y0), y0, sin(a) * outer_radius(shape, y0)), Vector3(cos(b) * outer_radius(shape, y0), y0, sin(b) * outer_radius(shape, y0)), Vector3(cos(b) * outer_radius(shape, y1), y1, sin(b) * outer_radius(shape, y1)), Vector3(cos(a) * outer_radius(shape, y1), y1, sin(a) * outer_radius(shape, y1))]
			if lines:
				if ring % 4 == 0:
					_add(result, shape, p[0], true)
					_add(result, shape, p[1], true)
				if slice % 6 == 0:
					_add(result, shape, p[0], true)
					_add(result, shape, p[3], true)
			else:
				for corner in [0, 1, 2, 0, 2, 3]:
					_add(result, shape, p[corner], false)
				if ring == 0:
					for point in [Vector3(0, y0, 0), p[1], p[0]]:
						_add(result, shape, point, false)
	# Bright green column boundary, clipped by the same spherical/conical sector.
	if lines:
		var r: float = shape.column_radius
		var bottom := maxf(float(shape.min_y), r / tan(float(shape.half_angle)))
		var top := sqrt(maxf(0, pow(float(shape.radius), 2) - r * r))
		result.surface_set_color(Color("67f3a3"))
		for slice in range(slices):
			var a := TAU * slice / slices
			var b := TAU * (slice + 1) / slices
			for y in [bottom, top]:
				result.surface_add_vertex(Vector3(cos(a) * r, y, sin(a) * r))
				result.surface_add_vertex(Vector3(cos(b) * r, y, sin(b) * r))
			if slice % 6 == 0:
				result.surface_add_vertex(Vector3(cos(a) * r, bottom, sin(a) * r))
				result.surface_add_vertex(Vector3(cos(a) * r, top, sin(a) * r))
	result.surface_end()
	return result

static func _add(result: ImmediateMesh, shape: Dictionary, point: Vector3, lines: bool) -> void:
	var quality: float = grade(shape, point).quality
	var color := Color("ee617b").lerp(Color("67f3a3"), quality)
	color.a = 0.75 if lines else 0.13
	result.surface_set_color(color)
	result.surface_add_vertex(point)
