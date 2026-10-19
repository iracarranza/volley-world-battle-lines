class_name ServeActionBiomechanics
extends RefCounted

## Style-specific embodiment layered over the established full serve chain.
## See RALLY_ACTION_ANIMATION_CHOREOGRAPHY.md before changing these silhouettes.

const BaseServe := preload("res://vendor/vwm/construction/scripts/data/serve_biomechanics.gd")

const STANDING := "Standing"
const JUMP_TOPSPIN := "Jump Topspin"
const JUMP_FLOAT := "Jump Float"
const HYBRID := "Hybrid"
const SKY_BALL := "Sky Ball"
const STYLES: Array[String] = [
	STANDING, JUMP_TOPSPIN, JUMP_FLOAT, HYBRID, SKY_BALL,
]

## Visual vocabulary semantics
##
## - standing: self-paced grounded overhead serve; compact toss, clean transfer,
##   contact, follow-through, and step into court.
## - jump topspin: aggressive approach and airborne overhead contact with a full
##   trunk bow, fast wrap, landing, and forward recovery.
## - jump float: compact airborne serve with controlled contact and an arrested
##   hand rather than the topspin wrap.
## - hybrid: airborne serve that shares the jump preparation while retaining a
##   more controlled late hand action.
## - sky ball: grounded underhand preparation and high lifting contact.
## - routine variants: pre-toss personal preparation only; they settle into the
##   same style-specific toss and never represent a separate contact outcome.


static func canonical_style(raw_style: String) -> String:
	for style in STYLES:
		if raw_style.to_lower() == style.to_lower():
			return style
	return STANDING


static func routine_variant(player_id: int) -> int:
	return absi(hash("serve-routine:%d" % player_id)) % 3


