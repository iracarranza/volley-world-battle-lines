class_name CognitionBillboard3D
extends Label3D

## The 3D half of one cue, above one voli's head.
##
## A separate node rather than more state inside `player_actor_3d.gd`, which is
## the file Codex's new models and VFX are about to rewrite; the whole point of
## keeping this component apart is that the two lines of work touch different
## nodes. The actor gains one child and one call.
##
## **Parity is on the description, not on the drawing.** The tactical board
## rasterises `CognitionBadge.describe` into arcs and polygons; this turns the
## same dictionary into a glyph and a colour. They will never look alike and
## must always mean alike, so anything that decides *meaning* -- which state, how
## urgent, whether the eye is open -- happens in the badge module and neither
## renderer is allowed a rule of its own.

const BadgeModel := preload("res://vendor/vwm/construction/scripts/systems/cognition_badge.gd")

## The glyph for each badge shape. Chosen so the silhouette survives at the
## distance a stationary camera actually puts a player at, which ruled out the
## eye shapes that read fine at 20 px on the board and turn to mush here.
const SHAPE_GLYPHS := {
	"circle": "◦",
	"wedge": "◗",
	"diamond": "◆",
	"dashed_ring": "◌",
	"burst": "✳",
}
const FACE_GLYPHS := {
	"upset": "✖",
	"sad": "▾",
	"confident": "▴",
	"pleased": "▴",
	"urgent": "!",
}
const TREND_GLYPHS := {1: "↑", -1: "↓"}

## The ambient tier: what a voli is doing when nothing more interesting is true
## of them.
##
## One mark per intent, grouped so a glance answers *which side of the ball* and
## a look answers the rest -- shields for the four ways of dealing with their
## ball, blades for the three ways of doing something to it, hands for the pivot,
## and a dot for a voli with nothing to add. The dot matters: without a mark,
## "no opinion" is indistinguishable from "not implemented", which is the state
## this layer started in at 0.75 volis of six.
const INTENT_GLYPHS := {
	"defending": "⛊", "covering": "⛉", "receiving": "⛨", "blocking": "⛰",
	"serving": "⇧", "preparing_attack": "⇡", "approaching": "⬆",
	"setting": "⌒", "watching": "•",
}
## `watching` was `·`, a middle dot, and it is **half of every mark drawn**.
##
## `run_cogniticon_screen_probe.gd`, eight rallies off the billboard nodes
## themselves: of the marks visible on screen, 49.2% are this one. It was also
## the least ink of any glyph in the set by a wide margin -- at the em size the
## ambient tier runs at, a middle dot is a few pixels.
##
## The comment above argues the dot has to exist, because without a mark "no
## opinion" is indistinguishable from "not implemented". An *invisible* dot
## fails that test by exactly the same argument, so it is a bullet: still the
## quietest thing in the vocabulary, still deliberately nothing in particular,
## but actually present.
## How far the ambient tier is held below the punctuating one.
##
## The whole two-tier rule in one number. An ambient mark is present on twelve
## volis at once and must never draw the eye; a state badge appears rarely and
## must be the only thing moving when it does. Sized and faded well under the
## badge so that going from 0.75 marks to twelve does not drown `lost_sight`,
## which fires 24 times in 47,000 cue-samples and lands because almost nothing
## else is lit.
## **The ambient tier was paying for quiet twice, and one of the two payments
## bought nothing.**
##
## It was 0.00010 against a badge running 0.00014 to 0.00022 -- 71% of the
## quietest badge and 45% of the loudest -- *and* held at 0.55 alpha. Reported
## from two frames of real playback: the marks cannot be made out at all, and
## the only ones legible on screen are the badge tier's solid diamonds.
##
## Size and contrast are not two ways of saying the same thing. **Size carries
## identity** -- which glyph is this, a shield or a blade -- and **contrast
## carries priority** -- should this pull my eye. Buying quiet with size spends
## the one thing the ambient layer exists for; `COGNITICONS.md` asks that "a
## glance anywhere on court tells you what that voli is doing", and a mark too
## small to identify answers that with nothing. Buying it with contrast costs
## only the pull, which is exactly what was meant to be given up.
##
## So the size goes up to where a shape is readable and the alpha comes down to
## pay for it. The two-tier rule is unchanged in its intent and now lives where
## it belongs: an ambient mark is *dimmer* than a state badge rather than
## smaller than one.
const AMBIENT_PIXEL_SIZE: float = 0.00020
const AMBIENT_ALPHA: float = 0.40

