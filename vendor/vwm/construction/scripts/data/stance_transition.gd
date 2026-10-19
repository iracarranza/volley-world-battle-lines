class_name StanceTransition
extends RefCounted

## Getting into a stance, and getting out of one.
##
## Two things on this rig change a body instantly, and they are the same thing
## seen twice:
##
## - **`ready_stance` is read fresh every frame.** `match_court_3d.gd` assigns
##   it and `set_pose` reads `ReadyStance.joints(...)` on the next frame, so a
##   middle dropping off the net goes from hands-up to a defender's crouch
##   between two frames. Nothing tweens it because nothing holds the previous
##   one.
## - **A floor recovery ends by running out of phase.** `_recovery_clock` is a
##   *phase*, so the moment playback stops drawing a voli as the contact actor
##   the recovery stops advancing and the body snaps to whatever the gait says.
##   Photographed: `pose_recover_roll` at 0.86 is upright with the arms still
##   out sideways, and `pose_recover_knee` never rises at all -- its `down`
##   term is monotonic and has no counterpart.
##
## Both are "this body is not in the stance it should be in, and has to get
## there". So there is one mechanism, with two entry points that differ only in
## how long they take: a fifth of a second to change what you are ready for, a
## second to get off the floor.
##
## Pure and deterministic, like the other pose modules.

## Visual vocabulary semantics
##
## Stance transitions continuously connect watching, defending, and blocking
## readiness instead of assigning a new idle silhouette. Floor transitions cover
## controlled knee recovery, sideways fall/roll, forward reaching slide, and
## backward blown-away recovery. Each is a recovery phase whose final body must
## join standing or locomotion without a reset.

## ## How long
##
## **Derived from the distance between the two stances rather than tabulated.**
##
## A table of pair durations is nine numbers for three stances and sixteen for
## four, and every one of them is a thing to get wrong quietly. The distance
## between two joint sets is already the answer to "how much has to change", and
## it is a number this file can compute -- so adding a fourth stance gets a
## sensible duration without anybody choosing one.
##
## The distance is in degrees, summed over the joints that carry a stance, with
## the trunk converted so a radian of lean counts like the tens of degrees it
## actually is.
const STANCE_MIN_SECONDS: float = 0.14
const STANCE_MAX_SECONDS: float = 0.42
const STANCE_SECONDS_PER_DEGREE: float = 0.0022

## **Dropping into a stance is faster than coming out of one.**
##
## An athlete snaps into a defensive posture -- that is the whole point of the
## word "ready" -- and unwinds out of it lazily, because nothing is asking them
## to hurry. Applied as a scale on the duration rather than as a second table,
## and keyed on whether the *target* is the more loaded of the two, which the
## knee already says.
const LOADING_SCALE: float = 0.72
const UNLOADING_SCALE: float = 1.25

## How long it takes to get back on your feet, in seconds.
##
## **These are the simulator's own numbers**, not a second opinion about them.
## `RallySimulator.RECOVERY_DELAY_SECONDS` already prices what each state costs a
## defender before they are a defender again -- a knee is most of a contact, a
## fall is a contact and the transition after it, being blown away is the rest of
## the exchange -- and a drawn recovery that takes a different length of time
## than the priced one is a body that stands up before or after the rally says it
## did.
##
## Copied rather than imported because the dependency would run the wrong way: a
## pose module must not reach into the simulator. A suite check holds the two
## tables equal, which is the same device the codebase uses wherever a value has
## to live in two places.
const FLOOR_SECONDS := {
	"knee": 0.55,
	"fall": 0.95,
	"blown_away": 1.35,
}

## The joints a stance is made of. Named so `distance` and `blend` cannot
## disagree about what they are walking, and so a stance that grows a joint gets
## it in both places at once.
const STANCE_KEYS: Array[String] = [
	"hip_degrees", "knee_degrees", "abduction_degrees",
	"arm_degrees", "elbow_degrees",
]
## The trunk, kept separate because it is in radians and everything else is in
## degrees. Summing the two without this is how a lean worth 20 degrees counts
## as a third of one.
const TORSO_KEY: String = "torso_radians"


## How far apart two stances are, in degrees.
static func distance(from_joints: Dictionary, to_joints: Dictionary) -> float:
	var total := 0.0
	for key in STANCE_KEYS:
		total += absf(
			float(to_joints.get(key, 0.0)) - float(from_joints.get(key, 0.0))
		)
	total += absf(rad_to_deg(
		float(to_joints.get(TORSO_KEY, 0.0))
			- float(from_joints.get(TORSO_KEY, 0.0))
	))
	return total


## How long this change of stance should take.
static func seconds_between(
	from_joints: Dictionary, to_joints: Dictionary
) -> float:
	var span := distance(from_joints, to_joints)
	var scale := LOADING_SCALE if float(to_joints.get("knee_degrees", 0.0)) \
		< float(from_joints.get("knee_degrees", 0.0)) else UNLOADING_SCALE
	return clampf(
		span * STANCE_SECONDS_PER_DEGREE * scale,
		STANCE_MIN_SECONDS, STANCE_MAX_SECONDS,
	)


## How long getting up off the floor should take. Zero for a recovery that never
## went down, which is the common case and must cost nothing.
static func floor_seconds(recovery: String) -> float:
	return float(FLOOR_SECONDS.get(recovery, 0.0))


## The settle curve.
##
## Ease-out rather than ease-in-out: a body arriving in a stance decelerates
## into it, and the acceleration at the start already happened -- it is the
## decision that caused the change. An ease-in on the front of that reads as
## hesitation, which is the opposite of what a ready stance means.
##
## Named `settle` and not `ease`, because `ease` is a GDScript global taking two
## arguments and a static method that shadows it fails to parse at every call
## site *except* its own file.
static func settle(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.4)


## One stance partway into another.
##
## Returns a joint set of the same shape, so the caller hands it to
## `GaitBiomechanics.resolve` exactly where it used to hand a named stance. That
## is the whole reason this is a blend of *stances* rather than a blend of the
## posed rig: the gait interpolates out of its ready stance already, and a
## transition that fought it further down would be two systems moving the same
## joints.
static func blend(
	from_joints: Dictionary, to_joints: Dictionary, progress: float
) -> Dictionary:
	var t := settle(progress)
	var out := {}
	for key in STANCE_KEYS:
		out[key] = lerpf(
			float(from_joints.get(key, 0.0)), float(to_joints.get(key, 0.0)), t
		)
	out[TORSO_KEY] = lerpf(
		float(from_joints.get(TORSO_KEY, 0.0)),
		float(to_joints.get(TORSO_KEY, 0.0)), t
	)
	return out
