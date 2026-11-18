extends RefCounted

# Receive confirmation plants the feet; input repositions the platform until impact.
const DURATION := 0.85
const Library := preload("res://scripts/pose_library.gd")
var _base: Dictionary = {}
var _pose: Dictionary = {}
var age := -1.0
var lean := Vector2.ZERO # lateral, forward (S retracts to neutral)
var yaw := 0.0
var pitch := 0.0
var contacted := false

func begin(facing: float, tilt: float) -> void:
	_base = Library.load_pose("planted_receive").channels
	_pose = {"mirror": false, "channels": _base.duplicate(), "left": {}, "right": {}}
	age = 0.0
	lean = Vector2.ZERO
	yaw = facing
	pitch = tilt
	contacted = false

func clear() -> void:
	age = -1.0
	lean = Vector2.ZERO
	contacted = false

func active() -> bool:
	return age >= 0 and age < DURATION

func tick(dt: float, input: Vector3, ready: bool) -> void:
	if not active(): return
	age += dt
	if ready and not contacted:
		lean.x = clampf(lean.x + input.x * dt * 2.5, -1, 1)
		lean.y = clampf(lean.y - input.z * dt * 2.5, 0, 1)

func offset() -> Vector3:
	return Vector3(lean.x * 0.55, -lean.y * 0.20, -lean.y * 0.65)

func pose(root: Node3D) -> void:
	if not active(): return
	var c: Dictionary = _pose.channels
	# Always complete the knee/arm push, including a whiff.
	var push := sin(clampf(age / DURATION, 0, 1) * PI)
	var fade := 1.0 - smoothstep(0.55, DURATION, age)
	c.hip_hinge = float(_base.hip_hinge) + lean.y * 24 * fade - push * 8
	c.thoracic_flexion = float(_base.thoracic_flexion) + lean.y * 12 * fade
	c.knee = float(_base.knee) + push * 26
	c.shoulder_pitch = float(_base.shoulder_pitch) + rad_to_deg(pitch) + push * 22 + lean.y * 12 * fade
	c.elbow = float(_base.elbow) - (push * 20 + lean.y * 16 * fade)
	c.shoulder_roll = float(_base.shoulder_roll) - lean.y * 5 * fade
	c.lumbar_bend = float(_base.lumbar_bend) - lean.x * 12 * fade
	_pose.left.shoulder_rotation = float(c.shoulder_rotation) - lean.x * 22 * fade
	_pose.left.abduction = float(c.abduction) - lean.x * 8 * fade
	_pose.right.shoulder_rotation = float(c.shoulder_rotation) + lean.x * 22 * fade
	_pose.right.abduction = float(c.abduction) + lean.x * 8 * fade
	Library.apply(root, _pose, 1.0)
