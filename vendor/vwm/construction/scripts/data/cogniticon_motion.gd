class_name CogniticonMotion
extends RefCounted

## How a cogniticon moves, as pure functions of time.
##
## The marks are drawn by `CogniticonMarks` and placed by
## `CognitionBillboard3D`; this module owns *when they are where*. Nothing here
## touches a node, holds state, or reads a frame delta -- same shape as
## `SpikeBiomechanics`, `BlockBiomechanics` and `GaitBiomechanics`, and for the
## same three reasons:
##
## - `match_screen.gd` carries a `playback_speed` from 0.1 to 4.0, and animation
##   driven by frame deltas would run at the wrong rate on a slow replay
## - the bodies are already phase-driven, so a second clock beside them is a
##   second clock to disagree with them
## - and a pure function can be gated headlessly, which is how every other
##   claim in this repository is checked
##
## ## Envelopes are in real seconds, and that is a measurement rather than a
## preference
##
## The obvious design is to run each envelope across its window as a 0-to-1
## progress. `run_window_budget_probe.gd`, 936 windows over 180 rallies, says
## that would break:
##
##     after        count     p10   median    mean     p90     min
##     ATTACK         210    0.03     0.33    0.63    1.62    0.02
##     BLOCK           59    0.22     0.29    0.36    0.63    0.22
##     DEFENSE        116    0.23     0.73    0.82    1.59    0.13
##     RECEPTION      161    1.35     1.43    1.41    1.48    0.91
##     SERVE          180    1.03     1.10    1.10    1.19    0.95
##     SET            210    0.87     1.00    1.13    1.50    0.59
##     ALL            936    0.22     1.06    0.97    1.48    0.02
##
## The slash lives on the attack's window, whose median is a third of a second
## and whose tenth percentile is **three hundredths**. A window-relative slash
## would be played out in two frames on a fast swing and stretched over a second
## and a half on a roll shot -- which is exactly the defect `BlockPhaseModel`
## was written to remove from the block's jump. A body's motion is its own
## duration; so is a mark's.
##
## So every envelope below is in seconds, clamped, and **allowed to keep running
## past the end of its window** into the next one. `BLOCK_DESCENT_SECONDS` in
## `match_screen.gd` already works this way and is the precedent.
##
## The other thing that table says: the swoop and the charge are comfortable.
## Blades arrive on the set's window (median 1.0 s) and the serve charges over
## its own (median 1.10 s), so a 0.22 s arrival has four times the room it needs.
## Only the reactions are tight, and reactions should be fast anyway.

## How long a mark takes to arrive. Deliberately the same order as
## `PlayerCognitionCue.FADE_SECONDS` (0.22) and `GLANCE_DWELL_SECONDS` (0.18) --
## the cue vocabulary already thinks at this scale and a mark that enters slower
## than a glance lasts would be a mark that misses its own moment.
const ARRIVE_SECONDS: float = 0.22
## And leaves. Slightly quicker than it came: a sheathe is a decision already
## made, where an arrival is one being taken.
const SHEATHE_SECONDS: float = 0.18

## The blink, which is the whole of what makes an idle mark feel alive.
##
## Fast down and slower up, which is what a real blink is and what separates it
## from a pulse. Both well under the ambient motion budget by duration even
## though they exceed it by rate -- the exception is named in the design doc.
const BLINK_DOWN_SECONDS: float = 0.09
const BLINK_UP_SECONDS: float = 0.15
## How often, per voli. A range rather than a constant so twelve eyes do not
## fall into step, and derived from the player id rather than randomly so a
## replay of the same rally blinks identically.
const BLINK_PERIOD_MIN: float = 3.1
const BLINK_PERIOD_SPAN: float = 2.7

## The startle. Fast in, slow out, because that is what a startle is; a
## symmetric envelope reads as a pulse and a slow one reads as dawning
## realisation, which is a different emotion and a much less useful one.
const SHOCK_SNAP_SECONDS: float = 0.04
const SHOCK_HOLD_SECONDS: float = 0.12
const SHOCK_SETTLE_SECONDS: float = 0.26

