class_name SetBiomechanics
extends RefCounted

## A set as a push from the floor, not as a shape made with the hands.
##
## The inline version had the right idea and half the timeline: shoulders opening
## from 96 to 132 and elbows from 98 to 22 across a `release` that reached 1.0
## **at contact** and stayed there. So the preparation was drawn and the delivery
## was not -- past phase 0 the setter held the finish position for the whole
## outgoing flight, hands stopped where the ball had been. And the legs were
## never touched at all, which left whatever the gait had last written on them:
## a setter standing straight-legged while their arms did the work.
##
## ## What a set actually is
##
## A setter does not push a ball with their arms. They get under it, load the
## legs, and *extend* -- ankles, knees, hips, shoulders, elbows, wrists, in that
## order and ending with the fingers. The arms are the last and smallest part of
## it. What the eye reads as a good set is the whole body finishing tall and
## travelling toward the target, and what it reads as a bad one is arms alone.
##
## Three things therefore have to survive past phase 0, and none of them did:
##
##   * the elbows keep opening, finishing near straight
##   * the legs keep extending, and the body rises with them
##   * the hands finish high and *out*, toward where the ball went
##
## ## The hands are together, because the ball is between them
##
## Kept from the version this replaces, along with the sign it took two attempts
## to get right: rolling an arm about +Z carries its hand toward +x, so the left
## arm takes `+flare` to converge and the right `-flare`. Reversed, a set is drawn
## as a player holding nothing. The forearms converge for the preparation *and*
## the push, and only the recovery opens them, once the ball has gone.
##
## ## Phase convention
##
## Signed, contact at 0, matching the other pose modules:
##
##   -1.0  moving to the ball, hands not yet up
##    0.0  the ball is in the hands
##   +1.0  recovered, watching the attack
##
## Pure and deterministic, and testable without a scene.

## Visual vocabulary semantics
##
## - standing/front set: clean, settled overhead second contact with full-body
##   extension toward the target.
## - moving/adjusting set: the same hand and release chain layered over a live
##   final step by `ContactArrivalBiomechanics`.
## - jump set: controlled airborne contact followed by landing and recovery.
## - back set: controlled overhead release behind the setter, preserving the
##   front-facing preparation before the late directional reveal.
## - underhand set: emergency low-ball second contact, not a generic overhead
##   reaching-set substitute.
##
## There is no separate reaching-overhead-set family here yet; comments should
## not imply a vocabulary the pose architecture cannot currently express.

## Where each stage begins on the signed timeline.
##
## A setter is under the ball early -- the hands are up long before the contact,
## which is most of what separates a setter from someone catching a ball -- so
## the gather occupies the bulk of the approach and the push is short.
const GATHER_START: float = -0.72
const GATHER_END: float = -0.16
const PUSH_END: float = 0.16
const EXTEND_END: float = 0.40
const RECOVER_END: float = 0.88

## The shoulders. 96 at the gather puts the upper arms out and slightly forward
## with the hands at the forehead; the push carries them up and the extension
## finishes them above and in front, which is where a released set leaves the
## hands.
const SHOULDER_READY_DEGREES: float = 30.0
const SHOULDER_GATHER_DEGREES: float = 96.0
const SHOULDER_CONTACT_DEGREES: float = 124.0
const SHOULDER_EXTEND_DEGREES: float = 152.0

## The elbow is what tells a set from a block. Both put the hands above the head;
## only one keeps the arms bent. At 98 the forearms stand vertical beside the
## head, which is the shape a setter waits in, and opening toward 4 is the push
## itself -- the joint that does the work, rather than the shoulder swinging the
## whole arm through the ball.
const ELBOW_GATHER_DEGREES: float = 98.0
const ELBOW_CONTACT_DEGREES: float = 46.0
const ELBOW_EXTEND_DEGREES: float = 8.0
const ELBOW_REST_DEGREES: float = 17.0

