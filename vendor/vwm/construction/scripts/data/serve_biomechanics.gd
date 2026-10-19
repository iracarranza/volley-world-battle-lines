class_name ServeBiomechanics
extends RefCounted

## A serve as a whole action, from the toss to the step into the court.
##
## What it replaces was two lines: one shoulder angle ramping to full extension
## and one elbow opening under it, both saturating at `-0.20` and then holding
## for the entire outgoing flight. Read on the sheet that is a server who cocks,
## swings, and then stands frozen with their arm above their head while the ball
## crosses the net -- no follow-through, no weight transfer, no toss arm coming
## down, and no legs at all. It is the same defect the spike and the block each
## had, and it is worth naming once more: **a contact drawn only up to the ball
## is half an action**, and the missing half is the half that tells a viewer what
## just happened.
##
## ## What a serve actually is
##
## Stand, toss, load, swing, contact, follow through, step in. The toss is the
## part servers practise most and the part a drawn serve most obviously lacks:
## the guide arm lifts the ball and *stays up* while the hitting arm goes back,
## and it comes down through the contact rather than before it.
##
## The load is a wind-up in three axes at once, and leaving any of them out is
## what makes an arm read as a hinge. The shoulder draws **back**, the elbow
## carries **out** away from the ribs, and the trunk arches and turns away from
## the target. The swing is those three unwinding in the reverse order they were
## wound: legs, trunk, shoulder, elbow -- the elbow last, which is where the whip
## comes from.
##
## The follow-through is not decoration. A serving arm does not stop overhead; it
## sweeps down and **across** to the opposite hip while the trunk keeps rotating
## and the weight arrives on the front foot. A server drawn without it looks like
## someone waving.
##
## ## The shoulder path is one continuous sweep
##
## Rotating an arm about x by `a` puts its direction at `(up, back) = (-cos a,
## -sin a)`, so **decreasing** `a` from zero carries a hanging arm backward, then
## up behind the head, then over the top and forward, then down in front:
##
##       0   hanging
##     -90   straight back, horizontal
##    -160   cocked: up and behind the head
##    -190   contact: overhead, a little in front
##    -250   forward and still high
##    -300   forward and below the shoulder
##    -352   hanging again, a shade in front
##
## Every stage below moves along that one line in one direction, which is why the
## arm never doubles back through the body to reach the next pose. Ending at -352
## rather than +8 is the whole trick: the two are the same arm and only one of
## them is reachable without unwinding the entire swing backwards.

## Visual vocabulary semantics
##
## Generic clean overhead serve chain: settled preparation, toss, load, committed
## contact, cross-body follow-through, and recovery step. Style-specific serve
## families layer onto this base; this file supplies continuity and force rhythm,
## not the volleyball result of the serve.
##
## ## Phase convention
##
## Signed, contact at 0, matching `SpikeBiomechanics` and `BlockBiomechanics`:
##
##   -1.0  standing behind the line, ball in both hands
##    0.0  the hand is on the ball
##   +1.0  recovered, stepping onto the court
##
## Pure and deterministic, for the same reason as the other pose modules: a
## function of phase alone is one the suite can check without a scene.

## Where each stage begins on the signed timeline.
##
## The toss occupies most of the wind-up because that is where the time actually
## goes -- a served ball hangs -- and the swing is brief, which is why a serve
## looks sudden even though the action is not.
const TOSS_START: float = -0.86
const TOSS_END: float = -0.58
const COCK_END: float = -0.22
const FOLLOW_END: float = 0.42
const RECOVER_END: float = 0.86
const STRIKE_START: float = -0.34
const ELBOW_RELEASE_START: float = -0.22
const SHOULDER_CONTACT_VELOCITY: float = -230.0
const ELBOW_CONTACT_VELOCITY: float = -250.0

