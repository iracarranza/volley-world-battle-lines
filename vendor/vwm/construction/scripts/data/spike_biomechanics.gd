class_name SpikeBiomechanics
extends RefCounted

const ApproachBiomechanics := preload("res://vendor/vwm/construction/scripts/data/approach_biomechanics.gd")

## A spike as a sequence of segments, not a single sweep.
##
## The attack pose used to interpolate one `swing` value: the shoulder rotated
## at a constant rate, the elbow opened at a constant rate, the legs held a fixed
## stride for the entire action and the torso held a fixed lean. Everything moved
## together and nothing moved first, which is what a windmill looks like and what
## a spike does not.
##
## What separates them is **proximal-to-distal sequencing**. A hitter drives from
## the floor and each segment peaks after the one inside it: knees extend, then
## the hips and trunk, then the shoulder, then the elbow, and the hand arrives
## last and fastest. Every segment is still travelling when the next one starts,
## so the body reads as a chain being cracked rather than a diagram rotating.
## That ordering is the whole of the visual difference, and it is why this is a
## table of staggered windows rather than a curve.
##
## Deliberately pure and deterministic: phase in, angles out, no state and no
## randomness. It is the only way pose work can be checked without eyes on a
## screen, and the suite does check it.
##
## ## Phase convention
##
## `phase` is signed and **contact is at 0**.
##
##   -1.0  the plant begins -- the hitter is still on the floor, arms behind
##    0.0  the hand meets the ball, at the top of the jump
##   +1.0  the landing has been absorbed
##
## The negative half is spent during the *set's* flight and the positive half
## during the attack's own, which is why playback needs a phase that spans two
## event windows rather than restarting in each. Before this, both halves ran
## 0 to 1 independently: the swing played out completely during the approach and
## then snapped back to fully cocked at the instant of contact and played again.

## Visual vocabulary semantics
##
## This is the clean, fully committed overhead attack base: plant and takeoff,
## high-elbow preparation, proximal-to-distal contact, follow-through, landing,
## and recovery. It assumes comfortable ideal striking geometry. Soft-shot and
## compromised/reaching families preserve this continuous chain and modify its
## late intention or body response rather than replacing the approach or launch.

## Where each phase of the spike begins, on the signed timeline above.
##
## Chosen against the real proportions of the action rather than spaced evenly.
## The plant and takeoff take most of the wind-up. The shoulder drive begins
## while the high elbow is still forming, then the elbow releases later. This
## overlap is quick without reducing the visible swing to a two-frame punch.
const PLANT_END: float = -0.62
const TAKEOFF_END: float = -0.40
const COCK_END: float = -0.22
const FOLLOW_END: float = 0.45

## How wide a slice around zero `phase_name` is willing to call the contact.
## Narrow on purpose: it is a label for the instant, not a phase with a duration.
const CONTACT_BAND: float = 0.04

## When the shoulder starts driving at the ball, and when the elbow follows.
##
## The shoulder starts before the named cock has finished and the elbow follows.
## The former -0.105/-0.09 windows compressed each into roughly two frames on
## the resolved takeoff clock. These wider windows publish a readable chain, and
## the Hermite contact velocity keeps that chain moving through phase zero.
const STRIKE_START: float = -0.32
const ELBOW_RELEASE_START: float = -0.20
const SHOULDER_CONTACT_VELOCITY: float = -260.0
const ELBOW_CONTACT_VELOCITY: float = 260.0
const ABDUCTION_CONTACT_VELOCITY: float = -42.0

## How high the guide arm reaches at the cock.
##
## 84 degrees is very nearly horizontal on this rig, and measured on the body it
## put the guide hand **0.10 m above the shoulder** -- out in front at chest
## height, where a hitter's non-hitting arm is doing nothing anybody can see.
## Reported as exactly that: the guide arm does not really do anything.
##
## The ball is above and in front. A guide arm that points at it has to be up
## there too, and the pull down from up there is what rotates the trunk. The
## value is chosen by where the hand lands rather than by what the angle sounds
## like; `tools/measure_spike_swing.gd` prints it.
const GUIDE_REACH_DEGREES: float = 132.0

## When the swing arm starts returning to a neutral hang.
##
## Well after `FOLLOW_END`, because the follow-through does not stop when the
## legs land. Set here rather than reusing `FOLLOW_END` so the two can be tuned
## apart -- they are different events happening to different limbs.
const ARM_RECOVER_START: float = FOLLOW_END

