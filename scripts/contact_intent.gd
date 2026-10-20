extends RefCounted
const Snapshot := preload("res://scripts/contact/snapshot.gd")

# Intended flight is immutable communication data, separate from resolved flight.
static func capture(actor: String, team: int, action: int, charge: float, origin: Vector3, target: Vector3, velocity: Vector3, simulation_time: float, influence: Dictionary = {},charge_mode: String = "manual") -> Dictionary:
	var direction := target - origin
	direction.y = 0
	direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var result := {"option_id": "neutral", "direction": direction, "actor": actor, "team": team, "action": action, "charge": charge if charge_mode == "manual" else "auto", "charge_mode":charge_mode, "origin": origin, "target": target, "preview_velocity": velocity, "simulation_time": simulation_time, "directional_influence": influence}
	return Snapshot.freeze(result)