## The shoulder, along the sweep described above.
const SHOULDER_REST_DEGREES: float = 8.0
const SHOULDER_COCK_DEGREES: float = -132.0
const SHOULDER_CONTACT_DEGREES: float = -202.0
const SHOULDER_FOLLOW_DEGREES: float = -292.0
## Not `SHOULDER_REST_DEGREES`. Same arm, reached forwards instead of by
## unwinding the swing -- see the note on the sweep above.
const SHOULDER_RECOVER_DEGREES: float = -352.0

## How far the elbow is carried away from the ribs, as a roll.
##
## The axis the spike went three revisions without. A serving arm cocked in one
## plane is a hinge; what makes it read as an arm is that the elbow is out to the
## side as well as behind, and that it comes back in across the body on the
## follow-through -- which is why the last value is negative and not zero.
const ABDUCT_COCK_DEGREES: float = 34.0
const ABDUCT_CONTACT_DEGREES: float = 12.0
const ABDUCT_FOLLOW_DEGREES: float = -26.0

## The elbow. Folded to cock, thrown open through the ball, and folding again as
## the arm comes down -- an arm that stays locked through the follow-through
## reads as a bowling action.
const ELBOW_COCK_DEGREES: float = 88.0
const ELBOW_CONTACT_DEGREES: float = 8.0
const ELBOW_FOLLOW_DEGREES: float = 44.0
const ELBOW_REST_DEGREES: float = 17.0

## The toss arm. Up in front at the top of the toss -- 150 puts the hand above
## the head and slightly ahead of it, which is where a ball has to leave from --
## and it stays there while the hitting arm loads.
const GUIDE_READY_DEGREES: float = 24.0
const GUIDE_TOSS_DEGREES: float = 150.0
const GUIDE_DROP_DEGREES: float = 30.0
## A toss with a bent elbow is a bad toss, and this is the one place in the file
## where a straight arm is the coaching point rather than a convenience.
const GUIDE_ELBOW_TOSS_DEGREES: float = 6.0
const GUIDE_ELBOW_REST_DEGREES: float = 20.0

## Trunk pitch, in radians, negative forward on this rig. Arched back over the
## loaded leg, driven through upright, and finishing folded forward over the
## front foot.
const TORSO_READY_RADIANS: float = -0.08
const TORSO_ARCH_RADIANS: float = 0.17
const TORSO_CONTACT_RADIANS: float = -0.10
const TORSO_FOLLOW_RADIANS: float = -0.26

## Trunk twist, in degrees, signed by hitting hand. The shoulders turn away from
## the target to load and keep turning through it afterwards -- a serve that ends
## square to the net is one played entirely with the arm.
const TWIST_COCK_DEGREES: float = 26.0
const TWIST_FOLLOW_DEGREES: float = -20.0

## The legs. Weight back on the loaded foot, then a step onto the front one --
## the hips swap which of them is forward, which is the whole of a weight
## transfer as far as a drawn figure is concerned.
const HIP_LOAD_LEAD_DEGREES: float = 14.0
const HIP_LOAD_TRAIL_DEGREES: float = -18.0
const HIP_STEP_LEAD_DEGREES: float = 32.0
const HIP_STEP_TRAIL_DEGREES: float = -26.0
const KNEE_READY_DEGREES: float = -14.0
const KNEE_LOAD_DEGREES: float = -34.0
const KNEE_DRIVE_DEGREES: float = -8.0
const KNEE_STEP_DEGREES: float = -22.0


