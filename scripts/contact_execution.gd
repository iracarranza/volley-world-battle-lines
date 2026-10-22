extends RefCounted

# Precision windows are doubled around their original midpoints.
# The nominal 200 ms preparation lead remains the bot/preview reference.
const SWEET_DELAY := 0.20
const SWEET_SECONDS := 0.18
const SWEET_CENTER := 0.245
const CONTACT_SECONDS := 0.55
# Spike timing is independent of Set/Receive/Block and the serve clock.
# Session-wide tuning shared by collision, animation, previews and bots.
static var spike_windup_enabled := true
static var spike_windup_seconds := 0.4
static var SPIKE_WINDUP: float:
	get: return clampf(spike_windup_seconds, 0.0, 1.0) if spike_windup_enabled else 0.0
const SPIKE_SWEEP_SECONDS := 0.2
static var SPIKE_PEAK: float:
	get: return SPIKE_WINDUP + SPIKE_SWEEP_SECONDS * 0.5
static var SPIKE_END: float:
	get: return SPIKE_WINDUP + SPIKE_SWEEP_SECONDS
const SPIKE_POWER_HALF := 0.06
static var SPIKE_POWER_START: float:
	get: return SPIKE_PEAK - SPIKE_POWER_HALF
static var SPIKE_RESCUE_SECONDS: float:
	get: return SPIKE_PEAK + SPIKE_POWER_HALF
const SPIKE_SWEET_SECONDS := 0.06
const RECEIVE_SWEET_SECONDS := 0.32
const RECEIVE_SWEET_CENTER := 0.28

static func sweet_seconds(action: int) -> float:
	return SPIKE_SWEET_SECONDS if action == 2 else (RECEIVE_SWEET_SECONDS if action == 0 else SWEET_SECONDS)

static func sweet_start(action: int) -> float:
	var midpoint := SPIKE_PEAK if action == 2 else (RECEIVE_SWEET_CENTER if action == 0 else SWEET_CENTER)
	return midpoint - sweet_seconds(action) * 0.5

static func sweet_end(action: int) -> float:
	return sweet_start(action) + sweet_seconds(action)

static func sweet_active(action: int, age: float) -> bool:
	return age >= sweet_start(action) - 0.000001 and age <= sweet_end(action) + 0.000001

static func assess(spatial: Dictionary, age: float, remembered: bool = false, action: int = -1) -> Dictionary:
	var result := spatial.duplicate(true)
	var live := age >= (SPIKE_WINDUP if action == 2 else 0.0) and age <= contact_seconds(action)
	var precision := live and sweet_active(action, age) and not remembered and not bool(result.get("rescue_only", false))
	var sweet := precision and bool(result.get("hit", false)) and str(result.get("zone", "")) in ["SWEET SPOT", "CLEAN"]
	result["sweet"] = sweet
	result["rescue"] = live and (not precision or remembered)
	result["confirmation_age"] = age
	if action == 2 and live:
		var very_far := float(result.get("reach_ratio", 0)) >= 1.80 or float(result.get("depth_ratio", 0)) >= 0.95
		var early := age < SPIKE_POWER_START
		result["rescue"] = remembered or age >= SPIKE_RESCUE_SECONDS or very_far or early
		result["spike_form"] = "roll" if early and not (remembered or very_far) else ("push" if result.rescue else "power")
		result["forgiving_spike"] = not sweet and not result.rescue
		var off_center := smoothstep(sweet_end(action), SPIKE_RESCUE_SECONDS, age) if age > sweet_end(action) else smoothstep(sweet_start(action), SPIKE_POWER_START, age)
		result["spike_power_factor"] = lerpf(1.0, 0.78, off_center)
		if result.forgiving_spike:
			if bool(result.get("rescue_only", false)):
				var stretch := smoothstep(1.0, 1.80, float(result.get("reach_ratio", 1)))
				result["strength"] = maxf(float(result.get("strength", 0.48)), lerpf(0.90, 0.68, stretch))
			result["strength"] = minf(float(result.get("strength", 0.95)), 0.98)
			if age > sweet_end(action) or bool(result.get("rescue_only", false)):
				result["zone"] = "LATE SPIKE" if age > sweet_end(action) else "STRETCHED SPIKE"
				result["quality"] = minf(float(result.get("quality", 0.7)), 0.80)
	if not live:
		result.merge({"hit": false, "quality": 0.0, "zone": "EXPIRED"}, true)
	elif result.rescue:
		result["zone"] = "RESCUE"
		result["quality"] = minf(float(result.get("quality", 0.35)), 0.45)
	elif not sweet and str(result.get("zone", "")) in ["SWEET SPOT", "CLEAN"]:
		result["zone"] = "FAIR"
	return result

