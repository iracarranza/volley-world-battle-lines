class_name LandingBiomechanics
extends RefCounted

## What a voli does in the half-second after their feet touch down.
##
## Nothing, until now. `SpikeBiomechanics` carries an attacker through their own
## landing because the swing's phase runs past contact to +1 -- but the moment
## the attack's playback window ends, the actor stops being the contact actor and
## snaps to a neutral stand on the next frame, mid-absorb. A blocker has it worse
## and gets no landing at all: the block pose is a static wall with no phase in
## it, so a blocker drops out of the sky and is standing normally the instant
## they touch the floor.
##
## ## Landing is not the reverse of jumping
##
## A jump is a push: the body extends *into* the floor and the joints open. A
## landing is a controlled collapse -- the joints fold to spread the deceleration
## over time, and they fold in the opposite order to the way they opened, distal
## first. Ankle, then knee, then hip, then trunk. That is why a landing drawn as
## a jump played backwards reads as a bounce.
##
## The absorb is also deeper and briefer than people expect: peak knee flexion
## arrives about a third of the way through and the recovery out of it takes
## twice as long as the drop into it.
##
## ## Landing carries the action that caused it
##
## Which is the reason this takes an `action` at all. A hitter has just swung
## across their body with their weight travelling forward, so they land long and
## asymmetric and keep drifting. A blocker has jumped straight up from a squat
## and has to be ready for the next ball, so they land square, absorb less, and
## bring their hands down late. A jump server lands *inside* the court having
## come from outside it and is travelling hardest of the three.
##
## Pure and deterministic, like the other two pose modules.

## Visual vocabulary semantics
##
## - attack landing: forward-carried, asymmetric touchdown after a swing.
## - block landing: square, compact absorption and rapid return to net readiness.
## - serve landing: forward court-entry after airborne service contact.
## - default landing: neutral touchdown and recovery for an unclassified jump.
##
## Every family covers touchdown, absorption, settle, and handoff to stance; it
## is the continuation of the preceding action, not an isolated landing pose.

## How long an absorb-and-recover takes, in seconds, for each action.
##
## A blocker's is shortest because they cannot afford a long one; a hitter's is
## longest because nothing is asking them to be ready.
const DURATION_SECONDS := {
	"attack": 0.52,
	"block": 0.34,
	"serve": 0.46,
	"default": 0.40,
}

## How deep the knees fold at the bottom of the absorb, in degrees. Negative,
## because every knee on this rig folds backward.
const KNEE_DEPTH_DEGREES := {
	"attack": -52.0,
	"block": -38.0,
	"serve": -46.0,
	"default": -30.0,
}

## How far the trunk folds forward at the bottom, in radians. Negative is
## forward. A blocker stays nearly upright -- folding over is how a blocker
## misses the transition to their next job.
const TORSO_FOLD_RADIANS := {
	"attack": -0.22,
	"block": -0.08,
	"serve": -0.17,
	"default": -0.12,
}

## How far apart the feet finish, in degrees of hip split. A hitter lands long
## and staggered because their weight is still travelling; a blocker lands square
## because they jumped straight up.
const HIP_SPLIT_DEGREES := {
	"attack": 21.0,
	"block": 3.0,
	"serve": 15.0,
	"default": 7.0,
}

## Where in the landing the knees are deepest. Early: the drop into the absorb is
## fast and the climb out of it is not.
const ABSORB_PEAK: float = 0.34

## How folded the voli already is at the instant of touchdown.
##
## Not zero, and the distinction matters twice. Physically, nobody lands on
## locked legs -- the knee is already carrying twenty-odd degrees when the foot
## meets the floor, and it is the *pre*-flexion that makes an absorb possible at
## all. Mechanically, this overlay takes over from `SpikeBiomechanics` partway
## through, at whatever frame the attack's playback window happens to end, and a
## curve starting from zero would snap the knee straight on that frame before
## folding it again.
const TOUCHDOWN_ABSORB: float = 0.38

