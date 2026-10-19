extends RefCounted
## Typed event construction. Published snapshots deeply own their data and are
## recursively read-only, so visual listeners cannot alter gameplay evidence.
const Snapshot := preload("res://scripts/contact/snapshot.gd")
var id := ""
var actor := ""
var team := -1
var action := 0
var charge := 0.0
var point := Vector3.ZERO
var incoming_velocity := Vector3.ZERO
var outgoing_velocity := Vector3.ZERO
var incoming_shot: Dictionary = {}
var outgoing_shot: Dictionary = {}
var assessment: Dictionary = {}
var intent: Dictionary = {}
var directional_influence: Dictionary = {}
var simulation_time := 0.0

func publish() -> Dictionary:
	var outcome: Dictionary = assessment.get("receive_outcome", {})
	return Snapshot.freeze({
		"id": id, "actor": actor, "team": team, "action": action,
		"charge": charge, "point": point,
		"incoming_velocity": incoming_velocity, "outgoing_velocity": outgoing_velocity,
		"incoming_shot": incoming_shot, "outgoing_shot": outgoing_shot,
		"physical_hit": bool(assessment.get("hit", false)),
		"zone": str(assessment.get("zone", "")),
		"quality": float(assessment.get("quality", 0.75)),
		"mechanics": assessment.get("mechanics", []),
		"receive_response": assessment.get("receive_response", {}),
		"sweet": bool(assessment.get("sweet", false)),
		"rescue": bool(assessment.get("rescue", false)),
		"confirmation_age": float(assessment.get("confirmation_age", 0.0)),
		"charge_match": assessment.get("charge_match", {}),
		"posture": str(assessment.get("posture", "")),
		"receive_outcome": outcome,
		"recovery": str(assessment.get("recovery", "")),
		"recovery_seconds": float(assessment.get("recovery_seconds", 0.0)),
		"recovery_penalty_seconds": float(outcome.get("recovery_penalty_seconds", 0.0)),
		"platform_band": str(assessment.get("band", "")),
		"platform_coord": assessment.get("platform_coord", Vector3.ZERO),
		"simulation_time": simulation_time, "intent": intent,
		"directional_influence": directional_influence,
	})
