class_name BlockBiomechanics
extends RefCounted

## A block as a jump, not as a shape.
##
## The block pose was the last static one in the rig: a single set of angles with
## no phase in it at all. Playback applies it the moment the blocker becomes the
## upcoming contact's actor, so a voli standing in ready posture had their arms
## teleport to full extension in one frame, held that wall for the whole flight,
## and dropped out of it just as abruptly.
##
## Smoothing cannot fix that, and it is worth saying why rather than leaving it
## to be rediscovered. A rate limit has to sit *above* the fastest motion that is
## supposed to happen, or it damages that motion -- and the fastest joint in this
## game is the spike's elbow at about 2,800 degrees per second. A ceiling above
## that turns the block's 158-degree snap into 56 milliseconds of travel, which
## is three frames and invisible. For the arms to take a readable fifth of a
## second the ceiling would have to be around 700 degrees per second, a quarter
## of the spike's, which would flatten the whip the spike model exists to
## produce. One number cannot be both, so the block gets decomposed instead.
##
## ## What a block actually is
##
## Not "arms up". A blocker reads, loads, drives, *penetrates*, holds, and
## withdraws, and the order matters the same way it does in a spike -- the legs
## are already extending while the arms are still low, and the shoulders shrug
## last. The penetration is the part that separates a block from a person
## reaching: the hands go **over** the net rather than up at it, which is a
## forward lean plus late shoulder elevation, arriving after the arms are
## already high.
##
## ## Phase convention
##
## Signed, contact at 0, matching `SpikeBiomechanics`:
##
##   -1.0  reading the setter, feet on the floor
##    0.0  the ball arrives at the wall, hands at full penetration
##   +1.0  arms withdrawn, back on the floor
##
## Pure and deterministic, for the same reason as the other pose modules.

## Visual vocabulary semantics
##
## The base family is a clean block attempt: read, load, jump, press, hold,
## withdraw, land, and recover. A two-arm wall reads as sealed/controlled; one
## arm is a late reach while closing; no committed arm is a beaten or incomplete
## wall. Post-contact response variants distinguish a hard impact absorbed by
## the hands, a touch/tooling deflection, and a beaten block after the ball has
## passed. They describe the visible response, not the contest outcome rules.

## Where each stage begins on the signed timeline.
##
## The read takes most of the wind-up because that is what a blocker actually
## spends their time doing; the drive is brief and the press briefer, which is
## why a block looks sudden even though the whole action is not.
const READ_END: float = -0.52
const LOAD_END: float = -0.30
const DRIVE_END: float = -0.08
## How long the wall stays up after the ball has been at it. A blocker does not
## drop their hands the instant the ball leaves -- and one drawn doing so reads
## as flinching away from it.
const HOLD_END: float = 0.34

## Shoulder rotation through the action. 158 at the press is the value the static
## pose used and is kept deliberately: the peak of this motion is the pose that
## was already judged to look right, and everything here is the route into and
## out of it rather than a retune of it.
const SHOULDER_READY_DEGREES: float = 62.0
const SHOULDER_LOAD_DEGREES: float = 44.0
const SHOULDER_DRIVE_DEGREES: float = 132.0
const SHOULDER_PRESS_DEGREES: float = 158.0
## Where the arms finish. Near a hang, not out in front -- at 34 the blocker
## ended the action holding their arms horizontally ahead of them, which is a
## pose nobody has ever been in.
const SHOULDER_WITHDRAW_DEGREES: float = 15.0

## The elbow is what tells a block from a set. Both put the hands above the head;
## only one keeps the arms straight. It folds in the ready posture -- hands at
## chest height waiting -- and opens through the drive to near-locked at the
## press, because a block that bends at the elbow is a block that gets driven
## back through the net.
const ELBOW_READY_DEGREES: float = 58.0
const ELBOW_DRIVE_DEGREES: float = 22.0
const ELBOW_PRESS_DEGREES: float = 4.0

## How far the hands are carried outside the shoulders, in degrees of roll. A
## sealed block is hands close; spreading them is how a ball goes through the
## middle of a double.
const HAND_SPREAD_DEGREES: float = 8.0

## Trunk pitch. Negative is forward on this rig. The blocker folds over their
## knees to load, comes back to upright through the drive, and finishes leaning
## *over* the net rather than standing under it.
const TORSO_READY_RADIANS: float = -0.06
const TORSO_LOAD_RADIANS: float = -0.26
const TORSO_DRIVE_RADIANS: float = 0.02
const TORSO_PRESS_RADIANS: float = -0.12

