extends RefCounted
## One ordered rules pipeline for player, court bots, Pepper and previews.
## Geometry -> timing -> charge -> receive outcome -> direction -> execution -> shank.
const Registry := preload("res://scripts/contact/mechanic_registry.gd")
const SetIsolation := preload("res://scripts/contact/set_isolation.gd")
const ReceiveResponse := preload("res://scripts/contact/receive_response.gd")
const BallState := preload("res://scripts/contact/ball_state.gd")
const Snapshot := preload("res://scripts/contact/snapshot.gd")
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
	result["geometry_assessment"] = Snapshot.freeze(spatial)
	result["timing_assessment"] = Snapshot.freeze({"sweet_eligible": result.get("sweet", false), "rescue": result.get("rescue", false), "confirmation_age": request.confirmation_age})
	if request.action == Action.SET:
		result = request.athlete.stabilize_set(result)
		result["set_isolation"] = SetIsolation.assess(request,result)
		var severity: float = result.set_isolation.severity
		if severity > 0:
			result["sweet"] = false
			result["quality"] *= 1.0-0.65*severity
			result["zone"] = "OVERWHELMED SET"
	if request.action == Action.RECEIVE:
		if not request.ideal_charge_match:
			result = Charge.assess(
				result, request.incoming_shot,
				request.charge * request.athlete.low_stamina_factor(),
				request.athlete.cushioning_bonus(), request.athlete.trait_effect("charge_tolerance"),request.auto_charge
			)
		result = Outcome.assess(
			result, request.shape, request.local_point, request.movement_speed,
			request.directional_input, atan2(-request.facing.x, -request.facing.z)
		)
	if request.auto_charge: result["auto_charge"] = Snapshot.freeze(request.auto_evidence)
	return result

static func resolve(request: Request, assessment: Dictionary) -> Result:
	var result := Result.new()
	result.assessment = assessment.duplicate(true)
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
	if request.action == Action.SET:
		var isolation: Dictionary = assessment.set_isolation
		velocity = SetIsolation.velocity(request.incoming,velocity,isolation,request.facing)
		result.outgoing_shot = BallState.set_contact(request.charge,request.actor_id,velocity,isolation,quality,request.incoming)
	if request.action == Action.RECEIVE:
		velocity = Outcome.velocity(velocity, assessment)
		if not request.ideal_charge_match and assessment.hit:
			var response := ReceiveResponse.resolve(request, assessment, velocity)
			velocity = response.velocity
			result.separation_offset = response.separation_offset
			result.assessment["receive_response"] = response
			result.outgoing_shot = BallState.receive(request.charge, request.actor_id, request.incoming_shot, request.incoming, velocity, response.delivery_quality, response)
	result.velocity = velocity
	result.mechanics = mechanics(request, result)
	result.assessment["mechanics"] = result.mechanics
	return result

static func mechanics(request: Request, result: Result) -> Array:
	var assessment := result.assessment
	var response: Dictionary = assessment.get("receive_response", {})
	var geometry: Dictionary = assessment.get("geometry_assessment", assessment)
	var timing: Dictionary = assessment.get("timing_assessment", {})
	var evidence := {
		"geometry": {"hit": geometry.get("hit", false), "zone": geometry.get("zone", ""), "quality": geometry.get("quality", 0), "intersection": request.local_point, "platform_quality": request.athlete.trait_effect("platform_quality") if request.action == Action.RECEIVE else 0.0},
		"timing": {"confirmation_age": request.confirmation_age, "sweet_eligible": timing.get("sweet_eligible", false), "early": response.get("early", 0), "late": response.get("late", 0), "timing": request.athlete.timing()},
		"potency": {"action_charge": request.charge, "available_output": request.athlete.low_stamina_factor(), "effective_receive_charge": assessment.get("charge_match", {}).get("receive_charge", request.charge), "cushioning": request.athlete.cushioning_bonus() if request.action == Action.RECEIVE else 0.0,"auto_charge":request.auto_evidence},
		"handling": {"profile": Registry.profile(request.action), "model": "receive_response" if not response.is_empty() else "existing_action_rules", "charge_match": assessment.get("charge_match", {}), "incoming_velocity": request.incoming,"set_isolation":assessment.get("set_isolation",{})},
		"pressure_control": {"uncontrolled_fraction": response.get("uncontrolled_fraction", 0), "absorption": response.get("receive_absorption", 0), "control": response.get("receive_control", 0), "retention": response.get("retention", 0)},
		"redirection": {"facing": request.facing, "directional_input": request.directional_input, "redirection": response.get("receive_redirection", 0), "scatter_radians": response.get("scatter_radians", 0), "seed": request.response_seed},
		"intent_transfer": {"intended_velocity": request.base_velocity, "outgoing_velocity": result.velocity, "delivery_quality": result.outgoing_shot.get("delivery_quality", assessment.get("quality", 0))},
		"consequences": {"sweet": assessment.get("sweet", false), "quality": assessment.get("quality", 0), "outgoing_shot": result.outgoing_shot, "recovery": assessment.get("recovery", ""), "separation_offset": result.separation_offset, "body_guard": response.get("body_guard", false)},
	}
	var stages: Array = []
	for stage in Registry.STAGES:
		stages.append(Registry.record(stage, evidence[stage]))
	return Snapshot.freeze(stages)
