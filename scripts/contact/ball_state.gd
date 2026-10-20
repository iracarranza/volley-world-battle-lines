extends RefCounted
## Ball charge describes delivered pace, separately from preparation input.
const PRESSURE_REFERENCE_SPEED := 18.0
const FOLLOW_THROUGH_CHARGE := 0.08
const Snapshot := preload("res://scripts/contact/snapshot.gd")

static func receive(action_charge: float, actor: String, incoming: Dictionary, incoming_velocity: Vector3, outgoing: Vector3, delivery_quality: float, response: Dictionary) -> Dictionary:
	var in_speed := incoming_velocity.length()
	# Calibrate against the incoming shot rather than assigning the receiver's input
	# to the ball. Squared pace ratio represents retained pressure, not extra speed.
	var source_charge := maxf(0, float(incoming.get("charge", in_speed / 30.0)))
	# A slow/stopped ball must not amplify historical shot metadata into enormous
	# pressure. Only incoming pace actually retained by this contact contributes.
	var retained := source_charge * pow(minf(outgoing.length(), in_speed) / maxf(in_speed, PRESSURE_REFERENCE_SPEED), 2)
	var follow_through := maxf(0, action_charge) * FOLLOW_THROUGH_CHARGE * delivery_quality
	return Snapshot.freeze({
		"kind": "receive", "charge": maxf(0, retained + follow_through),
		"action_charge": action_charge, "actor": actor,
		"delivery_quality": clampf(delivery_quality, 0, 1),
		"incoming_charge": source_charge, "retained_pressure": retained,
		"delivered_contribution": follow_through,
		"source_action": str(incoming.get("kind", "free_ball")),
		"reference_speed": outgoing.length(), "response_seed": response.get("seed", 0),
	})

static func set_contact(action_charge: float,actor: String,outgoing: Vector3,isolation: Dictionary,quality: float,incoming: Vector3) -> Dictionary:
	var retained: float = float(isolation.pressure)*float(isolation.severity)*pow(minf(outgoing.length(),incoming.length())/maxf(incoming.length(),PRESSURE_REFERENCE_SPEED),2)
	var delivered := pow(outgoing.length()/30.0,2)*0.65*(1.0-float(isolation.severity))
	return Snapshot.freeze({"kind":"set","actor":actor,"action_charge":action_charge,"charge":maxf(0,delivered+retained),"handling_charge":isolation.handling_charge,"delivery_quality":clampf(quality*(1.0-float(isolation.severity)),0,1),"retained_pressure":retained,"reference_speed":outgoing.length()})