## Hand convergence, in degrees of roll. Positive brings a hand toward the
## centreline -- see the note above about the sign.
const FLARE_GATHER_DEGREES: float = 21.0
const FLARE_CONTACT_DEGREES: float = 15.0
const FLARE_RECOVER_DEGREES: float = -20.0

## Trunk pitch, radians, negative forward. A setter gathers with a slight forward
## fold and finishes leaning *back* a little as the chest opens under the
## extension -- which is what stops the finish reading as a lunge at the ball.
const TORSO_GATHER_RADIANS: float = -0.12
const TORSO_EXTEND_RADIANS: float = 0.07
const TORSO_REST_RADIANS: float = -0.04

## How far the setter comes **off the floor** at the finish, in metres.
##
## Only the rise, and deliberately not the dip. The dip is already paid for: the
## knee folds to -46 in the gather and `_ground_the_feet` turns that fold into a
## body drop of about 0.10 m so the shoes stay on the ground. Adding a second
## explicit crouch on top would lower the body a second time and put the feet
## through the floor -- which is exactly the defect the dig had, and it is worth
## saying out loud that this module nearly repeated it.
##
## The rise is different in kind. A setter finishing a good ball comes up onto
## the toes and travels toward the target, so this genuinely is elevation and not
## a fold, and it is the one part of the vertical motion that has to be added
## rather than derived.
const EXTEND_RISE_METRES: float = 0.05

## The legs. Loaded under the ball, driven straight through the push, and the
## heels leaving the floor is what carries a good set forward -- drawn here as
## the knees passing through near-straight rather than stopping at the contact.
const KNEE_READY_DEGREES: float = -12.0
const KNEE_GATHER_DEGREES: float = -46.0
const KNEE_EXTEND_DEGREES: float = -4.0
## The feet split slightly, right foot forward, which is the stance a setter
## takes so the push travels toward the antenna rather than straight up.
const HIP_SPLIT_DEGREES: float = 11.0


