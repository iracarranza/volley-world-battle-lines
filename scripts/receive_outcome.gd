extends RefCounted

# Gameplay-only receive classification. Animation consumers use recovery/recovery_seconds.
const SHANK_SEVERITY := 0.5
const CENTER_SIDE := 0.40
const CENTER_FRONT := 0.68
const ASSIST := 0.35
const WRONG_PENALTY := 0.35
const DURATIONS := {"":0.0,"knee":0.55,"fall_roll":0.95,"fall_slide":0.95,"blown_away":1.35,"shrug":0.25}

static func assess(assessment: Dictionary, shape: Dictionary, local: Vector3, speed: float, world_input: Vector3, yaw: float) -> Dictionary:
	var result := assessment.duplicate(true)
	var posture := preload("res://scripts/receive_platform.gd").posture(shape,local,speed)
	var coord: Vector3 = result.get("platform_coord",Vector3.ZERO)
	var height := (local.y-(float(shape.center.y)-float(shape.size.y)*0.5))/float(shape.size.y)
	var front := maxf(-local.z/float(shape.forward_reach),0)
	var central := absf(coord.x) <= CENTER_SIDE and front <= CENTER_FRONT
	var low := height <= 1.0/3.0
	var match_result: Dictionary = result.get("charge_match",{})
	var under: bool = match_result.get("status","") == "undercharged"
	var raw_severity := float(match_result.get("severity",0))
	var forward := Vector3.FORWARD.rotated(Vector3.UP,yaw)
	var input := world_input.limit_length(1.0)
	var axes := Vector2(input.dot(forward.cross(Vector3.UP)),input.dot(forward)).limit_length(1.0)
	# Resolve the corrective direction before mitigation, so input cannot manufacture
	# a different geometry or turn an undercharged contact into a sweet receive.
	var correction := Vector2.ZERO
	if under and central and (raw_severity >= SHANK_SEVERITY or not low or axes.y < 0):
		correction = Vector2(0,-1)
	elif low and not (under and raw_severity >= SHANK_SEVERITY):
		correction = Vector2(0,1)
	elif posture in ["reaching","off-axis"]:
		correction = Vector2(signf(coord.x) if absf(coord.x) > 0.01 else signf(axes.x),0)
	var alignment := axes.dot(correction)
	var penalty_factor := 1.0-ASSIST*maxf(alignment,0)+WRONG_PENALTY*maxf(-alignment,0)
	var geometry_quality := float(result.get("quality",1))
	result["quality"] = clampf(1.0-(1.0-geometry_quality)*penalty_factor,0,1)
	result["posture"] = posture
	result["band"] = posture.to_upper()
	result["penalty_platform_coord"] = coord*penalty_factor
	if not match_result.is_empty():
		match_result = match_result.duplicate(true)
		match_result["raw_severity"] = raw_severity
		match_result["severity"] = clampf(raw_severity*penalty_factor,0,1)
		result["charge_match"] = match_result
	var outcome := ""
	if bool(result.get("hit",false)):
		if under and raw_severity >= SHANK_SEVERITY:
			outcome = "blown_away" if central else ("fall_slide" if posture in ["moving","reaching"] else "fall_roll")
		elif under and central and axes.y < 0 and raw_severity > 0:
			outcome = "shrug"
		elif low:
			outcome = "knee"
	# Recovery penalties stay explicit for Claude's animation/controller wiring.
	var evidence := {"outcome":outcome,"posture":posture,"central":central,"bottom_third":low,"height_fraction":height,"platform_coord":coord,"di_axes":axes,"correction":correction,"di_alignment":alignment,"penalty_factor":penalty_factor,"raw_charge_severity":raw_severity,"charge_severity":float(match_result.get("severity",0)),"recovery_seconds":float(DURATIONS[outcome]),"recovery_penalty_seconds":float(DURATIONS[outcome])*penalty_factor}
	evidence.make_read_only()
	result["receive_outcome"] = evidence
	result["recovery"] = outcome
	result["recovery_seconds"] = evidence.recovery_seconds
	return result

static func velocity(controlled: Vector3, assessment: Dictionary) -> Vector3:
	var outcome: Dictionary = assessment.get("receive_outcome",{})
	if outcome.get("outcome","") == "knee":
		# A low platform loses lift; forward influence recovers part of that loss.
		controlled.y *= maxf(0.0,1.0-0.18*float(outcome.get("penalty_factor",1)))
	return controlled
