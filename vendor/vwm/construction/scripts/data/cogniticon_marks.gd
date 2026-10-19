class_name CogniticonMarks
extends RefCounted

## The cogniticons as drawn marks, not as characters.
##
## `docs/design/COGNITICONS.md` and the visual review that went with it specify a
## vocabulary of **drawn** marks: shields for the four ways of dealing with their
## ball, blades for the three ways of doing something to it, hands for the pivot
## and the honest blank. What shipped was nine Unicode characters standing in for
## them -- `⛊ ⛉ ⛨ ⛰ ⇧ ⇡ ⬆ ⌒ •` -- in a `Label3D`.
##
## The stand-ins map one-to-one onto the designed marks, which is why every probe
## written against them reported the vocabulary as present. It is present as a
## placeholder. Three things the design asks for cannot be said with a character
## at all, and all three are the difference between a live read and a set of
## symbols:
##
## - a blade **fills from the bottom** as a hitter covers their run-up
## - a mark is **dashed** to mean available-but-not-committed, and dashed again
##   at lower opacity to mean it belongs to the other side
## - the family is carried by *shape*, so a shield and a blade differ at a
##   glance rather than by which arrow you are looking at
##
## This module is the blade family and the fill. Shields and hands follow; they
## need curve flattening, which the stroking below is already written for.
##
## ## Why rasterise rather than build geometry
##
## The marks are stroke-only paths in a 54x54 box. As geometry each one is a
## ribbon mesh with mitred joins and round caps -- more code, and it would have
## to be rebuilt whenever a width changed. As a texture each is a few hundred
## pixels of ink generated once at load and shared by all twelve volis, and the
## fill becomes a region on a sprite rather than a per-frame redraw.
##
## The cost is that a stroke width is baked in. That is acceptable here because
## the marks are drawn at one size by construction -- `fixed_size` billboards
## whose scale is a share of the viewport, not a world measurement.

## The design space every path below is written in, matching the review's own
## `viewBox="0 0 54 54"`. Keeping the numbers as authored means a path can be
## copied across without arithmetic, and arithmetic on a copied path is how a
## drawing quietly stops matching the thing it was approved as.
const CANVAS: float = 54.0
## Rasterised at four times that. Enough that the round caps do not stair-step
## at the size a billboard actually draws, and small enough that generating
## three of them at load is not noticeable.
const SCALE: int = 4
const PIXELS: int = 216

## **Ink and halo, not a family colour.**
##
## The review gives each family its own hue -- coral blades, blue shields, green
## hands. Drawn at size on a warm apricot court those hues sit *in* the palette
## rather than on top of it, and a mark that has to be found is not a mark that
## can be glanced at. So the ink is the one thing guaranteed to be nobody else's
## colour: white on Mikasa, near-black on Molten, at full strength.
##
## The family survives in the shape, which is where the review puts the weight
## anyway -- a shield and a blade differ at a glance without either being
## coloured, and losing the hue costs nothing that shape was not already saying.
const INK_DARK := Color(1.0, 0.99, 0.96)
const INK_LIGHT := Color(0.08, 0.09, 0.10)

## And the halo, which is what makes one ink work everywhere.
##
## A cogniticon floats above a head, so its ground is whatever happens to be
## behind it -- the lit court on one frame and the dark surround on the next.
## No single ink survives both. The `Label3D` tier already solved this with a
## 10 px outline in near-black; the drawn marks get the same idea, which is why
## a thinner stroke is affordable here: contrast is doing the work that width
## was doing before.
const HALO_DARK := Color(0.05, 0.07, 0.09, 0.85)
const HALO_LIGHT := Color(1.0, 0.98, 0.93, 0.85)
## How far the halo stands out past the ink, in design units, either side.
const HALO_SPREAD: float = 1.7

## The blade, as authored: `<rect x="21" y="6" width="12" height="30" rx="2">`
## over a guard `M13 40 H41` and a grip `M27 40 V48`.
const BLADE_RECT := Rect2(21.0, 6.0, 12.0, 30.0)
const BLADE_RADIUS: float = 2.0
## **Thinner than the review, because the ink is stronger than the review's.**
##
## 3.0 and 3.2 were drawn in a mid-tone family hue at partial opacity, where a
## stroke needs weight to register. At full-strength white or black over a halo
## it does not, and the same width then reads as a heavy sticker rather than a
## mark. Taken down about a quarter; the contrast pays for it.
##
## This is also what makes the eye possible: a pupil inside an outline only
## reads if the outline is thin enough to leave an interior.
const BLADE_STROKE: float = 2.2
const GUARD_STROKE: float = 2.4
## The serve is the same blade carried lower with a toss above it, so the rect
## moves rather than a second shape being invented: `x=21 y=14 w=12 h=28`, the
## guard at `M13 12 H41`, and the ball a filled `r=3.6` circle at `(27, 6)`.
const SERVE_RECT := Rect2(21.0, 14.0, 12.0, 28.0)
const SERVE_TOSS_CENTRE := Vector2(27.0, 6.0)
const SERVE_TOSS_RADIUS: float = 3.6
## `stroke-dasharray="5 4"`, which is what says *available* rather than
## *committed* on `preparing_attack`.
const DASH_ON: float = 5.0
const DASH_OFF: float = 4.0


## Which intents this module draws today.
##
## The renderer branches on this rather than on a family name, so each family
## switches from its Unicode stand-in to its drawn mark as it lands, instead of
## the whole layer waiting for the last one. Adding the shields means adding
## four entries here and their paths below; nothing else has to know.
const BLADE_INTENTS: Array[String] = [
	"preparing_attack", "approaching", "serving",
]


## ## The eye family -- where the voli is looking, and how hard
##
## A wider canvas than the intent marks, because an eye and its lead line are
## not square: `viewBox="0 0 70 56"` in the review. The three differ only in
## what leaves the eye, which is the whole design -- one eye, three leads:
##
## | mark | lead | means |
## |---|---|---|
## | `glance` | three short flicks, the middle longest | looked and moved on |
## | `track` | a dashed line | following it |
## | `fixed` | a solid line with an arrowhead | locked on, will not release |
##
## The pupil sits at x = 43 against an eye centred on 35, so it is **off-centre
## toward the lead**. That is the part that makes an eye read as looking rather
## than as staring out of the screen, and it is the reason the stroke had to come
## down: a 3-unit outline on a 9-unit radius leaves almost no interior for a
## 3.6-unit pupil to be seen in.
const EYE_CANVAS := Vector2(70.0, 56.0)
const EYE_CENTRE := Vector2(35.0, 28.0)
const EYE_RADII := Vector2(17.0, 9.0)
const PUPIL_CENTRE := Vector2(43.0, 28.0)
const PUPIL_RADIUS: float = 3.6
const EYE_STROKE: float = 2.0
## The one mark in the family drawn heavier, because "locked on" is the loudest
## thing this axis has to say.
const EYE_FIXED_STROKE: float = 2.4