## Eased 0-1 progress through a window, clamped outside it.
##
## Its own copy of the easing the other pose modules use, by the same reasoning:
## a shared convention rather than a shared dependency.
static func window(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	return smoothstep(from_phase, to_phase, phase)


## The three ways a second ball leaves the hands, and what separates them.
##
## `standing` is the push this module was written for: the legs load, drive, and
## the heels come off the floor. The other two are not variations of it.
##
## `jump` takes the floor away. A setter in the air cannot push off anything, so
## the legs stop being the engine and become ballast -- they fold *under* the
## body and stay folded, the split closes because there is no stance to take,
## and every newton the ball receives has to come from the shoulders and the
## hands. That is why the arm travel is larger here and the leg travel is
## nearly nothing: the same ball, out of a body with one fewer joint working.
##
## `underhand` is the ball that never got to hand height. The forearms take it,
## the arms stay long and low and swing as one piece from the shoulders, and the
## finish is a *point*: the whole body extends up behind the ball because the
## only way to put a low ball high is to stand up into it. Its signal already
## exists -- `_jump_set_decision` publishes `under the hands` as the reason a
## setter stayed down, 136 times in 1,342 sets.
const POSTURE_STANDING := &"standing"
const POSTURE_JUMP := &"jump"
const POSTURE_UNDERHAND := &"underhand"

## How high the body actually goes on a jump set, in metres before body scaling.
##
## A set jump is not a spike jump. A setter leaves the floor to meet the ball
## sooner and flatter, not to get as high as they can -- so this is well under
## `BlockJumpModel`'s leaps and is deliberately not derived from them.
const JUMP_RISE_METRES: float = 0.34
## The knees fold and stay folded. There is no drive in the air, so the legs
## hold one shape from take-off to landing rather than passing through it.
const JUMP_TUCK_KNEE_DEGREES: float = -58.0
## Everything the legs stop contributing has to come from somewhere. A jump
## setter's hands travel further and finish higher for the same ball.
const JUMP_SHOULDER_BONUS_DEGREES: float = 14.0

## The underhand set. Long arms, low contact, and a finish that goes straight up.
const UNDERHAND_SHOULDER_READY_DEGREES: float = -46.0
const UNDERHAND_SHOULDER_CONTACT_DEGREES: float = -14.0
## **The point.** The follow-through carries past the ball and finishes with the
## platform aimed at the ceiling, which is the whole read of an underhand set:
## a bump goes where the arms end up, so a ball meant to go up needs arms that
## end up pointing there.
const UNDERHAND_SHOULDER_FINISH_DEGREES: float = 62.0
## Straight. A platform is two forearms locked into one surface, and a bent
## elbow is the thing that makes a bump go sideways.
const UNDERHAND_ELBOW_DEGREES: float = 3.0
## Deeper than a standing set and it stays deep longer: the legs are what lift a
## low ball, and they extend *through* the contact rather than before it.
const UNDERHAND_KNEE_LOAD_DEGREES: float = -62.0
const UNDERHAND_RISE_METRES: float = 0.17

## ## Setting backwards
##
## A back set is the same three postures done to a ball the setter is not facing,
## and it was drawn identically to a front set because playback faces the rig at
## wherever the ball went -- so every setter on this branch has been squaring up
## to the target and pushing, including the ones delivering behind their own
## head. That is the one second-contact shape a viewer can name on sight, and it
## was the one shape the model could not make.
##
## It is an overlay rather than a fourth posture, because it is not a fourth
## action: a jumping back set and a standing back set differ exactly as a jumping
## front set and a standing one do. What changes in all three is the same three
## things, and they are the three a spectator actually reads:
##
##   * the trunk **arches**, chest to the ceiling, rather than travelling forward
##   * the hands carry back **over** the head instead of finishing out in front
##   * the stance stops driving forward -- weight goes onto the back foot, so the
##     split closes and reverses rather than pushing through
##
## Applied on the delivery window and released on the recovery, so a setter
## arches into the ball and comes back down out of it rather than standing bent
## backwards for the rest of the rally.
const BACK_SET_SHOULDER_CARRY_DEGREES: float = 26.0
const BACK_SET_TORSO_ARCH_RADIANS: float = 0.22
## Negative on purpose. A front set finishes over the lead foot; a back set
## finishes over the trailing one, and a scale that only shrank the split would
## draw the difference as "less of a stance" rather than as the other stance.
const BACK_SET_HIP_SPLIT_SCALE: float = -0.40


## Every joint of a set at one instant.
##
## `hand` is +1 for a right-hander and -1 for a left-hander and mirrors only the
## foot split. A set is a symmetric action; nothing else in it has a handedness.
##
## `posture` selects between the three actions above. It defaults to standing so
## every existing caller is unchanged, and the simulator already publishes the
## value on the SET event as `set_posture`.
##
## `back_set` is orthogonal to `posture` and is applied to all three -- see the
## note above `BACK_SET_SHOULDER_CARRY_DEGREES`.
static func resolve(
	phase: float,
	hand: float = 1.0,
	posture: StringName = POSTURE_STANDING,
	back_set: bool = false,
) -> Dictionary:
	if posture == POSTURE_UNDERHAND:
		return _arch(_underhand(phase, hand), _arch_weight(phase), back_set)
	var p := clampf(phase, -1.0, 1.0)
	var gather := window(p, GATHER_START, GATHER_END)
	## Runs *through* contact rather than up to it. This is the correction the
	## whole module exists for: a push that finishes at phase 0 is a push the
	## viewer never sees, because the ball leaves at the moment it completes.
	var push := window(p, GATHER_END, PUSH_END)
	var extend := window(p, 0.0, EXTEND_END)
	var recover := window(p, EXTEND_END, RECOVER_END)

	var shoulder := lerpf(SHOULDER_READY_DEGREES, SHOULDER_GATHER_DEGREES, gather)
	shoulder = lerpf(shoulder, SHOULDER_CONTACT_DEGREES, push)
	shoulder = lerpf(shoulder, SHOULDER_EXTEND_DEGREES, extend)
	shoulder = lerpf(shoulder, SHOULDER_READY_DEGREES, recover)

	var elbow := lerpf(ELBOW_REST_DEGREES, ELBOW_GATHER_DEGREES, gather)
	elbow = lerpf(elbow, ELBOW_CONTACT_DEGREES, push)
	elbow = lerpf(elbow, ELBOW_EXTEND_DEGREES, extend)
	elbow = lerpf(elbow, ELBOW_REST_DEGREES, recover)

	var flare := lerpf(4.0, FLARE_GATHER_DEGREES, gather)
	flare = lerpf(flare, FLARE_CONTACT_DEGREES, push)
	## Opening the hands is the *recovery*, not the extension. Keyed off the tail
	## of the action rather than the tail of the push, which -- once the push
	## reached past contact -- would have spread them while the ball was still in
	## them.
	flare = lerpf(flare, FLARE_RECOVER_DEGREES, recover)

	var torso := lerpf(TORSO_REST_RADIANS, TORSO_GATHER_RADIANS, gather)
	torso = lerpf(torso, TORSO_EXTEND_RADIANS, extend)
	torso = lerpf(torso, TORSO_REST_RADIANS, recover)

	## The legs lead. The drive starts before the hands move and finishes after
	## them, which is the ordering that makes a set look pushed rather than
	## thrown -- and is why `drive` opens earlier than `push` and closes later.
	var drive := window(p, GATHER_END - 0.06, EXTEND_END)
	var knee := lerpf(KNEE_READY_DEGREES, KNEE_GATHER_DEGREES, gather)
	knee = lerpf(knee, KNEE_EXTEND_DEGREES, drive)
	knee = lerpf(knee, KNEE_READY_DEGREES, recover)

	var rise := lerpf(0.0, EXTEND_RISE_METRES, drive)
	rise = lerpf(rise, 0.0, recover)

	## Off the floor, the legs stop working and the arms take over.
	##
	## Applied as a *replacement* for the leg terms rather than a blend with
	## them: a folded leg that is still tracking `drive` is a setter pedalling in
	## mid-air, which is what happens if this is written as a lerp toward a tuck.
	if posture == POSTURE_JUMP:
		var airborne := window(p, GATHER_END - 0.10, EXTEND_END + 0.18)
		var leave := window(p, GATHER_END - 0.10, 0.0)
		knee = lerpf(KNEE_GATHER_DEGREES, JUMP_TUCK_KNEE_DEGREES, leave)
		## A parabola, not a ramp: up to the contact and down out of it, so the
		## setter is at their peak when the ball leaves and is already coming
		## down through the follow-through.
		rise = JUMP_RISE_METRES * sin(clampf(airborne, 0.0, 1.0) * PI)
		shoulder += JUMP_SHOULDER_BONUS_DEGREES * push
		return _arch({
			"shoulder_degrees": shoulder,
			"elbow_degrees": elbow,
			"flare_degrees": flare,
			"torso_pitch_radians": torso,
			"knee_degrees": knee,
			## No split. A stance is something you take on the floor; in the air
			## the feet come together under the body.
			"hip_split_degrees": lerpf(HIP_SPLIT_DEGREES * hand, 0.0, leave),
			"rise_metres": rise,
			"posture": POSTURE_JUMP,
		}, _arch_weight(phase), back_set)
	return _arch({
		"shoulder_degrees": shoulder,
		"elbow_degrees": elbow,
		"flare_degrees": flare,
		"torso_pitch_radians": torso,
		"knee_degrees": knee,
		"hip_split_degrees": HIP_SPLIT_DEGREES * hand,
		"rise_metres": rise,
		"posture": POSTURE_STANDING,
	}, _arch_weight(phase), back_set)


## How much of the backwards arch is in effect at this instant.
##
## Complete **at contact** and released on the recovery.
##
## Keyed to the gather rather than to the push, which is the correction this
## comment exists for: opened on `GATHER_END..EXTEND_END` the arch stood at 0.20
## of itself on the frame the ball left the hands, so the pose a viewer actually
## sees was a fifth of the pose that was written. A setter arches to get *under*
## a ball they intend to send behind them -- the shape is finished before the
## contact, not built out of it.
static func _arch_weight(phase: float) -> float:
	var p := clampf(phase, -1.0, 1.0)
	return window(p, GATHER_START, 0.0) \
		* (1.0 - window(p, EXTEND_END, RECOVER_END))


## Bend a front set backwards.
##
## Written as a mutation of a finished solve rather than as a branch inside each
## one, because the alternative is three near-identical chains of lerps and this
## file already has three. `back_set` is always published, false included, so a
## consumer reading the key cannot silently get `null` from the postures that
## were never asked.
static func _arch(
	joints: Dictionary, weight: float, back_set: bool
) -> Dictionary:
	var applied := weight if back_set else 0.0
	joints["shoulder_degrees"] = float(joints.shoulder_degrees) \
		+ BACK_SET_SHOULDER_CARRY_DEGREES * applied
	joints["torso_pitch_radians"] = float(joints.torso_pitch_radians) \
		+ BACK_SET_TORSO_ARCH_RADIANS * applied
	joints["hip_split_degrees"] = float(joints.hip_split_degrees) \
		* lerpf(1.0, BACK_SET_HIP_SPLIT_SCALE, applied)
	joints["back_set"] = back_set
	return joints


## The ball that never got to hand height.
##
## Written as its own solve rather than as more windows inside the push, because
## it shares almost nothing with an overhead set: the arms start *below* the
## hips instead of above the head, the elbows never bend, and the finish is the
## expressive part rather than the recovery. Threading three postures through one
## chain of lerps is how a module ends up with joints that belong to no action.
static func _underhand(phase: float, hand: float) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var gather := window(p, GATHER_START, GATHER_END)
	var strike := window(p, GATHER_END, 0.0)
	## Past the ball. The follow-through is most of what this pose is for, so it
	## gets the widest window of the three phases.
	var finish := window(p, 0.0, EXTEND_END + 0.22)
	var recover := window(p, EXTEND_END + 0.22, RECOVER_END)

	var shoulder := lerpf(
		UNDERHAND_SHOULDER_READY_DEGREES,
		UNDERHAND_SHOULDER_READY_DEGREES - 8.0, gather
	)
	shoulder = lerpf(shoulder, UNDERHAND_SHOULDER_CONTACT_DEGREES, strike)
	shoulder = lerpf(shoulder, UNDERHAND_SHOULDER_FINISH_DEGREES, finish)
	shoulder = lerpf(shoulder, UNDERHAND_SHOULDER_READY_DEGREES, recover)

	## The legs lift the ball and they start before the arms, exactly as they do
	## in the standing push -- but they finish *later*, because the extension is
	## the thing that sends a low ball high.
	var drive := window(p, GATHER_END - 0.08, EXTEND_END + 0.14)
	var knee := lerpf(KNEE_READY_DEGREES, UNDERHAND_KNEE_LOAD_DEGREES, gather)
	knee = lerpf(knee, KNEE_EXTEND_DEGREES, drive)
	knee = lerpf(knee, KNEE_READY_DEGREES, recover)

	var rise := lerpf(0.0, UNDERHAND_RISE_METRES, drive)
	rise = lerpf(rise, 0.0, recover)

	## Folded over the ball at the gather and standing tall through the finish.
	var torso := lerpf(TORSO_REST_RADIANS, -0.26, gather)
	torso = lerpf(torso, 0.10, finish)
	torso = lerpf(torso, TORSO_REST_RADIANS, recover)

	return {
		"shoulder_degrees": shoulder,
		"elbow_degrees": UNDERHAND_ELBOW_DEGREES,
		## The arms are locked together into one surface, so there is no flare
		## until the platform breaks on the recovery.
		"flare_degrees": lerpf(0.0, FLARE_RECOVER_DEGREES, recover),
		"torso_pitch_radians": torso,
		"knee_degrees": knee,
		"hip_split_degrees": HIP_SPLIT_DEGREES * 0.5 * hand,
		"rise_metres": rise,
		"posture": POSTURE_UNDERHAND,
	}
