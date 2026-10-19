extends RefCounted

# Hand-authored poses as data. A pose is a set of joint channels in degrees, kept
# in res://data/poses/<name>.json so the pose editor can change them without code.
# Channels are written on top of whatever the gait left on the rig, blended by weight.
#
# { "mirror": true, "channels": {"knee": -60.0, ...}, "left": {...}, "right": {...} }
# `channels` are symmetric values. `left` / `right` hold per-side overrides, used
# only when the pose is authored with mirror off.
const SpineRig := preload("res://scripts/spine_rig.gd")
const DIR := "res://data/poses/"
const SIDES := ["Left", "Right"]

# Ranges are the joint's anatomical range of motion, so the editor cannot pose a body
# into something a person cannot do. sign: per side, so one positive number means the
# same movement on both sides. sided false means one joint, no left/right.
# Spine channels are positive forward (flexion), left (bend) and left (twist).
const CHANNELS := {
	"hip_shift": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-35, 35), "group": "Spine", "label": "Hips forward/back (cm, + forward)"},
	"hip_hinge": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-30, 90), "group": "Spine", "label": "Hip hinge (+ leans forward)"},
	"lumbar_flexion": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-20, 50), "group": "Spine", "label": "Lumbar bend (+ forward)"},
	"lumbar_bend": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-25, 25), "group": "Spine", "label": "Lumbar side bend (+ left)"},
	"lumbar_twist": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-15, 15), "group": "Spine", "label": "Lumbar twist (+ left)"},
	"thoracic_flexion": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-15, 40), "group": "Spine", "label": "Chest bend (+ forward)"},
	"thoracic_bend": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-25, 25), "group": "Spine", "label": "Chest side bend (+ left)"},
	"thoracic_twist": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-40, 40), "group": "Spine", "label": "Chest twist (+ left)"},
	"neck_flexion": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-50, 60), "group": "Head", "label": "Neck nod (+ chin down)"},
	"neck_bend": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-40, 40), "group": "Head", "label": "Neck tilt (+ left)"},
	"neck_twist": {"sign": [1.0, 1.0], "sided": false, "range": Vector2(-70, 70), "group": "Head", "label": "Neck turn (+ left)"},
	"hip": {"sign": [1.0, 1.0], "sided": true, "range": Vector2(-30, 125), "group": "Legs", "label": "Hip flexion (+ thigh forward)"},
	"abduction": {"sign": [-1.0, 1.0], "sided": true, "range": Vector2(-30, 50), "group": "Legs", "label": "Hip abduction (legs apart)"},
	"hip_rotation": {"sign": [1.0, -1.0], "sided": true, "range": Vector2(-45, 45), "group": "Legs", "label": "Hip rotation (+ toes out)"},
	"knee": {"sign": [1.0, 1.0], "sided": true, "range": Vector2(-150, 0), "group": "Legs", "label": "Knee (negative bends)"},
	"shoulder_pitch": {"sign": [1.0, 1.0], "sided": true, "range": Vector2(-60, 180), "group": "Arms", "label": "Shoulder flexion (raise forward)"},
	"shoulder_roll": {"sign": [1.0, -1.0], "sided": true, "range": Vector2(-30, 180), "group": "Arms", "label": "Shoulder abduction (arms apart)"},
	"shoulder_rotation": {"sign": [1.0, -1.0], "sided": true, "range": Vector2(-90, 90), "group": "Arms", "label": "Shoulder rotation (+ outward)"},
	"elbow": {"sign": [1.0, 1.0], "sided": true, "range": Vector2(0, 150), "group": "Arms", "label": "Elbow bend"},
	"forearm_rotation": {"sign": [1.0, -1.0], "sided": true, "range": Vector2(-80, 80), "group": "Arms", "label": "Forearm rotation (+ palm up)"},
}

# Joints that move a node. Axes are x, y, z euler angles of the node, composed in the order
# flexion, then abduction, then axial rotation -- so a twist turns the limb about its own
# long axis (a hip rotation swings the knee outward) instead of about the body's vertical.
const JOINTS := [
	{"path": "%sLeg", "x": "hip", "z": "abduction", "y": "hip_rotation"},
	{"path": "%sLeg/Knee", "x": "knee"},
	{"path": "%sArm", "x": "shoulder_pitch", "z": "shoulder_roll", "y": "shoulder_rotation"},
	{"path": "%sArm/Elbow", "x": "elbow"},
	{"path": "%sArm/Elbow/Wrist", "y": "forearm_rotation"},
]

