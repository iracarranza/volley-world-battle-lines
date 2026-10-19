class_name AttackPerformanceBiomechanics
extends RefCounted

## Presentation channels the original hinge skeleton could not express.
##
## `SpikeBiomechanics` remains the authoritative joint sequence and
## `AttackActionBiomechanics` remains the action-family vocabulary. This module
## only describes how the rest of the connected toy body carries that sequence:
## pelvis/chest separation, shoulder-girdle travel, palm orientation, toe-off,
## restrained mass deformation and variant-specific recovery.
##
## No value here moves an actor on the court, changes jump elevation, selects an
## outcome, or changes a ball. The contact fitter consumes the completed pose
## afterwards and remains the final authority on the rendered contact height.

const FAMILY_POWER := &"power"
const FAMILY_ROLL := &"roll"
const FAMILY_DINK := &"dink"

const ADJUSTMENT_CLEAN := &"clean"
const ADJUSTMENT_REACHING := &"reaching"
const ADJUSTMENT_MISTIMED := &"mistimed"
const ADJUSTMENT_MISSED := &"missed"


static func resolve(
	phase: float,
	family: StringName,
	adjustment: StringName,
	handedness_sign: float,
	action_power: float,
) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var hand := 1.0 if handedness_sign >= 0.0 else -1.0
	var load := smoothstep(-0.78, -0.44, p) \
		* (1.0 - smoothstep(-0.24, -0.04, p))
	var launch := smoothstep(-0.62, -0.36, p) \
		* (1.0 - smoothstep(-0.12, 0.08, p))
	var acceleration := smoothstep(-0.30, 0.0, p) \
		* (1.0 - smoothstep(0.14, 0.46, p))
	var continuation := smoothstep(-0.04, 0.24, p) \
		* (1.0 - smoothstep(0.62, 0.96, p))
	var landing := smoothstep(0.38, 0.74, p) \
		* (1.0 - smoothstep(0.82, 1.0, p))
	## Power, roll and dink sell the same action until the late striking choice.
	var late_choice := smoothstep(-0.18, 0.04, p)
	var family_force := 1.0
	if family == FAMILY_ROLL:
		family_force = lerpf(1.0, 0.66, late_choice)
	elif family == FAMILY_DINK:
		family_force = lerpf(1.0, 0.38, late_choice)
	var power_emphasis := lerpf(
		0.88, 1.12, smoothstep(0.58, 0.96, clampf(action_power, 0.0, 1.0))
	)
	var drive := family_force * power_emphasis

	## The pelvis carries only a share of the authored trunk rotation. The actor
	## keeps the connected upper silhouette on the legacy body pivot, then
	## counter-rotates the leg roots by the remainder around the hip centre.
	var pelvis_pitch_share := lerpf(0.48, 0.30, maxf(load, acceleration))
	var pelvis_twist_share := lerpf(0.42, 0.24, maxf(load, acceleration))
	var chest_pitch_extra := 0.055 * load - 0.045 * acceleration * drive
	var chest_twist_extra_degrees := hand * (
		5.5 * load - 4.0 * acceleration * drive + 2.0 * continuation * drive
	)

	## Offsets are in the actor's chest frame. X is distance out from the
	## centreline (mirrored by the actor), +Y is shrug, and -Z is toward the ball.
	var striking_shoulder_offset := Vector3(
		0.018 * load,
		0.018 * load + 0.030 * acceleration * drive,
		0.040 * load - 0.052 * acceleration * drive - 0.025 * continuation * drive
	)
	var guide_shoulder_offset := Vector3(
		0.008 * load,
		0.030 * load - 0.016 * continuation,
		-0.030 * load + 0.035 * acceleration + 0.018 * continuation
	)

	## A visible palm makes the distal release readable. The forearm remains the
	## existing elbow chain; these are wrist-local presentation angles only.
	var pronation_degrees := hand * (
		-12.0 * load + 48.0 * acceleration * drive + 22.0 * continuation * drive
	)
	var wrist_flex_degrees := -7.0 * load - 20.0 * acceleration * drive \
		+ 14.0 * continuation * drive
	var wrist_deviation_degrees := hand * (
		4.0 * load - 9.0 * acceleration * drive
	)
	if family == FAMILY_ROLL:
		wrist_flex_degrees = lerpf(wrist_flex_degrees, -4.0, late_choice * 0.80)
		pronation_degrees = lerpf(pronation_degrees, hand * 18.0, late_choice * 0.72)
	elif family == FAMILY_DINK:
		wrist_flex_degrees = lerpf(wrist_flex_degrees, 8.0, late_choice * 0.92)
		pronation_degrees = lerpf(pronation_degrees, hand * 4.0, late_choice * 0.92)
		wrist_deviation_degrees = lerpf(
			wrist_deviation_degrees, -hand * 3.0, late_choice * 0.80
		)

	## The shoe mesh is already the ankle joint. Plantar flexion supplies the
	## missing floor-to-body release while the existing elevation curve still
	## decides exactly when and how high the actor jumps.
	var lead_ankle_degrees := -25.0 * launch + 10.0 * landing
	var trail_ankle_degrees := -30.0 * launch + 8.0 * landing

	## Restrained, approximately volume-preserving mass response. Limbs are never
	## scaled; only the torso volume and the roots attached to it travel.
	var compression := 0.075 * load + 0.055 * landing
	var extension := 0.075 * acceleration * drive + 0.035 * launch
	var mass_height_scale := 1.0 - compression + extension
	var mass_width_scale := 1.0 / sqrt(maxf(mass_height_scale, 0.75))
	var mass_depth_scale := lerpf(1.0, mass_width_scale, 0.72)
	var anchor_height_scale := 1.0 - compression * 0.52 + extension * 0.58
	var chest_roll_degrees := hand * (
		-2.5 * load + 4.2 * continuation * drive
	)
	var recovery_carry := continuation * drive
	var impact_strength := acceleration * drive

	## Adjustment vocabulary is descriptive and remains inert unless a caller
	## explicitly supplies an authoritative label. It never infers one from
	## quality or success.
	var adjustment_weight := smoothstep(-0.24, 0.02, p) \
		* (1.0 - smoothstep(0.62, 0.96, p))
	if adjustment == ADJUSTMENT_REACHING:
		striking_shoulder_offset.x += 0.040 * adjustment_weight
		striking_shoulder_offset.y += 0.025 * adjustment_weight
		striking_shoulder_offset.z -= 0.035 * adjustment_weight
		chest_roll_degrees -= hand * 5.0 * adjustment_weight
		anchor_height_scale += 0.025 * adjustment_weight
		recovery_carry *= 1.16
	elif adjustment == ADJUSTMENT_MISTIMED:
		striking_shoulder_offset.y -= 0.028 * adjustment_weight
		striking_shoulder_offset.z += 0.026 * adjustment_weight
		chest_twist_extra_degrees += hand * 5.0 * adjustment_weight
		chest_roll_degrees += hand * 4.0 * adjustment_weight
		wrist_flex_degrees += 15.0 * adjustment_weight
		impact_strength *= 0.58
	elif adjustment == ADJUSTMENT_MISSED:
		var arrest := smoothstep(0.02, 0.42, p) \
			* (1.0 - smoothstep(0.72, 1.0, p))
		guide_shoulder_offset.z -= 0.045 * arrest
		chest_twist_extra_degrees -= hand * 7.0 * arrest
		chest_roll_degrees -= hand * 5.0 * arrest
		wrist_flex_degrees = lerpf(wrist_flex_degrees, 5.0, arrest)
		impact_strength = 0.0
		recovery_carry = maxf(recovery_carry - 0.34 * arrest, 0.0)

	return {
		"pelvis_pitch_share": pelvis_pitch_share,
		"pelvis_twist_share": pelvis_twist_share,
		"chest_pitch_extra_radians": chest_pitch_extra,
		"chest_twist_extra_degrees": chest_twist_extra_degrees,
		"chest_roll_degrees": chest_roll_degrees,
		"striking_shoulder_offset": striking_shoulder_offset,
		"guide_shoulder_offset": guide_shoulder_offset,
		"forearm_pronation_degrees": pronation_degrees,
		"wrist_flex_degrees": wrist_flex_degrees,
		"wrist_deviation_degrees": wrist_deviation_degrees,
		"lead_ankle_degrees": lead_ankle_degrees,
		"trail_ankle_degrees": trail_ankle_degrees,
		"mass_height_scale": mass_height_scale,
		"mass_width_scale": mass_width_scale,
		"mass_depth_scale": mass_depth_scale,
		"anchor_height_scale": anchor_height_scale,
		"recovery_carry": recovery_carry,
		"impact_strength": impact_strength,
		"family_force": family_force,
		"late_choice": late_choice,
	}
