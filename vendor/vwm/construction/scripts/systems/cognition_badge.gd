class_name CognitionBadge
extends RefCounted

## How one cue reads as a picture, in one place, for every renderer.
##
## The 2D tactical board draws with `draw_*` calls into a `Control`; the 3D
## billboard builds meshes facing a camera. They share no drawing code and must
## share every meaning, so the translation from semantics to appearance lives
## here and each renderer only decides how to put a circle on the screen.
##
## **Colour is never the only signal.** Every field this returns is redundant
## with another: an urgent cue is red *and* has a wide eye *and* carries `!`. A
## viewer who cannot separate the reds still reads the badge, and so does anyone
## looking at a greyscale screenshot in a bug report.

const CueModel := preload("res://vendor/vwm/construction/scripts/models/player_cognition_cue.gd")

## What each state is called, on a board that has to be read rather than
## decoded.
##
## Volleyball words where the sport has one and plain ones where it does not.
## `READ` is a voli watching the play develop, `SEES` is the instant they pick
## it up, `CALL` is the only one another player can hear, and `BLIND` is a
## defender who has lost the ball behind the wall.
const STATE_LABELS := {
	"searching": "READ",
	"recognizing": "SEES",
	"deciding": "CHOOSING",
	"calling": "CALL",
	"committed": "COMMITTED",
	"lost_sight": "BLIND",
	"reacting": "REACTS",
}

## Deliberately three hues, not a gradient. A badge is glanced at over a moving
## player, and a continuous colour ramp reads as one colour in motion.
const CALM_COLOR := Color(0.42, 0.62, 0.92)
const ALERT_COLOR := Color(0.95, 0.78, 0.24)
const URGENT_COLOR := Color(0.88, 0.30, 0.26)
const LOST_COLOR := Color(0.55, 0.55, 0.60)

## Eye openness, as a share of the badge radius. Searching is narrow and
## scanning; recognition snaps wide; a lost sightline closes.
const EYE_SEARCHING: float = 0.42
const EYE_RECOGNIZING: float = 0.86
const EYE_COMMITTED: float = 0.70
const EYE_LOST: float = 0.12


## The full drawable reading of one cue.
##
## `pupil` is a unit-ish offset in the renderer's own screen space, so the
## caller supplies the direction to whatever the cue is attending to and this
## decides how far the eye travels toward it. A cue attending to nothing looks
## straight ahead rather than at the court's origin, which is what a raw
## `Vector2.ZERO` attention position would otherwise produce.
static func describe(cue: Resource, toward: Vector2 = Vector2.ZERO) -> Dictionary:
	if cue == null:
		return {}
	var state := str(cue.state)
	var urgency := clampf(float(cue.urgency), 0.0, 1.0)
	var certainty := clampf(float(cue.certainty), 0.0, 1.0)
	var visibility := str(cue.visibility)
	var eye := EYE_SEARCHING
	match state:
		"recognizing":
			eye = EYE_RECOGNIZING
		"committed", "calling":
			eye = EYE_COMMITTED
		"lost_sight":
			eye = EYE_LOST
		"reacting":
			eye = lerpf(EYE_SEARCHING, EYE_RECOGNIZING, float(cue.affect_intensity))
	if visibility == "occluded":
		eye = EYE_LOST
	elif visibility == "partially_obscured":
		eye = minf(eye, EYE_SEARCHING)

	var color := CALM_COLOR
	if visibility != "visible":
		color = LOST_COLOR
	elif urgency >= 0.78:
		color = URGENT_COLOR
	elif urgency >= 0.45:
		color = ALERT_COLOR
	match str(cue.affect):
		"upset":
			color = URGENT_COLOR
		"sad":
			color = CALM_COLOR
		"confident", "pleased":
			color = ALERT_COLOR if urgency >= 0.5 else CALM_COLOR

	var direction := toward
	if direction.length() > 0.0001:
		## Bounded well inside the eye so the pupil never leaves it, which at a
		## twenty-pixel marker is the difference between a look and a defect.
		direction = direction.normalized() * clampf(certainty, 0.25, 1.0) * 0.42
	else:
		direction = Vector2.ZERO
	return {
		## The ambient axes, alongside the punctuating ones.
		##
		## **The badge decides meaning for both renderers, so these belong here
		## and not in either of them.** Until this existed the renderers read
		## `state` and nothing else, so every ambient cue -- one per voli per
		## flight, `state: committed` by construction -- came back a diamond
		## labelled COMMITTED. Twelve of them, permanently lit, which is the exact
		## failure the two-tier rule in `docs/design/COGNITICONS.md` was written to
		## prevent.
		"intent": str(cue.intent),
		"family": _family_for(str(cue.intent)),
		"progress": clampf(float(cue.progress), 0.0, 1.0),
		## Ambient marks lose every overlap they are in, so a renderer can tell
		## the two tiers apart without knowing what a priority number means.
		"is_ambient": int(cue.priority) < 0,
		"eye_openness": clampf(eye, 0.0, 1.0),
		"pupil": direction,
		"color": color,
		## Shape carries what colour carries, so neither is load-bearing alone.
		"shape": _shape_for(state, visibility),
		"punctuation": str(cue.punctuation),
		"is_call": state == "calling",
		"face": _face_for(cue),
		## -1, 0 or +1 rather than the raw float: an arrow either points up, down
		## or is not drawn, and a 0.08 trend drawn as a nearly-flat arrow reads as
		## a rendering error rather than as a small change.
		"trend_direction": (
			1 if float(cue.trend) > 0.15
			else (-1 if float(cue.trend) < -0.15 else 0)
		),
		"emphasis": clampf(maxf(urgency, float(cue.affect_intensity)), 0.0, 1.0),
	}


## Which side of the ball this voli is on, which is the question a glance has to
## answer before any of the detail matters.
##
## Nine intents is more shapes than anyone can separate at twenty pixels over a
## moving body, so the reading is two-stage: the family says *dealing with their
## ball* or *about to do something to it*, and the intent inside it says exactly
## what. `setting` and `watching` are neither, and pretending otherwise would put
## a sword on a setter and a shield on somebody standing still.
static func _family_for(intent: String) -> String:
	match intent:
		"defending", "covering", "receiving", "blocking":
			return "shield"
		"serving", "preparing_attack", "approaching":
			return "sword"
	return "hands"


## The badge outline. A circle is thinking, a wedge is a call heard by others,
## a diamond is commitment, and a dashed ring is a player who has lost the ball.
static func _shape_for(state: String, visibility: String) -> String:
	if visibility == "occluded" or state == "lost_sight":
		return "dashed_ring"
	match state:
		"calling":
			return "wedge"
		"committed":
			return "diamond"
		"reacting":
			return "burst"
	return "circle"


static func _face_for(cue: Resource) -> String:
	match str(cue.affect):
		"upset":
			return "upset"
		"sad":
			return "sad"
		"confident":
			return "confident"
		"pleased":
			return "pleased"
		"urgent":
			return "urgent"
	return ""


## Whether this cue is worth a badge at all.
##
## Idle ball-tracking is the floor of the priority ladder and is true of almost
## everyone almost always; drawing it would put a badge over all twelve players
## for the whole rally and turn the layer into wallpaper. The stream still
## carries those cues, because a renderer that wants to drive head direction
## from them should be able to.
static func is_worth_drawing(cue: Resource) -> bool:
	if cue == null:
		return false
	if str(cue.state) == "searching" and str(cue.attention_kind) == "ball" \
			and float(cue.urgency) < 0.65:
		return false
	return true
