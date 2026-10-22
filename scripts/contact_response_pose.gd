extends RefCounted
## Presentation of resolved contacts. No actor, ball, collision or input state.
const Library := preload("res://scripts/pose_library.gd")
const RECEIVE_SECONDS := 0.42
const BLOCK_SECONDS := 0.38

static func pulse(age: float, peak: float, end: float) -> float:
	if age < 0.0 or age >= end:
		return 0.0
	return smoothstep(0.0, peak, age) * (1.0 - smoothstep(peak, end, age))

static func offsets(action: int, age: float, evidence: Dictionary = {}, press_age: float = -1.0) -> Dictionary:
	var out := {}
	var charge: Dictionary = evidence.get("charge_match", {})
	var response: Dictionary = evidence.get("block_response", {})
	var severity := clampf(float(response.get("severity", charge.get("severity", 0.0))) if action == 3 else float(charge.get("severity", 0.0)), 0.0, 1.0)
	var shoulder := 0.0
	var elbow := 0.0
	if action == 0:
		var absorb := pulse(age, 0.08, 0.24)
		var release := pulse(age - 0.10, 0.12, RECEIVE_SECONDS - 0.10)
		shoulder = -lerpf(7.0, 13.0, severity)*absorb + 9.0*release
		elbow = lerpf(9.0, 18.0, severity)*absorb
		out["thoracic_flexion"] = -4.0*absorb + 3.0*release
	elif action == 3:
		var press := pulse(press_age, 0.06, 0.50)
		var recoil := pulse(age, 0.07, BLOCK_SECONDS)
		shoulder = -8.0*press + lerpf(5.0, 22.0, severity)*recoil
		elbow = 3.0*press + lerpf(6.0, 32.0, severity)*recoil
		out["thoracic_flexion"] = 3.0*press - lerpf(2.0, 7.0, severity)*recoil
		out["thoracic_bend"] = -4.0*clampf(float(response.get("side", 0.0)), -1.0, 1.0)*severity*recoil
	else:
		return out
	for side in Library.SIDES:
		out["shoulder_pitch:" + side] = shoulder
		out["elbow:" + side] = elbow
	return out

# Applied once to the freshly composed pose, before source-transition smoothing.
# The base is rebuilt each frame, so these offsets cannot accumulate.
static func apply(body: Node3D, delta: Dictionary) -> void:
	var active := false
	for value in delta.values():
		active = active or absf(float(value)) > 0.00001
	if not active:
		return
	var flat := Library.read_rig(body)
	for key in delta:
		flat[key] = float(flat.get(key, 0.0)) + float(delta[key])
	# Existing overhead stages use negative shoulder angles; preserve that convention.
	Library.apply(body, Library.from_flat(flat, false), 1.0)
