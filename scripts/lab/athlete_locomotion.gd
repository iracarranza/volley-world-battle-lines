extends RefCounted

# The athlete's hips and legs follow where they are going while the head keeps looking at the cursor.
#
# The body's own yaw stays the aim direction, because hurtboxes, contacts and the camera are built on it. This layer is
# purely visual: it turns the pelvis (legs, hips, tail) toward the direction of travel, lets the hips lag behind a fast
# cursor turn, and counter-twists the lumbar spine, chest and neck so the head faces the cursor as far as a spine can.
#
# Travelling away from the cursor beyond what the spine allows becomes a backpedal: the hips face the cursor and the
# legs run backwards, rather than twisting past 100 degrees.
#
# Steps are procedural. From standing, one leg leads toward the input direction while the other pushes off behind
# it. Asking for the opposite direction at speed first braces on the grounded (trailing) leg, planted ahead and bent to
# kill the momentum while the other leg lifts toward the new direction; once the speed is gone the hips turn and the
# launch step goes the new way.
#
# Everything here is a function of velocity, input and the cursor yaw, with explicit dt, so a test can step it.
const PELVIS_LIMIT := 95.0           # degrees the hips may sit away from the cursor direction
const TURN_RATE := 620.0             # degrees per second the hips swing toward a new direction
const SETTLE_RATE := 240.0           # degrees per second they come back to the cursor when standing
const STANDING_SPEED := 0.45
const BACKPEDAL_ENTER := 112.0       # degrees from the cursor beyond which the hips face the cursor and the legs reverse
const BACKPEDAL_EXIT := 96.0
const REVERSAL_DOT := -0.35          # input against the velocity by this much starts a brake
const BRAKE_MIN_SPEED := 1.4
const BRAKE_RELEASE_SPEED := 1.0
const BRAKE_MAX_SECONDS := 0.45
const LAUNCH_SECONDS := 0.26
const BLEND_RATE := 9.0
# How a counter-twist is shared out, within each region's range of movement: lumbar 15, chest 40, neck 70 degrees.
const LUMBAR_SHARE := 0.17
const THORACIC_SHARE := 0.44
const LUMBAR_MAX := 15.0
const THORACIC_MAX := 40.0
const NECK_MAX := 70.0
# Leg poses (hip flexion, knee, abduction) laid over the gait for a step, in degrees, in the pelvis's frame.
const LEAD_STEP := {"hip": 40.0, "knee": -42.0, "abduction": 6.0}
const PUSH_OFF := {"hip": -26.0, "knee": -6.0, "abduction": 4.0}
const BRACE := {"hip": 18.0, "knee": -40.0, "abduction": 10.0}
const REACH_NEW := {"hip": -30.0, "knee": -46.0, "abduction": 6.0}
const BRACE_LEAN := -12.0            # extra hip hinge, leaning back against the momentum

var pelvis_world := 0.0              # world yaw the hips point at, radians
var mode := "idle"                   # idle, run, brake, launch
var mode_time := 0.0
var backpedal := false
var lead := 1                        # leg (0 left, 1 right) that leads the next step
var brake_leg := 0
var weight := 0.0
var last_pelvis_relative := 0.0

func reset(facing_yaw: float) -> void:
	pelvis_world = facing_yaw
	mode = "idle"
	mode_time = 0.0
	backpedal = false
	weight = 0.0
	last_pelvis_relative = 0.0

static func _angle(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)

static func _wrap(angle: float) -> float:
	return wrapf(angle, -PI, PI)

# One frame. `ctx`: facing_yaw (cursor/aim, radians), velocity (Vector3), wish (the input direction in the world, zero
# when no key is down), enabled (false in the air, dives, receives and so on), hips (the gait's {left, right} hip
# flexion, to tell the grounded leg from the swinging one).
func update(dt: float, ctx: Dictionary) -> Dictionary:
	var facing: float = ctx.facing_yaw
	var velocity: Vector3 = ctx.velocity
	velocity.y = 0.0
	var speed := velocity.length()
	var wish: Vector3 = ctx.wish
	wish.y = 0.0
	var wishing := wish.length_squared() > 0.04
	if not bool(ctx.enabled):
		weight = move_toward(weight, 0.0, BLEND_RATE * dt)
		pelvis_world = facing
		mode = "idle"
		mode_time = 0.0
		backpedal = false
		return _result(facing, 0.0, ctx)
	weight = move_toward(weight, 1.0, BLEND_RATE * dt)
	mode_time += dt
	var travel := _angle(velocity) if speed > STANDING_SPEED else (_angle(wish) if wishing else facing)
	match mode:
		"idle":
			if wishing and speed < BRAKE_MIN_SPEED:
				_enter("launch", ctx)
			elif speed > STANDING_SPEED and wishing:
				_enter("run", ctx)
		"launch":
			if mode_time >= LAUNCH_SECONDS:
				_enter("run" if wishing or speed > STANDING_SPEED else "idle", ctx)
		"run":
			if wishing and speed > BRAKE_MIN_SPEED and wish.normalized().dot(velocity.normalized()) < REVERSAL_DOT:
				_enter("brake", ctx)
			elif not wishing and speed < STANDING_SPEED:
				_enter("idle", ctx)
		"brake":
			if speed < BRAKE_RELEASE_SPEED or mode_time > BRAKE_MAX_SECONDS or not wishing:
				_enter("launch" if wishing else "idle", ctx)
	# Where the hips want to point, in the world.
	var target := facing
	match mode:
		"run":
			target = travel
		"launch":
			target = _angle(wish) if wishing else travel
		"brake":
			target = _angle(velocity) if speed > 0.2 else pelvis_world   # held on the old line while the legs brake
	var relative_target := _wrap(target - facing)
	if mode == "idle":
		backpedal = false
	elif absf(relative_target) > deg_to_rad(BACKPEDAL_ENTER):
		backpedal = true
	elif absf(relative_target) < deg_to_rad(BACKPEDAL_EXIT):
		backpedal = false
	if backpedal:
		relative_target = _wrap(relative_target + PI)
	var rate := deg_to_rad(SETTLE_RATE if mode == "idle" else TURN_RATE)
	var here := _wrap(pelvis_world - facing)
	var step := clampf(_wrap(relative_target - here), -rate * dt, rate * dt)
	var next := here + step
	# The cursor drags the hips along when it swings further than the spine allows.
	var limit := deg_to_rad(PELVIS_LIMIT)
	next = clampf(next, -limit, limit)
	pelvis_world = facing + next
	return _result(facing, next, ctx)

