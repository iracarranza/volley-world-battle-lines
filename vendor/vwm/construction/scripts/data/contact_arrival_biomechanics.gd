class_name ContactArrivalBiomechanics
extends RefCounted

## Presentation-only handoff from the live gait into a contact family.
##
## The gait remains the source of foot geometry and stride phase. Contact
## resolvers remain the source of the final platform, setting base, or other
## action pose. This helper says only how much ownership has passed between the
## two, so upper-body preparation can overlap a final adjustment step without a
## root-position snap or a stride reset.

## Visual vocabulary semantics
##
## - settled arrival: the voli reached the contact base early and can establish
##   the platform or setting posture before contact.
## - moving arrival: the voli is still stepping while the upper body prepares.
## - reaching/off-axis arrival: late or awkward geometry retains more of the
##   active step while the contact apparatus extends toward the ball.
##
## This is the continuous preparation handoff from locomotion to contact. It
## describes carried stance and momentum, not contact quality or rally outcome.

const SETTLED_SPEED_MPS: float = 0.45
const MOVING_SPEED_MPS: float = 3.2


static func resolve(
	phase: float,
	speed_mps: float,
	stride_cycle: float,
	posture: String = "planted",
) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var moving := smoothstep(
		SETTLED_SPEED_MPS, MOVING_SPEED_MPS, maxf(speed_mps, 0.0)
	)
	if posture == "moving":
		moving = maxf(moving, 0.82)
	elif posture in ["reaching", "off-axis", "off_axis"]:
		moving = maxf(moving, 0.58)

	# Hands/arms can prepare while the feet are still resolving the last step.
	# The contact apparatus is complete before phase zero at every speed.
	var upper_start := lerpf(-0.72, -0.48, moving)
	var upper_weight := smoothstep(upper_start, -0.06, p)

	# Early arrivals establish the base early; late arrivals retain their active
	# step until the contact. Full action ownership follows immediately after, so
	# the family resolver still owns drive, landing, and recovery.
	var lower_start := lerpf(-0.68, -0.22, moving)
	var lower_end := lerpf(-0.14, 0.12, moving)
	var lower_weight := smoothstep(lower_start, lower_end, p)
	if p > 0.36:
		lower_weight = 1.0

	var stride_wave := sin(stride_cycle * TAU)
	var active_left := stride_wave >= 0.0
	var carry := moving * (1.0 - lower_weight) \
		* (1.0 - smoothstep(0.02, 0.34, p))
	return {
		"moving_weight": moving,
		"upper_body_weight": upper_weight,
		"lower_body_weight": lower_weight,
		"stride_carry_weight": carry,
		"stride_wave": stride_wave,
		"active_left": active_left,
		# A small whole-body counterbalance. It is a presentation tilt, not root
		# travel, and fades as the contact stance takes ownership.
		"momentum_roll_degrees": stride_wave * 3.8 * carry,
	}
