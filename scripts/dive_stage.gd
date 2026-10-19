extends RefCounted

# Staged dive receive, ported from VWM's DefenseActionBiomechanics (angles here in radians).
# Legs load first, hips hinge next, the upper body leans last; only after contact does the body lay out.
# Phase: -0.64 preparation opens, -0.42 takeoff, 0 contact, 0.34 landing.

const PREP_START := -0.64
const TAKEOFF := -0.42
const CONTACT := 0.0
const LANDING := 0.34
const CONTACT_FRACTION := 0.7
const OLD_FLIGHT_PITCH := -0.8

# Where the dive is in its own clock: prep from the approach, then flight time to landing.
static func phase_for(approach_progress: float, air_time: float, flight_time: float, airborne: bool) -> float:
	if not airborne:
		return lerpf(PREP_START, TAKEOFF, clampf(approach_progress / 0.2, 0.0, 1.0))
	var f := clampf(air_time / maxf(flight_time, 0.001), 0.0, 1.0)
	if f < CONTACT_FRACTION:
		return lerpf(TAKEOFF, CONTACT, f / CONTACT_FRACTION)
	return lerpf(CONTACT, LANDING, (f - CONTACT_FRACTION) / (1.0 - CONTACT_FRACTION))

# `local_direction` is (right, forward) in the body frame.
# `trail_override` names the foot that stays behind (0 left, 1 right) when the caller knows better than the
# direction does: a backward dive pivots on its trailing foot, so that foot is the one that trails.
static func resolve(phase: float, local_direction: Vector2 = Vector2(0, 1), trail_override: int = -1) -> Dictionary:
	var dir := local_direction.normalized() if local_direction.length_squared() > 0.0001 else Vector2(0, 1)
	var side := dir.x
	var ahead := dir.y
	var p := clampf(phase, -1.0, 1.0)
	var launch := smoothstep(TAKEOFF, CONTACT, p)
	var prep := smoothstep(PREP_START, -0.30, p)
	var hinge := smoothstep(-0.46, -0.08, p)
	var lean := smoothstep(-0.22, 0.0, p)
	var layout := smoothstep(CONTACT, LANDING, p)
	var wide := absf(side)
	# The trailing foot drives off the floor as the body leaves it.
	var push := smoothstep(-0.46, -0.24, p)
	var trail_right := (side <= 0.0) if trail_override < 0 else trail_override == 1
	return {
		"trunk_pitch": -0.14 + lerpf(0.0, -0.04, hinge) + lerpf(0.0, -0.08, lean) + OLD_FLIGHT_PITCH * 0.8 * layout,
		"trail_right": trail_right,
		# A lateral push: the lead foot steps out toward the ball and carries the body, the trailing foot loads
		# deep under it and then drives the body off the floor, finishing straight and trailing out behind.
		"trail_hip": deg_to_rad(lerpf(0.0, -34.0, prep) - 22.0 * launch * wide),
		"lead_hip": deg_to_rad(lerpf(0.0, 22.0 * maxf(ahead, 0.0) + 8.0 + 22.0 * wide, prep) * (1.0 - 0.6 * launch) + 30.0 * launch * wide),
		"lead_abduction": deg_to_rad(lerpf(0.0, 24.0 * wide, prep) + 10.0 * wide * launch),
		"trail_abduction": deg_to_rad(lerpf(0.0, 10.0 * wide, prep) + 28.0 * wide * launch),
		"lead_knee": deg_to_rad(lerpf(0.0, -34.0, prep) * (1.0 - 0.9 * launch) - 50.0 * launch * wide),
		"trail_knee": deg_to_rad((-18.0 - 30.0 * wide) * prep * (1.0 - push) + 57.0 * wide * push - 18.0 * (1.0 - wide) * prep * (1.0 - 0.9 * launch) * push),
		"hip_yaw": deg_to_rad(-side * 26.0 * hinge),
		"hip_roll": deg_to_rad(-side * 10.0 * hinge),
		"reach_side": side * lean,
		"protraction": deg_to_rad(12.0 * lean),
		"weight": prep,
		"side": side,
		"prep": prep, "hinge": hinge, "lean": lean, "launch": launch, "ahead": ahead,
		"layout_pitch": OLD_FLIGHT_PITCH * 0.8 * layout,
		# A side dive banks toward the ball through the flight, to the lean it lands in, so the reaching arms
		# point out toward the ball instead of up over the head and the landing carries on from the air.
		"layout_roll": -1.25 * side * launch,
	}

# Body-local (right, forward) of a world-space horizontal direction for a body facing `yaw`.
static func local_direction(world: Vector3, yaw: float) -> Vector2:
	if Vector2(world.x, world.z).length_squared() < 0.0001:
		return Vector2(0, 1)
	var d := Vector2(world.x, world.z).normalized()
	return Vector2(d.x * cos(yaw) - d.y * sin(yaw), -d.x * sin(yaw) - d.y * cos(yaw))

const PoseLibrary := preload("res://scripts/pose_library.gd")
const BASE_POSE := "planted_receive"
const Recovery := preload("res://scripts/dive_recovery.gd")
const ARM_CHANNELS := ["shoulder_pitch", "shoulder_roll", "shoulder_rotation", "elbow", "forearm_rotation"]