const ATTENTION_MARKS: Array[String] = ["glance", "track", "fixed"]
## And the fourth, which the review does not draw because the review had colour
## to spend on doubt and this vocabulary does not.
##
## **Certainty is one lead; doubt is a lead that forks.** Two prongs aimed at
## the two things a voli cannot choose between -- which is better than a hue on
## every count that matters here: it survives any court colour, it says *what*
## is doubted rather than merely that something is, it scales by widening, and
## it composes with a lead vocabulary that already exists.
const DOUBT_LEAD: String = "doubt"
const DOUBT_FORK_DEGREES: float = 26.0
const LEAD_MARKS: Array[String] = ["glance", "track", "fixed", "doubt"]


## Where the eye's ink has to move to sit in the middle of its own canvas.
##
## **A mark is placed by its texture's centre, so ink that is not centred in the
## texture is a mark that is not where it looks like it should be.** The review's
## eye is drawn against the left of its box -- the ellipse starts at x = 18 and
## the arrowhead runs to 69, so the ink's midpoint is 43.5 in a canvas whose
## middle is 35. Rasterised as authored and hung above a head, every eye would
## float eight units to the right of the voli it belongs to.
##
## The blades do not have this problem -- their ink is symmetric about 27 in a
## 54-wide box -- which is why it went unnoticed until the eye arrived. Applied
## at rasterise time rather than by editing the coordinates, so the paths stay
## the ones that were approved.
const EYE_INK_SHIFT := Vector2(-8.5, 0.0)


## Where the pupil ends up once the shift above has been applied.
##
## Exposed because a caller that wants to *find* the pupil -- the gate that
## checks it is still legible -- must not do this addition itself. It did, once:
## the shift was added here and the gate went on sampling the authored column,
## which after the move is the eye's outer edge rather than the pupil. It
## reported the pupil gone, which was true of the place it was looking and false
## of the drawing.
##
## One function, so the mark and the measurement cannot disagree about where the
## pupil is.
static func pupil_centre() -> Vector2:
	return PUPIL_CENTRE + EYE_INK_SHIFT


## Every attention texture, by the hold it draws.
##
## The **composed** eye: outline, pupil and lead flattened into one image. Kept
## alongside `eye_part_textures` below rather than replaced by it, because the
## two answer different questions. This one is the drawing as approved -- what a
## static plate shows and what the pupil-legibility gate measures. The parts are
## what a live voli is assembled from, and a gate run against those would be
## checking three sprites' transforms rather than whether the mark reads.
static func attention_textures(dark_theme: bool) -> Dictionary:
	var out := {}
	for mark in ATTENTION_MARKS:
		out[mark] = _eye(mark, dark_theme)
	return out


static func _eye(mark: String, dark_theme: bool) -> ImageTexture:
	var width := int(EYE_CANVAS.x) * SCALE
	var height := int(EYE_CANVAS.y) * SCALE
	var stroke := EYE_FIXED_STROKE if mark == "fixed" else EYE_STROKE
	var paths: Array = [
		{"points": _ellipse(EYE_CENTRE, EYE_RADII), "closed": true,
			"width": stroke, "dash": 0.0},
	]
	match mark:
		"glance":
			paths.append({"points": _line(56.0, 20.0, 64.0, 20.0),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": _line(56.0, 28.0, 67.0, 28.0),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": _line(56.0, 36.0, 64.0, 36.0),
				"closed": false, "width": stroke, "dash": 0.0})
		"track":
			paths.append({"points": _line(54.0, 28.0, 67.0, 28.0),
				"closed": false, "width": stroke, "dash": 3.0})
		_:
			paths.append({"points": _line(54.0, 28.0, 68.0, 28.0),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": PackedVector2Array([
				Vector2(64.0, 23.0), Vector2(69.0, 28.0), Vector2(64.0, 33.0),
			]), "closed": false, "width": stroke, "dash": 0.0})
	var discs: Array = [{"centre": PUPIL_CENTRE, "radius": PUPIL_RADIUS}]
	for path in paths:
		var moved := PackedVector2Array()
		for point in PackedVector2Array(path["points"]):
			moved.append(point + EYE_INK_SHIFT)
		path["points"] = moved
	for disc in discs:
		disc["centre"] = Vector2(disc["centre"]) + EYE_INK_SHIFT
	return _composite(width, height, paths, discs, [], dark_theme)


## ## The eyelid *is* the eye's top border
##
## Two earlier attempts got this wrong in instructive ways. The first scaled
## the whole outline vertically, which squashes an eyeball. The second drew a
## fixed socket with a lid sprite moving over it, and the lid read as an
## eyebrow -- because a stroke cannot occlude, so a lid laid on top of an
## outline is just a second line near it.
##
## **The eye has no outline of its own.** Its shape is bounded by two lids
## meeting at the corners, and where those lids sit *is* how open it is:
##
## | expression | upper lid | reads as |
## |---|---|---|
## | shocked | bowed high, rounding the eye out | wide, startled |
## | watching | roughly flush with the socket's natural top | open, neutral |
## | narrowed | lower, and **flatter** | focus, suspicion |
##
## The flattening is the part that makes it read in implied three dimensions.
## A closing lid rotates toward the viewer, so you see more of its face and
## less of its edge, and its curve goes slack. Falling out of a single bow
## height per lid rather than being a second parameter is what keeps it one
## number: a low bow is automatically a flat one.
##
## Generated per aperture step and cached rather than built per frame -- eight
## steps is finer than the eye can show at playback size, and eight textures is
## nothing against twelve volis asking for them.
const EYE_APERTURE_STEPS: int = 8
const EYE_APERTURE_MIN: float = 0.34
const EYE_APERTURE_MAX: float = 1.62
## How far the lower lid moves relative to the upper. Much less: a squint is
## mostly the top coming down, and a lower lid that travelled as far would read
## as a mouth closing rather than an eye.
const LOWER_LID_SHARE: float = 0.45


## One eye, bounded by two lids at the given openness.
##
## `openness` is the aperture: 1.0 is the almond at rest, below that is a
## narrowing lid, above it a retracting one.
static func eye_at(openness: float, dark_theme: bool) -> ImageTexture:
	var size := int(EYE_RADII.x * 2.0 + 8.0) * SCALE
	var half := float(size) / float(SCALE) * 0.5
	var span := EYE_RADII.x
	var upper_bow := EYE_RADII.y * clampf(openness, 0.05, 2.0)
	var lower_bow := EYE_RADII.y * lerpf(
		1.0 - LOWER_LID_SHARE, 1.0, clampf(openness, 0.0, 2.0) * 0.5 + 0.5
	)
	var left := Vector2(half - span, half)
	var right := Vector2(half + span, half)
	## A cubic whose control points ride the bow, so a low bow is a flat curve
	## and a high one is a round arc -- one number for both.
	var lid_upper := _cubic(
		left,
		Vector2(half - span * 0.52, half - upper_bow * 1.34),
		Vector2(half + span * 0.52, half - upper_bow * 1.34),
		right
	)
	var lid_lower := _cubic(
		right,
		Vector2(half + span * 0.52, half + lower_bow * 1.28),
		Vector2(half - span * 0.52, half + lower_bow * 1.28),
		left
	)
	return _composite(size, size, [
		{"points": _join([lid_upper, lid_lower]), "closed": true,
			"width": EYE_STROKE, "dash": 0.0},
	], [], [], dark_theme)


