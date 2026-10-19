extends RefCounted

# Keeps animation from jumping when the animation source changes. The lab drives the body from
# several sources that know nothing about each other (walking, receive stances, the approach,
# the dive...). Each frame the caller reads whatever pose the rig ended up in, says which source
# produced it, and gets back the pose to draw.
#
# When the source changes, the gap between what was on screen and what the new source wants
# becomes an offset that is run down to zero over a transition time, starting at the speed the
# joints already had (inertialization). The new source keeps full control of the motion; the
# offset only hides the seam. Within one source nothing is touched.
const Library := preload("res://scripts/pose_library.gd")
const Blender := preload("res://scripts/pose_blender.gd")

var _source := ""
var _previous_raw := {}
var _raw_speed := {}
var _shown := {}
var _shown_speed := {}
var _offset := {}
var _offset_speed := {}
var _elapsed := 0.0
var _duration := 0.0

func reset() -> void:
	_source = ""
	_previous_raw = {}
	_raw_speed = {}
	_shown = {}
	_shown_speed = {}
	_offset = {}
	_offset_speed = {}
	_elapsed = 0.0
	_duration = 0.0

func is_blending() -> bool:
	return _duration > 0.0 and _elapsed < _duration

# `raw` is a flat pose (PoseLibrary.read_rig), `source` names what produced it, `dt` is the time
# since the last call (0 for a repeat call in the same frame). Returns the flat pose to draw.
func update(raw: Dictionary, source: String, dt: float) -> Dictionary:
	var switching := not _shown.is_empty() and source != _source
	if dt > 0.0:
		for key in raw:
			# The step across a switch is the seam, not motion, so it says nothing about speed.
			_raw_speed[key] = 0.0 if switching else (float(raw[key]) - float(_previous_raw.get(key, raw[key]))) / dt
	if switching:
		_offset = {}
		_offset_speed = {}
		for key in raw:
			_offset[key] = float(_shown.get(key, raw[key])) - float(raw[key])
			_offset_speed[key] = float(_shown_speed.get(key, 0.0)) - float(_raw_speed.get(key, 0.0))
		_elapsed = 0.0
		_duration = float(Blender.transition(_source, source).seconds)
	_source = source
	_elapsed += dt
	var out := {}
	var s := 1.0 if _duration <= 0.0 else clampf(_elapsed / _duration, 0.0, 1.0)
	for key in raw:
		out[key] = float(raw[key]) + _decayed(float(_offset.get(key, 0.0)), float(_offset_speed.get(key, 0.0)), s)
	if dt > 0.0:
		for key in out:
			_shown_speed[key] = (float(out[key]) - float(_shown.get(key, out[key]))) / dt
	_shown = out
	_previous_raw = raw.duplicate()
	return out

# An offset of p0 moving at v0 brought to rest at zero by fraction s of the transition.
func _decayed(p0: float, v0: float, s: float) -> float:
	if s >= 1.0 or (p0 == 0.0 and v0 == 0.0):
		return 0.0
	var s2 := s * s
	var s3 := s2 * s
	var s4 := s3 * s
	var s5 := s4 * s
	return (1.0 - 10.0 * s3 + 15.0 * s4 - 6.0 * s5) * p0 + (s - 6.0 * s3 + 8.0 * s4 - 3.0 * s5) * v0 * _duration