## Where the approach leaves both arms, which is where this model has to pick
## them up.
##
## **Taken from `ApproachBiomechanics` rather than restated.** It was restated,
## as +42, and the approach ends at -74: opposite signs for the same instant.
## `PlayerActor3D` hands off from the approach to this model at `PLANT_END`, so
## every spike in the game swung both arms back through the run-up and then
## snapped them 101 degrees forward to a neutral hang on the first frame of the
## plant, and lifted from there. Measured on the rig, the striking hand jumps
## 1.15 m across that one seam -- 18.7 m/s, the fastest the hand moves in the
## entire action, in the wrong direction, before the swing has started.
##
## That is the reported "the arm load just looks like the arm raising up rather
## than swinging up and forward": the load *was* being drawn, by the approach,
## and then discarded.
##
## Two numbers that must agree, so there is now one number. See
## `_test_spike_biomechanics_sequence`, which asserts the seam rather than
## asserting a value at phase -1 that playback never reaches.
const BACKSWING_DEGREES: float = ApproachBiomechanics.ARM_BACK_DEGREES
## And the elbow at the same instant, for the same reason.
const BACKSWING_ELBOW_DEGREES: float = ApproachBiomechanics.ARM_ELBOW_BACK_DEGREES

## The striking shoulder through the action. Negative carries the arm up and
## over: -180 is straight overhead, so -204 at contact is just forward of
## vertical, which is where a hitter actually meets the ball, and -252 is the
## arm continuing down across the body.
const SHOULDER_LIFT_DEGREES: float = -124.0
## The cock is a **high elbow**, not a raised arm.
##
## It was -152, which carries the upper arm to 62 degrees above horizontal --
## nearly overhead -- and with the elbow folded from there the forearm had nowhere
## to go but down and behind. Measured on the rig, that pair put the elbow 0.34 m
## above the shoulder and the hand 0.15 m above it and 0.31 m behind: the hand
## *below* its own elbow, hanging backward. A hitter never loads there.
##
## At -128 the elbow sits 0.25 m up and 0.29 m back -- pulled behind the shoulder
## line and above it, which is where the tension actually is -- and the forearm
## can then stand up out of it. The power comes from the shoulder pivoting forward
## and the forearm extending, so the load has to leave both of those with somewhere
## to travel.
const SHOULDER_COCK_DEGREES: float = -122.0
const SHOULDER_CONTACT_DEGREES: float = -204.0
const SHOULDER_FOLLOW_DEGREES: float = -252.0

## The elbow is what makes the arm a whip rather than a stick. It stays folded
## deep into the cock and opens *through* contact, one beat behind the shoulder.
##
## **Negative, and the sign was measured rather than reasoned.** The comment on
## `_set_elbow` says positive folds the forearm forward, and with the upper arm
## already tipped past vertical at the old cock that sent the hand backward and
## down instead. Sampling the rig's own node positions settles it: negative
## carries the hand forward and up out of the elbow, which is the direction a
## cocked arm actually folds.
##
## **A fold the head is not inside.** At -46 the forearm finished within a couple
## of degrees of vertical against a shoulder already up and back, so the two
## segments were near enough collinear to read as one straight thing. At -90 they
## made a chevron -- and the chevron folded the forearm *across the head*, which
## reads worse than a straight arm because the one segment that should be
## unmistakable is the one hidden behind a skull.
##
## -64 against a -122 shoulder puts the upper arm nearer horizontal and behind,
## and stands the forearm up out of it: measured, the elbow sits 0.26 m behind the
## shoulder and the hand another 0.23 m behind that and 0.47 m up, so the forearm
## is *above* the upper arm and clear of the head rather than crossing it. Still a
## real bend -- 64 degrees is a bend anyone would draw -- and still folding
## forward-and-up out of the joint, which was the previous correction and is not
## being undone.
const ELBOW_COCK_DEGREES: float = -64.0

