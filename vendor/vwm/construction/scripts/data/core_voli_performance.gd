class_name CoreVoliPerformance
extends RefCounted

## Presentation-only rhythm layered over the authoritative action resolvers.
##
## Nothing here can choose a contact, move the ball, change an elevation, or
## rewrite a limb at the contact point.  It supplies the small whole-toy weight
## shifts, attention lag and attached-part follow-through that make the existing
## biomechanical poses read as one continuous performance.

## Visual vocabulary semantics
##
## Anticipation loads before commitment; commitment carries the body through the
## contact; force marks the contact accent; continuation and settle preserve
## inertia into recovery. Head/eye attention remains perceptive rather than
## mechanically locked. Body-type anatomy responds passively to acceleration,
## impact, and settling: it supports the primary action's meaning but never names
## a new action quality or selects an outcome.

const HEAD_RESPONSE_RADIANS_PER_SECOND := 7.4
const HEAD_PITCH_RESPONSE_RADIANS_PER_SECOND := 5.8


static func resolve(
	event_type: int,
	phase: float,
	body_type: String,
	dominant_hand: String,
	contact_direction: Vector2,
	action_context: Dictionary = {},
	block_arms: StringName = &"two",
	response_override: float = -1.0,
) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var anticipation := smoothstep(-0.82, -0.42, p) \
		* (1.0 - smoothstep(-0.25, 0.02, p))
	var commitment := smoothstep(-0.38, 0.02, p) \
		* (1.0 - smoothstep(0.18, 0.48, p))
	var continuation := smoothstep(-0.08, 0.25, p) \
		* (1.0 - smoothstep(0.68, 0.98, p))
	var settle := smoothstep(0.52, 1.0, p)
	var force := 1.0 - smoothstep(0.0, 0.24, absf(p))
	var response := response_override if response_override >= 0.0 else body_response(body_type)
	var handed := -1.0 if dominant_hand == "Left" else 1.0
	var roll_degrees := 0.0
	var lateral_metres := 0.0
	var head_roll_degrees := 0.0
	var head_pitch_degrees := 0.0

	match event_type:
		RallyEvent.EventType.ATTACK:
			var family := AttackActionBiomechanics.family(str(
				action_context.get("attack_type", "Power swing")
			))
			var adjustment := StringName(str(action_context.get(
				"attack_adjustment", AttackActionBiomechanics.ADJUSTMENT_CLEAN
			)))
			var scale := 0.55 if family == AttackActionBiomechanics.ROLL \
				else 0.25 if family == AttackActionBiomechanics.DINK else 1.0
			roll_degrees = handed * (-4.5 * anticipation + 7.5 * continuation) * scale
			lateral_metres = handed * (-0.018 * anticipation + 0.030 * continuation) * scale
			head_roll_degrees = -handed * (2.6 * anticipation + 1.8 * force) * scale
			head_pitch_degrees = -1.8 * commitment + 2.4 * continuation * scale
			## Explicit review labels alter only the carried performance after the
			## canonical joint pose. They are not inferred from quality or outcome.
			if adjustment == AttackActionBiomechanics.ADJUSTMENT_REACHING:
				roll_degrees += handed * 5.2 * commitment
				lateral_metres += handed * 0.030 * commitment
				head_roll_degrees -= handed * 2.8 * commitment
			elif adjustment == AttackActionBiomechanics.ADJUSTMENT_MISTIMED:
				roll_degrees -= handed * 4.4 * continuation
				lateral_metres -= handed * 0.018 * continuation
				head_pitch_degrees += 3.0 * continuation
				force *= 0.58
			elif adjustment == AttackActionBiomechanics.ADJUSTMENT_MISSED:
				var arrest := smoothstep(0.02, 0.52, p) \
					* (1.0 - smoothstep(0.72, 1.0, p))
				roll_degrees -= handed * 6.2 * arrest
				lateral_metres -= handed * 0.026 * arrest
				head_roll_degrees += handed * 3.0 * arrest
				force = 0.0
		RallyEvent.EventType.SERVE:
			var overhead_scale := 0.18 if str(action_context.get(
				"serve_style", ServeActionBiomechanics.STANDING
			)) == ServeActionBiomechanics.SKY_BALL else 1.0
			roll_degrees = handed * (-3.5 * anticipation + 6.0 * continuation) * overhead_scale
			lateral_metres = handed * 0.020 * (continuation - anticipation) * overhead_scale
			head_roll_degrees = -handed * 2.0 * anticipation * overhead_scale
			head_pitch_degrees = -1.2 * commitment + 1.8 * continuation * overhead_scale
		RallyEvent.EventType.RECEPTION, RallyEvent.EventType.DIG, RallyEvent.EventType.ATTACK_COVERAGE:
			var side := clampf(contact_direction.x, -1.0, 1.0)
			var platform_commit := smoothstep(-0.30, 0.18, p) \
				* (1.0 - smoothstep(0.70, 1.0, p))
			roll_degrees = side * 6.5 * platform_commit
			lateral_metres = side * 0.026 * platform_commit
			# The eyes/head stay with the flight while the platform and torso reach.
			head_roll_degrees = -side * 3.2 * platform_commit
			head_pitch_degrees = -1.4 * commitment
		RallyEvent.EventType.SET:
			var back := -1.0 if bool(action_context.get("back_set", false)) else 1.0
			roll_degrees = back * handed * 2.8 * continuation
			head_pitch_degrees = -1.8 * anticipation + 1.2 * continuation
		RallyEvent.EventType.BLOCK:
			if block_arms != &"two":
				var side := 1.0 if contact_direction.x > 0.0 else -1.0
				roll_degrees = side * 4.0 * continuation
			head_pitch_degrees = -2.2 * anticipation + 1.4 * continuation

	return {
		"anticipation": anticipation,
		"commitment": commitment,
		"force": force,
		"continuation": continuation,
		"settle": settle,
		"body_roll_degrees": roll_degrees * response,
		"lateral_metres": lateral_metres * response,
		"head_roll_degrees": head_roll_degrees * response,
		"head_pitch_degrees": head_pitch_degrees * response,
	}