## One number for how large a cogniticon is, so "too small" is one edit rather
## than four.
##
## The badge was sized against a body -- roughly a head on screen -- which is the
## right *relationship* and turned out to be the wrong *number* at the camera
## distances the match centre actually uses. A head is a fine size for a mark you
## are looking for and too small for one you are supposed to read at a glance
## across twelve volis, which is what these are for.
##
## Every size below is a multiple of this, and the two-tier rule survives the
## scaling: ambient stays well under the state badge, because both move together.
const COGNITICON_SCALE: float = 1.45

const BADGE_PIXEL_SIZE: float = 0.00017
const BADGE_PIXEL_SIZE_QUIET: float = 0.00014
const BADGE_PIXEL_SIZE_LOUD: float = 0.00022

const HEIGHT_ABOVE_HEAD_METERS: float = 0.30


func _init() -> void:
	## Always facing the camera and never occluded by the player it belongs to.
	## A thought that disappears behind a shoulder reads as a flicker.
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	## **Screen-relative, and therefore easy to get catastrophically wrong.**
	##
	## `fixed_size` keeps the label the same size however far the camera is, so
	## `pixel_size` is not a world measurement -- it is a share of the viewport.
	## At 0.0016 with a 96 pt face the glyphs came out several hundred pixels
	## tall: a single voli's badge covered most of the court, and six of them
	## covered the match. The 2D badge was sized against a 20 px marker and this
	## one was never sized against anything.
	##
	## A badge is a note about a body, so it wants to be a fraction of that body
	## on screen -- roughly a head. That is about a tenth of what was here.
	fixed_size = true
	pixel_size = BADGE_PIXEL_SIZE * COGNITICON_SCALE
	font_size = 96
	outline_size = 10
	outline_modulate = Color(0.02, 0.02, 0.04, 0.85)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false