## **The arm is not in one plane, and that was the whole thing missing.**
##
## Every angle above rotates about x, so the entire swing happened in the sagittal
## plane -- elbow straight back, forearm straight up, hand straight over. A hitter
## does not load like that. The elbow goes back *and out*, and the forearm rises
## up *and out* of it, which is what puts the hand where a hitter can see it and
## what makes the shape read as a bow rather than as a hinge.
##
## Abduction is that second axis: a roll on the shoulder, outward at the cock and
## unwound through the ball. It is deliberately not zero at contact either -- the
## arm comes over the top rather than through the centreline, and a hitter's
## contact is still a little outside their own shoulder.
##
## Signed by handedness like the trunk twist, so a left-hander loads outward on
## their own side rather than across their body.
const SHOULDER_ABDUCT_COCK_DEGREES: float = 36.0
const SHOULDER_ABDUCT_CONTACT_DEGREES: float = 11.0
const ELBOW_CONTACT_DEGREES: float = 7.0
const ELBOW_FOLLOW_DEGREES: float = 58.0

## The bow. The trunk hyperextends during the cock and snaps forward through
## contact, and this is where most of a spike's power actually comes from.
## Negative is a forward lean on this rig, so the positive value is the arch.
const TORSO_PLANT_RADIANS: float = -0.26
## Where the trunk gets back to as the hitter leaves the floor. Without this the
## plant's forward lean was held all the way to the arch, so the one frame where
## a hitter should look tallest was the frame they looked most like they were
## falling over.
const TORSO_TAKEOFF_RADIANS: float = -0.04
const TORSO_ARCH_RADIANS: float = 0.21
const TORSO_CONTACT_RADIANS: float = -0.12
## Deep enough to read as the trunk finishing the swing, shallow enough not to
## read as a bow. At -0.44 the landing frame was folded almost double.
const TORSO_FOLLOW_RADIANS: float = -0.29

## Hip-shoulder separation, in degrees of trunk twist. The shoulders rotate away
## from the target during the cock and unwind through contact; without it the
## whole upper body is one rigid plank and the arm appears to be doing all the
## work by itself.
const TORSO_TWIST_DEGREES: float = 19.0
const TORSO_UNWIND_DEGREES: float = -13.0

## Knee flexion, negative because every knee on this rig folds backward.
## A loaded athletic stance, not a squat. At -78 with the hips also forward the
## shin came through the front of the thigh and the plant read as tangled.
const KNEE_LOAD_DEGREES: float = -58.0
const KNEE_EXTENDED_DEGREES: float = -6.0
const KNEE_TUCK_DEGREES: float = -52.0
const KNEE_LANDING_DEGREES: float = -58.0


