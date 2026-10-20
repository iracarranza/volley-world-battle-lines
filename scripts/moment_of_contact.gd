extends Node

signal impact_started(event: Dictionary)
signal impact_ended

# Contact-triggered local simulation clocks; preparation always runs at full speed.
enum Mode { CURRENT_SLOWDOWN, TUNED_SLOWDOWN, NONE, TRAJECTORY_STEERING }
const Steering := preload("res://scripts/moc_steering.gd")
var steering := Steering.new()
var steering_speed := 0.05
var steering_duration := 0.40
var steering_rate := 1.25
var steering_hp_cost := 10.0
var steering_ramp := 0.06
var steering_feedback: Dictionary = {}
var mode := Mode.CURRENT_SLOWDOWN
const TUNED_DURATION := 0.2
const DURATION_EXTENSION := 0.100
const SLOW_SCALE := 0.60
const TUNED_SLOW_SCALE := 0.10
const SWEET_BONUS := 0.040
const CHAIN_BASE_LIMIT := 0.18
const CHAIN_LIMIT := CHAIN_BASE_LIMIT + DURATION_EXTENSION
const CHAIN_RECOVERY := 0.08
var enabled := true:
	set(value):
		enabled = value
		if not value:
			clear()
var tuned_speed := TUNED_SLOW_SCALE
var tuned_duration := TUNED_DURATION
var affect_ball := true
var affect_actor := true
var acting_actor := ""
var active := false
var last_event: Dictionary = {}
var event_count := 0
var _recent_ids: Array[String] = []
var _end_usec := 0
var _chain_start_usec := 0
var _blocked_until_usec := 0
var owner_lab: Node3D

# Tunable visual impact measure, not a measured force/energy model. Both pace
# and redirection matter: a fast soft receive still absorbs a strong impact.
static func impact_speed(incoming: Vector3, outgoing: Vector3) -> float:
	if not incoming.is_finite() or not outgoing.is_finite():
		return 0.0
	return incoming.length() * 0.25 + outgoing.length() * 0.25 + (outgoing - incoming).length() * 0.5

static func base_duration_for(action: int, incoming: Vector3, outgoing: Vector3, sweet: bool = false) -> float:
	if action < 0 or action > 4 or action == 1:
		return 0.0
	var impact := impact_speed(incoming, outgoing)
	var velocity_duration := lerpf(0.018, 0.140, clampf(impact / 30.0, 0, 1)) if impact >= 0.5 else 0.0
	return velocity_duration + (SWEET_BONUS if sweet else 0.0)

static func duration_for(action: int, incoming: Vector3, outgoing: Vector3, sweet: bool = false) -> float:
	var base := base_duration_for(action,incoming,outgoing,sweet)
	return base + DURATION_EXTENSION if base > 0 else 0.0

func set_mode(next_mode: int) -> void:
	next_mode = clampi(next_mode,Mode.CURRENT_SLOWDOWN,Mode.TRAJECTORY_STEERING)
	if mode == next_mode:
		return
	clear()
	mode = next_mode

func mode_name() -> String:
	if mode == Mode.TRAJECTORY_STEERING: return "Trajectory Steering"
	return "No MoC" if mode == Mode.NONE else ("Current Slowdown" if mode == Mode.CURRENT_SLOWDOWN else "Tuned Slowdown")

static func tuned_parts(event: Dictionary) -> Dictionary:
	# Fixed real-time observation window, independent of charge or contact quality.
	var duration := TUNED_DURATION if int(event.get("action", -1)) == 2 else 0.0
	return {"contact":duration,"velocity":0.0,"sweet":0.0,"extension":0.0,"total":duration}

func _effect_scale() -> float:
	if active and _now() >= _end_usec:
		_expire(_now())
	if active and mode == Mode.TRAJECTORY_STEERING:
		var age := float(_now()-_chain_start_usec)/1000000.0
		var ramp := minf(steering_ramp,float(_end_usec-_chain_start_usec)/1000000.0*0.25)
		return lerpf(1.0,steering_speed,smoothstep(0,maxf(ramp,0.0001),age))
	return (tuned_speed if mode == Mode.TUNED_SLOWDOWN else SLOW_SCALE) if active else 1.0

func simulation_scale() -> float:
	var scale := _effect_scale()
	return scale if affect_ball else 1.0

func actor_scale(actor_id: String) -> float:
	var scale := _effect_scale()
	return scale if affect_actor and actor_id == acting_actor else 1.0

# Helpers plan in ball-flight seconds, so they share its slowdown. A separately
# slowed acting bot still respects its own clock when ball slowdown is disabled.
func bot_scale(actor_id: String) -> float:
	return minf(simulation_scale(),actor_scale(actor_id))

func charge_duration(event: Dictionary) -> float:
	var action := int(event.get("action",-1))
	var shot: Dictionary = event.get("incoming_shot",{}) if action in [0,1,5] else event.get("outgoing_shot",{})
	if action == 4 or shot.get("kind","") == "serve": return 0.10
	var charge := float(shot.get("charge",event.get("charge",0.0 if action == 5 else 1.0)))
	return lerpf(0.05,maxf(0.05,steering_duration),clampf(charge,0,1))