## Shows one cue, or hides the badge when there is nothing worth showing.
##
## Returns the cue's attention target kind so the caller can decide whether to
## drive the head as well -- the actor's `look_toward` belongs to the actor, and
## this component should not reach into it.
func show_cue(
	cue: Resource, head_anchor: Vector3, simulation_time: float = -1.0
) -> void:
	if cue == null or not BadgeModel.is_worth_drawing(cue):
		visible = false
		return
	var reading: Dictionary = BadgeModel.describe(cue)
	if reading.is_empty():
		visible = false
		return
	## The ambient tier draws its intent and stops there.
	##
	## An ambient cue is `committed` by construction, so running it through the
	## state vocabulary returns a diamond labelled COMMITTED for every voli on
	## court, permanently -- which is what shipped before this branch existed.
	## What it actually has to say is what this voli is doing, and the fade says
	## when it has finished saying it.
	if bool(reading.get("is_ambient", false)):
		var strength: float = cue.glyph_strength(simulation_time)
		if strength <= 0.01:
			visible = false
			_hide_mark()
			return
		## **A drawn mark where one exists, the character otherwise.**
		##
		## The blade family is drawn; the shields and hands are still standing in
		## as Unicode until they are. Branching on what has been drawn rather
		## than on the intent means each family switches over as it lands,
		## instead of the whole layer waiting for the last one.
		var intent := str(reading.get("intent", "watching"))
		## **The hand-off.** The eye and the intent mark share one slot and
		## trade it, rather than being drawn together -- a voli finishing
		## looking and starting doing is one continuous gesture, and `state`
		## already says which half they are in. Reading states get the eye;
		## once a voli has called or committed, the eye minimises away and the
		## intent takes the slot.
		if _draw_eye(cue, reading, strength, simulation_time):
			text = ""
			visible = true
			position = head_anchor + _screen_up() * MARK_LIFT_METERS
			return
		if _draw_mark(
			intent, float(reading.get("progress", 0.0)), strength,
			simulation_time - float(cue.starts_at), 0.0,
			CogniticonMotion.variant_for(str(cue.state), str(cue.affect)),
			CogniticonMotion.affect_grade(str(cue.state), str(cue.affect), false),
		):
			text = ""
			visible = true
			position = head_anchor + _screen_up() * MARK_LIFT_METERS
			return
		text = str(INTENT_GLYPHS.get(intent, "•"))
		var ambient_color := Color(reading.color)
		ambient_color.a = AMBIENT_ALPHA * strength
		modulate = ambient_color
		pixel_size = AMBIENT_PIXEL_SIZE * COGNITICON_SCALE
		position = head_anchor + _screen_up() * MARK_LIFT_METERS
		visible = true
		return
	## **The two tiers differ in loudness, not in language.**
	##
	## The badge tier used to draw its own alphabet: a diamond for `committed`,
	## a wedge for `calling`, a burst for `reacting`, a dashed ring for a voli
	## who cannot see. Five abstract shapes that have to be learned, sitting
	## beside a drawn vocabulary where a shield looks like a shield -- and
	## reported exactly as you would expect, as a mark on the court that the
	## viewer could not read at all.
	##
	## Worse, the two overlapped. `lost_sight` and `reacting` are what the eye's
	## own shock already says; `occluded` is the pupil already drifting off its
	## target; and `committed` is true of every ambient cue by construction, so
	## the commonest badge on court asserted almost nothing.
	##
	## So a punctuating cue is now the **same mark made loud** -- the voli's own
	## shield or blade or eye, at badge size and full strength, coloured by the
	## grade its state earns. Nothing new to learn, and the tier separation
	## survives as what it was always described as: an ambient mark is quiet and
	## a state badge is not.
	var grade := CogniticonMotion.affect_grade(
		str(cue.state), str(cue.affect), false
	)
	var loud := Color(1.0, 1.0, 1.0)
	if grade != "C":
		loud = loud.lerp(UIPalette.grade_color(grade, light_mode), 0.85)
	if _draw_eye(cue, reading, 1.0, simulation_time):
		text = ""
		visible = true
		_amplify(loud)
		position = head_anchor + _screen_up() * HEIGHT_ABOVE_HEAD_METERS
		return
	if _draw_mark(
		str(reading.get("intent", "watching")),
		float(reading.get("progress", 0.0)), 1.0, -1.0, 0.0,
		CogniticonMotion.variant_for(str(cue.state), str(cue.affect)), grade,
	):
		text = ""
		visible = true
		_amplify(loud)
		position = head_anchor + _screen_up() * HEIGHT_ABOVE_HEAD_METERS
		return
	## Nothing drawn for this intent yet, so the character stands in -- but with
	## the punctuation and trend it always carried, because those say things the
	## mark does not: a call, a question, a rising or falling read.
	var face := str(FACE_GLYPHS.get(str(reading.face), ""))
	var punctuation := str(reading.punctuation)
	var trend := str(TREND_GLYPHS.get(int(reading.trend_direction), ""))
	text = "%s%s%s%s" % [
		face, str(INTENT_GLYPHS.get(str(reading.get("intent", "watching")), "•")),
		punctuation, trend,
	]
	modulate = loud
	pixel_size = lerpf(
		BADGE_PIXEL_SIZE_QUIET, BADGE_PIXEL_SIZE_LOUD, float(reading.emphasis)
	) * COGNITICON_SCALE
	position = head_anchor + _screen_up() * HEIGHT_ABOVE_HEAD_METERS
	visible = true