## Which cached step an openness lands in. Exposed so the renderer and any gate
## agree about the bucketing rather than each rounding it their own way.
static func aperture_step(openness: float) -> int:
	var span := EYE_APERTURE_MAX - EYE_APERTURE_MIN
	var t := clampf((openness - EYE_APERTURE_MIN) / maxf(span, 0.001), 0.0, 1.0)
	return int(round(t * float(EYE_APERTURE_STEPS - 1)))


static func aperture_for_step(step: int) -> float:
	var t := float(clampi(step, 0, EYE_APERTURE_STEPS - 1)) \
		/ float(EYE_APERTURE_STEPS - 1)
	return lerpf(EYE_APERTURE_MIN, EYE_APERTURE_MAX, t)


## The eye in separable parts, because its parts move independently.
##
## The eye bodies are one per aperture step -- the lids are the shape, so they
## cannot be a transform on a shared texture. The pupil and the leads still can.
static func eye_part_textures(dark_theme: bool) -> Dictionary:
	var parts := {"pupil": _eye_pupil(dark_theme)}
	for step in range(EYE_APERTURE_STEPS):
		parts["eye_%d" % step] = eye_at(aperture_for_step(step), dark_theme)
	for lead in LEAD_MARKS:
		parts[lead] = _eye_lead(lead, dark_theme)
	return parts


static func _eye_pupil(dark_theme: bool) -> ImageTexture:
	var size := int(PUPIL_RADIUS * 2.0 + 8.0) * SCALE
	var centre := Vector2(float(size) / float(SCALE) * 0.5, float(size) / float(SCALE) * 0.5)
	return _composite(
		size, size, [], [{"centre": centre, "radius": PUPIL_RADIUS}], [], dark_theme
	)


## A lead, drawn from the origin rightward so the sprite can simply be rotated
## to aim it. Every lead shares that convention, which is what lets the renderer
## swap one for another without moving anything.
static func _eye_lead(mark: String, dark_theme: bool) -> ImageTexture:
	var width := 34 * SCALE
	var height := 34 * SCALE
	var origin := Vector2(4.0, 17.0)
	var stroke := EYE_FIXED_STROKE if mark == "fixed" else EYE_STROKE
	var paths: Array = []
	match mark:
		"glance":
			paths.append({"points": _line(origin.x, origin.y - 8.0, origin.x + 8.0, origin.y - 8.0),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": _line(origin.x, origin.y, origin.x + 11.0, origin.y),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": _line(origin.x, origin.y + 8.0, origin.x + 8.0, origin.y + 8.0),
				"closed": false, "width": stroke, "dash": 0.0})
		"track":
			paths.append({"points": _line(origin.x, origin.y, origin.x + 13.0, origin.y),
				"closed": false, "width": stroke, "dash": 3.0})
		"doubt":
			## The fork. Two prongs from one root, so it reads as one look that
			## cannot decide rather than as two separate looks.
			var spread := deg_to_rad(DOUBT_FORK_DEGREES)
			for sign in [-1.0, 1.0]:
				var tip := origin + Vector2(cos(spread * sign), sin(spread * sign)) * 15.0
				paths.append({"points": PackedVector2Array([
					origin + Vector2(4.0, 0.0), tip,
				]), "closed": false, "width": stroke, "dash": 3.0})
			paths.append({"points": _line(origin.x, origin.y, origin.x + 4.0, origin.y),
				"closed": false, "width": stroke, "dash": 0.0})
		_:
			paths.append({"points": _line(origin.x, origin.y, origin.x + 14.0, origin.y),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": PackedVector2Array([
				Vector2(origin.x + 10.0, origin.y - 5.0),
				Vector2(origin.x + 15.0, origin.y),
				Vector2(origin.x + 10.0, origin.y + 5.0),
			]), "closed": false, "width": stroke, "dash": 0.0})
	return _composite(width, height, paths, [], [], dark_theme)


static func _line(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2)])


