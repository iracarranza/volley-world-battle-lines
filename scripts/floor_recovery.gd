extends RefCounted

# The four ways a defender who has played a ball off balance ends up, ported from VWM's recovery vocabulary:
#   knee        low but supported, one knee down, then back up        (0.55 s in VWM)
#   knocked_away  (event: fall_roll) arms thrown off the off-axis line, body twisted, a step back  (0.95 s)
#   collapse      (event: fall_slide) falls to hands and knees in the contact's direction          (0.95 s)
#   blown_away  driven off a hard ball: onto the back, sits up, stands (1.35 s)
#   shrug       (ours, not VWM's) a mishandled ball down the midline: arms shrug in and up, platform drops along the
#               chest, body straightens and staggers back, never falls (0.7 s)
# The stages, poses and body lie live in data/poses/floor_recoveries.json; each stage's pose is a pose file the
# pose editor can change. Durations are VWM's own priced recovery times, kept so the animation and the cost agree.
#
# Which recovery happens is decided by scripts/receive_outcome.gd (the lab's receive_resolved event). choose() below is the
# earlier heuristic, kept only for tools and tests; the lab does not call it.
const Library := preload("res://scripts/pose_library.gd")
const Dive := preload("res://scripts/dive_recovery.gd")
const FILE := "res://data/poses/floor_recoveries.json"
const BLOWN_SPEED := 18.0      # m/s of incoming ball at contact
const BLOWN_QUALITY := 0.6
const KNEE_QUALITY := 0.85
const MIDLINE := 0.35         # |contact_x| as a fraction of the platform reach that counts as down the middle

# The receive resolver's event names for two of them are older than their animations.
const ALIASES := {"fall_roll": "knocked_away", "fall_slide": "collapse"}

static var _plans := {}

static func resolve(name: String) -> String:
	return ALIASES.get(name, name)

static func plans() -> Dictionary:
	if _plans.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		_plans = parsed.recoveries if typeof(parsed) == TYPE_DICTIONARY else {}
	return _plans

static func forget() -> void:
	_plans = {}

static func names() -> Array:
	return plans().keys()

static func plan(name: String) -> Dictionary:
	return plans().get(name, {})

static func duration(name: String) -> float:
	return float(plan(name).get("seconds", 0.0))

# Which recovery a contact leaves the defender in, or "" for none. `event` is the lab's contact assessment plus
# the incoming ball speed: {hit, zone, quality, edge, rescue, posture, incoming_speed, contact_x}.
static func choose(event: Dictionary) -> String:
	var posture := String(event.get("posture", "planted"))
	var quality := float(event.get("quality", 1.0))
	var hit := bool(event.get("hit", true))
	var forward := posture in ["moving", "reaching"]
	if hit and float(event.get("incoming_speed", 0.0)) >= BLOWN_SPEED and quality <= BLOWN_QUALITY:
		return "blown_away"
	if not hit or bool(event.get("rescue", false)) or (bool(event.get("edge", false)) and posture != "planted"):
		return "collapse" if forward else "knocked_away"
	var centered := absf(float(event.get("contact_x", 0.0))) <= MIDLINE
	var mishandled: bool = String(event.get("zone", "CLEAN")) in ["WEAK", "SOUR SPOT", "FAIR"] and quality < KNEE_QUALITY or quality <= BLOWN_QUALITY
	if hit and centered and mishandled and posture in ["planted", "moving"] and not bool(event.get("edge", false)):
		return "shrug"
	if String(event.get("zone", "CLEAN")) in ["WEAK", "SOUR SPOT"] or (posture in ["reaching", "off-axis"] and quality < KNEE_QUALITY):
		return "knee"
	return ""

# Which side the body goes toward: from the contact's sideways offset, else the dominant hand.
static func side_of(contact_x: float, handedness: String = "Right") -> float:
	if absf(contact_x) > 0.02:
		return signf(contact_x)
	return -1.0 if handedness == "Left" else 1.0

static func _flat(name: String, mirror: bool) -> Dictionary:
	var flat := Library.flatten(Library.load_pose(name))
	return Dive.mirrored(flat) if mirror else flat

# Joint pose, body pitch and roll at `seconds`, the stage reached and progress. `side` is +1 right, -1 left;
# `from_root` and `from_flat` are the body as it was when the recovery began.
static func at(name: String, seconds: float, side: float, from_root: Vector2, from_flat: Dictionary) -> Dictionary:
	var p := plan(name)
	var stages: Array = p.stages
	var total := float(p.seconds)
	var mirror := bool(p.get("mirror", false)) and side < 0.0
	var times := [0.0]
	var pitches := [from_root.x]
	var rolls := [from_root.y]
	var flats := [from_flat]
	var directional := bool(p.get("mirror", false))
	for stage in stages:
		times.append(float(stage.t) * total)
		pitches.append(float(stage.root.pitch))
		rolls.append(float(stage.root.roll) * (side if directional else 1.0))
		flats.append(_flat(String(stage.pose), mirror))
	var flat := {}
	for key in flats[flats.size() - 1]:
		var channel := String(key).get_slice(":", 0)
		var values := []
		for i in range(flats.size()):
			var v := float(flats[i].get(key, 0.0))
			if i > 0:
				v = Dive._nearest(v, float(values[i - 1]), channel)
			values.append(v)
		if values.size() > 1:
			values[0] = Dive._nearest(float(values[0]), float(values[1]), channel)
		flat[key] = Dive._hermite(times, values, seconds)
	var stage_name := String(stages[stages.size() - 1].name)
	for stage in stages:
		if seconds <= float(stage.t) * total + 0.00001:
			stage_name = String(stage.name)
			break
	return {"flat": flat, "pitch": Dive._hermite(times, pitches, seconds), "roll": Dive._hermite(times, rolls, seconds), "stage": stage_name, "progress": clampf(seconds / maxf(total, 0.0001), 0.0, 1.0)}

# Seconds into the recovery at which the player gets control back: the start of the rise.
static func lock_seconds(name: String) -> float:
	var stages: Array = plan(name).stages
	return float(stages[stages.size() - 2].t) * duration(name)

static func apply(body: Node3D, state: Dictionary) -> void:
	Dive.apply(body, state)