## Push a drawn mark up to badge prominence: larger, at full strength, and
## wearing the grade its state earned.
##
## The one place the two tiers are allowed to differ, and it is a volume knob
## rather than a second vocabulary.
func _amplify(ink: Color) -> void:
	var boost := BADGE_PIXEL_SIZE_LOUD / AMBIENT_PIXEL_SIZE
	for part in [_backdrop, _mark, _mark_fill, _eye_outline, _eye_pupil, _eye_lead]:
		if part == null or not part.visible:
			continue
		part.pixel_size *= boost
		part.position *= boost
		var tint: Color = part.modulate
		part.modulate = Color(ink.r, ink.g, ink.b, minf(tint.a / MARK_ALPHA, 1.0))


## Which way is up **on screen**, in this billboard's own parent space.
##
## **"Above the head" is a screen claim, not a world one.** Offsetting along
## world +Y puts a mark above a voli only when the camera is level with the
## court. The match centre opens on a preset looking down from eight metres, and
## under that projection a world-vertical offset carries the mark up *and* away
## from the body -- which is why a mark drawn above a head reads as sitting
## behind and to one side of it. The higher the lift, the worse it gets, so the
## fix cannot be a smaller number.
##
## Taking the offset along the camera's own up vector instead means the mark
## lands directly above the head in the rendered image at any angle, because
## that is the definition of the camera's up. The body of this component is
## already billboarded for the same reason.
##
## Written now rather than when a dynamic camera arrives, because a camera that
## moves would otherwise slide every mark around its voli as it swung -- and a
## bug that only appears while the camera is in motion is the kind that gets
## blamed on the camera.
func _screen_up() -> Vector3:
	if not is_inside_tree():
		return Vector3.UP
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.UP
	var parent_3d := get_parent() as Node3D
	var up := camera.global_transform.basis.y
	if parent_3d != null:
		up = parent_3d.global_transform.basis.inverse() * up
	return up.normalized() if up.length_squared() > 0.0001 else Vector3.UP


func hide_cue() -> void:
	visible = false
	_hide_mark()


## The drawn marks, built once and shared by every voli on the court.
##
## Static because they are the same three textures twelve times over, and
## rasterising them per actor would be twelve times the work for one result.
static var _drawn: Dictionary = {}
static var _backdrops: Dictionary = {}
static var _blades_are_dark: bool = false

## This billboard's own two sprites: the mark, and the fill behind it.
##
## Two nodes rather than one, because the fill is a *region* of a second texture
## clipped from the bottom -- which is how the visual review draws it, and is
## what lets the outline stay whole while the interior rises. One node would
## need the fill baked into the mark, which is a texture per progress value.
var _mark: Sprite3D
var _mark_fill: Sprite3D
var _backdrop: Sprite3D


## The eye's three sprites, and the shared textures they wear.
static var _eye_parts: Dictionary = {}
var _eye_outline: Sprite3D
var _eye_pupil: Sprite3D
var _eye_lead: Sprite3D

## Which states are a voli *reading* rather than acting. Everything else has
## already chosen, and a chosen voli's mark is their intent.
const READING_STATES: Array[String] = [
	"searching", "recognizing", "deciding", "lost_sight", "reacting",
]

## Where the voli is looking, relative to their own facing, in radians -- told
## by the actor, which already computes and clamps it for the head. Carried as
## state for the same reason `ready_stance` is: it is a property of the voli,
## not of the cue being drawn.
var look_offset_radians: float = 0.0
var look_pitch_degrees: float = 0.0


