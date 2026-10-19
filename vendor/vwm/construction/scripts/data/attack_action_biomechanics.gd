class_name AttackActionBiomechanics
extends RefCounted

## Variant-specific striking chains. The approach and take-off remain the
## canonical SpikeBiomechanics sequence; only the late hand action diverges.

const Spike := preload("res://vendor/vwm/construction/scripts/data/spike_biomechanics.gd")
const AttackPerformance := preload(
	"res://vendor/vwm/construction/scripts/data/attack_performance_biomechanics.gd"
)

const POWER := &"power"
const ROLL := &"roll"
const DINK := &"dink"
const ADJUSTMENT_CLEAN := &"clean"
const ADJUSTMENT_REACHING := &"reaching"
const ADJUSTMENT_MISTIMED := &"mistimed"
const ADJUSTMENT_MISSED := &"missed"

## Visual vocabulary semantics
##
## - power: normal committed swing; clean overhead contact and full continuation.
## - roll: controlled soft attack; the approach sells power before a slower,
##   shaped hand action and contained follow-through.
## - dink/feint/tip: compact intentional touch with the hand forward at contact.
## - clean adjustment: comfortable ideal contact position.
## - reaching adjustment: poor spacing or late reach extends the striking side
##   outside the ideal axis while the approach momentum remains visible.
## - mistimed adjustment: compromised sequencing and cramped contact geometry.
## - missed adjustment: attempted swing after the ideal meeting point was lost;
##   the body still completes and recovers from the committed action.
##
## These labels describe pose meaning only. They do not define when playback or
## simulation should select a family.


static func family(attack_type: String) -> StringName:
	var lowered := attack_type.to_lower()
	if "roll" in lowered:
		return ROLL
	for token in ["feint", "dink", "tip"]:
		if token in lowered:
			return DINK
	return POWER


## The strings the current production simulation can publish. Kept beside the
## visual family resolver so the contract can prove every production name has a
## meaning here instead of relying on a permissive unknown->power fallback.
const PRODUCTION_ATTACK_TYPES: Array[String] = [
	"Power swing", "Tempo swing", "Quick attack", "Pipe attack",
	"Line attack", "Seam attack", "Tool attempt",
	"Controlled roll", "Roll shot",
	"Emergency tip", "Short tip", "Tip",
]


static func production_family(attack_type: String) -> StringName:
	assert(attack_type in PRODUCTION_ATTACK_TYPES)
	return family(attack_type)


static func resolve(
	phase: float,
	handedness_sign: float,
	action_power: float,
	attack_type: String,
	adjustment: StringName = ADJUSTMENT_CLEAN,
) -> Dictionary:
	var joints := Spike.resolve(phase, handedness_sign, action_power)
	var variant := family(attack_type)
	if variant == POWER:
		joints["attack_family"] = POWER
	else:
		_apply_soft_shot(joints, phase, handedness_sign, variant)
	_apply_adjustment(joints, phase, handedness_sign, adjustment)
	joints.merge(AttackPerformance.resolve(
		phase, variant, adjustment, handedness_sign, action_power
	), true)
	return joints