func begin(event: Dictionary) -> void:
	var incoming := Vector3(event.get("incoming_velocity", Vector3.ZERO))
	var outgoing := Vector3(event.get("outgoing_velocity", Vector3.ZERO))
	var legacy_duration := duration_for(int(event.action), incoming, outgoing, bool(event.get("sweet", false)))
	var parts := tuned_parts(event)
	if int(event.action) == 2:
		parts.contact = tuned_duration
		parts.total = tuned_duration
	var duration: float = 0.0 if mode == Mode.NONE else (legacy_duration if mode == Mode.CURRENT_SLOWDOWN else parts.total)
	if mode == Mode.TRAJECTORY_STEERING:
		duration = charge_duration(event) if int(event.action) in [0,1,2,3,4,5] else 0.0
	if not bool(event.get("physical_hit", false)):
		return
	if mode == Mode.CURRENT_SLOWDOWN and legacy_duration <= 0 and int(event.action) != 1:
		return
	var event_id := str(event.get("id", ""))
	if not event_id.is_empty():
		if event_id in _recent_ids:
			return
		_recent_ids.append(event_id)
		if _recent_ids.size() > 64:
			_recent_ids.pop_front()
	last_event = event.duplicate()
	last_event["moc_mode"] = mode_name()
	last_event["velocity_duration_seconds"] = base_duration_for(int(event.action), incoming, outgoing) if mode == Mode.CURRENT_SLOWDOWN else parts.velocity
	last_event["sweet_duration_seconds"] = (SWEET_BONUS if event.get("sweet", false) and int(event.action) != 1 else 0.0) if mode == Mode.CURRENT_SLOWDOWN else parts.sweet
	last_event["duration_extension_seconds"] = DURATION_EXTENSION if mode == Mode.CURRENT_SLOWDOWN and duration > 0 else (parts.extension if mode == Mode.TUNED_SLOWDOWN else 0.0)
	last_event["contact_duration_seconds"] = parts.contact if mode == Mode.TUNED_SLOWDOWN else 0.0
	last_event["duration_seconds"] = duration
	last_event["incoming_speed"] = incoming.length()
	last_event["outgoing_speed"] = outgoing.length()
	last_event["velocity_change"] = (outgoing - incoming).length()
	last_event.make_read_only()
	event_count += 1
	# A new non-spike contact ends the tuned observation of the previous spike.
	if (int(event.action) == 1 and mode != Mode.TRAJECTORY_STEERING) or (mode == Mode.TUNED_SLOWDOWN and int(event.action) != 2):
		clear()
	impact_started.emit(last_event)
	if duration <= 0 or not enabled or (is_instance_valid(owner_lab) and owner_lab.paused):
		return
	var now := _now()
	if active and now >= _end_usec:
		_expire(now)
	if mode == Mode.TRAJECTORY_STEERING:
		_chain_start_usec = now
		_end_usec = now+int(duration*1000000)
		acting_actor = str(event.get("actor","player"))
		var vision: float = owner_lab.contact_flow.profile(acting_actor).trait_effect("court_vision") if is_instance_valid(owner_lab) else 0.0
		steering.begin(event,vision)
		steering_feedback = {"amount":0.0,"spent":0.0,"color":Steering.BLUE}
		active = true
		return
	if mode == Mode.TUNED_SLOWDOWN:
		_chain_start_usec = now
		_end_usec = now + int(tuned_duration * 1000000)
		acting_actor = str(event.get("actor", "player"))
		active = true
		return
	if now < _blocked_until_usec:
		return
	if not active:
		_chain_start_usec = now
		active = true
	var limit := CHAIN_LIMIT
	_end_usec = mini(maxi(_end_usec, now) + int(duration * 1000000), _chain_start_usec + int(limit * 1000000))
	acting_actor = str(event.get("actor", "player"))
	# Slow simulation deltas locally; leave engine scheduling and rendering live.

func _process(_delta: float) -> void:
	if not active:
		return
	if is_instance_valid(owner_lab) and owner_lab.paused:
		clear()
	elif _now() >= _end_usec:
		_expire(_now())

func _expire(now: int) -> void:
	var limit := CHAIN_LIMIT
	var capped := mode == Mode.CURRENT_SLOWDOWN and _end_usec >= _chain_start_usec + int(limit*1000000)
	clear()
	if capped:
		_blocked_until_usec = now + int(CHAIN_RECOVERY * 1000000)

func clear() -> void:
	steering_feedback = {}
	acting_actor = ""
	_blocked_until_usec = 0
	if active:
		active = false
		impact_ended.emit()
	_end_usec = 0
	_chain_start_usec = 0

func _exit_tree() -> void:
	clear()

# The simulation can inject a clock in tests; gameplay uses monotonic real time.
var clock: Callable = Time.get_ticks_usec

func _now() -> int:
	return int(clock.call())

func steering_active() -> bool:
	_effect_scale()
	return active and mode == Mode.TRAJECTORY_STEERING and acting_actor == "player"

func steer(dt: float, input: Vector3) -> void:
	if not steering_active() or not is_instance_valid(owner_lab) or not owner_lab.ball_active: return
	var athlete = owner_lab.athlete
	var hp_multiplier := 1.5 if athlete.exhausted else 1.0
	var before := steering.velocity
	steering_feedback = steering.step(input,dt,steering_rate,steering_hp_cost*hp_multiplier*maxf(0,1.0-athlete.trait_effect("di_cost_reduction")/100.0),athlete.hp)
	athlete.spend(0,float(steering_feedback.cost)/hp_multiplier)
	# Preserve gravity/physics accumulated since the preceding real-time update.
	owner_lab.ball_velocity += steering.velocity-before
