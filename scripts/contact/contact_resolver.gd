extends RefCounted
## One ordered rules pipeline for player, court bots, Pepper and previews.
## Geometry -> timing -> charge -> receive outcome -> direction -> execution -> shank.
const Registry := preload("res://scripts/contact/mechanic_registry.gd")
const BlockResponse := preload("res://scripts/contact/block_response.gd")
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
	if request.action == Action.BLOCK:
		result = BlockResponse.assess(request,spatial)
	if request.source_athlete == null: request.source_athlete = request.athlete
	if request.source_athlete.gameplay_context.is_valid():
		var evidence := result.duplicate(true)
		evidence["incoming_shot"] = request.incoming_shot
		if request.action == Action.RECEIVE and not request.ideal_charge_match:
			var baseline := Charge.assess(result,request.incoming_shot,request.charge*request.source_athlete.low_stamina_factor(),request.source_athlete.cushioning_bonus(),request.source_athlete.trait_effect("charge_tolerance"),request.auto_charge)
			evidence["mismatch"] = not bool(baseline.get("charge_match",{}).get("matched",true))
			evidence["sweet"] = baseline.get("sweet",false)
			evidence["quality"] = baseline.get("quality",0)

		request.gameplay = request.source_athlete.gameplay_context.call(request.action,evidence)
		request.athlete = request.source_athlete.contact_copy(request.gameplay.get("effects",{}))
	result["gameplay"] = request.gameplay
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
	if request.action == Action.BLOCK:
		var block := BlockResponse.assess(request,spatial)
		for key in block: result[key] = block[key]
		result["timing_assessment"] = Snapshot.freeze({"sweet_eligible":result.sweet,"rescue":false,"confirmation_age":request.block_confirmation_age,"confirmation_pulse":result.block_response.confirmation_pulse})
	if request.auto_charge: result["auto_charge"] = Snapshot.freeze(request.auto_evidence)
	return result

# Hidden-sequence variation is gone: a spread leans toward the side of the hurtbox the ball met (then the way it was travelling), at the mean
# magnitude the old per-contact sine/seed produced.
const MEAN_SPREAD := 0.64
static func contact_bias(request: Request) -> float:
	if absf(request.local_point.x) > 0.02: return signf(request.local_point.x)
	if absf(request.incoming.x) > 0.02: return signf(request.incoming.x)
	return 1.0

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
		velocity = velocity.rotated(Vector3.UP, deviation * contact_bias(request) * MEAN_SPREAD * 0.5)
	if request.action == Action.ATTACK:
		if request.aim_random != null:
			result.aiming = Aim.apply(request.origin, velocity, request.aiming_accuracy, request.gravity, request.aim_random)
			velocity = result.aiming.velocity
		result.influence = Spike.resolve(
			velocity, assessment, request.directional_input, request.facing, request.keep_attack_intent, request.athlete.trait_effect("court_vision")
		)
	else:
		result.influence = Influence.resolve(
			velocity, request.action, request.directional_input, request.intent_direction, quality, request.athlete.trait_effect("court_vision")
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
	if request.action == Action.BLOCK and assessment.hit:
		var response := BlockResponse.resolve(request,assessment)
		result.assessment["block_response"] = response.evidence
		velocity = response.velocity
		result.separation_offset = response.separation_offset
		result.outgoing_shot = response.shot
	var variance := request.athlete.trait_effect("charge_aim_variance")
	if variance > 0 and not request.ideal_charge_match:
		var degrees := variance*request.charge*(1.0+request.directional_input.length())*(1.0-request.athlete.ball_control()/120.0)
		var lean := signf(request.directional_input.x) if absf(request.directional_input.x) > 0.02 else contact_bias(request)
		velocity = velocity.rotated(Vector3.UP,deg_to_rad(degrees*MEAN_SPREAD*lean))
	result.assessment["steering"] = {"facing":request.facing,"lateral_offset":result.influence.get("geometry_lateral_offset",0)}
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
		"potency": {"action_charge": request.charge, "available_output": request.athlete.low_stamina_factor(), "effective_receive_charge": assessment.get("charge_match", {}).get("receive_charge", request.charge), "cushioning": request.athlete.cushioning_bonus() if request.action == Action.RECEIVE else 0.0,"auto_charge":request.auto_evidence,"runtime_effects":request.gameplay.get("effects",{})},
		"handling": {"profile": Registry.profile(request.action), "model": "block_response" if request.action == Action.BLOCK else ("receive_response" if not response.is_empty() else "existing_action_rules"), "charge_match": assessment.get("charge_match", {}), "incoming_velocity": request.incoming,"set_isolation":assessment.get("set_isolation",{}),"block_response":assessment.get("block_response",{})},
		"pressure_control": {"uncontrolled_fraction": response.get("uncontrolled_fraction", 0), "absorption": response.get("receive_absorption", 0), "control": response.get("receive_control", 0), "retention": response.get("retention", 0)},
		"redirection": {"facing": request.facing, "directional_input": request.directional_input, "redirection": response.get("receive_redirection", 0), "scatter_radians": response.get("scatter_radians", 0), "seed": request.response_seed},
		"intent_transfer": {"intended_velocity": request.base_velocity, "outgoing_velocity": result.velocity, "delivery_quality": result.outgoing_shot.get("delivery_quality", assessment.get("quality", 0))},
		"consequences": {"sweet": assessment.get("sweet", false), "quality": assessment.get("quality", 0), "outgoing_shot": result.outgoing_shot, "recovery": assessment.get("recovery", ""), "separation_offset": result.separation_offset, "body_guard": response.get("body_guard", false)},
	}
	var stages: Array = []
	for stage in Registry.STAGES:
		stages.append(Registry.record(stage, evidence[stage]))
	return Snapshot.freeze(stages)
