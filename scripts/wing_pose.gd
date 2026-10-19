extends RefCounted

# Drives the Avi wing joints that VWM's rig builds under each arm. Only wing joints
# move, so arm poses and reach are untouched. Poses and limits come from VWM's rig data.
const Bodies := preload("res://vendor/vwm/body_type_models.gd")

static func has_wing(body: Node3D) -> bool:
	return body.get_node_or_null("LeftArm/WingShoulder") != null

# from_pose/to_pose: tucked, balance, block, flare. Weight is clamped to 0..1.
static func apply(body: Node3D, from_pose: String, to_pose: String, weight: float) -> void:
	if not has_wing(body):
		return
	var data: Dictionary = Bodies.AVI_WING
	var a: Dictionary = data.poses[from_pose]
	var b: Dictionary = data.poses[to_pose]
	var limits: Dictionary = data.limits
	var w := clampf(weight, 0.0, 1.0)
	for side in ["Left", "Right"]:
		var out := -1.0 if side == "Left" else 1.0
		var arm := "%sArm" % side
		var wrist_path := arm + "/Elbow/WingElbow/WingWrist"
		_set_z(body, arm + "/WingShoulder", out * _blend(a, b, "shoulder", w, limits.WingShoulder.z))
		_set_z(body, arm + "/Elbow/WingElbow", out * _blend(a, b, "elbow", w, limits.WingElbow.z))
		_set_z(body, wrist_path, out * _blend(a, b, "wrist", w, limits.WingWrist.z))
		var spread := _blend(a, b, "spread", w, limits.WingTipSpread.x)
		for index in range(3):
			var tip := body.get_node(wrist_path + "/WingTipSpread%d" % (index + 1)) as Node3D
			tip.rotation_degrees = Vector3(spread * float(index - 1), 0.0, 0.0)

static func _blend(a: Dictionary, b: Dictionary, key: String, w: float, limit: Vector2) -> float:
	return clampf(lerpf(float(a[key]), float(b[key]), w), limit.x, limit.y)

static func _set_z(body: Node3D, path: String, degrees: float) -> void:
	(body.get_node(path) as Node3D).rotation_degrees = Vector3(0.0, 0.0, degrees)
