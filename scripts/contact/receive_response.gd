extends RefCounted
## Gameplay response curves, not a rigid-body solver. All actors use these rules.
const Execution := preload("res://scripts/contact_execution.gd")
const BALL_RADIUS := 0.105 * 1.25
const CLEARANCE := 0.012
const REFERENCE_IMPACT_SPEED := 24.0
const MAX_TRAIT_FACTOR := 0.65
const BODY_RADIUS_HEIGHT_RATIO := 0.22
const DEPARTURE_LOOKAHEAD := 0.25

# Deterministic stand-in for the old per-contact seeded noise: the mean magnitude of that noise, always continuing the lean the contact
# already has. Identical physical contacts now respond identically, whatever happened earlier in the rally.
const MEAN_SCATTER := 0.64

static func resolve(request: RefCounted, assessment: Dictionary, controlled: Vector3) -> Dictionary:
	var yaw := atan2(-request.facing.x, -request.facing.z)
	var incoming: Vector3 = request.incoming.rotated(Vector3.UP, -yaw)
	var intended := controlled.rotated(Vector3.UP, -yaw)
	var coord: Vector3 = assessment.get("platform_coord", Vector3.ZERO)
	var height := clampf((request.local_point.y - (float(request.shape.center.y) - float(request.shape.size.y) * 0.5)) / float(request.shape.size.y), 0, 1)
	var side := clampf(coord.x, -1, 1)
	var reach := clampf(-request.local_point.z / float(request.shape.forward_reach), 0, 1)
	var match_result: Dictionary = assessment.get("charge_match", {})
	var severity := clampf(float(match_result.get("severity", 0)), 0, 1)
	var under := str(match_result.get("status", "")) == "undercharged"
	var over := str(match_result.get("status", "")) == "overcharged"
	# A short confirmation age means late preparation; an old input means early.
	var age: float = request.confirmation_age
	var late := 1.0 - smoothstep(0.0, Execution.sweet_start(0), age)
	var early := smoothstep(Execution.sweet_end(0), Execution.CONTACT_SECONDS, age)
	var impact := clampf(incoming.length() / REFERENCE_IMPACT_SPEED, 0, 1.5)
	var control_bonus := clampf(request.athlete.trait_effect("receive_control") / 100.0, 0, MAX_TRAIT_FACTOR)
	var absorption := clampf(request.athlete.trait_effect("receive_absorption") / 100.0, 0, MAX_TRAIT_FACTOR)
	var redirection := clampf(request.athlete.trait_effect("receive_redirection") / 100.0, 0, MAX_TRAIT_FACTOR)
	var failure := severity * (1.0 - control_bonus)
	var handedness := signf(side) if absf(side) > 0.02 else (signf(incoming.x) if absf(incoming.x) > 0.02 else 1.0)
	var placement := (0.20 + 0.80 * absf(side)) * late * (0.25 + 0.75 * impact) * (1.0 - redirection)
	var scatter := MEAN_SCATTER * (0.05 + 0.30 * height + placement * 0.60) * failure * (1.0 - redirection)
	# Upper contacts permit tangential escape; the low platform catches/damps more.
	var normal := Vector3(side * (0.20 + height * 0.90), lerpf(0.10, 1.0, height), -lerpf(1.0, 0.15, height)).normalized()
	normal = normal.rotated(Vector3.UP, -handedness * (placement * 0.65 + scatter)).normalized()
	if incoming.dot(normal) > 0:
		normal = -normal
	var normal_pace := maxf(0, -incoming.dot(normal))
	var tangent := incoming + normal * normal_pace
	var low_catch := (1.0 - smoothstep(0.15, 0.45, height)) * (1.0 - late * 0.55)
	var retention := lerpf(0.10, 0.80, height) + 0.10 * late * impact + 0.10 * early * height
	retention *= 1.0 - absorption * (0.5 + 0.5 * low_catch)
	var restitution := lerpf(0.08, 0.38, height) * (1.0 - absorption) * (1.0 + 0.20 * early * height)
	var passive := normal * normal_pace * restitution + tangent * clampf(retention, 0.02, 0.95)
	passive = passive.rotated(Vector3.UP, -handedness * scatter)
	passive.y = maxf(0.025, passive.y * (1.0 - 0.75 * low_catch) + maxf(0, request.charge) * 0.7 * (1.0 - early * 0.65))
	# Early bottom contacts can die almost in place. Higher and later hits retain
	# more tangential pace, so fast side contacts can escape sideways/backwards.
	passive *= lerpf(1.0, 0.45, low_catch * early)
	passive = passive.limit_length(incoming.length() * 0.95 + 0.25)
	var outgoing := intended
	if under:
		outgoing = intended.lerp(passive, failure)
	elif over:
		var excess := maxf(0, float(match_result.get("receive_charge", 0)) - float(match_result.get("maximum", 0)))
		var overhit := intended.rotated(Vector3.UP, -handedness * (0.25 + excess * 0.35 + scatter)) * (1.25 + excess * 0.75)
		overhit.y = maxf(0.1, intended.y * (0.45 - minf(excess, 1) * 0.20))
		outgoing = intended.lerp(overhit, failure)
	# This is separation from the effective contacting surface, not a permanent
	# collider. Clean contacts use their intended platform rather than a shank plane.
	var separating_normal := normal if failure > 0.5 else (intended.normalized() if intended.length_squared() > 0.001 else normal)
	var toward_surface := outgoing.dot(separating_normal)
	if toward_surface < 0.025:
		outgoing += separating_normal * (0.025 - toward_surface)
	var guarded := separate_body(request.local_point, outgoing, float(request.athlete.build.height), request.gravity)
	outgoing = guarded.velocity
	var at_floor: bool = request.origin.y + guarded.offset.y <= BALL_RADIUS + 0.06
	var departure_normals: Array[Vector3] = [separating_normal]
	if guarded.corrected or at_floor:
		var start: Vector3 = request.local_point + guarded.offset
		var outward := Vector3(start.x, 0, start.z).normalized()
		if outward.length_squared() > 0.001:
			departure_normals.append(outward)
	if at_floor:
		departure_normals.append(Vector3.UP)
	outgoing = allowed_departure(outgoing, departure_normals)
	var delivery := clampf(float(assessment.get("quality", 0)) * (1.0 - failure) * (1.0 - early * 0.25 - late * 0.35), 0, 1)
	return {
		"velocity": outgoing.rotated(Vector3.UP, yaw),
		"separation_offset": Vector3(guarded.offset).rotated(Vector3.UP, yaw),
		"delivery_quality": delivery, "seed": request.response_seed,
		"height_fraction": height, "side": side, "reach": reach,
		"early": early, "late": late, "impact": impact,
		"mismatch_severity": severity, "uncontrolled_fraction": failure,
		"receive_control": control_bonus, "receive_absorption": absorption, "receive_redirection": redirection,
		"retention": retention, "restitution": restitution, "scatter_radians": scatter,
		"effective_normal": separating_normal.rotated(Vector3.UP, yaw),
		"passive_velocity": passive.rotated(Vector3.UP, yaw),
		"body_guard": guarded.corrected,
	}