## Eased 0-1 progress through a window, clamped outside it.
##
## Smoothstep rather than linear because a segment accelerates into its own
## motion and decelerates out of it; linear ramps are what make interpolated
## joints read as machinery. A zero-width window returns 1.0 rather than
## dividing by it.
static func window(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	return smoothstep(from_phase, to_phase, phase)


## A window that **arrives at speed**: fastest at its end.
##
## `window` eases out, which is right for a segment settling into a position and
## exactly wrong for the one that hits the ball. Measured on the rig, the
## striking hand moved 5.0 m/s a tenth of a phase before contact, **1.0 m/s at
## contact** and 0.5 m/s just after -- the slowest part of the whole action was
## the instant the ball was struck, and the fastest was the backswing. That is
## the reported "the contact is still not snappy/explosive enough", and it was
## not a matter of magnitude: every angle was already correct at contact, and the
## arm had simply stopped by the time it got there.
##
## The cause was a correction that was right about pose and wrong about velocity.
## The shoulder's drive was deliberately ended at -0.03 and the elbow's at -0.02
## so that "a hitter is at full extension when the hand meets the ball" -- true,
## but a smoothstep reaches its end with zero slope, so full extension arrived
## *and stopped* three hundredths early. A hitter reaches full extension **at**
## the ball, travelling fastest, and decelerates afterwards.
static func accelerate(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	var t := clampf(inverse_lerp(from_phase, to_phase, phase), 0.0, 1.0)
	return t * t


## And a window that **leaves at speed**: fastest at its start.
##
## The other half of the same problem. With the follow-through easing *in* from
## contact, the frames after the ball were as still as the frames before it, so
## even a correctly accelerating swing would have arrived and frozen. An arm
## carries through the ball and slows down over the follow-through, which is this
## curve and not the other one.
static func decelerate(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	var t := clampf(inverse_lerp(from_phase, to_phase, phase), 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


## Cubic joint travel with velocities stated per unit of signed pose phase.
## Contact is the shared boundary of two Hermite segments, so using the same
## velocity on both sides makes phase zero part of the swing rather than an
## accelerated endpoint followed by a separately eased follow-through.
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


## Canonical jump envelope. The existing three-step approach owns everything
## before `PLANT_END`, so elevation is exactly zero until the bilateral plant.
## The loaded legs then launch the actor into contact and the positive half
## returns them to the floor without an independent gallery sine wave.
static func elevation_at(phase: float) -> float:
	var p := clampf(phase, -1.0, 1.0)
	if p < PLANT_END:
		return 0.0
	if p <= 0.0:
		return smoothstep(PLANT_END, 0.0, p)
	return 1.0 - smoothstep(0.0, 0.72, p)


## Every joint the attack pose needs, for one instant of the swing.
##
## `handedness_sign` is +1 for a right-handed hitter and -1 for a left-handed
## one, and only the twist and the follow-through's cross-body roll read it --
## the sagittal angles are the same swing either way.
static func resolve(
	phase: float,
	handedness_sign: float,
	action_power: float = 0.0,
) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var hand := 1.0 if handedness_sign >= 0.0 else -1.0
	## This is presentation intensity, not a second power model. Playback passes
	## the resolved action's 0-1 evidence; ordinary contacts remain byte-for-byte
	## on the authored pose and only the top band gains the exaggerated bow/snap.
	var power_boost := smoothstep(0.62, 0.96, clampf(action_power, 0.0, 1.0))

	## Proximal first. The legs are already extending while the arms are still
	## behind the body, which is what actually lifts the hitter.
	var load := window(p, -1.0, PLANT_END)
	var extend := window(p, PLANT_END, TAKEOFF_END)
	var tuck := window(p, TAKEOFF_END, COCK_END)
	## Then the trunk, then the shoulder, then the elbow -- each starting before
	## the previous one has finished and peaking after it.
	var arch := window(p, TAKEOFF_END, COCK_END + 0.02)
	var snap := window(p, COCK_END, 0.02)
	var lift := window(p, PLANT_END + 0.06, COCK_END)
	## The shoulder drives from the cock to the ball, and the elbow's window
	## starts *after* it and ends *after* it. That offset is the whip, and it is
	## the one relationship in this file that must not be tuned away: an elbow
	## that opens with the shoulder is a straight arm rotating from behind the
	## ear, which is the windmill this replaced.
	##
	## The elbow's is also the widest travel in the swing over the narrowest
	## window -- 111 degrees in 0.13 of phase -- because that is what a whip is.
	## It was narrower still until the continuity check pointed out that a
	## segment moving 7 degrees per sample is indistinguishable from one
	## teleporting, at the sampling rate playback actually runs at.
	## Phase zero is an instant inside the swing, not a clamped endpoint. The
	## contact pose is extended, but its velocity continues into follow-through.
	var strike := window(p, STRIKE_START, 0.0)
	## **The elbow holds its fold while the shoulder travels, then extends.**
	##
	## It opened over (-0.11, 0.02) against a shoulder driving over (-0.14, 0.00) --
	## a lag of three hundredths of a phase, which is no lag at all. Measured
	## through the swing, the elbow was already half open by -0.06 while the
	## shoulder was only two thirds of the way to the ball, so upper arm and forearm
	## swung as one segment and the whole action read as a straight stick rotating.
	## The frame-by-frame strip is what made it obvious; a single frame cannot show
	## an ordering.
	##
	## It stays folded after the shoulder begins, then opens into contact. Both
	## segments retain non-zero contact velocity, so neither appears to stop at
	## the ball before starting a second animation.
	var elbow_release := window(p, ELBOW_RELEASE_START, 0.0)
	var follow := decelerate(p, 0.0, FOLLOW_END)
	var land := window(p, FOLLOW_END, 1.0)
	## The arm finishes after the feet do.
	##
	## Shoulder and elbow used to return to rest on `land`, the same window the
	## legs absorb on -- so the swing arm snapped back to a neutral hang the
	## instant the follow-through ended, and the spike stopped looking like a
	## spike a beat before it stopped being one. A real follow-through carries
	## down and across the body and is still unwinding while the hitter is already
	## on the floor.
	##
	## The same proximal-to-distal rule the rest of this file runs on, applied to
	## the end of the action rather than the start of it.
	var arm_recover := window(p, ARM_RECOVER_START, 1.0)

	## The shoulder walks back through the plant, up through the takeoff, into
	## the cock, through the ball, and across the body.
	## Held where the approach left it rather than un-swung toward neutral. The
	## old `lerpf(BACKSWING, 0, load * 0.35)` carried the arm a third of the way
	## forward during a window playback never draws, which only mattered because
	## its start was the wrong sign; with the seam agreed, the arm is simply back
	## and stays back until the lift takes it up and over.
	var shoulder := BACKSWING_DEGREES
	shoulder = lerpf(shoulder, SHOULDER_LIFT_DEGREES, lift)
	shoulder = lerpf(shoulder, SHOULDER_COCK_DEGREES, tuck)
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
	## **Forward, not back.** This returned to -16, and the arm was at -252: a
	## 236-degree reversal, which is the swing running backwards. Measured, the
	## hand covered it at up to 17 m/s -- three times its speed through the ball,
	## so the fastest thing in a spike was the arm un-spiking afterwards.
	##
	## -340 approaches the same hanging arm by *continuing*: down across the body
	## and toward the bottom of the arc. Starting that return at `FOLLOW_END`
	## spreads it across the landing rather than producing a faster second swing.
	shoulder = lerpf(shoulder, -340.0, arm_recover)

	## And the elbow lags it. Folding early and opening late is the entire
	## difference between a whip and a windmill, so these windows deliberately
	## start after the shoulder's and end after it too.
	var elbow := lerpf(BACKSWING_ELBOW_DEGREES, ELBOW_COCK_DEGREES, maxf(lift, tuck))
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
	elbow = lerpf(elbow, 22.0, arm_recover)

	## Outward through the load, unwinding into the ball. Its own window rather
	## than the shoulder's, because the arm comes back into plane a beat *before*
	## the elbow extends -- the abduction is what the shoulder rotates out of.
	var abduct := lerpf(6.0, SHOULDER_ABDUCT_COCK_DEGREES, maxf(lift, tuck))
	if p >= COCK_END and p <= 0.0:
		abduct = travel(
			p, COCK_END, 0.0,
			SHOULDER_ABDUCT_COCK_DEGREES, SHOULDER_ABDUCT_CONTACT_DEGREES,
			0.0, ABDUCTION_CONTACT_VELOCITY,
		)
	elif p > 0.0:
		abduct = travel(
			p, 0.0, FOLLOW_END,
			SHOULDER_ABDUCT_CONTACT_DEGREES, 4.0,
			ABDUCTION_CONTACT_VELOCITY, 0.0,
		)
	abduct = lerpf(abduct, 0.0, arm_recover)

	## Rotation of the elbow plane around the upper arm. The upper-arm meshes are
	## radially symmetric, but the bent forearm is not: this axis carries the hand
	## around the shoulder instead of letting pitch plus extension punch it along
	## one horizontal line.
	var internal_rotation := lerpf(0.0, -18.0 * hand, maxf(lift, tuck))
	if p >= STRIKE_START and p <= 0.0:
		internal_rotation = travel(
			p, STRIKE_START, 0.0, -18.0 * hand, 12.0 * hand,
			0.0, 92.0 * hand,
		)
	elif p > 0.0:
		internal_rotation = travel(
			p, 0.0, FOLLOW_END, 12.0 * hand, 30.0 * hand,
			92.0 * hand, 0.0,
		)
	internal_rotation = lerpf(internal_rotation, 0.0, arm_recover)

	## The guide arm is not decoration. It **points at the ball** through the cock
	## and is pulled down hard as the striking arm comes forward -- that pull is
	## what rotates the trunk, and a hitter drawn without it looks like they are
	## swinging at something out of reach.
	##
	## It used to go to -148, which measured out as the hand half a metre *behind*
	## the shoulder and rising: both arms swung back together and the guide had
	## nothing to guide. Straight out instead -- 84 degrees is very nearly
	## horizontal on this rig, elbow almost locked -- which is what a hitter does
	## with it: the non-hitting hand tracks the ball and the swing comes through
	## underneath it.
	##
	## And it is held there. `guide_pull` starts a whole tenth of a phase after the
	## shoulder does, because the sequence is *reach, then pull*: pulling with the
	## shoulder would make the two arms one gesture again.
	var guide_pull := window(p, COCK_END + 0.08, 0.06)
	var guide := lerpf(BACKSWING_DEGREES, GUIDE_REACH_DEGREES, maxf(lift, tuck))
	guide = lerpf(guide, 18.0, guide_pull)
	guide = lerpf(guide, 6.0, follow)
	guide = lerpf(guide, 0.0, land)
	## Nearly straight while it reaches, folding as it is pulled in.
	var guide_elbow := lerpf(24.0, 4.0, tuck)
	guide_elbow = lerpf(guide_elbow, 68.0, guide_pull)
	guide_elbow = lerpf(guide_elbow, 46.0, follow)

	## The bow, and its release.
	var torso := lerpf(0.0, TORSO_PLANT_RADIANS, load)
	torso = lerpf(torso, TORSO_TAKEOFF_RADIANS, extend)
	torso = lerpf(torso, TORSO_ARCH_RADIANS, arch)
	torso = lerpf(torso, TORSO_CONTACT_RADIANS, snap)
	torso = lerpf(torso, TORSO_FOLLOW_RADIANS, follow)
	torso = lerpf(torso, -0.14, land)
	var twist := lerpf(0.0, TORSO_TWIST_DEGREES * hand, maxf(lift, tuck))
	twist = lerpf(twist, TORSO_UNWIND_DEGREES * hand, maxf(snap, follow))
	twist = lerpf(twist, 0.0, land)

	## Legs: loaded, extended, tucked under in flight, then swung forward to
	## land and folded again to absorb it.
	var knee := lerpf(-14.0, KNEE_LOAD_DEGREES, load)
	knee = lerpf(knee, KNEE_EXTENDED_DEGREES, extend)
	knee = lerpf(knee, KNEE_TUCK_DEGREES, tuck)
	knee = lerpf(knee, -24.0, follow)
	knee = lerpf(knee, KNEE_LANDING_DEGREES, land)
	var lead_hip := lerpf(16.0, 24.0, load)
	lead_hip = lerpf(lead_hip, 4.0, extend)
	lead_hip = lerpf(lead_hip, -12.0, tuck)
	lead_hip = lerpf(lead_hip, 26.0, follow)
	lead_hip = lerpf(lead_hip, 12.0, land)
	var trail_hip := lerpf(-12.0, -22.0, load)
	trail_hip = lerpf(trail_hip, -4.0, extend)
	trail_hip = lerpf(trail_hip, -21.0, tuck)
	trail_hip = lerpf(trail_hip, 14.0, follow)
	trail_hip = lerpf(trail_hip, 6.0, land)

	## Rule-of-cool power silhouette. More curl has to be followed by more travel
	## or it only makes the hitter look cramped: the trunk and shoulders draw
	## further back during the cock, then extend further through the ball and into
	## the follow-through. Proximal-to-distal timing above is untouched.
	var curl_weight := arch * (1.0 - snap)
	var extension_weight := maxf(strike, follow)
	shoulder -= 23.0 * power_boost * extension_weight
	elbow = lerpf(elbow, 0.0, power_boost * strike)
	torso += 0.19 * power_boost * curl_weight
	torso -= 0.15 * power_boost * maxf(snap, follow)
	twist += 16.0 * hand * power_boost * curl_weight
	twist -= 12.0 * hand * power_boost * maxf(snap, follow)
	knee = lerpf(knee, KNEE_EXTENDED_DEGREES * 0.35, power_boost * extend)
	lead_hip += 10.0 * power_boost * extension_weight
	trail_hip += 8.0 * power_boost * extension_weight

	return {
		"phase_name": phase_name(p),
		"striking_shoulder_degrees": shoulder,
		"striking_elbow_degrees": elbow,
		"striking_abduction_degrees": abduct * hand,
		"striking_internal_rotation_degrees": internal_rotation,
		"guide_shoulder_degrees": guide,
		"guide_elbow_degrees": guide_elbow,
		"torso_pitch_radians": torso,
		"torso_twist_degrees": twist,
		"knee_degrees": knee,
		"lead_hip_degrees": lead_hip,
		"trail_hip_degrees": trail_hip,
		"power_boost": power_boost,
	}


## Which named phase this instant belongs to, so a diagnostic can say where a
## swing is rather than printing nine angles.
static func phase_name(phase: float) -> String:
	if phase < PLANT_END:
		return "plant"
	if phase < TAKEOFF_END:
		return "takeoff"
	if phase < COCK_END:
		return "cock"
	if phase < 0.0:
		return "acceleration"
	## Contact is an instant rather than a span, but a diagnostic that never says
	## the word is a diagnostic that cannot report the one frame everything else
	## is timed against -- and this pose model exists because that frame was being
	## drawn wrong.
	if phase < CONTACT_BAND:
		return "contact"
	if phase < FOLLOW_END:
		return "follow_through"
	return "landing"
