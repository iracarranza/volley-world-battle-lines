class_name PlayerCognitionCue
extends Resource

## A replay-safe statement about what one player is attending to, deciding, or
## feeling during a rally.  This is semantic evidence: renderers decide how an
## eye, flame, face, punctuation mark, or arrow depicts it.
##
## **A cue never names a picture.** `state`, `attention_kind` and `affect` are
## the vocabulary; an eye shape, a call symbol or a colour is a renderer's
## reading of them. The 2D badge and the 3D billboard consume the same cue and
## must agree on meaning without agreeing on geometry, which is only possible if
## nothing here is a sprite name.
##
## **A cue carries only what its player perceived.** The resolver knows where
## the ball actually went; a blocker reading the setter does not. Grading an
## outcome is allowed after the decision boundary the cue describes, never
## before it -- otherwise the badge shows a player being certain about something
## they had no way to know, which is the one failure that would make the whole
## layer read as fake.

## The closed vocabularies. Declared rather than left as loose strings because
## two renderers and one compiler have to agree on them, and a typo in a
## `StringName` is silent everywhere.
const STATES: Array[StringName] = [
	&"searching", &"recognizing", &"deciding", &"calling",
	&"committed", &"lost_sight", &"reacting",
]
const ATTENTION_KINDS: Array[StringName] = [
	&"ball", &"setter", &"hitter", &"teammate", &"position", &"none",
]
const VISIBILITIES: Array[StringName] = [
	&"visible", &"partially_obscured", &"occluded",
]
const AUDIENCES: Array[StringName] = [&"private", &"public", &"observable"]
const AFFECTS: Array[StringName] = [
	&"neutral", &"confident", &"urgent", &"upset", &"sad", &"pleased",
]
## What this voli is preparing to do with their body.
##
## A third axis, and it has to be a third axis rather than more `STATES` values,
## because it is orthogonal to both of the others: a voli can be `committed`,
## attending the `ball`, and either dropping into a dig posture or winding up to
## swing. Same state, same attention, opposite readings. Nothing else here can
## tell those two apart.
##
## `watching` is in the list deliberately. A vocabulary with no term for "nothing
## in particular" invites whoever compiles a continuous stream to invent an
## intent to fill a gap -- which is the drifting-volis defect moved from the legs
## to the icons, and it is worse there because it is a claim about a mind.
const INTENTS: Array[StringName] = [
	&"serving", &"receiving", &"defending", &"covering", &"preparing_attack",
	&"approaching", &"blocking", &"setting", &"chasing", &"recovering",
	&"watching",
]
## How the eyes are being spent, which is not the same question as where they
## point.
##
## A receiver who checks their partner and looks away has *finished*: they got
## what they needed in a fifth of a second. A blocker holding the setter has not
## finished and will not until the ball leaves. Both are `attention_kind:
## teammate` or `setter` for their whole duration, so `ATTENTION_KINDS` alone
## cannot separate a question from a vigil -- and telling them apart at a glance
## is most of what makes the layer readable.
const ATTENTION_HOLDS: Array[StringName] = [
	## Brief, answered, and over. The look resolves and the voli moves on.
	&"glance",
	## Following something that is moving, for as long as it moves.
	&"track",
	## Locked on and not releasing until the phase does it for them.
	&"fixed",
]

## The shortest interval anyone can read. A cue thinner than this flickers past
## at 2x playback and reads as a rendering fault rather than a thought.
const MINIMUM_DURATION_SECONDS: float = 0.08

## How long a glyph takes to go from full strength to nothing once its message
## has been sent. Long enough to read as a decision letting go rather than as a
## sprite being switched off, short enough that a glance is genuinely brief.
const FADE_SECONDS: float = 0.22

## What a look costs when it is only a question. A receiver checking whether
## their partner is taking the ball has their answer inside this; the number is
## the same order as the quick end of a defender's reaction window, which is the
## nearest thing in the engine to a measured glance.
const GLANCE_DWELL_SECONDS: float = 0.18

