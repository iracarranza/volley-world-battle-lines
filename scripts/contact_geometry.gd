extends RefCounted

const BlockField := preload("res://scripts/block_field.gd")
const SetHurtbox := preload("res://scripts/set_hurtbox.gd")
const ReceivePlatform := preload("res://scripts/receive_platform.gd")

const VISUAL_BALL_RADIUS := 0.105
const BALL_RADIUS := VISUAL_BALL_RADIUS * 1.25
# Receive: contacts at the widest horizontal edges are sour spots.
const EDGE_ZONE := 0.78
const ZONE_COLORS := {"SWEET SPOT": Color("67f3a3"), "FAIR": Color("ffcf70"), "WEAK": Color("f69c69"), "SOUR SPOT": Color("ee617b")}

static func definition(action: int, height: float, reach: float, dive: bool, dominant_sign: float, shoulder_height: float = -1.0, shoulder_x: float = -1.0, ball_control: float = 65.0, arm_length: float = -1.0,morphology: Dictionary = {}) -> Dictionary:
	match action:
		0:
			return ReceivePlatform.definition(height, dive,0,morphology)
		1:
			return SetHurtbox.definition(height, reach, ball_control)
		2:
			var shoulder := height * 0.815 if shoulder_height < 0 else shoulder_height
			var radius := maxf(0.40, minf(reach - shoulder, arm_length) if arm_length > 0 else reach - shoulder)
			return {"shape": "sector", "center": Vector3((height * 0.17 if shoulder_x < 0 else shoulder_x) * dominant_sign, shoulder, -0.35), "size": Vector3(radius * 2, radius, 2.10), "radius": radius, "contact_margin": 0.12 * height / 1.86, "depth": 2.10, "physical_depth": 1.10, "dominant_sign": dominant_sign}
		_:
			return BlockField.definition(height,reach)

static func with_effects(base: Dictionary,effects: Dictionary) -> Dictionary:
	var scale := Vector3(maxf(0.1,1.0+float(effects.get("broad_range",0))/100.0),maxf(0.1,1.0+float(effects.get("vertical_reach",0))/100.0),1)
	if scale.is_equal_approx(Vector3.ONE): return base
	var result := base.duplicate(true)
	result["base_geometry"] = base.duplicate(true)
	result["geometry_scale"] = scale
	var pivot := Vector3(0,base.center.y-base.size.y*0.5,0)
	result["geometry_pivot"] = pivot
	result["center"] = pivot+(Vector3(base.center)-pivot)*scale
	result["size"] = Vector3(base.size)*scale
	if base.has("side_reach"): result["side_reach"] = float(base.side_reach)*scale.x
	result["broad_leniency"] = maxf(0,float(effects.get("broad_range",0))/100.0)
	return result

static func unscaled_point(shape: Dictionary,point: Vector3) -> Vector3:
	if not shape.has("base_geometry"): return point
	var pivot: Vector3 = shape.geometry_pivot
	return pivot+(point-pivot)/Vector3(shape.geometry_scale)

static func contains(definition: Dictionary, local_ball: Vector3) -> bool:
	if definition.has("base_geometry"): return contains(definition.base_geometry,unscaled_point(definition,local_ball))
	if definition.get("block_triangle",false): return BlockField.contains(definition,local_ball,BALL_RADIUS)
	var point: Vector3 = local_ball - definition.center
	if definition.shape == "set_sector":
		return SetHurtbox.contains(definition, local_ball, BALL_RADIUS)
	if definition.get("receive_platform", false):
		return ReceivePlatform.contains(definition, local_ball, BALL_RADIUS)
	if definition.shape == "sector":
		return point.y >= -BALL_RADIUS and Vector2(point.x, point.y).length() <= float(definition.radius) + float(definition.get("contact_margin", 0)) + BALL_RADIUS and absf(point.z) <= float(definition.depth) * 0.5 + BALL_RADIUS
	var radius: Vector3 = definition.size * 0.5 + Vector3.ONE * BALL_RADIUS
	if definition.shape == "ellipsoid":
		return (point / radius).length_squared() <= 1.0
	point = point.abs()
	return point.x <= radius.x and point.y <= radius.y and point.z <= radius.z

static func zone_at(radius_ratio: float, angle: float) -> String:
	if radius_ratio <= 0.32 or radius_ratio >= 0.90 or angle < 12.0 or angle > 168.0:
		return "SOUR SPOT"
	if radius_ratio >= 0.60 and radius_ratio <= 0.88 and angle >= 50.0 and angle <= 85.0:
		return "SWEET SPOT"
	return "FAIR" if angle < 90.0 else "WEAK"

