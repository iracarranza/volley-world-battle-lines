extends RefCounted

# What happens after a dive lands: impact, slide, gather, rise, then hand back to locomotion.
# The stages, their poses, hold times and whole-body orientation live in
# data/poses/dive_recovery.json; the time to move between poses is in transitions.json under the
# forward-family pose names. Each stage has a forward pose and a side pose (authored for a dive to
# the right, mirrored for the left), blended by where the dive went relative to the body.
#
# Joints and spine come from the pose library. The body's root pitch and roll say how it lies on
# the floor, and are the only whole-body rotation used. The caller keeps the body above the floor.
const Library := preload("res://scripts/pose_library.gd")
const Blender := preload("res://scripts/pose_blender.gd")
const FILE := "res://data/poses/dive_recovery.json"
const FALLBACK_MS := 220.0
# Channels whose positive direction is "to the character's left": mirrored with the pose.
const LEFT_POSITIVE := ["hip_yaw", "lumbar_bend", "lumbar_twist", "thoracic_bend", "thoracic_twist", "neck_bend", "neck_twist"]

static var _plan := {}

static func plan() -> Dictionary:
	if _plan.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		_plan = parsed if typeof(parsed) == TYPE_DICTIONARY else {"impact_ms": 140, "lock_until": "rise", "stages": []}
	return _plan

static func forget() -> void:
	_plan = {}

# Left and right swapped, and the left-positive spine channels reversed.
static func mirrored(flat: Dictionary) -> Dictionary:
	var out := {}
	for key in flat:
		var parts: PackedStringArray = String(key).split(":")
		var channel := parts[0]
		var value := float(flat[key])
		if LEFT_POSITIVE.has(channel):
			value = -value
		if parts.size() == 2:
			out["%s:%s" % [channel, "Right" if parts[1] == "Left" else "Left"]] = value
		else:
			out[channel] = value
	return out

static func _flat(name: String) -> Dictionary:
	return Library.flatten(Library.load_pose(name))

static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in a:
		out[key] = lerpf(float(a[key]), float(b.get(key, a[key])), t)
	return out

# Weight of the side family: a dive across the body is the side family, one along it the forward.
static func side_weight(local_direction: Vector2) -> float:
	var d := local_direction.normalized() if local_direction.length_squared() > 0.0001 else Vector2(0, 1)
	return smoothstep(0.25, 0.75, absf(d.x))

# The pose of one stage for a dive in `local_direction` (right, forward), as flat channels.
static func stage_flat(stage: Dictionary, local_direction: Vector2) -> Dictionary:
	var forward := _flat(String(stage.fwd))
	var d := local_direction.normalized() if local_direction.length_squared() > 0.0001 else Vector2(0, 1)
	var side := _flat(String(stage.side))
	if d.x < 0.0 and String(stage.side) != String(stage.fwd):
		side = mirrored(side)
	if String(stage.side) == String(stage.fwd):
		return side
	return _mix(forward, side, side_weight(d))

# Whole-body lie of one stage: (pitch, roll) in radians. Pitch is negative with the chest down.
static func stage_root(stage: Dictionary, local_direction: Vector2) -> Vector2:
	var d := local_direction.normalized() if local_direction.length_squared() > 0.0001 else Vector2(0, 1)
	var root: Dictionary = stage.root
	var pitch := float(root.pitch_fwd) * maxf(d.y, 0.0) + float(root.pitch_back) * maxf(-d.y, 0.0) + float(root.pitch_side) * absf(d.x)
	var roll := float(root.roll_side) * d.x
	return Vector2(pitch, roll)

static func _seconds(from_stage: Dictionary, to_stage: Dictionary) -> float:
	var table := Blender.transition(String(from_stage.fwd), String(to_stage.fwd))
	return float(table.seconds)

# Segments in order: seconds to arrive at the stage, then seconds held there.
static func segments() -> Array:
	var stages: Array = plan().stages
	var out := []
	for i in range(stages.size()):
		var arrive := float(plan().impact_ms) / 1000.0 if i == 0 else _seconds(stages[i - 1], stages[i])
		out.append({"stage": stages[i], "arrive": arrive, "hold": float(stages[i].hold_ms) / 1000.0})
	return out