## Draw the eye, or report that this cue is not a reading one.
## The eye does not take a backdrop. It is already the loudest thing the layer
## draws -- a lid, a pupil and a lead, three marks in one slot -- and a coloured
## ground behind it turns a face into a badge.
func _draw_eye(
	cue: Resource, reading: Dictionary, strength: float, simulation_time: float
) -> bool:
	var state := str(cue.state)
	if not READING_STATES.has(state):
		return false
	_ensure_eye()
	## **Doubt is `deciding`.** A voli between options is exactly what the
	## forked lead is for, and it is a state the model already publishes rather
	## than a confidence number invented for the drawing.
	var doubtful := state == "deciding"
	## A reaction's clock starts when its cue does. Negative before that, which
	## is the honesty gate: a mark may be wrong but never early.
	var shock_seconds := -1.0
	if state == "lost_sight" or state == "reacting":
		shock_seconds = simulation_time - float(cue.starts_at)
	var blink := CogniticonMotion.blink_closure(
		simulation_time, int(cue.player_id), str(cue.attention_hold)
	)
	var aperture := CogniticonMotion.aperture(
		float(reading.get("eye_openness", 1.0)), str(cue.attention_hold),
		doubtful, shock_seconds, blink,
	)
	if doubtful:
		aperture *= CogniticonMotion.doubt_waver(
			simulation_time, int(cue.player_id)
		)
	var shock: Dictionary = CogniticonMotion.shock_envelope(shock_seconds)
	## Colour is the rating scale: neutral is grade C, and a voli who has just
	## been beaten grades where anything else that went badly grades.
	var grade := CogniticonMotion.affect_grade(state, str(cue.affect), doubtful)
	var ink := Color(1.0, 1.0, 1.0)
	if grade != "C":
		ink = ink.lerp(
			UIPalette.grade_color(grade, light_mode),
			maxf(float(shock["colour_mix"]), 0.55 if doubtful else 0.0),
		)
	var alpha := MARK_ALPHA * strength
	var size := AMBIENT_PIXEL_SIZE * COGNITICON_SCALE * MARK_PIXEL_RATIO

	## **The lid is the eye's top border, so openness is a different drawing
	## rather than a transform.** A stroke cannot occlude, so a lid laid over a
	## socket reads as an eyebrow; the eye is bounded by its two lids instead,
	## and a closing lid both lowers and flattens because it is rotating toward
	## the viewer. Cached per aperture step, since eight of them serve the whole
	## court.
	var step := CogniticonMarks.aperture_step(aperture * (1.0 - blink))
	if _backdrop != null:
		_backdrop.visible = false
	_eye_outline.texture = _eye_parts["eye_%d" % step]
	_eye_outline.pixel_size = size
	_eye_outline.modulate = Color(ink.r, ink.g, ink.b, alpha)
	_eye_outline.scale = Vector3.ONE
	_eye_outline.visible = true

	## The pupil follows what the voli is watching. Twelve eyes turning to the
	## ball together is the largest "alive" gain in the layer and costs one
	## offset, because the actor already knows the heading.
	var offset := CogniticonMotion.pupil_offset(
		look_offset_radians, look_pitch_degrees,
		str(cue.visibility) == "occluded",
	)
	_eye_pupil.texture = _eye_parts["pupil"]
	_eye_pupil.pixel_size = size
	_eye_pupil.modulate = Color(ink.r, ink.g, ink.b, alpha)
	## Scaled by the aperture too, so a squinting eye does not have a pupil
	## standing proud of its own lids.
	_eye_pupil.position = Vector3(
		offset.x * EYE_SPAN_METERS, offset.y * EYE_SPAN_METERS * 0.4, 0.01
	)
	_eye_pupil.visible = blink < 0.6
	_eye_pupil.scale = Vector3.ONE * clampf(1.0 - blink, 0.05, 1.0)

	var lead := CogniticonMarks.DOUBT_LEAD if doubtful \
		else str(cue.attention_hold)
	_eye_lead.texture = _eye_parts.get(lead, _eye_parts["track"])
	_eye_lead.pixel_size = size
	_eye_lead.modulate = Color(ink.r, ink.g, ink.b, alpha * 0.92)
	_eye_lead.position = Vector3(EYE_SPAN_METERS * 1.15, 0.0, 0.0)
	_eye_lead.visible = true
	if _mark != null:
		_mark.visible = false
	if _mark_fill != null:
		_mark_fill.visible = false
	return true


