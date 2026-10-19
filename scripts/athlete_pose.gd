extends RefCounted
const Gait := preload("res://vendor/vwm/construction/scripts/data/gait_biomechanics.gd")
const Ready := preload("res://vendor/vwm/construction/scripts/data/ready_stance.gd")

const PoseLibrary := preload("res://scripts/pose_library.gd")

static func base(root: Node3D, cycle: float, speed: float, heading: float, receiving: bool, receive_weight: float = 1.0) -> Dictionary:
	PoseLibrary.release_trunk(root)
	# Standing still is the ready_stance pose and a receive is the planted_receive pose, both from data/poses so
	# the pose editor changes the walk's resting stance too. The built-in numbers are only the fallback.
	var neutral := PoseLibrary.gait_stance("ready_stance", {"hip_degrees": 2.0, "knee_degrees": -5.0, "abduction_degrees": 0.0, "arm_degrees": -5.0, "elbow_degrees": 12.0, "torso_radians": 0.0})
	var stance := neutral.duplicate()
	if receiving:
		var defending := PoseLibrary.gait_stance("planted_receive", Ready.defending())
		for key in stance:
			stance[key] = lerpf(float(neutral[key]), float(defending[key]), receive_weight)
	# A voli with a receive ready shuffles: low base, feet never crossing, hips quiet, whichever way they travel.
	# VWM's gait only shuffles for sideways travel, so the heading is turned square to the body as the stance comes
	# in, and the forward and backward parts of it fade out with it.
	if receiving:
		var sideways := maxf(absf(sin(heading)), receive_weight)
		heading = atan2((signf(sin(heading)) if absf(sin(heading)) > 0.001 else 1.0) * sideways, cos(heading) * (1.0 - receive_weight))
	var gait := Gait.resolve(cycle, speed, heading, stance)
	for side in ["Left", "Right"]:
		var key: String = side.to_lower()
		var leg := root.get_node(side + "Leg") as Node3D
		leg.rotation_degrees = Vector3(gait[key + "_hip_degrees"], 0, gait.abduction_degrees * (-1 if side == "Left" else 1))
		var knee := leg.get_node("Knee") as Node3D
		knee.rotation_degrees = Vector3(gait[key + "_knee_degrees"], 0, 0)
		var arm := root.get_node(side + "Arm") as Node3D
		arm.rotation_degrees = Vector3(gait[key + "_arm_degrees"], 0, 0)
		arm.get_node("Elbow").rotation_degrees = Vector3(gait.elbow_degrees, 0, 0)
	return gait

static func ground_feet(root: Node3D) -> void:
	var lowest := INF
	for side in ["Left", "Right"]:
		var leg := root.get_node(side + "Leg") as Node3D
		var knee := leg.get_node("Knee") as Node3D
		var shoe := knee.get_node("Shoe") as MeshInstance3D
		# Counter-rotate the ankle so the sole stays flat under hip/knee motion.
		var base_pitch: float = root.get_meta("shoe_base_pitch", 0.0)
		shoe.basis = (Basis.from_euler(leg.rotation) * Basis.from_euler(knee.rotation)).inverse() * Basis.from_euler(Vector3(base_pitch, 0, 0))
		var transform := root.global_transform.affine_inverse() * shoe.global_transform
		var bounds := shoe.get_aabb()
		for corner in range(8):
			lowest = minf(lowest, (transform * bounds.get_endpoint(corner)).y)
	root.position.y = -lowest * root.scale.y
