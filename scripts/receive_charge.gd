extends RefCounted
const ABOVE_LEEWAY := 0.15
const CONTROL_CHARGE := 0.65
const FULL_SHANK_GAP := 0.35

static func match_charge(shot: Dictionary, charge: float, cushioning: float = 0.0, tolerance: float = 0.0) -> Dictionary:
	var required := str(shot.get("kind", "")) in ["serve", "attack"] and shot.has("charge")
	var lower := maxf(float(shot.get("charge", 0)), 0)
	var upper := lower + ABOVE_LEEWAY
	var input_charge := charge
	charge = maxf(0,charge+cushioning)
	var status := "unrestricted"
	if required:
		status = "undercharged" if charge < lower else ("overcharged" if charge > upper else "matched")
	var gap := maxf(lower - charge, charge - upper) if required else 0.0
	gap = maxf(0, gap)
	var severity := smoothstep(0, FULL_SHANK_GAP*(1.0+maxf(tolerance,0)/100.0), gap)
	var result := {"gap": gap, "severity": severity, "required": required, "matched": status in ["matched", "unrestricted"], "status": status, "incoming_charge": lower, "receive_charge": charge, "input_charge":input_charge,"cushioning":cushioning,"tolerance":tolerance, "minimum": lower, "maximum": upper}
	result.make_read_only()
	return result

static func assess(assessment: Dictionary, shot: Dictionary, charge: float, cushioning: float = 0.0, tolerance: float = 0.0) -> Dictionary:
	var result := assessment.duplicate(true)
	var match_result := match_charge(shot, charge, cushioning,tolerance)
	result["charge_match"] = match_result
	if not match_result.matched:
		result["sweet"] = false
		result["quality"] = minf(float(result.get("quality", 0.25)), lerpf(1.0, 0.25, float(match_result.severity)))
		result["zone"] = ("UNDERCHARGED" if match_result.status == "undercharged" else "OVERCHARGED") + (" SHANK" if match_result.severity >= 0.5 else " / MILD")
	return result

static func velocity(controlled: Vector3, incoming: Vector3, facing: Vector3, assessment: Dictionary) -> Vector3:
	var match_result: Dictionary = assessment.get("charge_match", {})
	if match_result.get("matched", true):
		return controlled
	var forward := Vector3(facing.x, 0, facing.z).normalized()
	var coord: Vector3 = assessment.get("platform_coord", Vector3.ZERO)
	var side := signf(coord.x) if absf(coord.x) > 0.01 else (signf(incoming.dot(forward.cross(Vector3.UP))) if absf(incoming.dot(forward.cross(Vector3.UP))) > 0.01 else 1.0)
	if match_result.status == "undercharged":
		var deficit := clampf(float(match_result.minimum) - float(match_result.receive_charge), 0, 1)
		var carry := lerpf(0.65, 0.95, deficit)
		var shank := incoming * carry + forward.rotated(Vector3.UP, -side * 0.18) * 1.5 + Vector3.UP * 0.7
		return controlled.lerp(shank, float(match_result.get("severity", 1.0)))
	var excess := clampf(float(match_result.receive_charge) - float(match_result.maximum), 0, 1)
	var output := controlled.rotated(Vector3.UP, -side * deg_to_rad(14.0 + excess * 20.0)) * (1.25 + excess * 0.75)
	output.y = maxf(0.3, controlled.y * (0.45 - excess * 0.20))
	return controlled.lerp(output, float(match_result.get("severity", 1.0)))

static func shot(kind: String, charge: float, actor: String) -> Dictionary:
	var result := {"kind": kind, "charge": maxf(charge, 0), "actor": actor}
	result.make_read_only()
	return result