static func evaluate(definition: Dictionary, local_ball: Vector3) -> Dictionary:
	if definition.has("base_geometry"):
		var grade := evaluate(definition.base_geometry,unscaled_point(definition,local_ball))
		if grade.hit:
			var leniency := float(definition.get("broad_leniency",0))
			grade.quality = 1.0-(1.0-float(grade.quality))/(1.0+leniency)
			if float(grade.strength) < 1.0: grade.strength = 1.0-(1.0-float(grade.strength))/(1.0+leniency)
			# Enlarged reach cannot manufacture an anatomically impossible sweetspot.
			if definition.shape == "sector":
				var physical := evaluate(definition.base_geometry,local_ball)
				if physical.get("zone","") == "SWEET SPOT":
					grade.zone = "SWEET SPOT"
					grade.quality = physical.quality
					grade.strength = physical.strength
				elif grade.zone == "SWEET SPOT":
					grade.zone = "FAIR"
					grade.quality = minf(0.82,float(grade.quality))
				grade["rescue_only"] = physical.get("rescue_only",not physical.hit)
		return grade
	if not contains(definition, local_ball):
		return {"hit": false, "zone": "MISS", "quality": 0.0, "strength": 0.0}
	if definition.get("block_triangle",false): return BlockField.grade(definition,local_ball)
	var point: Vector3 = local_ball - definition.center
	if definition.get("receive_platform", false):
		return ReceivePlatform.evaluate(definition, point)
	if definition.shape == "set_sector":
		return SetHurtbox.grade(definition, point)
	if definition.shape != "sector":
		var normalized: Vector3 = point / (definition.size * 0.5 + Vector3.ONE * BALL_RADIUS)
		if absf(normalized.x) >= float(definition.get("edge_zone", 2.0)):
			return {"hit": true, "zone": "SOUR SPOT", "quality": 0.40, "strength": 1.0, "edge": true}
		return {"hit": true, "zone": "CLEAN" if normalized.length() < 0.65 else "STRETCHED", "quality": clampf(1.0 - normalized.length() * 0.35, 0.55, 1.0), "strength": 1.0}
	var ratio := Vector2(point.x, point.y).length() / float(definition.radius)
	var angle := rad_to_deg(atan2(maxf(point.y, 0), point.x * float(definition.dominant_sign)))
	var zone := zone_at(ratio, angle)
	if (point + Vector3(0, 0, -0.35)).length() > float(definition.radius) or absf(point.z) > float(definition.get("physical_depth", definition.depth)) * 0.5:
		zone = "SOUR SPOT"
	var quality: float = {"SWEET SPOT": 1.0, "FAIR": 0.82, "WEAK": 0.58, "SOUR SPOT": 0.22}[zone]
	var strength: float = {"SWEET SPOT": 1.08, "FAIR": 0.95, "WEAK": 0.78, "SOUR SPOT": 0.48}[zone]
	return {"hit": true, "zone": zone, "quality": quality, "strength": strength, "rescue_only": (point + Vector3(0, 0, -0.35)).length() > float(definition.radius), "spike_geometry": true, "spike_lateral_offset": (point.x - cos(deg_to_rad(67.5)) * 0.74 * float(definition.radius) * float(definition.dominant_sign)) / float(definition.radius), "reach_ratio": (point + Vector3(0, 0, -0.35)).length() / float(definition.radius), "depth_ratio": absf(point.z) / (float(definition.depth) * 0.5)}