## How briskly the voli comes off the bottom of the absorb.
##
## Above 1, so the recovery leaves the deepest point sooner than a plain cosine
## would. The recovery still takes twice as long as the drop -- that ratio is what
## makes a landing a catch rather than a bounce -- but a cosine spends most of
## that time near the bottom, and a hitter photographed at 40% and 60% of their
## landing was in a near-identical deep crouch in both. What reads as absorbing is
## passing *through* the bottom, not sitting in it.
const RECOVERY_SHARPNESS: float = 1.5

## How much of the landing a blocker's hands stay up for.
##
## A blocker does not drop their arms the instant they land -- they come down
## after the feet, and a blocker drawn with their arms already at their sides on
## the touchdown frame reads as someone who gave up on the ball.
const BLOCK_ARMS_HELD: float = 0.42


## Every joint the landing overlay needs, for one instant of it.
##
## `progress` runs 0 at touchdown to 1 when the voli is standing again. Values
## outside that are clamped, so a caller that overruns its own timer gets the
## neutral stand rather than an extrapolated fold.
static func resolve(progress: float, action: String) -> Dictionary:
	var p := clampf(progress, 0.0, 1.0)
	var key := action if DURATION_SECONDS.has(action) else "default"
	## One curve, peaking at `ABSORB_PEAK` and reaching zero at both ends: the
	## voli is extended at the moment of contact with the floor, deepest a third
	## of the way through, and upright again at the end.
	##
	## Two half-sines rather than one, because a symmetric curve would take as
	## long to stand up as it took to collapse -- and a landing that takes as long
	## to recover as to absorb reads as a squat rather than as a catch.
	var absorb := lerpf(
		TOUCHDOWN_ABSORB, 1.0, sin(p / ABSORB_PEAK * PI * 0.5)
	) if p < ABSORB_PEAK \
		else pow(
			cos((p - ABSORB_PEAK) / (1.0 - ABSORB_PEAK) * PI * 0.5),
			RECOVERY_SHARPNESS,
		)

	## Distal to proximal: the knee is already folding while the trunk is still
	## upright, and the trunk is still folding as the knee starts to open. Same
	## staggering rule as the spike, run in the opposite direction, because that
	## is literally what a landing is.
	var trunk_lag := clampf((p - ABSORB_PEAK * 0.5) / (1.0 - ABSORB_PEAK * 0.5), 0.0, 1.0)
	var trunk_absorb := sin(trunk_lag * PI)

	var split: float = float(HIP_SPLIT_DEGREES[key])
	## Arms: down and forward for balance through the absorb. A blocker's stay up
	## for the first stretch and only then come down.
	var arm_hold := 0.0
	if key == "block":
		arm_hold = 1.0 - smoothstep(0.0, BLOCK_ARMS_HELD, p)

	return {
		"action": key,
		"absorb": absorb,
		"knee_degrees": float(KNEE_DEPTH_DEGREES[key]) * absorb,
		"torso_pitch_radians": float(TORSO_FOLD_RADIANS[key]) * trunk_absorb,
		## Lead leg ahead, trail leg behind, both collapsing toward level as the
		## voli stands up out of it.
		"lead_hip_degrees": split * absorb,
		"trail_hip_degrees": -split * 0.62 * absorb,
		## No `drop_meters` here on purpose. How far the hips fall is not an
		## artistic choice that can be stated independently -- it is whatever the
		## folded leg is shorter by, which depends on the voli's own bone lengths
		## and so belongs to whoever owns the rig. Published as a constant it would
		## be a number free to drift out of agreement with the knee it is supposed
		## to be caused by, which is how a landing ends up hovering.
		"arm_degrees": lerpf(28.0 * absorb, 152.0, arm_hold),
		"arm_hold": arm_hold,
	}


## How long this action's landing runs, in seconds.
static func duration_seconds(action: String) -> float:
	return float(DURATION_SECONDS.get(action, DURATION_SECONDS["default"]))