# The stage as a pose in the pose library's terms: the planted receive, plus what the dive
# adds. The dive moves the spine and joints, not the whole body, so the platform arms stay
# on the shoulders while the hips and waist do the work:
#   legs load first (hips back, knees and hips fold, lead leg steps toward the ball),
#   the hips hinge and the waist twists and bends toward the ball next,
#   and the chest and shoulders lean last, and least.
static func pose_for(stage: Dictionary, base: Dictionary = {}) -> Dictionary:
	var pose: Dictionary = (base if not base.is_empty() else PoseLibrary.load_pose(BASE_POSE)).duplicate(true)
	pose.mirror = false
	var prep := float(stage.prep)
	var hinge := float(stage.hinge)
	var lean := float(stage.lean)
	var launch := float(stage.launch)
	var side := float(stage.side)
	var wide := absf(side)
	var trail_side: String = "Right" if bool(stage.trail_right) else "Left"
	var lead_side: String = "Left" if bool(stage.trail_right) else "Right"
	var ch: Dictionary = pose.channels
	# Spine. Waist before chest, so the upper body stays up while the platform forms.
	PoseLibrary.set_value(pose, "hip_shift", "", float(ch.get("hip_shift", 0.0)) - 14.0 * prep * (1.0 - launch))
	PoseLibrary.set_value(pose, "hip_hinge", "", float(ch.get("hip_hinge", 0.0)) + 7.0 * hinge)
	PoseLibrary.set_value(pose, "lumbar_flexion", "", float(ch.get("lumbar_flexion", 0.0)) + 6.0 * hinge + 10.0 * lean)
	PoseLibrary.set_value(pose, "lumbar_twist", "", float(ch.get("lumbar_twist", 0.0)) - side * 12.0 * hinge)
	PoseLibrary.set_value(pose, "lumbar_bend", "", float(ch.get("lumbar_bend", 0.0)) - side * 10.0 * hinge)
	PoseLibrary.set_value(pose, "thoracic_flexion", "", float(ch.get("thoracic_flexion", 0.0)) + 3.0 * lean)
	PoseLibrary.set_value(pose, "thoracic_twist", "", float(ch.get("thoracic_twist", 0.0)) - side * 18.0 * lean)
	PoseLibrary.set_value(pose, "thoracic_bend", "", float(ch.get("thoracic_bend", 0.0)) - side * 6.0 * lean)
	PoseLibrary.set_value(pose, "neck_flexion", "", float(ch.get("neck_flexion", 0.0)) - 6.0 * prep - 10.0 * launch * wide)
	# Side dive: banked toward the ball, the chest twists from the far shoulder downward toward the floor, so the
	# body approaches parallel to it and the back arm can reach across to form the platform.
	PoseLibrary.set_value(pose, "lumbar_twist", "", PoseLibrary.value(pose, "lumbar_twist") - side * 6.0 * launch)
	PoseLibrary.set_value(pose, "thoracic_twist", "", PoseLibrary.value(pose, "thoracic_twist") - side * 34.0 * launch)
	PoseLibrary.set_value(pose, "neck_twist", "", float(ch.get("neck_twist", 0.0)) - side * 22.0 * launch)
	# A backward dive turns the upper body ahead of the hips, then the hips follow it round.
	var spine_lead := float(stage.get("turn_spine", 0.0))
	PoseLibrary.set_value(pose, "lumbar_twist", "", PoseLibrary.value(pose, "lumbar_twist") + spine_lead * 0.27)
	PoseLibrary.set_value(pose, "thoracic_twist", "", PoseLibrary.value(pose, "thoracic_twist") + spine_lead * 0.73)
	PoseLibrary.set_value(pose, "neck_twist", "", PoseLibrary.value(pose, "neck_twist") + float(stage.get("turn_neck", 0.0)))
	# The arms reach out through the flight to where they are when the body meets the floor: forward
	# for a forward dive, out toward the ball for a side dive. Without this they stay tucked in the
	# platform until touchdown, then jump out.
	var landing: Dictionary = Recovery.stage_flat(Recovery.plan().stages[0], Vector2(side, float(stage.get("ahead", 1.0))))
	for channel in ARM_CHANNELS:
		for arm_side in PoseLibrary.SIDES:
			var key := "%s:%s" % [channel, arm_side]
			if landing.has(key):
				PoseLibrary.set_value(pose, channel, arm_side, lerpf(PoseLibrary.value(pose, channel, arm_side), float(landing[key]), launch))
	# Legs, per side.
	var stage_deg := {
		lead_side: {"hip": rad_to_deg(float(stage.lead_hip)), "abduction": rad_to_deg(float(stage.lead_abduction)), "knee": rad_to_deg(float(stage.lead_knee))},
		trail_side: {"hip": rad_to_deg(float(stage.trail_hip)), "abduction": rad_to_deg(float(stage.trail_abduction)), "knee": rad_to_deg(float(stage.trail_knee))},
	}
	for leg_side in stage_deg:
		for channel in stage_deg[leg_side]:
			PoseLibrary.set_value(pose, channel, leg_side, PoseLibrary.value(pose, channel, leg_side) + float(stage_deg[leg_side][channel]))
	return pose

# Layers the stage onto the rig. Returns the yaw it added to the body, which is none now: the
# waist does the turning. The caller still removes it next frame, so the contract is unchanged.
static func apply(root: Node3D, stage: Dictionary, weight: float = 1.0) -> float:
	var gate := float(stage.weight) * weight
	if gate <= 0.0001:
		return 0.0
	PoseLibrary.apply(root, pose_for(stage), gate)
	# Once the body is airborne past contact it lays out as a whole, which is orientation, not posture.
	root.rotation.x = lerpf(root.rotation.x, float(stage.layout_pitch), gate)
	root.rotation.z = lerpf(root.rotation.z, float(stage.layout_roll), gate)
	return 0.0