func _enter(new_mode: String, ctx: Dictionary) -> void:
	mode = new_mode
	mode_time = 0.0
	var hips: Dictionary = ctx.get("hips", {"left": 0.0, "right": 0.0})
	# The grounded leg is the trailing one: the one with less hip flexion.
	var trailing := 0 if float(hips.get("left", 0.0)) <= float(hips.get("right", 0.0)) else 1
	if new_mode == "brake":
		brake_leg = trailing
		lead = 1 - trailing
	elif new_mode == "launch":
		# Reversing: the leg that braced pushes off and the other leads. From standing the legs take turns.
		lead = 1 - brake_leg if _was_braking else 1 - lead
	_was_braking = new_mode == "brake"

var _was_braking := false

func _result(facing: float, relative: float, ctx: Dictionary) -> Dictionary:
	var p := rad_to_deg(relative) * weight
	var magnitude := absf(p)
	var sign_p := signf(p)
	var lumbar := minf(magnitude * LUMBAR_SHARE, LUMBAR_MAX)
	var thoracic := minf(magnitude * THORACIC_SHARE, THORACIC_MAX)
	var neck := minf(magnitude - lumbar - thoracic, NECK_MAX)
	last_pelvis_relative = relative
	# The gait heading is the travel direction as the hips see it: zero running forward along them, pi backpedalling.
	var velocity: Vector3 = ctx.get("velocity", Vector3.ZERO)
	var heading := 0.0
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		heading = _wrap(_angle(Vector3(velocity.x, 0.0, velocity.z)) - pelvis_world)
	return {
		"weight": weight,
		"mode": mode,
		"pelvis_world": pelvis_world,
		"hip_yaw": p,
		"lumbar_twist": -sign_p * lumbar,
		"thoracic_twist": -sign_p * thoracic,
		"neck_twist": -sign_p * maxf(neck, 0.0),
		"heading": heading,
		"backpedal": backpedal,
		"lead": lead,
		"brake_leg": brake_leg,
		"time": mode_time,
		"lean": BRACE_LEAN * _brace_weight() * weight,
		"legs": _legs(),
	}

func _brace_weight() -> float:
	return smoothstep(0.0, 0.10, mode_time) if mode == "brake" else 0.0

# Overlay for each leg: {hip, knee, abduction, weight} in the pelvis's frame, or an empty dictionary for none.
func _legs() -> Dictionary:
	var out := {}
	match mode:
		"launch":
			var t := mode_time / LAUNCH_SECONDS
			var w := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.55, 1.0, t)) * weight
			out[lead] = LEAD_STEP.merged({"weight": w})
			out[1 - lead] = PUSH_OFF.merged({"weight": w})
		"brake":
			var w := smoothstep(0.0, 0.10, mode_time) * weight
			out[brake_leg] = BRACE.merged({"weight": w})
			out[1 - brake_leg] = REACH_NEW.merged({"weight": w})
	return out

# Lay the leg overlay on the legs the gait just posed. `legs` is the two leg nodes, left then right.
static func apply_legs(legs: Array, overlay: Dictionary) -> void:
	for index in overlay:
		var o: Dictionary = overlay[index]
		var w := float(o.weight)
		if w <= 0.0:
			continue
		var leg := legs[index] as Node3D
		var knee := leg.get_node("Knee") as Node3D
		leg.rotation_degrees.x = lerpf(leg.rotation_degrees.x, float(o.hip), w)
		leg.rotation_degrees.z = lerpf(leg.rotation_degrees.z, float(o.abduction) * (-1.0 if index == 0 else 1.0), w)
		knee.rotation_degrees.x = lerpf(knee.rotation_degrees.x, float(o.knee), w)