static func zone_mesh(definition: Dictionary, lines: bool = false, grading_shape: Dictionary = {}) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES if lines else Mesh.PRIMITIVE_TRIANGLES)
	var radius: float = definition.radius
	var depth: float = definition.depth * 0.5
	var radial := [0.0, 0.32, 0.60, 0.88, 0.90, 1.0]
	var angles: Array[float] = []
	for value in range(0, 181, 5):
		angles.append(float(value))
	angles.append(12.0)
	angles.append(168.0)
	angles.sort()
	for ring in range(radial.size() - 1):
		for segment in range(angles.size() - 1):
			var a: float = angles[segment]
			var b: float = angles[segment + 1]
			var r0: float = radial[ring]
			var r1: float = radial[ring + 1]
			var zone := zone_at((r0 + r1) * 0.5, (a + b) * 0.5)
			var color: Color = ZONE_COLORS[zone]
			color.a = 0.20 if not lines else 0.85
			mesh.surface_set_color(color)
			for z in [-depth, 0.0, depth]:
				var sample := sector_point(definition,(r0+r1)*0.5,(a+b)*0.5,z)
				var grade := evaluate(definition,Vector3(definition.center)+sample) if grading_shape.is_empty() else evaluate(grading_shape,Vector3(grading_shape.center)+sample*Vector3(grading_shape.get("geometry_scale",Vector3.ONE)))
				color = ZONE_COLORS.get("WEAK" if grade.get("rescue_only", false) else grade.zone, Color("ee617b"))
				color.a = 0.16 if not lines else 0.85
				mesh.surface_set_color(color)
				var points := [sector_point(definition, r0, a, z), sector_point(definition, r1, a, z), sector_point(definition, r1, b, z), sector_point(definition, r0, b, z)]
				if lines:
					if ring == radial.size() - 2:
						mesh.surface_add_vertex(points[1])
						mesh.surface_add_vertex(points[2])
					if segment == 0 or segment == angles.size() - 2:
						mesh.surface_add_vertex(points[0])
						mesh.surface_add_vertex(points[1])
				else:
					for corner in [0, 1, 2, 0, 2, 3]:
						mesh.surface_add_vertex(points[corner])
	if lines:
		for angle in [0.0, 50.0, 85.0, 90.0, 180.0]:
			mesh.surface_add_vertex(sector_point(definition, 1, angle, -depth))
			mesh.surface_add_vertex(sector_point(definition, 1, angle, depth))
	if lines:
		var outer: float = definition.radius + definition.get("contact_margin", 0)
		mesh.surface_set_color(Color("f69c69"))
		for step in range(36):
			for z in [-depth, depth]:
				for angle in [PI * step / 36.0, PI * (step + 1) / 36.0]:
					mesh.surface_add_vertex(Vector3(cos(angle) * outer * definition.dominant_sign, sin(angle) * outer, z))
	mesh.surface_end()
	return mesh

static func sector_point(definition: Dictionary, ratio: float, angle: float, z: float) -> Vector3:
	if definition.has("base_geometry"): return sector_point(definition.base_geometry,ratio,angle,z)*Vector3(definition.geometry_scale)
	return Vector3(cos(deg_to_rad(angle)) * ratio * float(definition.radius) * float(definition.dominant_sign), sin(deg_to_rad(angle)) * ratio * float(definition.radius), z)

static func block_mesh(definition: Dictionary) -> ImmediateMesh:
	return BlockField.mesh(definition)

static func block_overlap(definition: Dictionary,point: Vector3,padding: float = 0.0) -> bool:
	return BlockField.contains(definition.get("base_geometry",definition),unscaled_point(definition,point),BALL_RADIUS+padding)

static func block_approaching(definition: Dictionary,point: Vector3,velocity: Vector3) -> bool:
	return BlockField.approaching(definition.get("base_geometry",definition),unscaled_point(definition,point),velocity/Vector3(definition.get("geometry_scale",Vector3.ONE)))

static func arm_length(arm: Node3D, scale: float) -> float:
	var elbow := arm.get_node_or_null("Elbow") as Node3D
	var wrist := arm.get_node_or_null("Elbow/Wrist") as Node3D
	if elbow == null or wrist == null:
		return -1.0
	var anchor := arm.get_node_or_null("Elbow/Wrist/ContactAnchor") as Node3D
	return (elbow.position.length() + wrist.position.length() + (anchor.position.length() if anchor != null else 0.0)) * scale

# The whole envelope remains visible; only a shallow slice can strike at a time.
# Local +z is behind the athlete. The slice crosses overhead and ends ahead (-z).
static func spike_active(shape: Dictionary, local_ball: Vector3, age: float) -> bool:
	var clock := preload("res://scripts/contact_execution.gd")
	if age < clock.SPIKE_WINDUP or age > clock.SPIKE_END or not contains(shape, local_ball):
		return false
	var base: Dictionary = shape.get("base_geometry", shape)
	var point := unscaled_point(shape, local_ball) - Vector3(base.center)
	var depth := float(base.depth)
	var active_z := lerpf(depth * 0.5, -depth * 0.5, clock.spike_progress(age))
	return absf(point.z - active_z) <= BALL_RADIUS + 0.18
