class_name ApproachBiomechanics
extends RefCounted

## The three-step approach: the footwork that turns a run into a jump.
##
## `SpikeBiomechanics` starts at `PLANT_END`, phase -0.62, with both feet already
## down and the arms already back. Everything before that -- the part a hitter
## spends most of the action doing, and the part a viewer watches to know whether
## a swing is going to be any good -- was the ordinary running gait, so every
## attacker in the game jogged to the net and then teleported into a plant.
##
## ## Why three steps and not a run
##
## An approach is not locomotion with a jump on the end. It is a deceleration:
## the hitter arrives with horizontal speed they do not want and converts it into
## vertical speed they do, and the three steps are the mechanism.
##
##   **Directional** -- a short step that sets the line to the ball. Small,
##   because its job is aim rather than pace, and it is the step a hitter cuts
##   when the set is fast.
##
##   **Penultimate** -- the long one, and the whole point of the approach. The
##   foot reaches well out in front of the hips and the body stays low behind it,
##   which is what lets the leg act as a brake. A hitter whose penultimate is
##   short has nothing to convert and jumps off their calves.
##
##   **Close** -- the trail foot arrives beside the lead one and both plant
##   together. Feet square, knees deepest, and the arms -- which have been
##   swinging back through the last two steps -- are behind the hips and ready to
##   throw upward.
##
## ## Handedness
##
## A right-handed hitter closes **right then left**: the right foot takes the
## long penultimate step and the left closes beside it, which is what turns the
## shoulders slightly away from the net and loads the swing. A left-hander
## mirrors it exactly. That is why `lead_is_left` is the only handedness input --
## everything else falls out of which foot is doing which job.
##
## Pure and deterministic, like `SpikeBiomechanics` and `GaitBiomechanics`, and
## for the same reason: pose work that cannot be checked without eyes on a screen
## does not get checked.

## Visual vocabulary semantics
##
## Canonical attack preparation: directional step, long penultimate, closing
## plant, then takeoff. It represents a committed normal approach whose carried
## run is converted into vertical launch. Power, roll, dink, and compromised
## attack variants all begin from this same continuous footwork; their volleyball
## meaning diverges at the late striking action rather than through a new run-up.

## Where each step owns the approach window, as a share of it. The directional
## step is short and the last two are where the time goes -- a real approach is
## mostly its penultimate and its close, and rendering them at even thirds is the
## single fastest way to make an approach look like jogging.
const DIRECTIONAL_END: float = 0.34
const PENULTIMATE_END: float = 0.76

## How far each foot swings, in degrees of hip. The penultimate is nearly double
## the directional, which is the proportion that makes it read as a *reach*
## rather than as another stride.
const DIRECTIONAL_HIP_DEGREES: float = 22.0
const PENULTIMATE_HIP_DEGREES: float = 41.0
## And where the trail leg is while the lead reaches: extended behind, because
## the hitter is still travelling and has not caught up with their own foot yet.
const TRAIL_EXTENSION_DEGREES: float = -26.0

## Knee fold through the approach: gathering on the directional step, deep behind
## the penultimate, deepest at the close. The last of these is what
## `SpikeBiomechanics.KNEE_LOAD_DEGREES` (-58) picks up, so the two meet without
## a step in the curve.
const KNEE_GATHER_DEGREES: float = -28.0
const KNEE_BRACE_DEGREES: float = -44.0
const KNEE_LOAD_DEGREES: float = -58.0

## The arms. They run with the legs, then stop counter-swinging and go back
## together -- the moment they do is the clearest signal in the whole action that
## a jump is coming, and it is the one thing a viewer can read at a distance.
const ARM_RUN_DEGREES: float = 30.0
const ARM_BACK_DEGREES: float = -74.0
const ARM_ELBOW_RUN_DEGREES: float = 62.0
const ARM_ELBOW_BACK_DEGREES: float = 18.0
## Where the arms give up the run and start the backswing together. Inside the
## penultimate step, not at the close: by the time both feet land the arms are
## already behind, which is the whole timing of a jump.
const ARM_GATHER_START: float = 0.42

## Trunk. Upright on the approach, then folding forward over the penultimate as
## the hips sit back behind the braking foot. Negative is forward on this rig,
## matching `SpikeBiomechanics.TORSO_PLANT_RADIANS` at -0.26, which this hands
## off to.
const TORSO_RUN_RADIANS: float = -0.08
const TORSO_PLANT_RADIANS: float = -0.26


