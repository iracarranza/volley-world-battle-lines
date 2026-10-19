class_name ReadyStance
extends RefCounted

## What a voli stands like when they are not playing the ball.
##
## The rig had exactly one answer to that, and it was a passer's. `player_actor_3d.gd`
## returns after the gait for anybody who is not the drawn contact actor, and the
## gait used to interpolate every joint directly out of a single floor stance --
## knees at -60, hips back, arms carried behind, feet outside the shoulders.
## That is a defender waiting
## for a ball, and it was being worn by all twelve bodies on the court.
##
## Two separate reports are that one fact seen from opposite sides:
##
## - a front-row voli at the net stands in a defender's crouch instead of with
##   their hands up at the tape
## - and a voli with no responsibility for the serve holds a passing posture
##   through it anyway
##
## Measured before building, because three cases this session turned out not to
## occur: `run_idle_stance_probe.gd` over 8 rallies finds **66.5%** of the frames
## within 1.6 m of the net are fully in that crouch, with another 23% partly in
## it. The stance is not a corner case; it is most of what is on screen.
##
## ## The stances are not invented here
##
## The `blocking` numbers are `BlockBiomechanics`'s own read stage -- the pose a
## blocker is already interpolating out of when their jump begins. Taking them
## from there rather than authoring a fourth set of angles is what makes the
## idle *continuous* with the block that follows it: a voli waiting at the net
## and the first frame of that voli's jump are the same body, so nothing snaps
## when the wall starts to go up. Writing them again by hand would have produced
## two poses that agree by accident until one of them is retuned.
##
## Both files put shoulder pitch on the arm's local x and the bend on `Elbow.x`,
## so the two sets of constants are directly comparable rather than merely
## similarly named -- which is worth stating, because the sign conventions on
## this rig differ per joint and the knee is negative in every file.
##
## ## Why this is its own module
##
## `GaitBiomechanics` must not know what a block is. The two are a locomotion
## model and a jump, and the comment in `BlockBiomechanics` about sharing a
## convention rather than a dependency applies here in the same direction. So
## the gait takes the idle stance as an argument, and the arbitration -- which
## body wears which -- lives here, where both may be named without either
## depending on the other. Locomotion releases the leg portion through upright
## standing before the walk/run cycle takes it over; upper-body carriage can
## still interpolate directly from the job-specific stance.

## Visual vocabulary semantics
##
## - defending: settled, loaded reception/dig readiness with a wide base.
## - blocking: tall net readiness, hands available to read and close a wall.
## - watching: soft non-contact attention when this voli is not playing the ball.
##
## These are continuity endpoints for idle, locomotion, action preparation, and
## recovery. They describe the visible job of the body, not tactical selection.

## The defender's crouch. Wide, low, loaded: the stance the whole court was
## wearing, and still the right one for anybody who may have to play this ball.
##
## These are `GaitBiomechanics`' own `READY_*` constants, referenced rather than
## copied so the default cannot drift away from the file that documents it.
static func defending() -> Dictionary:
	return {
		"hip_degrees": GaitBiomechanics.READY_HIP_DEGREES,
		"knee_degrees": GaitBiomechanics.READY_KNEE_DEGREES,
		"abduction_degrees": GaitBiomechanics.READY_ABDUCTION_DEGREES,
		"arm_degrees": GaitBiomechanics.READY_ARM_DEGREES,
		"elbow_degrees": GaitBiomechanics.READY_ELBOW_DEGREES,
		"torso_radians": GaitBiomechanics.READY_TORSO_RADIANS,
	}


## Hands up at the tape, reading the setter.
##
## Every joint is `BlockBiomechanics.resolve(-1.0)` -- the read stage, before the
## countermovement -- so this pose and the first frame of a block are the same
## body. A blocker is *tall*: the crouch that suits a defender costs height, and
## height at the net is the entire point of standing there.
##
## The one departure is the hips. The block's read splits them 6 and -6 into a
## staggered stance, which is where a blocker's feet go once they have chosen a
## direction to move; a blocker who has not yet read anything stands square to
## the net with their feet parallel. The split arrives with the block itself.
static func blocking() -> Dictionary:
	return {
		"hip_degrees": 4.0,
		"knee_degrees": BlockBiomechanics.KNEE_READY_DEGREES,
		## Narrower than a defender's base. A blocker's feet are about shoulder
		## width because they travel along the net by shuffling, and a stance
		## already at its widest has nowhere to shuffle from.
		"abduction_degrees": 9.0,
		"arm_degrees": BlockBiomechanics.SHOULDER_READY_DEGREES,
		"elbow_degrees": BlockBiomechanics.ELBOW_READY_DEGREES,
		"torso_radians": BlockBiomechanics.TORSO_READY_RADIANS,
	}