static func separate_body(point: Vector3, velocity: Vector3, height: float, gravity: float) -> Dictionary:
	var radius := height * BODY_RADIUS_HEIGHT_RATIO + BALL_RADIUS
	var horizontal := Vector2(point.x, point.z)
	var movement := Vector2(velocity.x, velocity.z)
	var offset := Vector3.ZERO
	var corrected := false
	if point.y <= height * 1.05 + BALL_RADIUS and horizontal.length() < radius + CLEARANCE:
		var outward := horizontal.normalized() if horizontal.length_squared() > 0.00001 else Vector2(0, -1)
		var shift := outward * (radius + CLEARANCE - horizontal.length())
		offset = Vector3(shift.x, 0, shift.y)
		horizontal += shift
		corrected = true
	var a := movement.length_squared()
	var b := horizontal.dot(movement)
	var c := horizontal.length_squared() - radius * radius
	var discriminant := b * b - a * c
	if a > 0.000001 and b < 0 and discriminant >= 0:
		var entry := (-b - sqrt(discriminant)) / a
		var y := point.y + velocity.y * entry - gravity * entry * entry * 0.5
		if entry >= 0 and entry <= DEPARTURE_LOOKAHEAD and y >= -BALL_RADIUS and y <= height * 1.05 + BALL_RADIUS:
			var outward := horizontal.normalized()
			movement -= outward * minf(0, movement.dot(outward) - 0.025)
			velocity.x = movement.x
			velocity.z = movement.y
			corrected = true
	return {"velocity": velocity, "offset": offset, "corrected": corrected}

# Choose the closest velocity in the allowed departure cone. This guard removes
# forbidden inward motion without adding shot energy. A dead stop is valid when
# platform, body and floor leave no useful direction for the attempted contact.
static func allowed_departure(velocity: Vector3, normals: Array[Vector3]) -> Vector3:
	var candidates: Array[Vector3] = [velocity, Vector3.ZERO]
	for normal in normals:
		candidates.append(velocity - normal * velocity.dot(normal))
	for a in range(normals.size()):
		for b in range(a + 1, normals.size()):
			var axis := normals[a].cross(normals[b]).normalized()
			if axis.length_squared() > 0.001:
				candidates.append(axis * velocity.dot(axis))
	var best := Vector3.ZERO
	var error := velocity.length_squared()
	for candidate in candidates:
		var valid := true
		for normal in normals:
			if candidate.dot(normal) < -0.000001:
				valid = false
				break
		var distance := candidate.distance_squared_to(velocity)
		if valid and distance <= error:
			best = candidate
			error = distance
	return best
