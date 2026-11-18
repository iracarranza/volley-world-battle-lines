extends RefCounted
const C := preload("res://tests/support/characterization.gd")
var lab: Node
var trace: Array = []
var events: Array = []
func _init(owner_lab: Node) -> void:
	lab = owner_lab
	lab.moc.impact_started.connect(func(event): events.append(event))
func step(label: String, extra: Dictionary = {}) -> void:
	trace.append({"label": label, "state": C.snapshot(lab), "extra": C.norm(extra)})
func event_log() -> Array:
	return events.map(func(e): return C.norm({"id": e.get("id", ""), "actor": e.get("actor", ""), "action": e.get("action", -1), "team": e.get("team", -1), "charge": e.get("charge", -1.0),
		"quality": e.get("quality", -1.0), "zone": e.get("zone", ""), "sweet": e.get("sweet", false), "rescue": e.get("rescue", false),
		"incoming": e.get("incoming_velocity", Vector3.ZERO), "outgoing": e.get("outgoing_velocity", Vector3.ZERO),
		"confirmation_age": e.get("confirmation_age", -1.0), "simulation_time": e.get("simulation_time", -1.0)}))