## Standing, but not at rest: a voli watching a ball that is not theirs.
##
## The one stance here with no prior file to take it from, so each joint is
## anchored on something rather than chosen. It sits between the defender's
## crouch and zero -- and zero is not an option, because the argument
## `GaitBiomechanics` already makes about straight legs and hanging arms holds
## just as well for somebody watching as for somebody waiting.
static func watching() -> Dictionary:
	return {
		"hip_degrees": 6.0,
		## Soft rather than loaded. A third of the defender's fold: enough that
		## the legs are not columns, not so much that the body reads as ready to
		## move when it is not.
		"knee_degrees": -22.0,
		## About shoulder width -- feet apart, but not the defender's wide base.
		"abduction_degrees": 8.0,
		## Hanging, barely behind the body. The defender's -30 carries the hands
		## forward ready to platform; this does not.
		"arm_degrees": -12.0,
		## Near `PlayerActor3D.READY_ELBOW_BEND` (17), which is already the
		## file's answer to "nobody stands with their arms locked straight".
		"elbow_degrees": 24.0,
		## The same near-upright the block's read carries, and for the same
		## reason: a body that is not leaning anywhere.
		"torso_radians": -0.06,
	}


## How close to the net a body has to be to be standing *at* it, in metres.
##
## A blocker's stance is taken within about a metre of the tape. Past that they
## are a defender again and the crouch is the right pose, which is why this is a
## band rather than a side.
const NET_BAND_METERS: float = 1.6


## Which stance this voli should be holding.
##
## Position rather than rotation, deliberately: playback knows where a body is
## standing and does not know which slot it is rotated into, and for this
## question the position is the better instrument anyway. A voli at the net *is*
## a front-row voli, and one who has dropped off it has stopped being one for as
## long as they are back there.
##
## The order is the precedence, and the first rule is the one that outranks the
## other two: being at the net with the ball on the far side of it is a job, and
## it beats the general-purpose crouch that was previously the only answer.
## **Poised begins at the toss, and before it nobody is poised.** Reported as the
## ready stance reading unbalanced, with the volis up on their toes -- and the
## side view says why: `defending` rakes the shin about 36 degrees forward, so the
## foot is not under the body and the weight line falls behind it. That is a real
## posture, but it is the instant before a movement rather than a thing a body
## holds, and holding it through a server's whole routine is what reads as a
## permanent flinch.
##
## `ball_is_live` is false only before the server tosses. It is not a new
## threshold: `ServeBiomechanics.TOSS_START` is where the toss already begins,
## and the toss is the first moment the ball can move and therefore the first
## thing a passer has to react to. The stance a body wears until then is
## `watching` -- which exists, is authored for "a voli watching a ball that is not
## theirs", and before the toss the ball is nobody's. Authoring a fourth set of
## angles for it would be inventing what this file already says it will not.
static func choose(
	at_the_net: bool, plays_the_ball_next: bool, ball_is_live: bool = true
) -> String:
	if not ball_is_live:
		return "watching"
	if at_the_net and not plays_the_ball_next:
		return "blocking"
	if plays_the_ball_next:
		return "defending"
	return "watching"


## Whether this stance turns the body to the net rather than to the ball.
##
## **The thing that outranks "face the ball".** Reported as the middle turning
## around entirely to watch the play, and it was: `_watch_the_ball` aimed every
## body on the court at the ball's sampled position, every frame, with nothing
## above it. The rule that a blocker never turns their back on the net already
## existed in `set_pose`, but only for the one voli playback had chosen to draw
## as the contact -- so a middle waiting at the tape, who is by definition not
## that voli, span to face a ball behind them.
##
## The head is not included in this and must not be. `look_toward` clamps to
## `HEAD_YAW_LIMIT_DEGREES` off the torso, so a blocker facing the net still
## tracks the ball over their shoulder and simply loses it when it goes too far
## behind -- which is exactly what a middle at the net does, and is why the neck
## having its own limit is what makes this rule affordable.
static func faces_the_net(stance_name: String) -> bool:
	return stance_name == "blocking"


## The joint set for a named stance, defaulting to the crouch every body used to
## wear -- so a caller that names nothing gets exactly what it had before.
static func joints(stance_name: String) -> Dictionary:
	match stance_name:
		"blocking":
			return blocking()
		"watching":
			return watching()
	return defending()