static func _apply_soft_shot(
	joints: Dictionary, phase: float, handedness_sign: float, variant: StringName
) -> void:
	var p := clampf(phase, -1.0, 1.0)
	## The sell remains intact through most of the cock. This late envelope is the
	## biomechanical fact both soft-shot families depend on.
	var change := smoothstep(-0.18, -0.01, p) \
		* (1.0 - smoothstep(0.42, 0.88, p))
	var hand := 1.0 if handedness_sign >= 0.0 else -1.0
	if variant == ROLL:
		joints["striking_shoulder_degrees"] = lerpf(
			float(joints.striking_shoulder_degrees), -196.0, 0.82 * change
		)
		joints["striking_elbow_degrees"] = lerpf(
			float(joints.striking_elbow_degrees), 22.0, 0.90 * change
		)
		joints["striking_abduction_degrees"] = lerpf(
			float(joints.striking_abduction_degrees), 28.0 * hand, 0.82 * change
		)
		joints["striking_internal_rotation_degrees"] = lerpf(
			float(joints.get("striking_internal_rotation_degrees", 0.0)),
			8.0 * hand, 0.72 * change
		)
		joints["torso_pitch_radians"] = lerpf(
			float(joints.torso_pitch_radians), -0.08, 0.58 * change
		)
		joints["torso_twist_degrees"] = lerpf(
			float(joints.torso_twist_degrees), -4.0 * hand, 0.60 * change
		)
		# The guide arm stays available for balance instead of being ripped down
		# as it is in the power chain. Together with the open striking shoulder,
		# this makes the late deceleration legible in silhouette.
		joints["guide_shoulder_degrees"] = lerpf(
			float(joints.guide_shoulder_degrees), 62.0, 0.72 * change
		)
		joints["guide_elbow_degrees"] = lerpf(
			float(joints.guide_elbow_degrees), 28.0, 0.68 * change
		)
	else:
		joints["striking_shoulder_degrees"] = lerpf(
			# Past vertical: the elbow remains compact, but the *upper arm* has
			# already carried the hand in front of the striking shoulder.
			float(joints.striking_shoulder_degrees), -225.0, 0.96 * change
		)
		joints["striking_elbow_degrees"] = lerpf(
			float(joints.striking_elbow_degrees), 62.0, 0.98 * change
		)
		joints["striking_abduction_degrees"] = lerpf(
			float(joints.striking_abduction_degrees), 14.0 * hand, 0.82 * change
		)
		joints["striking_internal_rotation_degrees"] = lerpf(
			float(joints.get("striking_internal_rotation_degrees", 0.0)),
			10.0 * hand, 0.90 * change
		)
		joints["torso_pitch_radians"] = lerpf(
			float(joints.torso_pitch_radians), -0.01, 0.82 * change
		)
		joints["torso_twist_degrees"] = lerpf(
			float(joints.torso_twist_degrees), 0.0, 0.88 * change
		)
		## Keep the guide hand high: a compact touch is balanced by the other arm,
		## not by the violent guide-arm pull of a power swing.
		joints["guide_shoulder_degrees"] = lerpf(
			float(joints.guide_shoulder_degrees), 92.0, 0.76 * change
		)
	joints["attack_family"] = variant
	joints["variant_weight"] = change


## Airborne organization around a resolved poor swing. The approach and launch
## are untouched; this envelope begins only after the canonical plant.
static func _apply_adjustment(
	joints: Dictionary, phase: float, handedness_sign: float,
	adjustment: StringName,
) -> void:
	joints["attack_adjustment"] = adjustment
	joints["adjustment_roll_degrees"] = 0.0
	joints["landing_stagger_degrees"] = 0.0
	if adjustment == ADJUSTMENT_CLEAN:
		return
	var p := clampf(phase, -1.0, 1.0)
	var hand := 1.0 if handedness_sign >= 0.0 else -1.0
	var adjust := smoothstep(-0.24, 0.02, p) \
		* (1.0 - smoothstep(0.56, 0.94, p))
	if adjustment == ADJUSTMENT_REACHING:
		joints["striking_shoulder_degrees"] = lerpf(
			float(joints.striking_shoulder_degrees), -242.0, 0.38 * adjust
		)
		joints["guide_shoulder_degrees"] = lerpf(
			float(joints.guide_shoulder_degrees), 82.0, 0.72 * adjust
		)
		joints["adjustment_roll_degrees"] = -hand * 8.5 * adjust
		joints["landing_stagger_degrees"] = 14.0 * adjust
	elif adjustment == ADJUSTMENT_MISTIMED:
		joints["striking_elbow_degrees"] = lerpf(
			float(joints.striking_elbow_degrees), 48.0, 0.72 * adjust
		)
		joints["torso_twist_degrees"] = lerpf(
			float(joints.torso_twist_degrees), 0.0, 0.62 * adjust
		)
		joints["guide_shoulder_degrees"] = lerpf(
			float(joints.guide_shoulder_degrees), 68.0, 0.64 * adjust
		)
		joints["adjustment_roll_degrees"] = hand * 6.0 * adjust
		joints["landing_stagger_degrees"] = -12.0 * adjust
	elif adjustment == ADJUSTMENT_MISSED:
		# Preserve the attempted arc through phase zero, then use the guide arm
		# and trunk to arrest the unspent rotation rather than drawing a ball-driven
		# carry that never happened.
		var arrest := smoothstep(0.02, 0.40, p) \
			* (1.0 - smoothstep(0.70, 1.0, p))
		joints["striking_shoulder_degrees"] = lerpf(
			float(joints.striking_shoulder_degrees), -205.0, 0.52 * arrest
		)
		joints["striking_elbow_degrees"] = lerpf(
			float(joints.striking_elbow_degrees), 34.0, 0.48 * arrest
		)
		joints["guide_shoulder_degrees"] = lerpf(
			float(joints.guide_shoulder_degrees), 74.0, 0.78 * arrest
		)
		joints["adjustment_roll_degrees"] = -hand * 7.0 * arrest
		joints["landing_stagger_degrees"] = 10.0 * arrest