## Knee flexion, negative like every other knee on this rig. Loaded deep, driven
## straight, then tucked in flight -- a blocker's shins swing under and ahead of
## them on the way up, which is what makes it a jump rather than a hurdle.
const KNEE_READY_DEGREES: float = -18.0
const KNEE_LOAD_DEGREES: float = -62.0
const KNEE_EXTENDED_DEGREES: float = -6.0
const KNEE_TUCK_DEGREES: float = -34.0

## Hip angles in flight, kept apart so the legs do not read as a single fused
## limb. These are the values the static pose used.
const HIP_LEAD_FLIGHT_DEGREES: float = 26.0
const HIP_TRAIL_FLIGHT_DEGREES: float = 22.0

## How far the shoulders shrug at the press, in metres.
##
## Arriving *after* the arms are already up is the whole of the penetration: a
## blocker gains their last few centimetres over the net from the shoulder
## girdle, not the arm, and it is the last thing to move.
const SHOULDER_LIFT_METERS: float = 0.06


## Eased 0-1 progress through a window, clamped outside it.
##
## Deliberately the same smoothstep easing `SpikeBiomechanics.window` uses, and
## deliberately its own copy: the two modules share a convention, not a
## dependency, and a block reaching into the spike's file to borrow four lines
## would be the wrong relationship between them.
static func window(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	return smoothstep(from_phase, to_phase, phase)


## Every joint the block pose needs, for one instant of the jump.
const RESPONSE_WALL := &"wall"
const RESPONSE_IMPACT := &"impact"
const RESPONSE_TOOL := &"tool"
const RESPONSE_BEATEN := &"beaten"


static func resolve(
	phase: float,
	response: StringName = RESPONSE_WALL,
	contact_side: float = 1.0,
) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)

	## Proximal first, as in the spike: the legs are already driving while the
	## arms are still low. The windows overlap, so no segment has finished when
	## the next one starts.
	var load := window(p, -1.0, READ_END)
	var drive := window(p, READ_END, LOAD_END)
	var lift := window(p, READ_END + 0.06, DRIVE_END)
	var press := window(p, LOAD_END, 0.0)
	var tuck := window(p, LOAD_END, DRIVE_END)
	## The shoulder girdle last. It starts after the arms are most of the way up
	## and finishes on the ball, which is what turns a reach into a penetration.
	var shrug := window(p, DRIVE_END - 0.06, 0.0)
	var withdraw := window(p, HOLD_END, 1.0)

	var shoulder := lerpf(SHOULDER_READY_DEGREES, SHOULDER_LOAD_DEGREES, load)
	shoulder = lerpf(shoulder, SHOULDER_DRIVE_DEGREES, lift)
	shoulder = lerpf(shoulder, SHOULDER_PRESS_DEGREES, press)
	shoulder = lerpf(shoulder, SHOULDER_WITHDRAW_DEGREES, withdraw)

	var elbow := lerpf(ELBOW_READY_DEGREES, ELBOW_DRIVE_DEGREES, lift)
	elbow = lerpf(elbow, ELBOW_PRESS_DEGREES, press)
	elbow = lerpf(elbow, ELBOW_READY_DEGREES, withdraw)

	var torso := lerpf(TORSO_READY_RADIANS, TORSO_LOAD_RADIANS, load)
	torso = lerpf(torso, TORSO_DRIVE_RADIANS, drive)
	torso = lerpf(torso, TORSO_PRESS_RADIANS, press)
	torso = lerpf(torso, TORSO_READY_RADIANS, withdraw)

	var knee := lerpf(KNEE_READY_DEGREES, KNEE_LOAD_DEGREES, load)
	knee = lerpf(knee, KNEE_EXTENDED_DEGREES, drive)
	knee = lerpf(knee, KNEE_TUCK_DEGREES, tuck)
	knee = lerpf(knee, KNEE_READY_DEGREES, withdraw)

	## On the floor the feet are under the blocker; in the air they swing ahead.
	var lead_hip := lerpf(6.0, -4.0, load)
	lead_hip = lerpf(lead_hip, HIP_LEAD_FLIGHT_DEGREES, tuck)
	lead_hip = lerpf(lead_hip, 4.0, withdraw)
	var trail_hip := lerpf(-6.0, -12.0, load)
	trail_hip = lerpf(trail_hip, HIP_TRAIL_FLIGHT_DEGREES, tuck)
	trail_hip = lerpf(trail_hip, -2.0, withdraw)

	var joints := {
		"phase_name": phase_name(p),
		"shoulder_degrees": shoulder,
		"elbow_degrees": elbow,
		"hand_spread_degrees": HAND_SPREAD_DEGREES * maxf(lift, press),
		"torso_pitch_radians": torso,
		"knee_degrees": knee,
		"lead_hip_degrees": lead_hip,
		"trail_hip_degrees": trail_hip,
		"shoulder_lift_meters": SHOULDER_LIFT_METERS * shrug * (1.0 - withdraw),
	}
	_apply_response(joints, p, response, contact_side)
	return joints