static func velocity(action: int, outgoing: Vector3, incoming: Vector3, facing: Vector3, assessment: Dictionary, timing: float, ideal: Vector3 = Vector3.ZERO, ball_control: float = 65.0, flow: float = 0.0, available_output: float = 1.0) -> Vector3:
	var direction := Vector3(facing.x, 0, facing.z).normalized()
	var t := clampf(timing / 100.0, 0, 1)
	var control := preload("res://scripts/stat_tuning.gd").pace(ball_control)
	var flow_fraction := clampf(flow/100.0,0,1)
	if bool(assessment.get("rescue", false)) and action == 2 and str(assessment.get("spike_form", "")) == "roll":
		# Early swing: a controlled roll shot, still facing-only.
		return (direction * 5.5 + Vector3.UP * 3.0)*available_output
	if bool(assessment.get("rescue", false)) and action in [0, 2]:
		# Facing-only push: no target selection or directional influence survives.
		return (direction * (3.2 if action == 2 else 3.8) + Vector3.UP * (2.0 if action == 2 else 6.0))*available_output
	var sweet := bool(assessment.get("sweet", false))
	match action:
		0:
			if ideal.length_squared() > 0.001:
				outgoing = ideal+(outgoing-ideal)/maxf(0.1,control)
				outgoing = outgoing.lerp(ideal,0.12*flow_fraction)
			if sweet and ideal.length_squared() > 0.001:
				outgoing = outgoing.lerp(ideal, lerpf(0.15, 0.75, t))
		1:
			# Even a central set has a small execution error at low Timing.
			var error := (0.012 if sweet else 0.09) * (1.0 - (t if sweet else float(assessment.get("quality", 0.4))))
			outgoing = outgoing.rotated(Vector3.UP, error/maxf(control,0.1)*(1.0-0.25*flow_fraction) * sin(incoming.x * 0.7 + incoming.z * 0.3 + 0.8))
		2:
			outgoing *= float(assessment.get("spike_power_factor", 1.0))
			outgoing *= 1.0+0.12*flow_fraction
			if sweet:
				outgoing *= lerpf(0.74, 1.14, t)
		3:
			var q := float(assessment.get("quality", 0.4))
			var absorption := lerpf(0.20, 0.50, q) + (0.40 * t if sweet else 0.0)+0.15*flow_fraction
			# Absorb tangential force, but reflect the normal component explicitly.
			# Mixing opposite velocities can cancel to zero and strand the ball.
			absorption *= available_output
			var normal_speed := absf(incoming.dot(direction))
			var tangent := Vector3(incoming.x, 0, incoming.z) - direction * incoming.dot(direction)
			var returned_speed := maxf(2.5, normal_speed * (0.24 + 0.12 * q))*available_output
			var downward := (1.0 + (4.0 * t if sweet else q)+0.8*flow_fraction)*available_output
			outgoing = direction * returned_speed + tangent * (1.0 - clampf(absorption, 0, 0.95))
			outgoing.y = minf(-0.6, incoming.y * (1.0 - absorption) - downward)
	return outgoing

static func contact_seconds(action: int) -> float:
	return SPIKE_END if action == 2 else CONTACT_SECONDS

static func ideal_age(action: int) -> float:
	return SPIKE_PEAK if action == 2 else SWEET_DELAY

static func spike_progress(age: float) -> float:
	return clampf((age - SPIKE_WINDUP) / SPIKE_SWEEP_SECONDS, 0.0, 1.0)