## An ellipse as a closed polyline, for the same reason the rounded rect is one:
## one path representation, so dashes and caps behave identically everywhere.
static func _ellipse(centre: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	## Enough segments that the curve is smooth at four times design size and
	## few enough that the stroker is not visiting the same pixels forty times.
	for step in range(48):
		var angle := TAU * float(step) / 48.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


## A cubic Bezier as a polyline, so the shields and hands can be authored as the
## review authored them.
##
## The blade family is straight lines and a rounded rect; every other family in
## the vocabulary has curves, and the review writes them as SVG cubics. Rather
## than redraw them as arcs -- which is how a copied path quietly stops matching
## the thing that was approved -- they are flattened here and stroked by the same
## code as everything else.
##
## Sixteen segments per curve. The largest curve in the set spans about 34 design
## units, so that is a chord of roughly two units before scaling, which
## disappears under a stroke twice that wide.
static func _cubic(
	from: Vector2, control_a: Vector2, control_b: Vector2, to: Vector2
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(17):
		var t := float(step) / 16.0
		var inverse := 1.0 - t
		points.append(
			from * inverse * inverse * inverse
			+ control_a * 3.0 * inverse * inverse * t
			+ control_b * 3.0 * inverse * t * t
			+ to * t * t * t
		)
	return points


## Join several point runs into one open polyline.
static func _join(runs: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for run in runs:
		for point in PackedVector2Array(run):
			if points.size() > 0 and points[points.size() - 1].distance_to(point) < 0.001:
				continue
			points.append(point)
	return points


## ## The shield family -- the four ways of dealing with their ball
##
## One shield outline, differentiated by what is inside it. Exactly as authored:
## `M27 6 L46 13 V29 C46 40 36 46 27 49 C18 46 8 40 8 29 V13 Z`, with the
## blocking variant sitting lower so its prongs can rise over the top edge.
const SHIELD_INTENTS: Array[String] = [
	"defending", "covering", "receiving", "blocking",
]
const SHIELD_STROKE: float = 2.4
const SHIELD_MARK_STROKE: float = 2.2


static func shield_textures(dark_theme: bool) -> Dictionary:
	var out := {}
	for intent in SHIELD_INTENTS:
		out[intent] = _shield(intent, dark_theme)
	out["fill"] = _shield_fill(dark_theme)
	return out


static func _shield_outline(lowered: bool) -> PackedVector2Array:
	var top := 10.0 if lowered else 6.0
	var shoulder := 17.0 if lowered else 13.0
	var waist := 31.0 if lowered else 29.0
	var curve_in := 41.0 if lowered else 40.0
	return _join([
		PackedVector2Array([
			Vector2(27.0, top), Vector2(46.0, shoulder), Vector2(46.0, waist),
		]),
		_cubic(
			Vector2(46.0, waist), Vector2(46.0, curve_in),
			Vector2(36.0, 46.0), Vector2(27.0, 49.0)
		),
		_cubic(
			Vector2(27.0, 49.0), Vector2(18.0, 46.0),
			Vector2(8.0, curve_in), Vector2(8.0, waist)
		),
		PackedVector2Array([Vector2(8.0, shoulder), Vector2(27.0, top)]),
	])


static func _shield(intent: String, dark_theme: bool) -> ImageTexture:
	var lowered := intent == "blocking"
	var paths: Array = [
		{"points": _shield_outline(lowered), "closed": true,
			"width": SHIELD_STROKE, "dash": 0.0},
	]
	match intent:
		"covering":
			## A chevron collapsing inward -- the shape of a side folding in
			## behind their own hitter.
			paths.append({"points": PackedVector2Array([
				Vector2(16.0, 24.0), Vector2(27.0, 34.0), Vector2(38.0, 24.0),
			]), "closed": false, "width": SHIELD_MARK_STROKE, "dash": 0.0})
		"receiving":
			## The platform, angled across the shield. The one mark in the
			## family that is a *surface* rather than a direction.
			paths.append({"points": _line(14.0, 30.0, 40.0, 22.0),
				"closed": false, "width": 2.9, "dash": 0.0})
		"blocking":
			## Three prongs over the top edge: hands above the tape, which is
			## the only thing a blocker is for.
			paths.append({"points": _line(18.0, 8.0, 18.0, 19.0),
				"closed": false, "width": SHIELD_MARK_STROKE, "dash": 0.0})
			paths.append({"points": _line(27.0, 5.0, 27.0, 17.0),
				"closed": false, "width": SHIELD_MARK_STROKE, "dash": 0.0})
			paths.append({"points": _line(36.0, 8.0, 36.0, 19.0),
				"closed": false, "width": SHIELD_MARK_STROKE, "dash": 0.0})
	return _composite(PIXELS, PIXELS, paths, [], [], dark_theme)


## The shield's interior, for the fill. "The shield family fills the same way,
## from the bottom" -- so a wall that never closed is a shield that never
## filled, which is the same honest lateness the blade already tells.
static func _shield_fill(dark_theme: bool) -> ImageTexture:
	var ink := INK_DARK if dark_theme else INK_LIGHT
	var image := _layer(PIXELS, PIXELS, ink)
	var outline := _shield_outline(false)
	## Scanline fill of the flattened outline. Cheap, exact enough at four times
	## design size, and it cannot spill past the shape the way an inset
	## rectangle would.
	for y in range(image.get_height()):
		var row := float(y) / float(SCALE)
		var crossings: Array[float] = []
		for index in range(outline.size()):
			var a := outline[index]
			var b := outline[(index + 1) % outline.size()]
			if (a.y <= row and b.y > row) or (b.y <= row and a.y > row):
				crossings.append(a.x + (row - a.y) / (b.y - a.y) * (b.x - a.x))
		crossings.sort()
		var pair := 0
		while pair + 1 < crossings.size():
			var from := int(crossings[pair] * float(SCALE))
			var to := int(crossings[pair + 1] * float(SCALE))
			for x in range(maxi(from, 0), mini(to, image.get_width() - 1) + 1):
				image.set_pixel(x, y, ink)
			pair += 2
	return ImageTexture.create_from_image(image)


## ## The hands -- the pivot, and the honest blank
##
## `setting` is two nested arcs, hands under the ball. `watching` is a small
## soft disc: deliberately nothing in particular, and deliberately present,
## because without a mark "no opinion" reads as "not implemented".
const HAND_INTENTS: Array[String] = ["setting", "watching"]
const WATCHING_RADIUS: float = 5.5


static func hand_textures(dark_theme: bool) -> Dictionary:
	return {
		"setting": _composite(PIXELS, PIXELS, [
			{"points": _cubic(
				Vector2(12.0, 34.0), Vector2(12.0, 20.0),
				Vector2(20.0, 12.0), Vector2(27.0, 12.0)
			), "closed": false, "width": 2.5, "dash": 0.0},
			{"points": _cubic(
				Vector2(27.0, 12.0), Vector2(34.0, 12.0),
				Vector2(42.0, 20.0), Vector2(42.0, 34.0)
			), "closed": false, "width": 2.5, "dash": 0.0},
			{"points": _join([
				_cubic(Vector2(20.0, 40.0), Vector2(20.0, 32.0),
					Vector2(23.0, 27.0), Vector2(27.0, 27.0)),
				_cubic(Vector2(27.0, 27.0), Vector2(31.0, 27.0),
					Vector2(34.0, 32.0), Vector2(34.0, 40.0)),
			]), "closed": false, "width": 2.2, "dash": 0.0},
		], [], [], dark_theme),
		"watching": _composite(
			PIXELS, PIXELS, [],
			[{"centre": Vector2(27.0, 27.0), "radius": WATCHING_RADIUS}],
			[], dark_theme
		),
	}


## ## Variants: how a mark says the thing went well, or did not
##
## A family says what a voli is doing. A **variant** says how it is going, and
## the rally's own events choose it -- no mark reads another mark, so a shattered
## shield is shattered because the resolver says the ball went through it, not
## because some other voli's blade was drawn nearby.
##
## | | ascendant | broken |
## |---|---|---|
## | where it lives | **behind** the mark, in the backdrop | **in** the mark |
## | blade | flares | fractures across its midpoint |
## | shield | flares | fractures apex to hem |
##
## **The two directions are not symmetrical, and that is the design.** Succeeding
## is something that happens *around* a voli -- the mark is unchanged and the
## ground behind it catches light. Failing happens *to* the mark: it breaks, and
## the pieces fall away from each other.
##
## The first version drew both into the ink -- flame tongues off a blade's edge,
## rays off a shield's rim -- which meant every family owed two more path lists,
## and a flaming blade and a shining shield had nothing in common but intent.
## One flare behind any mark costs one drawing for the whole vocabulary and says
## the same thing about every family.
const VARIANTS: Array[String] = ["plain", "ascendant", "broken"]


## ## The break, as a fracture rather than a cut
##
## A shape parted along a straight line reads as *two shapes*, which is what the
## first attempt produced: a shield in halves and a blade drawn in two pieces.
## A **jagged** seam is what makes it read as one thing that broke, because the
## two edges are complementary -- the teeth of one side are the gaps of the
## other, and the eye reassembles them.
##
## The seams run where the shape is weakest, which is also where they read:
## **apex to hem** down a shield, and **across the midpoint** of a blade.
const FRACTURE_TEETH: int = 7
const FRACTURE_JAG: float = 2.3
## How far the two pieces separate along the break, and how far the loose one
## falls. Both matter: parted-but-level reads as a shape with a crack in it,
## and it is *falling away* that says the thing failed.
const FRACTURE_PART: float = 2.1
const FRACTURE_FALL: float = 3.4
const FRACTURE_TURN_DEGREES: float = 9.0


## A zigzag from `from` to `to`, deviating either side of the straight line.
##
## Deterministic rather than random: the same mark has to rasterise identically
## every run, and a break that is a different shape each time reads as noise
## rather than as a property of the drawing.
static func _jagged(
	from: Vector2, to: Vector2, teeth: int = FRACTURE_TEETH,
	jag: float = FRACTURE_JAG
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var normal := (to - from).normalized()
	normal = Vector2(-normal.y, normal.x)
	for step in range(teeth + 1):
		var t := float(step) / float(teeth)
		var side := 1.0 if step % 2 == 1 else -1.0
		## The ends stay on the line so the seam meets the outline it cuts;
		## a tooth at the endpoint would leave the break hanging off the edge.
		var amount := 0.0 if step == 0 or step == teeth else jag * side
		## The middle teeth are the deepest, which is where a break opens widest.
		amount *= 1.0 - absf(t - 0.5)
		out.append(from.lerp(to, t) + normal * amount)
	return out


## Which side of the cut a point is on, with **no third answer**.
##
## `signf` has one, and it is what made a vertical break silently do nothing: a
## shield's apex sits exactly at x=27 and a diamond's corners exactly on their
## own axis, so the vertex the cut is aimed through scored zero, the walk saw no
## sign change, and the outline came back in one piece. The mark rendered as
## whole and the failure was invisible -- there was no error, just an unbroken
## shield labelled "fractured".
##
## A point on the line is counted as the positive side. Any consistent answer
## works; having one is the point.
static func _side_of(point: Vector2, centre: Vector2, cut_normal: Vector2) -> float:
	return 1.0 if (point - centre).dot(cut_normal) >= 0.0 else -1.0


## Split a closed outline where a cut line crosses it, returning one entry per
## side with the crossing points planted on both.
##
## Walked rather than filtered. A side's vertices are contiguous only if the
## loop's start vertex sits on the far side of the cut; the first version
## filtered, the run wrapped, and the open polyline joined its two ends with a
## chord straight across the shape. That stray diagonal read plausibly as the
## cut itself, and was found by a *cleaved* shield carrying more ink than a whole
## one -- not by looking at it.
static func _split_at_cut(
	outline: PackedVector2Array, centre: Vector2, cut_normal: Vector2
) -> Array:
	var arcs: Array = []
	var current := PackedVector2Array()
	var current_side := _side_of(outline[0], centre, cut_normal)
	for index in range(outline.size() + 1):
		var point: Vector2 = outline[index % outline.size()]
		var offset := (point - centre).dot(cut_normal)
		var side := _side_of(point, centre, cut_normal)
		if side != current_side and current.size() > 0:
			var previous: Vector2 = current[current.size() - 1]
			var previous_offset := (previous - centre).dot(cut_normal)
			var span := previous_offset - offset
			var crossing := previous if absf(span) < 0.0001 \
				else previous.lerp(point, previous_offset / span)
			current.append(crossing)
			arcs.append({"side": current_side, "points": current})
			current = PackedVector2Array([crossing])
			current_side = side
		current.append(point)
	if current.size() > 1:
		arcs.append({"side": current_side, "points": current})
	## The loop's start sits mid-arc, so the first and last arcs are one arc that
	## the walk happened to begin inside.
	if arcs.size() > 2 and float(arcs[0]["side"]) == float(arcs[-1]["side"]):
		var joined: PackedVector2Array = arcs[-1]["points"]
		joined.append_array(arcs[0]["points"])
		arcs[0] = {"side": arcs[0]["side"], "points": joined}
		arcs.remove_at(arcs.size() - 1)
	return arcs


## Break a closed outline along a cut and let the pieces fall apart.
##
## Each piece is its own arc closed off by the jagged seam, so both halves carry
## the break -- a seam drawn once and shared would sit between the pieces rather
## than on them, and the halves would read as clipped rather than as broken.
static func _fracture_paths(
	outline: PackedVector2Array, centre: Vector2, cut_normal: Vector2,
	stroke: float, falling_side: float = 1.0,
	teeth: int = FRACTURE_TEETH, jag: float = FRACTURE_JAG
) -> Array:
	var arcs := _split_at_cut(outline, centre, cut_normal)
	if arcs.size() < 2:
		return [{"points": outline, "closed": true, "width": stroke, "dash": 0.0}]
	var fall_direction := Vector2(cut_normal.y, -cut_normal.x)
	var out: Array = []
	for arc in arcs:
		var points: PackedVector2Array = arc["points"]
		if points.size() < 3:
			continue
		var side := float(arc["side"])
		## The seam between this arc's two ends, jagged. Reversed on one side so
		## the two sets of teeth interlock instead of mirroring.
		var seam := _jagged(points[points.size() - 1], points[0], teeth, jag)
		if side < 0.0:
			## Walked from the other end so the two sets of teeth interlock --
			## drawn the same way round, both pieces would deviate to the same
			## side of the seam and the break would read as a fold.
			seam = _jagged(points[0], points[points.size() - 1], teeth, jag)
			seam.reverse()
		var piece := PackedVector2Array(points)
		for index in range(1, seam.size() - 1):
			piece.append(seam[index])
		## Parted along the cut, and the loose piece also falls and turns. A
		## level part is a shape with a crack in it; falling is what says it lost.
		var shift := cut_normal * side * FRACTURE_PART
		var turn := 0.0
		if side == falling_side:
			shift += fall_direction * FRACTURE_FALL
			turn = deg_to_rad(FRACTURE_TURN_DEGREES)
		var placed := PackedVector2Array()
		for point in piece:
			var centred := point - centre
			placed.append(Vector2(
				centred.x * cos(turn) - centred.y * sin(turn),
				centred.x * sin(turn) + centred.y * cos(turn)
			) + centre + shift)
		out.append({"points": placed, "closed": true,
			"width": stroke, "dash": 0.0})
	return out


## Every blade, in every variant it can be in.
##
## `ascendant` is the plain drawing. Succeeding does not change the mark -- it
## lights the ground behind it, which is `backdrop_textures`. Keyed here anyway
## so the renderer's lookup is one dictionary read for every variant and a
## family that later wants its own ascendant ink has somewhere to put it.
static func blade_variant_textures(dark_theme: bool) -> Dictionary:
	var out := {}
	for intent in BLADE_INTENTS:
		var plain := _blade(
			intent == "preparing_attack", SERVE_RECT if intent == "serving" \
				else BLADE_RECT, intent == "serving", dark_theme
		)
		out["%s|plain" % intent] = plain
		out["%s|ascendant" % intent] = plain
	out["approaching|broken"] = _composite(
		PIXELS, PIXELS, _shattered_blade_paths(), [], [], dark_theme
	)
	return out


## The blade broken **across its midpoint**, the tip half falling away.
##
## Horizontal, because that is the break a blade takes and the one that reads at
## size: a blade split lengthways is two thin bars, and two thin bars beside each
## other are indistinguishable from one blade drawn badly.
static func _shattered_blade_paths() -> Array:
	var blade := _rounded_rect(BLADE_RECT, BLADE_RADIUS)
	var midpoint := BLADE_RECT.position.y + BLADE_RECT.size.y * 0.5
	## Five shallow teeth, not seven deep ones. The seam runs across the blade's
	## *width* -- 12 units against a shield's 38 -- and `FRACTURE_JAG` on that
	## span puts teeth taller than they are wide, which rasterises as a scribble
	## rather than as a break. Scaled to the shape being cut.
	var out := _fracture_paths(
		blade, Vector2(27.0, midpoint), Vector2(0.0, 1.0), BLADE_STROKE, -1.0,
		5, 1.4
	)
	## The guard and grip stay with the half still in a hand. They are what makes
	## the surviving piece read as *the blade a voli is still holding* rather than
	## as the other fragment.
	out.append({"points": _line(13.0, 40.0, 41.0, 40.0), "closed": false,
		"width": GUARD_STROKE, "dash": 0.0})
	out.append({"points": _line(27.0, 40.0, 27.0, 48.0), "closed": false,
		"width": GUARD_STROKE, "dash": 0.0})
	return out


static func shield_variant_textures(dark_theme: bool) -> Dictionary:
	var out := {}
	for intent in SHIELD_INTENTS:
		var plain := _shield(intent, dark_theme)
		out["%s|plain" % intent] = plain
		out["%s|ascendant" % intent] = plain
	out["defending|broken"] = _composite(
		PIXELS, PIXELS,
		_fracture_paths(
			_shield_outline(false), Vector2(27.0, 27.0), Vector2(1.0, 0.0),
			SHIELD_STROKE, 1.0
		),
		[], [], dark_theme
	)
	out["blocking|broken"] = _composite(
		PIXELS, PIXELS,
		_fracture_paths(
			_shield_outline(true), Vector2(27.0, 29.0), Vector2(1.0, 0.0),
			SHIELD_STROKE, 1.0
		),
		[], [], dark_theme
	)
	return out


## ## The backdrop: where a rating lives, and where success lives
##
## Two questions turned out to be one. A rating colour needs somewhere to sit
## that is not the ink -- the ink is doing contrast, and tinting it spends the
## thing that makes a mark legible on any ground. And succeeding needed a
## treatment that was not another set of paths per family.
##
## Both are answered by a shape **behind** the mark: a disc for an ordinary
## contact, a flare for one that came off. It carries the grade as its colour and
## the variant as its silhouette, and it costs one drawing rather than one per
## family.
##
## ### Sized to its own mark, not to one radius
##
## `tools/run_mark_extent_probe.gd` measured the ink bounding box of every mark
## in the vocabulary: an eye needs r=91, a plain blade r=111, a shield r=131. A
## single disc sized for the largest is **64% wider** than the smallest mark
## needs, so the same grade would read as two different weights depending on what
## was inside it -- the opposite of what a rating scale is for.
##
## So the backdrop is scaled per mark, from the mark's own authored geometry
## rather than by scanning its pixels. The geometry is free and exact; a scan of
## ten textures is a million `get_pixel` calls at load.
const BACKDROP_SHARE: float = 1.06
const BACKDROP_RADIUS: float = 21.0
const FLARE_TONGUES: int = 12
const FLARE_REACH: float = 1.42


## The backdrop shapes, drawn white so a grade colour can tint them.
##
## Not run through `_composite`: a backdrop has no ink and no halo. It is a soft
## coloured ground, and giving it an outline would make it a second mark.
static func backdrop_textures() -> Dictionary:
	return {
		"plain": _backdrop_disc(),
		"ascendant": _flare(),
		## A broken mark keeps the disc. The grade is already saying it went
		## badly, and a second loud silhouette behind a shape that is coming apart
		## is two things shouting the same word.
		"broken": _backdrop_disc(),
	}


static func _backdrop_disc() -> ImageTexture:
	var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	_disc(image, Vector2(27.0, 27.0), BACKDROP_RADIUS, Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


## The flare: the same disc with flame tongues licking off it.
##
## Radial and irregular by construction rather than by chance -- tongues alternate
## long and short and lean with their angle, which is what stops a ring of equal
## spikes reading as a gear or a sun stamp.
static func _flare() -> ImageTexture:
	var image := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var centre := Vector2(27.0, 27.0)
	## The same radius as the plain disc, so a flare is exactly *the disc plus
	## what it is throwing off*. Drawn smaller at first, which made the loud
	## version cover less ground than the quiet one -- the opposite of the claim.
	var base := BACKDROP_RADIUS
	for index in range(FLARE_TONGUES):
		var angle := TAU * float(index) / float(FLARE_TONGUES)
		## Longest at the top and shortest at the bottom, because heat rises and
		## a ring that is even all the way round reads as a stamp.
		var lift := 0.5 - 0.5 * cos(angle + PI * 0.5)
		var reach := base * (1.0 + (FLARE_REACH - 1.0) * (0.45 + 0.55 * lift))
		if index % 2 == 1:
			reach = base + (reach - base) * 0.55
		## Drawn as a run of shrinking discs rather than a polygon, which keeps
		## the tongue soft-edged and needs no polygon filler.
		var steps := 7
		for step in range(steps + 1):
			var t := float(step) / float(steps)
			var at := centre + Vector2(cos(angle), sin(angle)) * lerpf(base * 0.55, reach, t)
			_disc(image, at, lerpf(6.0, 1.1, t), Color(1.0, 1.0, 1.0, 1.0))
	_disc(image, centre, base, Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


## How large this mark's backdrop should be, relative to the mark itself.
##
## Derived from the authored geometry of each family rather than measured off
## pixels, and stated as a share so the relationship survives any future change
## to the size a mark is drawn at.
static func backdrop_scale(intent: String) -> float:
	if SHIELD_INTENTS.has(intent):
		return BACKDROP_SHARE
	if BLADE_INTENTS.has(intent):
		## A blade is tall and narrow: 12 units across against a shield's 38. A
		## disc that contained it would be a disc sized by its *length*, which is
		## the 64% problem the probe found. Sized to the blade's own width
		## instead, so the grade reads at the weight of the mark it belongs to.
		return BACKDROP_SHARE * 0.78
	return BACKDROP_SHARE * 0.70


## ## Commitment as a process, not a symbol
##
## The diamond used to be a *state* -- an abstract shape meaning `committed`
## that a viewer had to be taught, and which was reported, fairly, as
## unreadable. It comes back as something else entirely: a mark that **forms**.
##
## Committing to a ball takes a moment, and a mark whose outline draws itself
## around a perimeter says that without any vocabulary at all -- it is a loading
## bar bent into a shape. Half-drawn is a decision half-made. And a commitment
## that fails does not fade; it **breaks**, which is the hesitating passer of
## the scene.
const COMMIT_RADII := Vector2(13.0, 16.0)
const COMMIT_STROKE: float = 2.6
const COMMIT_TRACK_STROKE: float = 1.3
const COMMIT_TRACK_DASH: float = 2.6


static func commitment(progress: float, broken: bool, dark_theme: bool) -> ImageTexture:
	var centre := Vector2(27.0, 27.0)
	var corners := PackedVector2Array([
		centre + Vector2(0.0, -COMMIT_RADII.y),
		centre + Vector2(COMMIT_RADII.x, 0.0),
		centre + Vector2(0.0, COMMIT_RADII.y),
		centre + Vector2(-COMMIT_RADII.x, 0.0),
		centre + Vector2(0.0, -COMMIT_RADII.y),
	])
	if broken:
		## Broken the same way everything else in the vocabulary breaks: fractured
		## on a jagged seam, parted, and one piece falling away. Vertical, apex to
		## point, because that is the diamond's long axis and a horizontal break
		## would leave two wide shallow pieces that read as a fold.
		##
		## Shares `_fracture_paths` with the blade and the shield rather than
		## drawing its own split. Three families breaking three different ways
		## still have to break in one hand, and the first version -- two straight
		## half-outlines parted by 1.6 units -- read on the plate as an intact
		## diamond with two specks in it.
		return _composite(PIXELS, PIXELS, _fracture_paths(
			corners, centre, Vector2(1.0, 0.0), COMMIT_STROKE, 1.0
		), [], [], dark_theme)
	## Drawn around its own perimeter to `progress`, which is the loading bar.
	##
	## A bar needs its *track* as much as its fill. Drawn without one, a
	## half-formed commitment is just a short line: legible as motion, useless as
	## a fraction, and at zero it was measured as literally nothing on the plate.
	## The track is the same diamond dashed and thin, which is the vocabulary's
	## existing word for provisional -- so the empty part of the bar is already
	## saying "not yet" without a second colour or an alpha channel.
	var paths: Array = [
		{"points": corners, "closed": false,
			"width": COMMIT_TRACK_STROKE, "dash": COMMIT_TRACK_DASH},
	]
	var drawn := _truncate(corners, clampf(progress, 0.0, 1.0))
	if drawn.size() >= 2:
		paths.append({
			"points": drawn, "closed": false,
			"width": COMMIT_STROKE, "dash": 0.0,
		})
	return _composite(PIXELS, PIXELS, paths, [], [], dark_theme)


## The first `fraction` of a polyline, by arc length.
static func _truncate(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var total := 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	var budget := total * clampf(fraction, 0.0, 1.0)
	var out := PackedVector2Array()
	if points.size() > 0:
		out.append(points[0])
	for index in range(points.size() - 1):
		var span := points[index].distance_to(points[index + 1])
		if span <= 0.0001:
			continue
		if budget >= span:
			out.append(points[index + 1])
			budget -= span
			continue
		out.append(points[index].lerp(points[index + 1], budget / span))
		break
	return out


## Draw a mark as halo then ink, and flatten the two.
##
## Two passes rather than one, because a halo is a second colour and the stroker
## keeps the *maximum* coverage per pass -- which is what stops a rounded corner
## reading as a bead, and would blend two colours into mud if they shared a pass.
## So each colour gets its own layer and the ink composites over the halo.
static func _composite(
	width: int,
	height: int,
	paths: Array,
	discs: Array,
	fills: Array,
	dark_theme: bool,
) -> ImageTexture:
	var ink := INK_DARK if dark_theme else INK_LIGHT
	var halo := HALO_DARK if dark_theme else HALO_LIGHT
	var halo_layer := _layer(width, height, halo)
	var ink_layer := _layer(width, height, ink)
	for pass_index in range(2):
		var image := halo_layer if pass_index == 0 else ink_layer
		var colour := halo if pass_index == 0 else ink
		var extra := HALO_SPREAD * 2.0 if pass_index == 0 else 0.0
		for path in paths:
			_stroke(
				image, path["points"], float(path["width"]) + extra, colour,
				bool(path["closed"]), float(path.get("dash", 0.0)), DASH_OFF,
			)
		for disc in discs:
			_disc(
				image, disc["centre"],
				float(disc["radius"]) + extra * 0.5, colour,
			)
		for fill in fills:
			_fill_rounded_rect(
				image, fill["rect"], float(fill["radius"]), colour, extra * 0.5
			)
	_over(halo_layer, ink_layer)
	return ImageTexture.create_from_image(halo_layer)


static func _layer(width: int, height: int, colour: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(colour.r, colour.g, colour.b, 0.0))
	return image


## Source-over, in place on `base`.
static func _over(base: Image, top: Image) -> void:
	for y in range(base.get_height()):
		for x in range(base.get_width()):
			var over := top.get_pixel(x, y)
			if over.a <= 0.0:
				continue
			var under := base.get_pixel(x, y)
			var alpha := over.a + under.a * (1.0 - over.a)
			if alpha <= 0.0:
				continue
			base.set_pixel(x, y, Color(
				(over.r * over.a + under.r * under.a * (1.0 - over.a)) / alpha,
				(over.g * over.a + under.g * under.a * (1.0 - over.a)) / alpha,
				(over.b * over.a + under.b * under.a * (1.0 - over.a)) / alpha,
				alpha,
			))


## Every blade texture, by the intent it draws. Built once; the caller keeps it.
##
## `fill` is the blade's interior as a solid, drawn separately so the filling can
## be a region on a sprite rather than a texture regenerated every frame. The
## review clips it from the bottom edge upward, and a region does exactly that.
static func blade_textures(dark_theme: bool) -> Dictionary:
	return {
		"preparing_attack": _blade(true, BLADE_RECT, false, dark_theme),
		"approaching": _blade(false, BLADE_RECT, false, dark_theme),
		"serving": _blade(false, SERVE_RECT, true, dark_theme),
		"fill": _blade_fill(dark_theme),
	}


## The blade outline, its guard and its grip.
static func _blade(
	dashed: bool, rect: Rect2, tossed: bool, dark_theme: bool
) -> ImageTexture:
	var paths: Array = [
		{"points": _rounded_rect(rect, BLADE_RADIUS), "closed": true,
			"width": BLADE_STROKE, "dash": DASH_ON if dashed else 0.0},
	]
	var discs: Array = []
	if tossed:
		## The serve's guard is a bare cross-bar above the grip, and the toss is
		## a filled ball above that -- the one blade in the family that is not
		## planted, because a server is holding the ball rather than the floor.
		paths.append({"points": _line(13.0, 12.0, 41.0, 12.0), "closed": false,
			"width": GUARD_STROKE, "dash": 0.0})
		discs.append({"centre": SERVE_TOSS_CENTRE, "radius": SERVE_TOSS_RADIUS})
	else:
		## The guard and the grip, which are what stop a blade reading as a
		## thermometer once it starts filling.
		paths.append({"points": _line(13.0, 40.0, 41.0, 40.0), "closed": false,
			"width": GUARD_STROKE, "dash": 0.0})
		paths.append({"points": _line(27.0, 40.0, 27.0, 48.0), "closed": false,
			"width": GUARD_STROKE, "dash": 0.0})
	return _composite(PIXELS, PIXELS, paths, discs, [], dark_theme)


## The blade's interior as a solid, for the fill.
##
## Drawn to the blade's own rounded rect so the fill cannot spill past the
## outline it lives inside, which is what the review's clip-path guarantees by
## construction and a naive rectangle would not.
##
## Inked without a halo. The fill lives *behind* the outline, and a halo behind
## something already outlined is a second edge nobody asked for -- it read as a
## smudge growing up the blade.
static func _blade_fill(dark_theme: bool) -> ImageTexture:
	var ink := INK_DARK if dark_theme else INK_LIGHT
	var image := _layer(PIXELS, PIXELS, ink)
	_fill_rounded_rect(image, BLADE_RECT, BLADE_RADIUS, ink, 0.0)
	return ImageTexture.create_from_image(image)


## Where the fill's top edge sits, in design units, for a progress of 0 to 1.
##
## The review clips from y = 39 up to y = 4 across the full range, which
## overshoots the blade at both ends on purpose so the fill reads as full a
## little before progress does. Kept, because a blade that only looks full at
## exactly 1.0 reads as never quite arriving.
const FILL_BOTTOM: float = 39.0
const FILL_TOP: float = 4.0


## The region of the fill texture to draw, in texture pixels, for this progress.
##
## Bottom-anchored: the region always ends at the fill's bottom edge and its top
## rises with progress. Returned as a `Rect2` so the caller hands it straight to
## `Sprite3D.region_rect` without doing this arithmetic again -- it was done
## twice in the review's own markup and the two disagreed by half a unit.
static func fill_region(progress: float) -> Rect2:
	var covered := clampf(progress, 0.0, 1.0) * (FILL_BOTTOM - FILL_TOP)
	var top := (FILL_BOTTOM - covered) * float(SCALE)
	var bottom := FILL_BOTTOM * float(SCALE)
	return Rect2(0.0, top, float(PIXELS), maxf(bottom - top, 0.0))


## How far to shift a bottom-anchored region so it stays where it belongs.
##
## A `Sprite3D` centres whatever region it is given, so a region taken from the
## lower part of a texture would jump to the middle. The offset puts it back.
##
## Derived rather than guessed, because the first version was written by
## intuition and had the sign inverted -- which draws a fill that *descends* as
## progress rises, and looked plausible enough in code to ship. With the whole
## texture drawn, texture row `y` lands at world height `(H/2 - y)`, since
## texture y runs down and world y runs up. A region is drawn centred on its own
## midpoint `yc`, so putting it back means offsetting by `H/2 - yc`, and
## `yc = (top + bottom) / 2`.
static func fill_offset(region: Rect2) -> Vector2:
	return Vector2(
		0.0, (float(PIXELS) - region.position.y - region.end.y) * 0.5
	)


## A rounded rectangle as a closed polyline, in design units.
##
## Flattened here rather than drawn as an arc primitive because the stroker takes
## polylines and shields will need the same treatment for their cubics -- one
## path representation, so the dash pattern and the caps behave identically on
## every mark rather than per shape.
static func _rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5, 0.0],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0, PI * 0.5],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],
		[Vector2(rect.position.x + r, rect.position.y + r), PI, PI * 1.5],
	]
	for corner in corners:
		var centre: Vector2 = corner[0]
		var from: float = corner[1]
		var to: float = corner[2]
		for step in range(5):
			var angle := lerpf(from, to, float(step) / 4.0)
			points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points


## Stroke a polyline into the image, with round caps and an optional dash.
##
## Distance-to-segment with a smooth edge, rather than Bresenham: the marks are
## small and a hard-edged 3 unit stroke at this size reads as a staircase. Only
## the pixels within a stroke's width of each segment are visited, so the cost is
## proportional to ink rather than to canvas.
static func _stroke(
	image: Image,
	points: PackedVector2Array,
	width: float,
	ink: Color,
	closed: bool,
	dash_on: float,
	dash_off: float,
) -> void:
	var segments: Array = []
	var count := points.size()
	var last := count if closed else count - 1
	for index in range(last):
		segments.append([points[index], points[(index + 1) % count]])
	if dash_on > 0.0:
		segments = _dash(segments, dash_on, dash_off)
	for segment in segments:
		_stroke_segment(image, segment[0], segment[1], width, ink)


## Cut a run of segments into dashes, measured along the path rather than per
## segment -- a dash pattern restarted at every corner is not a dash pattern.
static func _dash(segments: Array, on: float, off: float) -> Array:
	var out: Array = []
	var travelled := 0.0
	for segment in segments:
		var from: Vector2 = segment[0]
		var to: Vector2 = segment[1]
		var length := from.distance_to(to)
		if length <= 0.0001:
			continue
		var direction := (to - from) / length
		var cursor := 0.0
		while cursor < length:
			var cycle := fmod(travelled + cursor, on + off)
			var remaining := (on - cycle) if cycle < on else (on + off - cycle)
			## **Floored, or this loop does not terminate.** When the cursor
			## lands a hair before a dash boundary `remaining` is on the order of
			## 1e-7, the cursor advances by that much, and the walk takes
			## millions of iterations to cross one segment -- which presents as
			## a hang during rasterisation rather than as a wrong drawing, and
			## cost a render to find. A dash cannot usefully be shorter than one
			## rasterised pixel anyway.
			var span := maxf(
				minf(remaining, length - cursor), 1.0 / float(SCALE)
			)
			if cycle < on:
				out.append([
					from + direction * cursor, from + direction * (cursor + span),
				])
			cursor += span
		travelled += length
	return out


static func _stroke_segment(
	image: Image, from: Vector2, to: Vector2, width: float, ink: Color
) -> void:
	var half := width * 0.5 * float(SCALE)
	var a := from * float(SCALE)
	var b := to * float(SCALE)
	## One pixel of feather either side of the edge. Any more and a 12 pixel
	## stroke loses a sixth of itself to the blur.
	var feather := 1.0
	var reach := half + feather + 1.0
	var min_x := maxi(int(floor(minf(a.x, b.x) - reach)), 0)
	var max_x := mini(int(ceil(maxf(a.x, b.x) + reach)), image.get_width() - 1)
	var min_y := maxi(int(floor(minf(a.y, b.y) - reach)), 0)
	var max_y := mini(int(ceil(maxf(a.y, b.y) + reach)), image.get_height() - 1)
	var span := b - a
	var length_squared := maxf(span.length_squared(), 0.000001)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var t := clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
			var distance := point.distance_to(a + span * t)
			var alpha := 1.0 - smoothstep(half - feather, half + feather, distance)
			if alpha > 0.0:
				_blend(image, x, y, ink, alpha)


static func _disc(
	image: Image, centre: Vector2, radius: float, ink: Color
) -> void:
	var c := centre * float(SCALE)
	var r := radius * float(SCALE)
	var reach := r + 2.0
	for y in range(maxi(int(c.y - reach), 0), mini(int(c.y + reach), image.get_height() - 1) + 1):
		for x in range(maxi(int(c.x - reach), 0), mini(int(c.x + reach), image.get_width() - 1) + 1):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c)
			var alpha := 1.0 - smoothstep(r - 1.0, r + 1.0, distance)
			if alpha > 0.0:
				_blend(image, x, y, ink, alpha)


static func _fill_rounded_rect(
	image: Image, rect: Rect2, radius: float, ink: Color, grow: float = 0.0
) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5) * float(SCALE)
	var scaled := Rect2(rect.position * float(SCALE), rect.size * float(SCALE))
	scaled = scaled.grow(grow * float(SCALE))
	var centre := scaled.position + scaled.size * 0.5
	var half := scaled.size * 0.5 - Vector2(r, r)
	for y in range(maxi(int(scaled.position.y - 2.0), 0), mini(int(scaled.end.y + 2.0), image.get_height() - 1) + 1):
		for x in range(maxi(int(scaled.position.x - 2.0), 0), mini(int(scaled.end.x + 2.0), image.get_width() - 1) + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var delta := (point - centre).abs() - half
			var outside := Vector2(maxf(delta.x, 0.0), maxf(delta.y, 0.0))
			var distance := outside.length() + minf(maxf(delta.x, delta.y), 0.0) - r
			var alpha := 1.0 - smoothstep(-1.0, 1.0, distance)
			if alpha > 0.0:
				_blend(image, x, y, ink, alpha)


## Source-over, keeping the highest coverage rather than accumulating it.
##
## Two segments meeting at a corner overlap, and adding their alphas there makes
## every join darker than the strokes it joins -- visible as beads at each corner
## of a rounded rect. Taking the maximum is what makes a join look like a join.
static func _blend(
	image: Image, x: int, y: int, ink: Color, alpha: float
) -> void:
	var existing := image.get_pixel(x, y)
	image.set_pixel(x, y, Color(
		ink.r, ink.g, ink.b, maxf(existing.a, clampf(alpha, 0.0, 1.0))
	))