## How wide the eye is on screen, in the units the sprites are placed in. Not a
## world measurement -- these are `fixed_size` sprites -- so it is tuned against
## the plate rather than derived.
const EYE_SPAN_METERS: float = 0.16


func _ensure_eye() -> void:
	if _eye_parts.is_empty() or _blades_are_dark != _mark_theme_is_dark():
		_eye_parts = CogniticonMarks.eye_part_textures(_mark_theme_is_dark())
	if _eye_outline == null:
		_eye_outline = _new_mark_sprite()
		_eye_pupil = _new_mark_sprite()
		_eye_lead = _new_mark_sprite()
		add_child(_eye_outline)
		add_child(_eye_lead)
		add_child(_eye_pupil)


## Draw this intent as a mark, or report that nothing is drawn for it yet.
func _draw_mark(
	intent: String, progress: float, strength: float,
	seconds_since_start: float = -1.0, course: float = 0.0,
	variant: String = "plain", grade: String = "C"
) -> bool:
	_ensure_marks()
	## **The variant is looked up, not required.** Only two intents have an
	## ascendant and a broken drawing today; every other family falls back to its
	## plain mark rather than vanishing. Asking for a variant that does not exist
	## has to be free, or adding the third family means touching the compiler.
	var texture: Texture2D = _drawn.get("%s|%s" % [intent, variant], null)
	if texture == null:
		texture = _drawn.get(intent, null)
	if texture == null:
		return false
	## **Arrival, so a mark swoops in rather than appearing.** Every mark used
	## to pop into existence, which is most of why they read as overlays rather
	## than as belonging to a body. Paced in real seconds -- see the window
	## budget in `CogniticonMotion` -- so it finishes whatever the flight does.
	var entry := {"alpha": 1.0, "offset": Vector2.ZERO,
		"rotation_degrees": 0.0, "scale": 1.0}
	if seconds_since_start >= 0.0:
		entry = CogniticonMotion.arrival(seconds_since_start)
	## And the charge: prominence rather than size, plus the course tilt that
	## lets one mark carry both what a voli is doing and which way -- the reason
	## a second concurrent mark is not needed.
	var charge: Dictionary = CogniticonMotion.charge(progress, course)
	var alpha := MARK_ALPHA * strength * float(entry["alpha"])
	var size := AMBIENT_PIXEL_SIZE * COGNITICON_SCALE * MARK_PIXEL_RATIO \
		* float(entry["scale"]) * float(charge["scale"])
	var swing := float(entry["rotation_degrees"]) \
		+ float(charge["rotation_degrees"])
	var offset: Vector2 = entry["offset"]

	_mark.texture = texture
	_mark.modulate = Color(1.0, 1.0, 1.0, alpha)
	_mark.pixel_size = size
	_mark.rotation_degrees = Vector3(0.0, 0.0, -swing)
	_mark.position = Vector3(offset.x * 0.2, offset.y * 0.2, 0.0)
	_mark.visible = true
	## Only the intents that accumulate carry a fill, and the review is explicit
	## that the fill is *distance covered* and never *likelihood of arriving* --
	## a hitter who will be late still fills, because they are running.
	## A broken mark does not fill. The fill is a region cut from the plain
	## drawing's own rectangle, so laying it over a shattered blade would put an
	## interior where the blade no longer is -- and a shattered blade reporting
	## run-up progress is a claim about an approach that has already failed.
	var fills := FILLING_INTENTS.has(intent) and progress > 0.001 \
		and variant != "broken"
	_mark_fill.visible = fills
	if fills:
		var region := CogniticonMarks.fill_region(progress)
		_mark_fill.texture = _drawn.get(
			"shield_fill" if intent in CogniticonMarks.SHIELD_INTENTS else "fill",
			_drawn.get("fill", null)
		)
		_mark_fill.region_enabled = true
		_mark_fill.region_rect = region
		_mark_fill.offset = CogniticonMarks.fill_offset(region)
		_mark_fill.modulate = Color(1.0, 1.0, 1.0, alpha * 0.72)
		_mark_fill.pixel_size = size
		_mark_fill.rotation_degrees = _mark.rotation_degrees
		_mark_fill.position = _mark.position
	for part in [_eye_outline, _eye_pupil, _eye_lead]:
		if part != null:
			part.visible = false
	_draw_backdrop(intent, variant, grade, size, alpha)
	return true