# The values the game used before poses became data, so a missing or damaged file
# still gives the same body.
const BUILTIN := {
	"planted_receive": {
		"hip": 16.0, "abduction": 15.0, "knee": -60.0,
		"shoulder_pitch": 56.14986, "shoulder_roll": 18.33465, "elbow": 17.18873,
		"hip_hinge": 5.729578, "hip_shift": 0.0,
	},
}

static var _cache := {}

static func file_path(name: String) -> String:
	return DIR + name + ".json"

static func builtin(name: String) -> Dictionary:
	return {"mirror": true, "channels": (BUILTIN.get(name, {}) as Dictionary).duplicate(), "left": {}, "right": {}}

static func load_pose(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var pose := read_file(name)
	_cache[name] = pose
	return pose

static func read_file(name: String) -> Dictionary:
	var pose := builtin(name)
	if not FileAccess.file_exists(file_path(name)):
		return pose
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(file_path(name)))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Pose %s is unreadable; using built-in values" % name)
		return pose
	pose.mirror = bool(parsed.get("mirror", true))
	for group in ["channels", "left", "right"]:
		var source = parsed.get(group, {})
		if typeof(source) == TYPE_DICTIONARY:
			source = _migrated(source)
			for key in source:
				if CHANNELS.has(key):
					pose[group][key] = clampf(float(source[key]), CHANNELS[key].range.x, CHANNELS[key].range.y)
	return pose

# Files saved before the spine existed carry `trunk_pitch`, negative leaning forward.
static func _migrated(source: Dictionary) -> Dictionary:
	var out := source.duplicate()
	if out.has("trunk_pitch") and not out.has("hip_hinge"):
		out["hip_hinge"] = -float(out["trunk_pitch"])
	out.erase("trunk_pitch")
	return out

static func save_pose(name: String, pose: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var file := FileAccess.open(file_path(name), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_ordered(pose), "\t") + "\n")
	_cache.erase(name)
	return OK

# One number per joint per side, keyed "knee:Left" (unsided: "hip_hinge"), for blending.
static func flatten(pose: Dictionary) -> Dictionary:
	var flat := {}
	for channel in CHANNELS:
		if CHANNELS[channel].sided:
			for side in SIDES:
				flat["%s:%s" % [channel, side]] = value(pose, channel, side)
		else:
			flat[channel] = value(pose, channel)
	return flat

static func from_flat(flat: Dictionary, clamp_to_range: bool = true) -> Dictionary:
	var pose := {"mirror": false, "channels": {}, "left": {}, "right": {}}
	for key in flat:
		var parts: PackedStringArray = String(key).split(":")
		var channel := parts[0]
		if not CHANNELS.has(channel):
			continue
		var v := float(flat[key])
		if clamp_to_range:
			v = clampf(v, CHANNELS[channel].range.x, CHANNELS[channel].range.y)
		if parts.size() == 1:
			pose.channels[channel] = v
		else:
			pose[parts[1].to_lower()][channel] = v
			if parts[1] == "Left":
				pose.channels[channel] = v
	return pose

# The rig's current joints as channels, unclamped, so any animation can be read back and blended
# whether or not it was authored as a pose. Inverse of apply().
static func read_rig(body: Node3D) -> Dictionary:
	var flat := {}
	var thorax_inverse := Basis()
	if body.has_meta("spine_xf"):
		thorax_inverse = (body.get_meta("spine_xf").thorax as Transform3D).basis.inverse()
	var before_leg_solve: Dictionary = body.get_meta("pre_ik", {})
	for joint in JOINTS:
		for index in range(2):
			var side: String = SIDES[index]
			var path: String = joint.path % side
			var node := body.get_node_or_null(path) as Node3D
			if node == null:
				continue
			var basis := node.basis
			if joint.path == "%sArm":
				basis = thorax_inverse * basis
			var euler := basis.get_euler(EULER_ORDER_XZY)
			if before_leg_solve.has(side):
				if joint.path == "%sLeg":
					euler.x = before_leg_solve[side].hip
				elif joint.path == "%sLeg/Knee":
					euler = Vector3(before_leg_solve[side].knee, 0.0, 0.0)
			for axis in [["x", 0], ["y", 1], ["z", 2]]:
				if joint.has(axis[0]):
					var channel: String = joint[axis[0]]
					flat["%s:%s" % [channel, side]] = rad_to_deg(euler[axis[1]]) * float(CHANNELS[channel].sign[index])
	var torso := body.get_node_or_null("Torso") as Node3D
	var head := body.get_node_or_null("Head") as Node3D
	for channel in CHANNELS:
		if not CHANNELS[channel].sided:
			flat[channel] = 0.0
	if body.has_meta("spine_angles"):
		var angles: Dictionary = body.get_meta("spine_angles")
		for channel in angles:
			flat[channel] = float(angles[channel])
	else:
		# Not posed through the spine: the older code leans and turns the torso and head directly.
		if torso != null:
			flat["hip_hinge"] = -rad_to_deg(torso.rotation.x)
			flat["thoracic_twist"] = rad_to_deg(torso.rotation.y)
		if head != null:
			flat["neck_twist"] = rad_to_deg(head.rotation.y)
	return flat

