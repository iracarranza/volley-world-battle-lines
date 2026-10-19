extends RefCounted
## One ordered rules pipeline for player, court bots, Pepper and previews.
## Geometry -> timing -> charge -> receive outcome -> direction -> execution -> shank.
const Request := preload("res://scripts/contact/contact_request.gd")
const Result := preload("res://scripts/contact/contact_result.gd")
const Action := preload("res://scripts/contact/action.gd").Type
const Geometry := preload("res://scripts/contact_geometry.gd")
const Execution := preload("res://scripts/contact_execution.gd")
const Charge := preload("res://scripts/receive_charge.gd")
const Outcome := preload("res://scripts/receive_outcome.gd")
const Platform := preload("res://scripts/receive_platform.gd")
const Influence := preload("res://scripts/directional_influence.gd")
const Spike := preload("res://scripts/spike_direction.gd")
const Aim := preload("res://scripts/bot_aim.gd")

static func assess(request: Request) -> Dictionary:
	var spatial := Geometry.evaluate(request.shape, request.local_point)
	var result := Execution.assess(
		spatial, request.confirmation_age, request.remembered, request.action
	)
	if request.action == Action.SET:
		result = request.athlete.stabilize_set(result)
	if request.action == Action.RECEIVE:
		if not request.ideal_charge_match:
			result = Charge.assess(
				result, request.incoming_shot,
				request.charge * request.athlete.low_stamina_factor(),
				request.athlete.cushioning_bonus(), request.athlete.trait_effect("charge_tolerance")
			)
		result = Outcome.assess(
			result, request.shape, request.local_point, request.movement_speed,
			request.directional_input, atan2(-request.facing.x, -request.facing.z)
		)
	return result

static func resolve(request: Request, assessment: Dictionary) -> Result:
	var result := Result.new()
	result.assessment = assessment
	var velocity := request.base_velocity
	var ideal := velocity
	var quality := float(assessment.quality) if assessment.hit else 0.35
	var yaw := atan2(-request.facing.x, -request.facing.z)
	if request.rolling_receive:
		quality = 1.0
	elif request.action == Action.RECEIVE and assessment.hit:
		velocity = Platform.redirect(
			velocity, request.origin, yaw, request.incoming, assessment, request.gravity
		)
	elif request.action == Action.ATTACK:
		velocity *= float(assessment.strength) / request.attack_strength_reference if assessment.hit else 0.48
	if (request.action == Action.SET and request.apply_set_spread) or (request.action == Action.BLOCK and request.apply_block_spread):
		var deviation := (1.0 - quality) * (1.0 - request.athlete.ball_control() / 120.0)
		velocity = velocity.rotated(Vector3.UP, deviation * sin(request.spread_phase) * 0.5)
	if request.action == Action.ATTACK:
		if request.aim_random != null:
			result.aiming = Aim.apply(request.origin, velocity, request.aiming_accuracy, request.gravity, request.aim_random)
			velocity = result.aiming.velocity
		result.influence = Spike.resolve(
			velocity, assessment, request.directional_input, request.facing, request.keep_attack_intent
		)
	else:
		result.influence = Influence.resolve(
			velocity, request.action, request.directional_input, request.intent_direction, quality
		)
	velocity = Execution.velocity(
		request.action, result.influence.velocity, request.incoming, request.facing,
		assessment, request.athlete.timing(), ideal, request.athlete.ball_control(),
		request.flow, request.athlete.low_stamina_factor()
	)
	if request.action == Action.RECEIVE and request.receive_heading.length_squared() > 0:
		var speed := Vector2(velocity.x, velocity.z).length()
		velocity.x = request.receive_heading.x * speed
		velocity.z = request.receive_heading.z * speed
	if request.action != Action.ATTACK and request.aim_random != null:
		result.aiming = Aim.apply(
			request.origin, velocity, request.aiming_accuracy, request.gravity,
			request.aim_random, request.receive_heading.length_squared() > 0
		)
		velocity = result.aiming.velocity
	if request.action == Action.RECEIVE:
		velocity = Outcome.velocity(velocity, assessment)
		if not request.ideal_charge_match:
			velocity = Charge.velocity(velocity, request.incoming, request.facing, assessment)
	result.velocity = velocity
	return result