## **Where a rating lives, and where a rally that came off lives.**
##
## Both behind the mark, because both were asking for the same thing. Tinting
## the ink would spend the contrast that lets one ink work on any ground -- a
## mark above a head sits against the lit court on one frame and the dark
## surround on the next -- and drawing success into each family's paths meant
## every family owing two more path lists for no shared meaning.
##
## Sized per family. `run_mark_extent_probe` put the spread across the
## vocabulary at 64%: one radius for everything would make the same grade read
## louder behind a shield than behind a blade, which is the opposite of what a
## rating scale is for.
func _draw_backdrop(
	intent: String, variant: String, grade: String, size: float, alpha: float
) -> void:
	if _backdrop == null:
		return
	## Grade C is *nothing to report*, and a neutral disc behind every one of
	## twelve volis is twelve pieces of furniture. It draws when the rally has
	## something to say -- a grade off neutral, or a variant off plain.
	if grade == "C" and variant == "plain":
		_backdrop.visible = false
		return
	var texture: Texture2D = _backdrops.get(variant, null)
	if texture == null:
		_backdrop.visible = false
		return
	var tint := UIPalette.grade_color(grade, light_mode)
	_backdrop.texture = texture
	_backdrop.pixel_size = size * CogniticonMarks.backdrop_scale(intent)
	_backdrop.modulate = Color(
		tint.r, tint.g, tint.b, BACKDROP_ALPHA * alpha / maxf(MARK_ALPHA, 0.001)
	)
	_backdrop.rotation_degrees = Vector3.ZERO
	_backdrop.position = _mark.position
	_backdrop.visible = true


## How solid the ground behind a mark is.
##
## Below the ink deliberately. The backdrop is a *ground*, and one that competes
## with the mark it is behind has stopped being a backdrop -- which is the whole
## reason the rating went here rather than into the ink.
const BACKDROP_ALPHA: float = 0.55


## Which intents accumulate, and therefore fill. A blade fills as a hitter
## covers their run-up; a shield fills as a wall closes. Everything else has no
## progress to show and draws plain.
const FILLING_INTENTS: Array[String] = [
	"approaching", "blocking", "covering",
]


## How much larger a drawn mark is than the character it replaces.
##
## A glyph is drawn at a font size and fills a fraction of its em box; a mark
## fills its own canvas edge to edge. Matched by eye against the plate so the
## two tiers keep the relationship the gate asserts -- the mark reads at the
## size the character was *supposed* to, rather than at the size it managed.
const MARK_PIXEL_RATIO: float = 0.82

## How far above the crown the mark sits, in metres.
##
## **The reason a mark felt detached from its voli.** It was centred *on*
## `_cognition_head_height`, which is the scalp -- so half the mark overlapped
## the head and half towered above it, and at `fixed_size` that half does not
## shrink with distance. A big shape straddling the top of a head reads as
## something hovering near the voli rather than as something belonging to them.
##
## Sitting it just clear of the crown instead, with the size down, puts the ink
## in the space directly above the head where a thought bubble goes. Small and
## in metres: the mark is screen-relative and this is not, so a large gap would
## open up as the camera pulled back.
## Half the mark hangs below its own centre, so the lift has to clear the crown
## *and* that half -- at 0.13 the grip sat on the voli's head. Sized against the
## badge tier's own 0.30, which has been sitting above heads without complaint.
const MARK_LIFT_METERS: float = 0.34