## Response begins at the authoritative contact. The pre-contact wall is
## byte-for-byte the ordinary solve, so presentation cannot predict or cause a
## tool, impact, or beaten block.
static func _apply_response(
	joints: Dictionary, phase: float, response: StringName, contact_side: float
) -> void:
	joints["block_response"] = response
	joints["left_shoulder_delta_degrees"] = 0.0
	joints["right_shoulder_delta_degrees"] = 0.0
	joints["left_elbow_delta_degrees"] = 0.0
	joints["right_elbow_delta_degrees"] = 0.0
	joints["response_roll_degrees"] = 0.0
	if response == RESPONSE_WALL or phase < 0.0:
		return
	var impact := smoothstep(0.0, 0.16, phase) \
		* (1.0 - smoothstep(0.46, 0.82, phase))
	if response == RESPONSE_IMPACT:
		joints["shoulder_degrees"] = float(joints.shoulder_degrees) - 8.0 * impact
		joints["elbow_degrees"] = float(joints.elbow_degrees) + 12.0 * impact
		joints["torso_pitch_radians"] = float(joints.torso_pitch_radians) \
			+ 0.10 * impact
		joints["knee_degrees"] = float(joints.knee_degrees) - 10.0 * impact
	elif response == RESPONSE_TOOL:
		var right_contact := contact_side >= 0.0
		if right_contact:
			joints["right_shoulder_delta_degrees"] = -15.0 * impact
			joints["right_elbow_delta_degrees"] = 20.0 * impact
		else:
			joints["left_shoulder_delta_degrees"] = -15.0 * impact
			joints["left_elbow_delta_degrees"] = 20.0 * impact
		joints["response_roll_degrees"] = (7.5 if right_contact else -7.5) * impact
	elif response == RESPONSE_BEATEN:
		var chase := smoothstep(0.0, 0.26, phase) \
			* (1.0 - smoothstep(0.38, 0.70, phase))
		joints["shoulder_degrees"] = float(joints.shoulder_degrees) - 18.0 * chase
		joints["elbow_degrees"] = float(joints.elbow_degrees) + 18.0 * chase
		joints["response_roll_degrees"] = contact_side * 5.5 * chase


## How far off the floor the blocker is at this instant, 0 to 1.
##
## Lives here rather than in playback because it is not free: the feet have to
## leave the ground when the legs finish driving and be back down after the arms
## withdraw, and both of those moments are defined by the windows above. Stated
## separately it is a second timeline free to disagree with the first, which is
## how a blocker ends up pressing while still standing on the floor.
func elevation(phase: float) -> float:
	return elevation_at(phase)


## Static twin, for callers that have no instance. Same curve.
static func elevation_at(phase: float) -> float:
	var p := clampf(phase, -1.0, 1.0)
	if p <= LOAD_END:
		return 0.0
	if p <= 0.0:
		## Rising through the drive and the press, peaking on the ball.
		return sin((p - LOAD_END) / (0.0 - LOAD_END) * PI * 0.5)
	## Held near the top while the wall is up, then down. Landing is the actor's
	## own overlay from there.
	if p >= LANDED_PHASE:
		return 0.0
	return cos(p / LANDED_PHASE * PI * 0.5)


## When the blocker is back on the floor. After `HOLD_END`, because the hands
## come down on the way down rather than after it.
const LANDED_PHASE: float = 0.78


## Which named stage this instant belongs to, so a diagnostic can say where a
## block is rather than printing seven angles.
static func phase_name(phase: float) -> String:
	if phase < READ_END:
		return "read"
	if phase < LOAD_END:
		return "load"
	if phase < DRIVE_END:
		return "drive"
	if phase < 0.0:
		return "press"
	if phase < HOLD_END:
		return "hold"
	return "withdraw"