@export var sequence: int = 0
@export var action_sequence: int = -1
@export var player_id: int = -1
@export var side: StringName = &""
@export var phase: StringName = &"before"
@export var state: StringName = &"searching"
@export var starts_at: float = 0.0
@export var ends_at: float = 0.0
@export var intent: StringName = &"watching"
## How far along the attempt is, for the intents that accumulate -- run-up
## distance covered, the close toward a wall, the collapse into cover, the
## travel to a release seat. Zero for the rest, and a renderer draws those
## plain.
##
## **This is how far along, never how likely.** A hitter who will arrive late
## still fills their bar, because they are running; the lateness reads as the bar
## not being full when the ball arrives. Grading it by the outcome would break
## the rule at the top of this file in the least visible and most damaging way,
## because a progress bar looks like a measurement.
@export_range(0.0, 1.0) var progress: float = 0.0
@export var attention_kind: StringName = &"ball"
@export var attention_hold: StringName = &"track"
@export var attention_player_id: int = -1
@export var attention_position: Vector2 = Vector2.ZERO
@export var visibility: StringName = &"visible"
@export_range(0.0, 1.0) var certainty: float = 0.5
@export_range(0.0, 1.0) var urgency: float = 0.5
@export var punctuation: String = ""
@export var affect: StringName = &"neutral"
@export_range(0.0, 1.0) var affect_intensity: float = 0.0
@export_range(-1.0, 1.0) var trend: float = 0.0
@export var outcome_name: String = ""
@export var audience: StringName = &"observable"
@export var priority: int = 0
## How long the glyph holds full strength before it fades, from `starts_at`.
## Negative means "as long as the cue lasts", which is the right answer for
## anything ongoing.
##
## **This is what separates the cue from its ink, and the separation is what
## makes a continuous stream survivable.** Coverage wants exactly one live cue
## per voli at every instant, so that what they are doing is always defined. A
## court with twelve glyphs burning at full strength for the whole rally is the
## opposite of legible, and it would drown the markers that currently carry the
## rally -- `lost_sight` fires 24 times in 47,000 cue-samples, and it lands
## because almost nothing else is lit.
##
## So a cue stays active and its glyph goes quiet once its message has been
## sent. A glance is the clearest case: the look is over in a fifth of a second
## and the voli keeps whatever they learned.
@export var dwell_seconds: float = -1.0


static func create(
	player: int,
	player_side: StringName,
	action: int,
	from_time: float,
	to_time: float,
	cue_state: StringName,
	cue_phase: StringName = &"before",
) -> PlayerCognitionCue:
	var cue := PlayerCognitionCue.new()
	cue.player_id = player
	cue.side = player_side
	cue.action_sequence = action
	cue.starts_at = maxf(from_time, 0.0)
	cue.ends_at = maxf(to_time, cue.starts_at + MINIMUM_DURATION_SECONDS)
	cue.state = cue_state
	cue.phase = cue_phase
	return cue


func is_active_at(simulation_time: float) -> bool:
	return simulation_time >= starts_at and simulation_time <= ends_at


func duration() -> float:
	return maxf(ends_at - starts_at, 0.0)


## How much ink this cue is worth at a given moment, 0 to 1.
##
## The renderer's whole fade rule, kept here rather than in two renderers, so the
## 3D billboard and the 2D badge cannot disagree about when a thought is spent --
## which is the same reason `state` and `affect` live here and their pictures do
## not.
func glyph_strength(simulation_time: float) -> float:
	if not is_active_at(simulation_time):
		return 0.0
	if dwell_seconds < 0.0:
		return 1.0
	var elapsed := simulation_time - starts_at
	if elapsed <= dwell_seconds:
		return 1.0
	return clampf(1.0 - (elapsed - dwell_seconds) / FADE_SECONDS, 0.0, 1.0)


## A look that is answered and released, rather than one held.
##
## Sets the hold and the dwell together on purpose. They are two statements about
## the same act and letting a caller set one without the other is how a glance
## ends up burning for two seconds -- the defect this pair exists to prevent.
func as_glance(dwell: float = GLANCE_DWELL_SECONDS) -> PlayerCognitionCue:
	attention_hold = &"glance"
	dwell_seconds = maxf(dwell, 0.0)
	return self


## A look held for as long as the cue lasts. The default, stated explicitly for
## the sites where holding is the point -- a blocker on a setter, a defender on
## the ball.
func as_held(fixed_gaze: bool = false) -> PlayerCognitionCue:
	attention_hold = &"fixed" if fixed_gaze else &"track"
	dwell_seconds = -1.0
	return self


## Whether this cue may be shown to a viewer watching the whole court.
##
## `private` is a thought the player had and nobody could see -- a setter's
## option weighing, a blocker's belief about the lane. It is still recorded,
## because the 2D tactical board is a coaching instrument and may show it, but
## the 3D presentation is a camera in a gym and must not.
func is_visible_to_spectators() -> bool:
	return audience != &"private"


