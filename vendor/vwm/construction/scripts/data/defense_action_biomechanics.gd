class_name DefenseActionBiomechanics
extends RefCounted

## The pre-contact flight of a diving first contact. Floor recovery remains in
## the existing recovery model and starts only after phase zero.

## Visual vocabulary semantics
##
## The dive is an emergency first-contact preparation: a moving or reaching voli
## commits beyond a settled platform, contacts while airborne or descending, and
## arrives at the floor before the shared recovery takes over. Non-diving clean,
## moving, strained, and off-axis passes remain in the platform/contact-arrival
## vocabulary; this overlay does not redefine them or their contact result.

const DIVE_START: float = -0.42
const CONTACT: float = 0.0
const FLOOR_END: float = 0.34


static func resolve(phase: float, diving: bool) -> Dictionary:
	if not diving:
		return {
			"dive_weight": 0.0, "forward_metres": 0.0, "drop_metres": 0.0,
			"torso_pitch_radians": 0.0, "trail_hip_degrees": 0.0,
		}
	var p := clampf(phase, -1.0, 1.0)
	# The dive overlay hands back to the shared recovery before the action ends,
	# so the next event does not inherit a hidden translation or a sunken rig.
	var recover := 1.0 - smoothstep(0.62, 1.0, p)
	var launch := smoothstep(DIVE_START, CONTACT, p) * recover
	var floor_arrival := smoothstep(CONTACT, FLOOR_END, p) \
		* (1.0 - smoothstep(0.72, 1.0, p))
	return {
		"dive_weight": maxf(launch, floor_arrival),
		"forward_metres": lerpf(0.0, 0.38, launch) + 0.10 * floor_arrival,
		# The shared recovery resolver owns the actual arrival at the floor. This
		# overlay supplies only the pre-contact centre-of-mass commitment.
		"drop_metres": lerpf(0.0, 0.07, launch) + 0.05 * floor_arrival,
		"torso_pitch_radians": lerpf(0.0, -0.48, launch) - 0.18 * floor_arrival,
		"trail_hip_degrees": lerpf(0.0, -34.0, launch),
		"phase_name": "commit" if p < CONTACT else "floor_arrival",
	}


static func is_diving(posture: String, recovery: String) -> bool:
	return recovery in ["fall", "blown_away"] \
		and posture in ["moving", "reaching", "off_axis"]