# Slower for a poorly timed dive, quicker for a clean one. quality is 0..1.
static func time_scale(quality: float) -> float:
	return lerpf(1.15, 0.85, clampf(quality, 0.0, 1.0))

static func duration(quality: float = 0.5) -> float:
	var total := 0.0
	for segment in segments():
		total += float(segment.arrive) + float(segment.hold)
	return total * time_scale(quality)

# Seconds into the recovery at which the body is rising and the player gets control back.
static func lock_seconds(quality: float = 0.5) -> float:
	var total := 0.0
	for segment in segments():
		if String(segment.stage.name) == String(plan().lock_until):
			break
		total += float(segment.arrive) + float(segment.hold)
	return total * time_scale(quality)

# The dive's own ending is the landing and slide; the recovery is getting up afterwards. Each stage
# in the plan says which it belongs to, and `phases` names the animation source each one draws as, so
# the lab can smooth the dive -> recovery -> standing seams separately.
static func phase_of(stage: Dictionary) -> String:
	return String(stage.get("phase", "recovery"))

static func source_for(phase: String) -> String:
	return String(plan().get("phases", {}).get(phase, "dive_recover"))

# Seconds into the whole sequence at which the dive's ending is over and the recovery begins.
static func floor_seconds(quality: float = 0.5) -> float:
	var total := 0.0
	for segment in segments():
		if phase_of(segment.stage) != "dive":
			break
		total += float(segment.arrive) + float(segment.hold)
	return total * time_scale(quality)

# "dive" until the slide has finished, then "recovery".
static func phase_at(seconds: float, quality: float = 0.5) -> String:
	return "dive" if seconds < floor_seconds(quality) else "recovery"

# Angles wrap, so a channel that last read -204 and is going to 165 is turning 9 degrees, not 369.
static func _nearest(value: float, toward: float, channel: String) -> float:
	if channel == "hip_shift":
		return value
	return toward + wrapf(value - toward, -180.0, 180.0)

# Cubic Hermite through (times, values), moving through every key instead of coming to rest at it.
# The first tangent carries on at the first slope; the last settles to rest.
static func _hermite(times: Array, values: Array, t: float) -> float:
	var n := times.size()
	if t <= float(times[0]):
		return float(values[0])
	if t >= float(times[n - 1]):
		return float(values[n - 1])
	var i := 0
	while i < n - 2 and t > float(times[i + 1]):
		i += 1
	var slopes := []
	for k in range(n - 1):
		slopes.append((float(values[k + 1]) - float(values[k])) / maxf(float(times[k + 1]) - float(times[k]), 0.0001))
	var tangents := []
	for k in range(n):
		if k == 0:
			tangents.append(float(slopes[0]))
		elif k == n - 1:
			tangents.append(0.0)
		else:
			# Carry on through the key at the average of the slopes either side (Catmull-Rom). Where the
			# move turns round the pose still slows, but it does not stop dead and start again.
			tangents.append((float(slopes[k - 1]) + float(slopes[k])) * 0.5)
	var h := float(times[i + 1]) - float(times[i])
	var u := (t - float(times[i])) / h
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * float(values[i]) + (u3 - 2.0 * u2 + u) * h * float(tangents[i]) \
		+ (-2.0 * u3 + 3.0 * u2) * float(values[i + 1]) + (u3 - u2) * h * float(tangents[i + 1])