## Every field, so a saved rally replays identically to the one that was
## resolved. Godot serialises `@export`ed resources on its own, but a rally
## result also crosses a JSON save, and a cue that survived one and not the
## other would produce two different replays of the same seed.
func to_dict() -> Dictionary:
	return {
		"sequence": sequence,
		"action_sequence": action_sequence,
		"player_id": player_id,
		"side": str(side),
		"phase": str(phase),
		"state": str(state),
		"starts_at": starts_at,
		"ends_at": ends_at,
		"intent": str(intent),
		"progress": progress,
		"attention_kind": str(attention_kind),
		"attention_hold": str(attention_hold),
		"attention_player_id": attention_player_id,
		"attention_position": attention_position,
		"visibility": str(visibility),
		"certainty": certainty,
		"urgency": urgency,
		"punctuation": punctuation,
		"affect": str(affect),
		"affect_intensity": affect_intensity,
		"trend": trend,
		"outcome_name": outcome_name,
		"audience": str(audience),
		"priority": priority,
		"dwell_seconds": dwell_seconds,
	}


static func from_dict(data: Dictionary) -> PlayerCognitionCue:
	var cue := PlayerCognitionCue.new()
	cue.sequence = int(data.get("sequence", 0))
	cue.action_sequence = int(data.get("action_sequence", -1))
	cue.player_id = int(data.get("player_id", -1))
	cue.side = StringName(str(data.get("side", "")))
	cue.phase = StringName(str(data.get("phase", "before")))
	cue.state = StringName(str(data.get("state", "searching")))
	cue.starts_at = float(data.get("starts_at", 0.0))
	cue.ends_at = float(data.get("ends_at", 0.0))
	## Defaulted rather than required, because every cue written before these
	## three axes existed loads as an ongoing, held, watching one -- which is the
	## honest reading of a stream that had no opinion about intent.
	cue.intent = StringName(str(data.get("intent", "watching")))
	cue.progress = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	cue.attention_kind = StringName(str(data.get("attention_kind", "ball")))
	cue.attention_hold = StringName(str(data.get("attention_hold", "track")))
	cue.attention_player_id = int(data.get("attention_player_id", -1))
	## A Vector2 survives Godot's own resource format and does not survive JSON,
	## where it arrives as a dictionary or an array. Accepting all three is
	## cheaper than discovering at load time which writer produced the save.
	cue.attention_position = _to_vector2(data.get("attention_position", Vector2.ZERO))
	cue.visibility = StringName(str(data.get("visibility", "visible")))
	cue.certainty = clampf(float(data.get("certainty", 0.5)), 0.0, 1.0)
	cue.urgency = clampf(float(data.get("urgency", 0.5)), 0.0, 1.0)
	cue.punctuation = str(data.get("punctuation", ""))
	cue.affect = StringName(str(data.get("affect", "neutral")))
	cue.affect_intensity = clampf(float(data.get("affect_intensity", 0.0)), 0.0, 1.0)
	cue.trend = clampf(float(data.get("trend", 0.0)), -1.0, 1.0)
	cue.outcome_name = str(data.get("outcome_name", ""))
	cue.audience = StringName(str(data.get("audience", "observable")))
	cue.priority = int(data.get("priority", 0))
	cue.dwell_seconds = float(data.get("dwell_seconds", -1.0))
	return cue


static func _to_vector2(raw: Variant) -> Vector2:
	if raw is Vector2:
		return raw
	if raw is Dictionary:
		return Vector2(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)))
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


## Whether every field holds a value from its own vocabulary and the interval
## runs forwards. Used by the gate rather than by the compiler: a cue that fails
## this is a bug in whoever built it, and silently repairing one would hide the
## bug rather than the badge.
func is_well_formed() -> bool:
	return (
		player_id >= 0
		and STATES.has(state)
		and ATTENTION_KINDS.has(attention_kind)
		and ATTENTION_HOLDS.has(attention_hold)
		and INTENTS.has(intent)
		and progress >= 0.0 and progress <= 1.0
		## A glance whose dwell outlasts the cue is not a glance, and a held look
		## that quietly fades is not held. Both are caller mistakes rather than
		## data to repair.
		and (dwell_seconds < 0.0 or dwell_seconds <= duration() + 0.0001)
		and (attention_hold != &"glance" or dwell_seconds >= 0.0)
		and VISIBILITIES.has(visibility)
		and AUDIENCES.has(audience)
		and AFFECTS.has(affect)
		and starts_at >= 0.0
		and ends_at >= starts_at
		and duration() >= MINIMUM_DURATION_SECONDS - 0.0001
	)
