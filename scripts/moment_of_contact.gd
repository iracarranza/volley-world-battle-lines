extends Node

signal impact_started(event: Dictionary)
signal impact_ended

# Real-time milliseconds, deliberately brief impact emphasis, not selection time.
enum Mode { CURRENT_SLOWDOWN, IMPACT_HOLD, NONE }
var mode := Mode.CURRENT_SLOWDOWN
const HOLD_FRAME := 1.0 / 60.0
const DURATION_EXTENSION := 0.100
const HOLD_BASE_LIMIT := 5.0 / 60.0
const HOLD_LIMIT := HOLD_BASE_LIMIT + DURATION_EXTENSION
const SLOW_SCALE := 0.60
const SWEET_BONUS := 0.040
const CHAIN_BASE_LIMIT := 0.18
const CHAIN_LIMIT := CHAIN_BASE_LIMIT + DURATION_EXTENSION
const CHAIN_RECOVERY := 0.08
var enabled := true:
	set(value):
		enabled = value
		if not value:
			clear()
var acting_actor := ""
var active := false
var last_event: Dictionary = {}
var event_count := 0
var _recent_ids: Array[String] = []
var _end_usec := 0
var _chain_start_usec := 0
var _restore_scale := 1.0
var _blocked_until_usec := 0
var owner_lab: Node3D
var hold_pose_pending := false
var hold_event: Dictionary = {}
var pending_inputs: Array[InputEvent] = []
var _slowed_world := false
var _held_ball_scale := Vector3.ONE
var _compressed_ball := false

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
	next_mode = clampi(next_mode,Mode.CURRENT_SLOWDOWN,Mode.NONE)
	if mode == next_mode:
		return
	clear()
	mode = next_mode

func mode_name() -> String:
	return "No MoC" if mode == Mode.NONE else ("Current Slowdown" if mode == Mode.CURRENT_SLOWDOWN else "Tuned Slowdown")

static func hold_parts(event: Dictionary) -> Dictionary:
	var action := int(event.get("action",0))
	if action == 1 or action < 0 or action > 4:
		return {"velocity":0.0,"sweet":0.0,"extension":0.0,"total":0.0}
	var incoming := Vector3(event.get("incoming_velocity",Vector3.ZERO))
	var outgoing := Vector3(event.get("outgoing_velocity",Vector3.ZERO))
	var sweet := bool(event.get("sweet",false))
	var rescue: bool = bool(event.get("rescue",false)) or not event.get("charge_match",{}).get("matched",true)
	var impact := impact_speed(incoming,outgoing)
	var velocity_frames := 0
	var sweet_frames := 0
	if rescue or not sweet:
		velocity_frames = 1 if impact >= 12.0 else 0
	else:
		sweet_frames = 1
		if action == 0:
			velocity_frames = 1 + roundi(clampf(impact/30.0,0,1))
		else:
			velocity_frames = maxi(2,1+roundi(clampf(impact/30.0,0,1)*3))
	var base := minf(HOLD_BASE_LIMIT,(velocity_frames+sweet_frames)*HOLD_FRAME)
	var extension := DURATION_EXTENSION if base > 0 else 0.0
	return {"velocity":velocity_frames*HOLD_FRAME,"sweet":sweet_frames*HOLD_FRAME,"extension":extension,"total":base+extension}

func holding() -> bool:
	# Both comparison modes slow simulation; neither gates physics or input.
	return false

func simulation_scale() -> float:
	if active and Time.get_ticks_usec() >= _end_usec:
		_expire(Time.get_ticks_usec())
	return SLOW_SCALE if active else 1.0

func actor_scale(actor_id: String) -> float:
	return simulation_scale() if actor_id == acting_actor else 1.0

func buffer_input(_event: InputEvent) -> void:
	pass # Compatibility only: input is always immediate.

func prepare_hold_pose() -> void:
	pass # Compatibility only: poses are never frozen.

func begin(event: Dictionary) -> void:
	var incoming := Vector3(event.get("incoming_velocity", Vector3.ZERO))
	var outgoing := Vector3(event.get("outgoing_velocity", Vector3.ZERO))
	var legacy_duration := duration_for(int(event.action), incoming, outgoing, bool(event.get("sweet", false)))
	var parts := hold_parts(event)
	var duration: float = 0.0 if mode == Mode.NONE else (legacy_duration if mode == Mode.CURRENT_SLOWDOWN else parts.total)
	if (legacy_duration <= 0 and int(event.action) != 1) or not bool(event.get("physical_hit", false)):
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
	last_event["duration_extension_seconds"] = DURATION_EXTENSION if mode == Mode.CURRENT_SLOWDOWN and duration > 0 else (parts.extension if mode == Mode.IMPACT_HOLD else 0.0)
	last_event["duration_seconds"] = duration
	last_event["incoming_speed"] = incoming.length()
	last_event["outgoing_speed"] = outgoing.length()
	last_event["velocity_change"] = (outgoing - incoming).length()
	last_event.make_read_only()
	event_count += 1
	# A set must launch at normal speed even if a prior contact is still slowed.
	if int(event.action) == 1:
		clear()
	impact_started.emit(last_event)
	if duration <= 0 or not enabled or (is_instance_valid(owner_lab) and owner_lab.paused):
		return
	var now := Time.get_ticks_usec()
	if active and now >= _end_usec:
		_expire(now)
	if now < _blocked_until_usec:
		return
	if not active:
		_restore_scale = Engine.time_scale
		_chain_start_usec = now
		active = true
		if mode == Mode.IMPACT_HOLD and is_instance_valid(owner_lab):
			_held_ball_scale = owner_lab.ball.scale
	var limit := CHAIN_LIMIT if mode == Mode.CURRENT_SLOWDOWN else HOLD_LIMIT
	_end_usec = mini(maxi(_end_usec, now) + int(duration * 1000000), _chain_start_usec + int(limit * 1000000))
	acting_actor = str(event.get("actor", "player"))
	# Slow simulation deltas locally; leave engine scheduling and rendering live.
	_slowed_world = false

func _process(_delta: float) -> void:
	if not active:
		return
	if is_instance_valid(owner_lab) and owner_lab.paused:
		clear()
	elif Time.get_ticks_usec() >= _end_usec:
		_expire(Time.get_ticks_usec())

func _expire(now: int) -> void:
	var limit := CHAIN_LIMIT if mode == Mode.CURRENT_SLOWDOWN else HOLD_LIMIT
	var capped := _end_usec >= _chain_start_usec + int(limit*1000000)
	var inputs := pending_inputs.duplicate()
	var replay := false
	clear()
	if capped or replay:
		_blocked_until_usec = now + int(CHAIN_RECOVERY*1000000)
	if replay and is_instance_valid(owner_lab) and not owner_lab.paused:
		for event in inputs:
			owner_lab._input(event)
			owner_lab._unhandled_input(event)

func clear() -> void:
	acting_actor = ""
	_blocked_until_usec = 0
	pending_inputs.clear()
	hold_pose_pending = false
	hold_event = {}
	if _compressed_ball and is_instance_valid(owner_lab) and is_instance_valid(owner_lab.ball):
		owner_lab.ball.scale = _held_ball_scale
	_compressed_ball = false
	if active:
		if _slowed_world:
			Engine.time_scale = _restore_scale
		active = false
		impact_ended.emit()
	_slowed_world = false
	_end_usec = 0
	_chain_start_usec = 0

func _exit_tree() -> void:
	clear()