# A pose as the stance VWM's gait interpolates out of when it is standing still: the six joints it
# takes. `fallback` is used when the pose file is missing, so the gait never loses its stance.
static func gait_stance(name: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(file_path(name)):
		return fallback
	var pose := load_pose(name)
	return {
		"hip_degrees": value(pose, "hip", "Left"),
		"knee_degrees": value(pose, "knee", "Left"),
		"abduction_degrees": value(pose, "abduction", "Left"),
		"arm_degrees": value(pose, "shoulder_pitch", "Left"),
		"elbow_degrees": value(pose, "elbow", "Left"),
		"torso_radians": -deg_to_rad(value(pose, "hip_hinge")),
	}

# Names of the pose files in the library (without the extension).
static func list_poses() -> Array:
	var names := []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return names
	for file in dir.get_files():
		if file.ends_with(".json") and file != "transitions.json":
			names.append(file.trim_suffix(".json"))
	names.sort()
	return names

static func forget(name: String) -> void:
	_cache.erase(name)

# Value of one channel on one side ("Left", "Right", or "" for an unsided joint).
static func value(pose: Dictionary, channel: String, side: String = "") -> float:
	if side != "" and not bool(pose.get("mirror", true)):
		var overrides: Dictionary = pose.get(side.to_lower(), {})
		if overrides.has(channel):
			return float(overrides[channel])
	return float(pose.channels.get(channel, 0.0))

# Mirrored poses write the shared value and drop overrides; unmirrored poses write
# one side so the other keeps what it had.
static func set_value(pose: Dictionary, channel: String, side: String, v: float) -> void:
	v = clampf(v, CHANNELS[channel].range.x, CHANNELS[channel].range.y)
	if bool(pose.get("mirror", true)) or side == "" or not CHANNELS[channel].sided:
		pose.channels[channel] = v
		pose.left.erase(channel)
		pose.right.erase(channel)
		return
	for other in SIDES:
		var key: String = other.to_lower()
		if not pose[key].has(channel):
			pose[key][channel] = float(pose.channels.get(channel, 0.0))
	pose[side.to_lower()][channel] = v

static func set_mirror(pose: Dictionary, on: bool) -> void:
	if on and not bool(pose.mirror):
		for channel in pose.left:
			pose.channels[channel] = pose.left[channel]
		pose.left = {}
		pose.right = {}
	pose.mirror = on

# Undo any spine pose before the next pose is built. Pose.base calls this every frame.
static func release_trunk(body: Node3D) -> void:
	SpineRig.release(body)

static func apply(body: Node3D, pose: Dictionary, weight: float = 1.0) -> void:
	var w := clampf(weight, 0.0, 1.0)
	# If the spine was already posed this frame (another pose layered under this one), blend from that.
	var spine_from: Dictionary = body.get_meta("spine_angles", {})
	SpineRig.release(body)
	for joint in JOINTS:
		for index in range(2):
			var node := body.get_node_or_null(joint.path % SIDES[index]) as Node3D
			if node == null:
				continue
			var euler := node.basis.get_euler(EULER_ORDER_XZY)
			for axis in [["x", 0], ["y", 1], ["z", 2]]:
				if joint.has(axis[0]):
					var channel: String = joint[axis[0]]
					var target := deg_to_rad(value(pose, channel, SIDES[index]) * CHANNELS[channel].sign[index])
					euler[axis[1]] = lerpf(euler[axis[1]], target, w)
			node.basis = Basis.from_euler(euler, EULER_ORDER_XZY)
	# The spine is a chain over the rig's rigid parts. The caller's torso lean (the gait's) is
	# the starting point, so a partial weight blends from it to the authored hinge.
	var torso := body.get_node_or_null("Torso") as Node3D
	var gait_lean := 0.0 if torso == null else -rad_to_deg(torso.rotation.x)
	var angles := {}
	for channel in CHANNELS:
		if not CHANNELS[channel].sided:
			angles[channel] = value(pose, channel)
	for channel in angles:
		var start := float(spine_from[channel]) if spine_from.has(channel) else (gait_lean if channel == "hip_hinge" else 0.0)
		angles[channel] = lerpf(start, angles[channel], w)
	if torso != null:
		torso.rotation = Vector3.ZERO
	# Where the feet are before the hips move: they stay there, and the legs fold to meet them.
	var feet := {}
	var moving_hips := absf(float(angles.get("hip_shift", 0.0))) > 0.0001
	if moving_hips:
		var solved := {}
		for side in SIDES:
			var leg := body.get_node_or_null("%sLeg" % side) as Node3D
			var knee := body.get_node_or_null("%sLeg/Knee" % side) as Node3D
			if leg != null and knee != null:
				solved[side] = {"hip": leg.basis.get_euler(EULER_ORDER_XZY).x, "knee": knee.rotation.x}
		body.set_meta("pre_ik", solved)
		for side in SIDES:
			var shoe := body.get_node_or_null("%sLeg/Knee/Shoe" % side) as Node3D
			if shoe != null:
				feet[side] = body.to_local(shoe.global_position)
	SpineRig.pose(body, angles)
	for side in feet:
		_plant_foot(body, side, feet[side])

# Two-bone leg solve for the hip and knee flexion that put the foot on `target` (body space),
# keeping the leg's abduction and rotation. Damped Gauss-Newton on the real nodes, so it
# agrees with whatever the rig does with those angles.
static func _plant_foot(body: Node3D, side: String, target: Vector3) -> void:
	var leg := body.get_node("%sLeg" % side) as Node3D
	var knee := leg.get_node("Knee") as Node3D
	var shoe := knee.get_node("Shoe") as Node3D
	var euler := leg.basis.get_euler(EULER_ORDER_XZY)
	var hip := euler.x
	var bend := knee.rotation.x
	var hip_range: Vector2 = CHANNELS.hip.range
	var knee_range: Vector2 = CHANNELS.knee.range
	for _step in range(10):
		var here := _foot(body, leg, knee, shoe, euler, hip, bend)
		var error := target - here
		if error.length() < 0.0005:
			break
		var step := 0.01
		var d_hip := (_foot(body, leg, knee, shoe, euler, hip + step, bend) - here) / step
		var d_knee := (_foot(body, leg, knee, shoe, euler, hip, bend + step) - here) / step
		var a := d_hip.dot(d_hip) + 0.001
		var b := d_hip.dot(d_knee)
		var c := d_knee.dot(d_knee) + 0.001
		var g0 := d_hip.dot(error)
		var g1 := d_knee.dot(error)
		var det := a * c - b * b
		if absf(det) < 1e-9:
			break
		hip = clampf(hip + (c * g0 - b * g1) / det, deg_to_rad(hip_range.x), deg_to_rad(hip_range.y))
		bend = clampf(bend + (a * g1 - b * g0) / det, deg_to_rad(knee_range.x), deg_to_rad(knee_range.y))
	_foot(body, leg, knee, shoe, euler, hip, bend)

static func _foot(body: Node3D, leg: Node3D, knee: Node3D, shoe: Node3D, euler: Vector3, hip: float, bend: float) -> Vector3:
	leg.basis = Basis.from_euler(Vector3(hip, euler.y, euler.z), EULER_ORDER_XZY)
	knee.rotation = Vector3(bend, 0.0, 0.0)
	return body.to_local(shoe.global_position)

static func _ordered(pose: Dictionary) -> Dictionary:
	var out := {"mirror": bool(pose.mirror), "channels": {}}
	for channel in CHANNELS:
		out.channels[channel] = snappedf(float(pose.channels.get(channel, 0.0)), 0.0001)
	for group in ["left", "right"]:
		if not pose[group].is_empty():
			out[group] = {}
			for channel in CHANNELS:
				if pose[group].has(channel):
					out[group][channel] = snappedf(float(pose[group][channel]), 0.0001)
	return out