## Every joint of the approach, for one instant of it.
##
## `progress` runs 0 at the first directional step to 1 at the plant, so callers
## remap whatever phase window they have onto it and this stays free of any
## particular pose's timing.
static func resolve(progress: float, lead_is_left: bool) -> Dictionary:
	var t := clampf(progress, 0.0, 1.0)

	## Which foot is doing what. The lead foot takes the directional step and the
	## close; the trail foot takes the long penultimate. Naming them by job
	## rather than by side is what keeps the mirror to one flag.
	var lead_hip := 0.0
	var trail_hip := 0.0
	var knee := KNEE_GATHER_DEGREES

	if t < DIRECTIONAL_END:
		## Step one. The lead foot swings through and plants; the trail leg is
		## still behind, finishing the stride that carried them here.
		var step := t / DIRECTIONAL_END
		lead_hip = sin(step * PI) * DIRECTIONAL_HIP_DEGREES
		trail_hip = lerpf(TRAIL_EXTENSION_DEGREES, 0.0, step)
		knee = lerpf(KNEE_GATHER_DEGREES, KNEE_GATHER_DEGREES * 0.7, step)
	elif t < PENULTIMATE_END:
		## Step two, the long one. The trail foot reaches out in front while the
		## body stays behind it, and the knee folds to take the load. The lead leg
		## trails and extends -- it is the one about to be brought through.
		var step := (t - DIRECTIONAL_END) / (PENULTIMATE_END - DIRECTIONAL_END)
		trail_hip = smoothstep(0.0, 1.0, step) * PENULTIMATE_HIP_DEGREES
		lead_hip = lerpf(DIRECTIONAL_HIP_DEGREES * 0.3, TRAIL_EXTENSION_DEGREES, step)
		knee = lerpf(KNEE_GATHER_DEGREES * 0.7, KNEE_BRACE_DEGREES, step)
	else:
		## Step three. The lead foot closes to the trail one and both arrive
		## together, so the two hips converge rather than one overtaking the
		## other. Converging *to the same value* is what makes this a plant and
		## not a fourth step.
		var step := (t - PENULTIMATE_END) / maxf(1.0 - PENULTIMATE_END, 0.001)
		var square := smoothstep(0.0, 1.0, step)
		trail_hip = lerpf(PENULTIMATE_HIP_DEGREES, 8.0, square)
		lead_hip = lerpf(TRAIL_EXTENSION_DEGREES, 8.0, square)
		knee = lerpf(KNEE_BRACE_DEGREES, KNEE_LOAD_DEGREES, square)

	## The arms leave the run together rather than one at a time, which is what
	## separates an approach from a jog with a jump on the end.
	var gather := clampf(
		(t - ARM_GATHER_START) / maxf(1.0 - ARM_GATHER_START, 0.001), 0.0, 1.0
	)
	var swung := smoothstep(0.0, 1.0, gather)
	## Before the gather the arms counter-swing off the legs, as in any run.
	var counter := sin(t / maxf(ARM_GATHER_START, 0.001) * TAU) * ARM_RUN_DEGREES

	return {
		"left_hip_degrees": lead_hip if lead_is_left else trail_hip,
		"right_hip_degrees": trail_hip if lead_is_left else lead_hip,
		"knee_degrees": knee,
		"left_arm_degrees": lerpf(counter, ARM_BACK_DEGREES, swung),
		"right_arm_degrees": lerpf(-counter, ARM_BACK_DEGREES, swung),
		"elbow_degrees": lerpf(
			ARM_ELBOW_RUN_DEGREES, ARM_ELBOW_BACK_DEGREES, swung
		),
		"torso_pitch_radians": lerpf(
			TORSO_RUN_RADIANS, TORSO_PLANT_RADIANS, smoothstep(
				0.0, 1.0, clampf(t / maxf(PENULTIMATE_END, 0.001), 0.0, 1.0)
			)
		),
		## Named so a caption or a probe can say which step is on screen without
		## re-deriving the bands.
		"step_name": (
			"directional" if t < DIRECTIONAL_END
			else ("penultimate" if t < PENULTIMATE_END else "close")
		),
	}
