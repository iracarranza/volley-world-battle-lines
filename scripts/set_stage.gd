extends RefCounted

# The set, from VWM's SetBiomechanics, as pose-library channels so it can be opened, edited and blended in the
# pose editor. Phase: -0.72 hands start to gather, -0.16 gathered at the forehead, 0.16 push done, 0.40 arms fully
# extended, 0.88 recovered. `posture` is "standing" (an overhand set), "jump" or "underhand" (a set off the forearms).
const Library := preload("res://scripts/pose_library.gd")
const Set := preload("res://vendor/vwm/construction/scripts/data/set_biomechanics.gd")
const BASE_POSE := "ready_stance"

# The set at `phase` as a flat pose (see PoseLibrary.flatten). `hand` is +1 right-handed, -1 left.
static func pose_for(phase: float, hand: float = 1.0, posture: StringName = Set.POSTURE_STANDING, back_set: bool = false) -> Dictionary:
	var push := Set.resolve(phase, hand, posture, back_set)
	var flat := Library.flat_pose(BASE_POSE)
	# VWM tips the whole body by the torso pitch (negative leans forward); the hips carry it here.
	flat["hip_hinge"] = -rad_to_deg(float(push.torso_pitch_radians))
	var split := float(push.hip_split_degrees)
	flat["hip:Left"] = -split
	flat["hip:Right"] = split
	for side in Library.SIDES:
		flat["knee:%s" % side] = float(push.knee_degrees)
		flat["abduction:%s" % side] = 0.0
		flat["shoulder_pitch:%s" % side] = float(push.shoulder_degrees)
		flat["shoulder_roll:%s" % side] = float(push.flare_degrees)
		flat["shoulder_rotation:%s" % side] = 0.0
		flat["elbow:%s" % side] = float(push.elbow_degrees)
	return flat

static func apply(body: Node3D, phase: float, hand: float = 1.0, posture: StringName = Set.POSTURE_STANDING, back_set: bool = false) -> void:
	Library.apply(body, Library.from_flat(pose_for(phase, hand, posture, back_set), false), 1.0)

# --- Driven by the pose files, so edits in the pose editor reach the lab -----------------------------------
# The poses the set passes through, in order, and the phase each one stands for. A jump set passes through the jump
# contact pose where the standing set uses the standing contact and extension.
# Ground-set follow-through. The set waits armed at the gather pose (-0.16) and contact used to jump
# straight to 0.04, skipping ~0.16 s of motion in a single frame. The gap now runs down over BLEND
# seconds, so the follow-through starts from the pose already on screen.
const GATHER_PHASE := -0.16
const CONTACT_PHASE := 0.04
const FOLLOW_SECONDS := 0.5
const FOLLOW_BLEND := 0.20

static func follow_phase(since: float) -> float:
	var base := lerpf(CONTACT_PHASE, 0.88, clampf(since / FOLLOW_SECONDS, 0.0, 1.0))
	return base - (CONTACT_PHASE - GATHER_PHASE) * maxf(0.0, 1.0 - since / FOLLOW_BLEND)

const KEYS_STANDING := [[-0.72, "ready_stance"], [-0.16, "set_gather"], [0.04, "set_contact"], [0.40, "set_extend"], [0.88, "ready_stance"]]
const KEYS_JUMP := [[-0.72, "ready_stance"], [-0.16, "set_gather"], [0.04, "set_jump_contact"], [0.40, "set_jump_contact"], [0.88, "ready_stance"]]

# The set at `phase`, blended between the pose files either side of it. `hand` mirrors the foot split for left-handers.
static func data_pose(phase: float, jump: bool = false, hand: float = 1.0) -> Dictionary:
	var keys: Array = KEYS_JUMP if jump else KEYS_STANDING
	var p := clampf(phase, float(keys[0][0]), float(keys[keys.size() - 1][0]))
	var index := 0
	while index < keys.size() - 2 and p > float(keys[index + 1][0]):
		index += 1
	var from_key: Array = keys[index]
	var to_key: Array = keys[index + 1]
	var weight := smoothstep(float(from_key[0]), float(to_key[0]), p)
	var a := Library.flatten(Library.load_pose(String(from_key[1])))
	var b := Library.flatten(Library.load_pose(String(to_key[1])))
	var flat := {}
	for key in a:
		flat[key] = lerpf(float(a[key]), float(b.get(key, a[key])), weight)
	if hand < 0.0:
		var left: float = flat["hip:Left"]
		flat["hip:Left"] = flat["hip:Right"]
		flat["hip:Right"] = left
	return flat

static func apply_data(body: Node3D, phase: float, jump: bool = false, hand: float = 1.0) -> void:
	Library.apply(body, Library.from_flat(data_pose(phase, jump, hand), false), 1.0)