static func window(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	return smoothstep(from_phase, to_phase, phase)


static func resolve(
	phase: float,
	hand: float = 1.0,
	action_power: float = 0.0,
	serve_style: String = STANDING,
	routine: int = 0,
) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var style := canonical_style(serve_style)
	if style == SKY_BALL:
		return _sky_ball(p, hand, routine)

	var joints := BaseServe.resolve(p, hand, action_power)
	var routine_motion := _routine_motion(p, routine)
	joints["torso_pitch_radians"] = float(joints.torso_pitch_radians) \
		+ float(routine_motion.torso_pitch_radians)
	joints["lead_hip_degrees"] = float(joints.lead_hip_degrees) \
		+ float(routine_motion.lead_hip_degrees)
	joints["trail_hip_degrees"] = float(joints.trail_hip_degrees) \
		+ float(routine_motion.trail_hip_degrees)

	var rise := 0.0
	var support := "grounded_stagger"
	match style:
		JUMP_TOPSPIN:
			rise = _jump_rise(p, -0.38, 0.34, 0.62)
			var approach := window(p, -0.94, -0.42) \
				* (1.0 - window(p, -0.42, -0.28))
			joints["lead_hip_degrees"] = float(joints.lead_hip_degrees) + 24.0 * approach
			joints["trail_hip_degrees"] = float(joints.trail_hip_degrees) - 20.0 * approach
			joints["knee_degrees"] = minf(float(joints.knee_degrees), lerpf(-18.0, -56.0, approach))
			joints["torso_pitch_radians"] = float(joints.torso_pitch_radians) \
				+ 0.12 * window(p, -0.44, -0.10) \
				- 0.18 * window(p, -0.10, 0.20)
			support = "airborne_bilateral"
		JUMP_FLOAT:
			rise = _jump_rise(p, -0.30, 0.28, 0.36)
			var punch := window(p, -0.14, 0.0) \
				* (1.0 - window(p, 0.10, 0.34))
			joints["torso_pitch_radians"] = lerpf(
				float(joints.torso_pitch_radians), -0.04, 0.72 * punch
			)
			joints["torso_twist_degrees"] = lerpf(
				float(joints.torso_twist_degrees), 0.0, 0.74 * punch
			)
			joints["striking_abduction_degrees"] = lerpf(
				float(joints.striking_abduction_degrees), 4.0 * hand, punch
			)
			## Arrest the hand shortly after contact instead of wrapping it to the hip.
			joints["striking_shoulder_degrees"] = lerpf(
				float(joints.striking_shoulder_degrees), -218.0, window(p, 0.02, 0.30)
			)
			joints["striking_elbow_degrees"] = lerpf(
				float(joints.striking_elbow_degrees), 16.0, window(p, 0.02, 0.30)
			)
			support = "airborne_square"
		HYBRID:
			rise = _jump_rise(p, -0.34, 0.31, 0.47)
			var ambiguity := window(p, -0.38, -0.08) \
				* (1.0 - window(p, 0.18, 0.52))
			joints["torso_pitch_radians"] = lerpf(
				float(joints.torso_pitch_radians), -0.08, 0.38 * ambiguity
			)
			joints["striking_shoulder_degrees"] = lerpf(
				float(joints.striking_shoulder_degrees), -260.0, 0.35 * window(p, 0.0, 0.38)
			)
			support = "airborne_compact"
		_:
			pass

	joints["rise_metres"] = rise
	joints["serve_style"] = style
	joints["support"] = support
	joints["routine_variant"] = posmod(routine, 3)
	joints["underhand"] = false
	return joints


static func _routine_motion(phase: float, routine: int) -> Dictionary:
	## The possession beat ends before the toss. The envelope returns to zero at
	## both ends, so no routine can retime or displace the authored toss.
	var progress := clampf(inverse_lerp(-1.0, BaseServe.TOSS_START, phase), 0.0, 1.0)
	var envelope := sin(progress * PI)
	var pulses := float(posmod(routine, 3) + 1)
	var beat := sin(progress * PI * pulses) * envelope
	var sign := -1.0 if posmod(routine, 2) == 0 else 1.0
	return {
		"torso_pitch_radians": 0.018 * beat,
		"lead_hip_degrees": 3.0 * beat,
		"trail_hip_degrees": -3.0 * beat * sign,
	}


static func _jump_rise(
	phase: float, takeoff_phase: float, landing_phase: float, height: float
) -> float:
	var progress := clampf(inverse_lerp(takeoff_phase, landing_phase, phase), 0.0, 1.0)
	if phase <= takeoff_phase or phase >= landing_phase:
		return 0.0
	return height * sin(progress * PI)


static func _sky_ball(phase: float, hand: float, routine: int) -> Dictionary:
	var load := window(phase, -0.72, -0.24)
	var strike := window(phase, -0.24, 0.02)
	var follow := window(phase, 0.0, 0.48)
	var recover := window(phase, 0.48, 0.90)
	var routine_motion := _routine_motion(phase, routine)
	var shoulder := lerpf(10.0, -54.0, load)
	shoulder = lerpf(shoulder, 46.0, strike)
	shoulder = lerpf(shoulder, 82.0, follow)
	shoulder = lerpf(shoulder, 12.0, recover)
	var knee := lerpf(-14.0, -48.0, load)
	knee = lerpf(knee, -5.0, strike)
	knee = lerpf(knee, -14.0, recover)
	var torso := lerpf(-0.04, -0.24, load)
	torso = lerpf(torso, 0.08, strike)
	torso = lerpf(torso, -0.04, recover)
	return {
		"striking_shoulder_degrees": shoulder,
		"striking_abduction_degrees": 9.0 * hand,
		"striking_internal_rotation_degrees": 0.0,
		"striking_elbow_degrees": lerpf(18.0, 4.0, maxf(strike, follow)),
		"guide_shoulder_degrees": lerpf(18.0, -28.0, strike),
		"guide_elbow_degrees": 12.0,
		"torso_pitch_radians": torso + float(routine_motion.torso_pitch_radians),
		"torso_twist_degrees": lerpf(8.0 * hand, 0.0, strike),
		"lead_hip_degrees": lerpf(10.0, -4.0, strike),
		"trail_hip_degrees": lerpf(-14.0, 9.0, strike),
		"knee_degrees": knee,
		"power_boost": 0.0,
		"rise_metres": 0.0,
		"serve_style": SKY_BALL,
		"support": "grounded_open",
		"routine_variant": posmod(routine, 3),
		"underhand": true,
	}
