extends RefCounted

# Live procedural variants on the actual VWM skeleton. The rig faces -Z;
# positive shoulder pitch takes a downward arm forward, not behind the back.
const PoseLibrary := preload("res://scripts/pose_library.gd")

# `pose` is for tools that want to try a pose that is not saved yet; the game passes none.
static func apply(root: Node3D, posture: String, contact: Vector3, weight: float = 1.0, pose: Dictionary = {}) -> void:
	if posture == "planted":
		# Planted receive is authored data (data/poses/planted_receive.json), edited in the pose editor.
		PoseLibrary.apply(root, pose if not pose.is_empty() else PoseLibrary.load_pose("planted_receive"), weight)
		root.get_node("Torso").rotation.y = 0.0
		root.get_node("Head").rotation.y = 0.0
		return
	var pitch := 0.98
	var elbow := 0.30
	var turn := 0.0
	# Every posture is built from where the ball is: the platform and shoulders turn toward it, by as much as the posture allows.
	var aim := clampf(atan2(-contact.x, maxf(-contact.z, 0.2)), -0.90, 0.90)
	var trunk := -0.10
	if posture == "reaching":
		pitch = 1.25
		elbow = 0.12
		trunk = -0.28
		turn = aim * 0.6
	elif posture == "off-axis":
		turn = aim
		pitch = 1.10
		elbow = 0.22
		trunk = -0.16
	elif posture == "moving":
		pitch = 1.05
		elbow = 0.25
		trunk = -0.14
		turn = aim * 0.35
	for side in ["Left", "Right"]:
		var arm := root.get_node(side + "Arm") as Node3D
		var target := Vector3(pitch, turn, 0.32 if side == "Left" else -0.32)
		arm.rotation = arm.rotation.lerp(target, weight)
		var joint := arm.get_node("Elbow") as Node3D
		joint.rotation.x = lerpf(joint.rotation.x, elbow, weight)
	var torso := root.get_node("Torso") as Node3D
	torso.rotation.x = lerpf(torso.rotation.x, trunk, weight)
	torso.rotation.y = turn * 0.35 * weight
	root.get_node("Head").rotation.y = turn * 0.45 * weight
	if posture == "reaching":
		# The leg on the ball's side lunges toward it; the other trails.
		var lead := root.get_node("RightLeg" if contact.x >= 0.0 else "LeftLeg") as Node3D
		var trail := root.get_node("LeftLeg" if contact.x >= 0.0 else "RightLeg") as Node3D
		lead.rotation.x = lerpf(lead.rotation.x, 0.50, weight)
		lead.get_node("Knee").rotation.x = lerpf(lead.get_node("Knee").rotation.x, -0.95, weight)
		trail.rotation.x = lerpf(trail.rotation.x, -0.10, weight)
		trail.get_node("Knee").rotation.x = lerpf(trail.get_node("Knee").rotation.x, -0.25, weight)
	elif posture == "off-axis":
		var far := root.get_node("LeftLeg" if contact.x > 0 else "RightLeg") as Node3D
		far.rotation.y = -turn * 0.35 * weight