## Eased 0-1 progress through a window, clamped outside it.
##
## Its own copy of the same easing `SpikeBiomechanics` and `BlockBiomechanics`
## use. The three modules share a convention, not a dependency.
static func window(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	return smoothstep(from_phase, to_phase, phase)


static func travel(
	phase: float,
	from_phase: float,
	to_phase: float,
	from_value: float,
	to_value: float,
	from_velocity: float,
	to_velocity: float,
) -> float:
	if phase <= from_phase:
		return from_value
	if phase >= to_phase:
		return to_value
	var span := maxf(to_phase - from_phase, 0.0001)
	var t := clampf((phase - from_phase) / span, 0.0, 1.0)
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * from_value \
		+ (t3 - 2.0 * t2 + t) * from_velocity * span \
		+ (-2.0 * t3 + 3.0 * t2) * to_value \
		+ (t3 - t2) * to_velocity * span


## Every joint of a serve at one instant.
##
## `hand` is +1 for a right-hander and -1 for a left-hander, and multiplies only
## the quantities that genuinely mirror: the roll of the hitting arm and the
## twist of the trunk. The shoulder sweep and the elbow do not mirror -- both
## arms of both handednesses swing through the same plane.
static func resolve(
	phase: float,
	hand: float = 1.0,
	action_power: float = 0.0,
) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var power_boost := smoothstep(0.62, 0.96, clampf(action_power, 0.0, 1.0))
	var toss := window(p, TOSS_START, TOSS_END)
	var cock := window(p, TOSS_END - 0.06, COCK_END)
	## The shoulder begins before the elbow and both remain in motion through
	## contact. Shared Hermite endpoint velocities prevent contact from becoming
	## a stop followed by a separately eased follow-through.
	var swing := window(p, STRIKE_START, 0.0)
	var follow := window(p, 0.0, FOLLOW_END)
	var recover := window(p, FOLLOW_END, RECOVER_END)

	var shoulder := lerpf(SHOULDER_REST_DEGREES, SHOULDER_COCK_DEGREES, cock)
	if p >= STRIKE_START and p <= 0.0:
		shoulder = travel(
			p, STRIKE_START, 0.0,
			SHOULDER_COCK_DEGREES, SHOULDER_CONTACT_DEGREES,
			0.0, SHOULDER_CONTACT_VELOCITY,
		)
	elif p > 0.0:
		shoulder = travel(
			p, 0.0, FOLLOW_END,
			SHOULDER_CONTACT_DEGREES, SHOULDER_FOLLOW_DEGREES,
			SHOULDER_CONTACT_VELOCITY, 0.0,
		)
	shoulder = lerpf(shoulder, SHOULDER_RECOVER_DEGREES, recover)

	var abduct := lerpf(6.0, ABDUCT_COCK_DEGREES, cock)
	abduct = lerpf(abduct, ABDUCT_CONTACT_DEGREES, swing)
	abduct = lerpf(abduct, ABDUCT_FOLLOW_DEGREES, follow)
	abduct = lerpf(abduct, 0.0, recover)

	var elbow := lerpf(ELBOW_REST_DEGREES, ELBOW_COCK_DEGREES, cock)
	if p >= ELBOW_RELEASE_START and p <= 0.0:
		elbow = travel(
			p, ELBOW_RELEASE_START, 0.0,
			ELBOW_COCK_DEGREES, ELBOW_CONTACT_DEGREES,
			0.0, ELBOW_CONTACT_VELOCITY,
		)
	elif p > 0.0:
		elbow = travel(
			p, 0.0, FOLLOW_END,
			ELBOW_CONTACT_DEGREES, ELBOW_FOLLOW_DEGREES,
			ELBOW_CONTACT_VELOCITY, 0.0,
		)
	elbow = lerpf(elbow, ELBOW_REST_DEGREES, recover)

	var internal_rotation := lerpf(0.0, -20.0 * hand, cock)
	if p >= STRIKE_START and p <= 0.0:
		internal_rotation = travel(
			p, STRIKE_START, 0.0,
			-20.0 * hand, 12.0 * hand, 0.0, 90.0 * hand,
		)
	elif p > 0.0:
		internal_rotation = travel(
			p, 0.0, FOLLOW_END,
			12.0 * hand, 30.0 * hand, 90.0 * hand, 0.0,
		)
	internal_rotation = lerpf(internal_rotation, 0.0, recover)

	## The toss arm holds up until the ball is nearly struck, then comes down.
	## Dropping it on the cock -- which is what a single ramp would do -- draws a
	## server who has already put the tossing hand away before the ball is hit.
	var guide_drop := window(p, -0.16, FOLLOW_END * 0.7)
	var guide := lerpf(GUIDE_READY_DEGREES, GUIDE_TOSS_DEGREES, toss)
	guide = lerpf(guide, GUIDE_DROP_DEGREES, guide_drop)
	guide = lerpf(guide, GUIDE_READY_DEGREES, recover)
	var guide_elbow := lerpf(GUIDE_ELBOW_REST_DEGREES, GUIDE_ELBOW_TOSS_DEGREES, toss)
	guide_elbow = lerpf(guide_elbow, GUIDE_ELBOW_REST_DEGREES, guide_drop)

	## The trunk arches *while* the arm cocks and unwinds a shade before it, which
	## is the ordering that puts the whip in the arm rather than in the back.
	var arch := window(p, TOSS_END, COCK_END + 0.04)
	var uncoil := window(p, COCK_END + 0.02, -0.04)
	var torso := lerpf(TORSO_READY_RADIANS, TORSO_ARCH_RADIANS, arch)
	torso = lerpf(torso, TORSO_CONTACT_RADIANS, uncoil)
	torso = lerpf(torso, TORSO_FOLLOW_RADIANS, follow)
	torso = lerpf(torso, TORSO_READY_RADIANS, recover)

	var twist := lerpf(0.0, TWIST_COCK_DEGREES, arch)
	twist = lerpf(twist, 0.0, uncoil)
	twist = lerpf(twist, TWIST_FOLLOW_DEGREES, follow)
	twist = lerpf(twist, 0.0, recover)

	var lead_hip := lerpf(6.0, HIP_LOAD_LEAD_DEGREES, arch)
	lead_hip = lerpf(lead_hip, HIP_STEP_LEAD_DEGREES, follow)
	lead_hip = lerpf(lead_hip, 8.0, recover)
	var trail_hip := lerpf(-6.0, HIP_LOAD_TRAIL_DEGREES, arch)
	trail_hip = lerpf(trail_hip, HIP_STEP_TRAIL_DEGREES, follow)
	trail_hip = lerpf(trail_hip, -8.0, recover)

	var knee := lerpf(KNEE_READY_DEGREES, KNEE_LOAD_DEGREES, arch)
	knee = lerpf(knee, KNEE_DRIVE_DEGREES, uncoil)
	knee = lerpf(knee, KNEE_STEP_DEGREES, follow)
	knee = lerpf(knee, KNEE_READY_DEGREES, recover)

	## A high-power serve loads as a deeper bow and pays that load off with a
	## longer extension. The authored stage timing remains identical, so scaling
	## the silhouette cannot make the hand arrive late to the ball.
	var curl_weight := arch * (1.0 - uncoil)
	var extension_weight := maxf(swing, follow)
	shoulder -= 22.0 * power_boost * extension_weight
	elbow = lerpf(elbow, 0.0, power_boost * swing)
	torso += 0.18 * power_boost * curl_weight
	torso -= 0.14 * power_boost * maxf(uncoil, follow)
	twist += 15.0 * power_boost * curl_weight
	twist -= 11.0 * power_boost * follow
	knee = lerpf(knee, KNEE_LOAD_DEGREES - 8.0, power_boost * curl_weight)
	lead_hip += 10.0 * power_boost * extension_weight
	trail_hip -= 8.0 * power_boost * extension_weight

	return {
		"striking_shoulder_degrees": shoulder,
		"striking_abduction_degrees": abduct * hand,
		"striking_internal_rotation_degrees": internal_rotation,
		"striking_elbow_degrees": elbow,
		"guide_shoulder_degrees": guide,
		"guide_elbow_degrees": guide_elbow,
		"torso_pitch_radians": torso,
		"torso_twist_degrees": twist * hand,
		"lead_hip_degrees": lead_hip,
		"trail_hip_degrees": trail_hip,
		"knee_degrees": knee,
		"power_boost": power_boost,
	}
