extends RefCounted

# Moves a body from one pose to the next over a time in seconds. Poses are the pose library's
# joint channels, so a transition is one number per joint running from where it is to where it
# should be, all with the same duration and curve.
#
# The default curve is a minimum-jerk quintic that starts with the speed the joint already has.
# Asking for a new pose halfway through a transition therefore carries on smoothly instead of
# restarting from rest, and a joint never snaps. Other curves are plain easings of the position.
#
#   var blender := PoseBlender.new()
#   blender.snap(pose)               # start from this pose, no motion
#   blender.go(next_pose, 0.18)      # reach next_pose in 180 ms
#   blender.update(delta)            # every frame
#   blender.apply(body)              # write the blended pose onto the rig
const Library := preload("res://scripts/pose_library.gd")
const TRANSITIONS_FILE := "res://data/poses/transitions.json"
const DEFAULT_SECONDS := 0.16
const EASES := ["min_jerk", "linear", "ease_in", "ease_out", "ease_in_out"]

var position := {}
var velocity := {}
var _from := {}
var _from_velocity := {}
var _target := {}
var _duration := 0.0
var _elapsed := 0.0
var _ease := "min_jerk"

func snap(pose: Dictionary) -> void:
	position = Library.flatten(pose)
	velocity = {}
	for key in position:
		velocity[key] = 0.0
	_from = position.duplicate()
	_from_velocity = velocity.duplicate()
	_target = position.duplicate()
	_duration = 0.0
	_elapsed = 0.0

# Head for `pose`, arriving in `seconds`. Keeps the joints' current positions and speeds.
func go(pose: Dictionary, seconds: float = DEFAULT_SECONDS, ease_name: String = "min_jerk") -> void:
	if position.is_empty():
		snap(pose)
		return
	_from = position.duplicate()
	_from_velocity = velocity.duplicate()
	_target = Library.flatten(pose)
	_duration = maxf(seconds, 0.0)
	_elapsed = 0.0
	_ease = ease_name if EASES.has(ease_name) else "min_jerk"
	if _duration <= 0.0:
		position = _target.duplicate()
		for key in velocity:
			velocity[key] = 0.0

func is_moving() -> bool:
	return _duration > 0.0 and _elapsed < _duration - 0.000001

func progress() -> float:
	return 1.0 if _duration <= 0.0 else clampf(_elapsed / _duration, 0.0, 1.0)

func duration() -> float:
	return _duration

func update(delta: float) -> void:
	if _duration <= 0.0:
		return
	seek(_elapsed + delta)

# Jump to a moment in the current transition. Scrubbing and playback both use this.
func seek(elapsed: float) -> void:
	_elapsed = clampf(elapsed, 0.0, _duration)
	if _elapsed >= _duration - 0.000001:
		_elapsed = _duration
	var s := _elapsed / _duration if _duration > 0.0 else 1.0
	for key in _target:
		var channel := String(key).get_slice(":", 0)
		var range: Vector2 = Library.CHANNELS[channel].range
		var p0: float = _from.get(key, _target[key])
		var p1: float = _target[key]
		var v0: float = _from_velocity.get(key, 0.0)
		var value_and_speed := _curve(p0, v0, p1, s)
		position[key] = clampf(value_and_speed.x, range.x, range.y)
		velocity[key] = value_and_speed.y

# Position and speed at fraction s of the transition. x = position, y = speed per second.
func _curve(p0: float, v0: float, p1: float, s: float) -> Vector2:
	var t := _duration
	if _ease == "min_jerk":
		var s2 := s * s
		var s3 := s2 * s
		var s4 := s3 * s
		var s5 := s4 * s
		var h0 := 1.0 - 10.0 * s3 + 15.0 * s4 - 6.0 * s5
		var h1 := s - 6.0 * s3 + 8.0 * s4 - 3.0 * s5
		var h3 := 10.0 * s3 - 15.0 * s4 + 6.0 * s5
		var d0 := -30.0 * s2 + 60.0 * s3 - 30.0 * s4
		var d1 := 1.0 - 18.0 * s2 + 32.0 * s3 - 15.0 * s4
		var d3 := 30.0 * s2 - 60.0 * s3 + 30.0 * s4
		return Vector2(h0 * p0 + h1 * v0 * t + h3 * p1, (d0 * p0 + d1 * v0 * t + d3 * p1) / t)
	var warped := s
	var slope := 1.0
	match _ease:
		"ease_in":
			warped = s * s
			slope = 2.0 * s
		"ease_out":
			warped = 1.0 - (1.0 - s) * (1.0 - s)
			slope = 2.0 * (1.0 - s)
		"ease_in_out":
			warped = smoothstep(0.0, 1.0, s)
			slope = 6.0 * s * (1.0 - s)
	return Vector2(lerpf(p0, p1, warped), (p1 - p0) * slope / t)

# The blended pose, ready for PoseLibrary.apply.
func pose() -> Dictionary:
	return Library.from_flat(position)

func apply(body: Node3D, weight: float = 1.0) -> void:
	Library.apply(body, pose(), weight)

# How long the library says it takes to get from one pose to another, and with what curve.
static func transition(from_name: String, to_name: String) -> Dictionary:
	var table := _table()
	var entry: Dictionary = table.get("pairs", {}).get("%s>%s" % [from_name, to_name], {})
	return {
		"seconds": float(entry.get("ms", table.get("default_ms", DEFAULT_SECONDS * 1000.0))) / 1000.0,
		"ease": String(entry.get("ease", table.get("default_ease", "min_jerk"))),
	}

static func save_transition(from_name: String, to_name: String, seconds: float, ease_name: String) -> Error:
	var table := _table()
	if not table.has("pairs"):
		table["pairs"] = {}
	table.pairs["%s>%s" % [from_name, to_name]] = {"ms": roundi(seconds * 1000.0), "ease": ease_name}
	var file := FileAccess.open(TRANSITIONS_FILE, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(table, "\t", true) + "\n")
	return OK

static func _table() -> Dictionary:
	if FileAccess.file_exists(TRANSITIONS_FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TRANSITIONS_FILE))
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	return {"default_ms": DEFAULT_SECONDS * 1000.0, "default_ease": "min_jerk", "pairs": {}}