# The key poses in time: the pose at touchdown, then each stage reached and held. Times are real seconds.
static func keys(local_direction: Vector2, quality: float, from_root: Vector2, from_flat: Dictionary) -> Array:
	var scale := time_scale(quality)
	var segs := segments()
	var out := []
	var first_flat := from_flat if not from_flat.is_empty() else stage_flat(segs[0].stage, local_direction)
	out.append({"t": 0.0, "flat": first_flat, "pitch": from_root.x, "roll": from_root.y, "stage": ""})
	var t := 0.0
	for segment in segs:
		t += float(segment.arrive) * scale
		var flat := stage_flat(segment.stage, local_direction)
		var root := stage_root(segment.stage, local_direction)
		out.append({"t": t, "flat": flat, "pitch": root.x, "roll": root.y, "stage": String(segment.stage.name)})
		if float(segment.hold) > 0.0:
			t += float(segment.hold) * scale
			out.append({"t": t, "flat": flat, "pitch": root.x, "roll": root.y, "stage": String(segment.stage.name)})
	return out

# The recovery at `seconds` after touchdown: the joint pose (flat), the body's root pitch and roll,
# how far through it is and which stage it is in. `from_root` and `from_flat` are the body as it
# touched down, so the sequence starts from the pose the dive actually ended in.
static func at(seconds: float, local_direction: Vector2, quality: float, from_root: Vector2, from_flat: Dictionary = {}) -> Dictionary:
	var key_list := keys(local_direction, quality, from_root, from_flat)
	var times := []
	for key in key_list:
		times.append(float(key.t))
	var flat := {}
	for channel_key in key_list[key_list.size() - 1].flat:
		var channel := String(channel_key).get_slice(":", 0)
		var values := []
		for index in range(key_list.size()):
			var value := float(key_list[index].flat.get(channel_key, 0.0))
			# Walk the angles along the shortest way round, key to key.
			if index > 0:
				value = _nearest(value, float(values[index - 1]), channel)
			values.append(value)
		# The first key is the odd one out (it came from the rig): bring it to the second.
		if values.size() > 1:
			values[0] = _nearest(float(values[0]), float(values[1]), channel)
			for index in range(1, values.size()):
				values[index] = _nearest(float(values[index]), float(values[index - 1]), channel)
		flat[channel_key] = _hermite(times, values, seconds)
	var pitches := []
	var rolls := []
	for key in key_list:
		pitches.append(float(key.pitch))
		rolls.append(float(key.roll))
	var stage_name := ""
	for key in key_list:
		if float(key.t) >= seconds - 0.00001 and String(key.stage) != "":
			stage_name = String(key.stage)
			break
	if stage_name == "":
		stage_name = String(key_list[key_list.size() - 1].stage)
	return {
		"flat": flat,
		"pitch": _hermite(times, pitches, seconds),
		"roll": _hermite(times, rolls, seconds),
		"stage": stage_name,
		"progress": clampf(seconds / maxf(duration(quality), 0.0001), 0.0, 1.0),
	}

# How far the body's turn (a backward dive turns to face where it is going) has been given back to
# the player's facing: not at all while the body is down, then through the rise.
static func facing_release(seconds: float, quality: float = 0.5) -> float:
	var from := lock_seconds(quality) * 0.55
	return smoothstep(from, maxf(duration(quality), from + 0.01), seconds)

# Draw it on the rig. The body's lie is applied to the root; joints through the pose library.
static func apply(body: Node3D, state: Dictionary) -> void:
	Library.apply(body, Library.from_flat(state.flat), 1.0)
	body.rotation.x = float(state.pitch)
	body.rotation.z = float(state.roll)

# The lowest point of the drawn surface in world space, for keeping it off the floor. Real vertices,
# not bounding boxes: the corner of a tilted box is far below any surface it holds. Ink hulls are skipped.
static func lowest_world_y(body: Node3D) -> float:
	var lowest := INF
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or mesh_node.name == "Ink" or not mesh_node.is_visible_in_tree():
			continue
		var transform := mesh_node.global_transform
		for vertex in mesh_node.mesh.get_faces():
			lowest = minf(lowest, (transform * vertex).y)
	return lowest

# Raise or lower the body so its lowest part rests on `floor_y`.
static func rest_on_floor(body: Node3D, floor_y: float) -> void:
	var lowest := lowest_world_y(body)
	if is_inf(lowest):
		return
	body.global_position.y += floor_y - lowest