## The slash, sized against the ATTACK row above rather than against taste. Even
## this is longer than a tenth of attack windows, which is why it runs on its
## own clock and finishes in the next one.
const SLASH_DOWN_SECONDS: float = 0.12
const SLASH_RECOVER_SECONDS: float = 0.20
## How far the blade swings through the downswing.
const SLASH_DEGREES: float = 72.0

## Aperture, as multiples of the eye's drawn height.
const APERTURE_NARROW: float = 0.45
const APERTURE_NOMINAL: float = 1.0
const APERTURE_DOUBT: float = 1.18
const APERTURE_SHOCK: float = 1.55
## How much the doubtful aperture wavers, and how fast. Small and slow: this is
## ambient, and the fork carries the message.
const DOUBT_WAVER: float = 0.06
const DOUBT_WAVER_HZ: float = 1.6

## How far the charging blade grows, and how far it straightens.
const CHARGE_SCALE_GAIN: float = 0.12
const CHARGE_TILT_DEGREES: float = 6.0
## And how far a directed mark leans toward the course it has chosen. This is
## the parameter that removes the need for a second concurrent mark: a blade
## tilted toward the line and one tilted cross are different marks at a glance.
const COURSE_TILT_DEGREES: float = 22.0


## A mark arriving: swooping in rather than appearing.
##
## Returns the transform to apply on top of the mark's resting place. The fade
## runs *ahead* of the motion -- alpha reaches full at 70% of the travel -- so
## the mark is never seen as a solid object in the wrong place, which is the
## single tell that separates an entrance from a pop.
static func arrival(seconds_since_start: float) -> Dictionary:
	var t := clampf(seconds_since_start / ARRIVE_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	return {
		"alpha": clampf(t / 0.7, 0.0, 1.0),
		## From behind the shoulder and above, settling down and in.
		"offset": Vector2(-0.55, 0.42) * (1.0 - eased),
		"rotation_degrees": 35.0 * (1.0 - eased),
		"scale": lerpf(0.72, 1.0, eased),
		"done": t >= 1.0,
	}


## And leaving. A hitter the setter passed over sheathes rather than blinking
## out, which is backlog entry 14 made legible without moving a body.
static func sheathe(seconds_since_release: float) -> Dictionary:
	var t := clampf(seconds_since_release / SHEATHE_SECONDS, 0.0, 1.0)
	var eased := t * t
	return {
		"alpha": 1.0 - clampf((t - 0.2) / 0.8, 0.0, 1.0),
		"offset": Vector2(-0.42, 0.30) * eased,
		"rotation_degrees": -26.0 * eased,
		"scale": lerpf(1.0, 0.84, eased),
		"done": t >= 1.0,
	}


## How open an eye is, for one voli at one instant.
##
## Composes four things that all want the same number, in priority order:
## shock beats doubt, doubt beats focus, and a blink beats everything because a
## blink is a shutter rather than an expression.
static func aperture(
	eye_openness: float,
	hold: String,
	doubtful: bool,
	seconds_since_shock: float,
	blink_closure: float,
) -> float:
	var base := lerpf(APERTURE_NARROW, APERTURE_NOMINAL, clampf(eye_openness, 0.0, 1.0))
	## A fixed hold is a hard read, and a hard read narrows. The model already
	## publishes the hold; this is the only place it is used for anything.
	if hold == "fixed":
		base = minf(base, APERTURE_NARROW + 0.08)
	if doubtful:
		base = maxf(base, APERTURE_DOUBT)
	var shock := shock_envelope(seconds_since_shock)
	base = lerpf(base, APERTURE_SHOCK, float(shock["weight"]))
	return base * (1.0 - clampf(blink_closure, 0.0, 1.0))


## The startle, as a 0-1 weight and how far the ink has travelled toward its
## grade colour. One envelope drives both so the widening and the colouring can
## never drift apart.
static func shock_envelope(seconds_since_shock: float) -> Dictionary:
	if seconds_since_shock < 0.0:
		## **The honesty gate, and it is the only one that matters.** A reaction
		## may be wrong -- a blocker's eye may be aimed at a decoy -- but it may
		## not be *early*. A negative time is a shock that has not happened yet.
		return {"weight": 0.0, "colour_mix": 0.0}
	var snap := SHOCK_SNAP_SECONDS
	var hold := snap + SHOCK_HOLD_SECONDS
	var out := hold + SHOCK_SETTLE_SECONDS
	if seconds_since_shock <= snap:
		return _shock_pair(seconds_since_shock / maxf(snap, 0.0001))
	if seconds_since_shock <= hold:
		return _shock_pair(1.0)
	if seconds_since_shock >= out:
		return {"weight": 0.0, "colour_mix": 0.0}
	var settle := (seconds_since_shock - hold) / SHOCK_SETTLE_SECONDS
	## The colour outlives the shape on the way out, which is the "fading from
	## orange into red" of the scene read the right way round: the eye returns
	## to its size before it returns to its temper.
	return {
		"weight": 1.0 - smoothstep(0.0, 1.0, settle),
		"colour_mix": 1.0 - smoothstep(0.0, 1.0, settle * 0.68),
	}


static func _shock_pair(value: float) -> Dictionary:
	return {"weight": value, "colour_mix": value}


## How closed a blink has this voli's eye, at this instant.
##
## Deterministic from the player id: no randomness, so a replay of a seed blinks
## the same way twice, and no two volis blink together. A blink is suppressed
## while the hold is `fixed`, because not blinking is what staring *is* -- and
## getting that from a field the model already publishes is free.
static func blink_closure(
	simulation_time: float, player_id: int, hold: String
) -> float:
	if hold == "fixed":
		return 0.0
	var period := BLINK_PERIOD_MIN + BLINK_PERIOD_SPAN * _scatter(player_id)
	var phase := fposmod(simulation_time + _scatter(player_id * 7 + 3) * period, period)
	if phase < BLINK_DOWN_SECONDS:
		return smoothstep(0.0, 1.0, phase / BLINK_DOWN_SECONDS)
	if phase < BLINK_DOWN_SECONDS + BLINK_UP_SECONDS:
		return 1.0 - smoothstep(
			0.0, 1.0, (phase - BLINK_DOWN_SECONDS) / BLINK_UP_SECONDS
		)
	return 0.0


## A stable 0-1 scatter from an integer. Hashed rather than a modulo, so ids
## that differ by one do not land next to each other and blink almost together.
static func _scatter(value: int) -> float:
	var hashed := (value * 2654435761) % 1000003
	return float(absi(hashed)) / 1000003.0


## Where the pupil sits inside the eye, as a fraction of the eye's radii.
##
## The heading is the voli's own look direction relative to their facing, which
## the actor already computes and clamps to a neck's range. An occluded view
## drifts the pupil off the target rather than moving it: the voli is looking,
## and not seeing, which is `attention_kind` and `visibility` disagreeing.
static func pupil_offset(
	heading_offset_radians: float, pitch_degrees: float, occluded: bool
) -> Vector2:
	var lateral := clampf(sin(heading_offset_radians), -1.0, 1.0)
	var vertical := clampf(pitch_degrees / 45.0, -1.0, 1.0)
	var offset := Vector2(lateral, -vertical) * 0.42
	if occluded:
		## Not centred and not aimed -- adrift, which is neither of the two
		## things a working eye does.
		offset = offset.lerp(Vector2(0.22, 0.12), 0.7)
	return offset


## The blade's slash, on its own clock.
##
## Negative seconds is before the contact and returns rest, which is the same
## honesty gate as the shock: a blade may swing at the wrong ball, but it may
## not swing before the swing.
static func slash(seconds_since_contact: float) -> Dictionary:
	if seconds_since_contact < 0.0:
		return {"rotation_degrees": 0.0, "streak": 0.0, "offset": Vector2.ZERO}
	var down := SLASH_DOWN_SECONDS
	if seconds_since_contact <= down:
		var t := seconds_since_contact / maxf(down, 0.0001)
		var eased := smoothstep(0.0, 1.0, t)
		return {
			"rotation_degrees": SLASH_DEGREES * eased,
			## The streak peaks mid-swing, where the blade is fastest.
			"streak": sin(eased * PI),
			"offset": Vector2(0.0, -0.22 * eased),
		}
	var recover := clampf(
		(seconds_since_contact - down) / SLASH_RECOVER_SECONDS, 0.0, 1.0
	)
	var settle := 1.0 - smoothstep(0.0, 1.0, recover)
	return {
		"rotation_degrees": SLASH_DEGREES * settle,
		"streak": 0.0,
		"offset": Vector2(0.0, -0.22 * settle),
	}


## What a charging blade looks like at this much progress.
##
## Prominence rather than size: the fill is the loud signal and this is the
## weight behind it. `course` is -1 for line, +1 for cross, 0 for undecided --
## the tilt that lets one mark carry both what a voli is doing and which way,
## and therefore the reason a second concurrent mark is not needed.
static func charge(progress: float, course: float) -> Dictionary:
	var filled := clampf(progress, 0.0, 1.0)
	return {
		"scale": 1.0 + CHARGE_SCALE_GAIN * filled,
		"rotation_degrees": lerpf(CHARGE_TILT_DEGREES, 0.0, filled)
			+ COURSE_TILT_DEGREES * clampf(course, -1.0, 1.0),
	}


## The unsteadiness of a doubtful eye, as a multiplier on its aperture.
##
## Slow and shallow on purpose. The fork says *what* is doubted; this only says
## the body cannot hold still about it, and anything faster would breach the
## ambient motion budget that keeps twelve marks from becoming a light show.
static func doubt_waver(simulation_time: float, player_id: int) -> float:
	var phase := simulation_time * TAU * DOUBT_WAVER_HZ + _scatter(player_id) * TAU
	return 1.0 + sin(phase) * DOUBT_WAVER


## Which grade a cue's affect is written in.
##
## **Colour is the rating scale, and that is not a borrowed palette -- it is the
## same claim.** `UIPalette.GRADE_COLORS` runs S gold, A green, B blue, C
## neutral, D red, and it already means *how well is this going*. A blocker
## who has just been beaten by a decoy is watching poorly, so a shocked eye
## being grade D is not a colour chosen to look alarming; it is the same
## judgement the rest of the interface would make about the same moment.
##
## It also solves the problem the softened court created. Grade C in Mikasa is
## `f2f4f7`, which is within a shade of the ink already chosen for contrast --
## so neutral costs nothing and every departure from it is a rating.
static func affect_grade(state: String, affect: String, doubtful: bool) -> String:
	if state == "lost_sight" or affect == "upset":
		return "D"
	if doubtful or affect == "urgent":
		## Not yet failed, not going well. B rather than C, so doubt is visibly
		## *a* reading rather than the absence of one.
		return "B"
	if affect == "pleased" or state == "committed":
		return "A"
	if affect == "confident":
		return "S"
	return "C"


## Which variant of a family's mark the rally has earned.
##
## **The rally events decide, and nothing else does.** The marks do not interact
## and never negotiate: a blade does not flame because the shield beside it
## broke. It flames because the cue compiled off this voli's own contact says
## the read went well, and it shatters because the same cue says it did not.
##
## Read off the two axes that already exist rather than a new one, which is what
## keeps this honest. `affect` is where the compiler puts how a contact went, and
## `lost_sight` is the one state that is a failure on its face -- a voli who
## cannot see the ball has already lost whatever they were doing.
##
## The middle is deliberately wide. `plain` is the answer for every ordinary
## contact, and it has to be, or the loud variants stop meaning anything: a
## vocabulary where every mark is flaming is a vocabulary with one word in it.
static func variant_for(state: String, affect: String) -> String:
	if state == "lost_sight" or affect == "upset" or affect == "sad":
		return "broken"
	if affect == "confident" or affect == "pleased":
		return "ascendant"
	return "plain"