static func body_response(body_type: String) -> float:
	match body_type:
		"Feli", "Simi": return 1.18
		"Avi": return 1.10
		"Cani": return 0.96
		"Ursi": return 0.78
		"Vegi": return 0.98
	return 1.0


## Stable head pursuit: eyes can use the target immediately while the mass of
## the head catches up.  This is presentation state only and never feeds a
## decision or changes the body facing chosen by playback.
static func attention_step(
	current: Vector2, target: Vector2, delta: float
) -> Vector2:
	return Vector2(
		move_toward(
			current.x, target.x,
			HEAD_RESPONSE_RADIANS_PER_SECOND * maxf(delta, 0.0)
		),
		move_toward(
			current.y, target.y,
			HEAD_PITCH_RESPONSE_RADIANS_PER_SECOND * maxf(delta, 0.0)
		),
	)


static func pupil_attention_offset(
	current: Vector2, target: Vector2
) -> Vector2:
	var residual := target - current
	return Vector2(
		clampf(residual.x * 0.42, -0.34, 0.34),
		clampf(-residual.y * 0.42, -0.24, 0.24),
	)


static func handoff_seconds(event_type: int) -> float:
	match event_type:
		RallyEvent.EventType.SERVE: return 0.24
		RallyEvent.EventType.SET: return 0.18
		RallyEvent.EventType.BLOCK: return 0.22
		RallyEvent.EventType.ATTACK: return 0.20
		RallyEvent.EventType.RECEPTION, RallyEvent.EventType.DIG, RallyEvent.EventType.ATTACK_COVERAGE:
			return 0.20
	return 0.16


static func handoff_weight(progress: float) -> float:
	return 1.0 - smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))


## Names identify only which already-authored attachment can flex; they do not
## author anatomy or body-specific behaviour.  The amplitudes are deliberately
## small, with hanging ears/tails responding more than compact ears or a muzzle.
static func passive_response(
	body_type: String, part_name: String, performance: Dictionary,
	dominant_hand: String,
) -> Vector3:
	var lower := part_name.to_lower()
	var strength := 0.0
	if "tail" in lower:
		strength = 1.0
	elif "ear" in lower and body_type in ["Cani", "Feli"]:
		strength = 0.62
	elif "crest" in lower or "stem" in lower or "shoot" in lower \
			or "calyx" in lower or "cap" in lower:
		strength = 0.52
	elif "wing" in lower or "feather" in lower:
		strength = 0.42
	if strength <= 0.0:
		return Vector3.ZERO
	var handed := -1.0 if dominant_hand == "Left" else 1.0
	var anticipation := float(performance.get("anticipation", 0.0))
	var force := float(performance.get("force", 0.0))
	var continuation := float(performance.get("continuation", 0.0))
	var settle := float(performance.get("settle", 0.0))
	var body_roll := float(performance.get("body_roll_degrees", 0.0))
	var lag := (2.8 * anticipation - 5.2 * continuation + 1.8 * settle) * strength
	return Vector3(
		lag,
		handed * force * 2.2 * strength,
		-body_roll * 0.42 * strength,
	)