## **A drawn mark is opaque; the character it replaced was not.**
##
## `AMBIENT_ALPHA` is 0.40, and applying it here would have thrown away the
## whole reason the marks are drawn in ink and halo: the contrast *is* the
## legibility, and fading it to 40% puts back the problem the ink was chosen to
## solve. The two-tier rule survives elsewhere -- an ambient mark is a thin
## outline where a state badge is a solid glyph, so the badge still carries more
## weight at the same opacity.
##
## The fill sits under the outline at a lower share, so a full blade still reads
## as an edge with an interior rather than as a solid slab.
const MARK_ALPHA: float = 0.76


func _hide_mark() -> void:
	if _backdrop != null:
		_backdrop.visible = false
	if _mark != null:
		_mark.visible = false
	if _mark_fill != null:
		_mark_fill.visible = false
	for part in [_eye_outline, _eye_pupil, _eye_lead]:
		if part != null:
			part.visible = false


func _ensure_marks() -> void:
	if _drawn.is_empty() or _blades_are_dark != _mark_theme_is_dark():
		_blades_are_dark = _mark_theme_is_dark()
		## Every family that has been drawn, in one table. The renderer asks
		## this rather than a family name, so a family switches from its
		## Unicode stand-in to its mark the moment it is added here.
		_drawn = CogniticonMarks.blade_textures(_blades_are_dark)
		var shields: Dictionary = CogniticonMarks.shield_textures(_blades_are_dark)
		_drawn["shield_fill"] = shields["fill"]
		for intent in CogniticonMarks.SHIELD_INTENTS:
			_drawn[intent] = shields[intent]
		for intent in CogniticonMarks.HAND_INTENTS:
			_drawn[intent] = CogniticonMarks.hand_textures(_blades_are_dark)[intent]
		## And the variants, keyed `intent|variant`. Merged into the same table
		## rather than kept beside it so the lookup in `_draw_mark` stays one
		## dictionary read with one fallback, and so a family that gains a variant
		## later needs no new branch anywhere.
		_drawn.merge(CogniticonMarks.blade_variant_textures(_blades_are_dark))
		_drawn.merge(CogniticonMarks.shield_variant_textures(_blades_are_dark))
		## The backdrops carry no ink, so they are theme-independent: they are
		## drawn white and tinted by the grade at draw time. Keyed apart from the
		## marks so a variant name can never collide with an intent name.
		_backdrops = CogniticonMarks.backdrop_textures()
	if _mark == null:
		_backdrop = _new_mark_sprite()
		_mark_fill = _new_mark_sprite()
		_mark = _new_mark_sprite()
		## Added in draw order, because every one of these sets `no_depth_test`
		## and a sprite with no depth test is drawn in the order its parent lists
		## it. Backdrop, then fill, then outline: the ground first, then the
		## interior, then the edge that keeps the blade crisp as the fill rises
		## past it.
		add_child(_backdrop)
		add_child(_mark_fill)
		add_child(_mark)


func _new_mark_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.fixed_size = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.transparent = true
	sprite.shaded = false
	sprite.visible = false
	return sprite


## Which ink the marks are drawn in.
##
## Told, not derived. `UIPalette` is a table rather than a state -- every call
## site passes the mode in -- so a billboard asking it "which theme is on" would
## be inventing a second answer to a question the actor is already handed by
## `apply_ui_palette`. Defaulted to Mikasa because that is what the match centre
## opens in.
var light_mode: bool = false


func _mark_theme_is_dark() -> bool:
	return not light_mode
