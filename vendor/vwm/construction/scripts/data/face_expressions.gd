class_name FaceExpressions
extends RefCounted

## Faces, built from the same primitives as the rest of the body.
##
## The alternative was a drawn texture on a quad in front of the head, which is
## cheaper and gives finer control -- and would have read as a sticker. Every
## other feature on these bodies is a box or a sphere sitting in space, so a
## painted face would have been the only flat thing on an actor made of solids.
## Small solids projected onto the head's surface curve with it and light with
## it, which is what makes the face belong to the head rather than sit on it.
##
## **A face is a pair, and the name is a lookup.** Three eye states and three
## mouth shapes, and the label is whatever that combination reads as. Nothing is
## authored per expression.
##
## The first version did it the other way round -- five named faces, each with
## its own hand-picked numbers -- and it produced a "happy" that everybody read
## as *devious*, because a smile under narrowed eyes is a scheme rather than a
## delight. With the name derived from the parts that cannot happen: narrowed
## eyes plus a smile *is* devious, and it is called that because of what it is
## made of rather than what it was meant to be.
##
## It also turns five faces into nine for no extra authoring, and every new eye
## state would add three more.

## Visual vocabulary semantics
##
## These are perceptive or emotional surface states layered over action poses,
## not volleyball-quality labels. Neutral/concerned/focused-looking combinations
## may accompany preparation, contact, or recovery without implying a clean,
## strained, successful, or failed action. Blink and rally gaze remain separate
## continuous attention motion.

const NEUTRAL: String = "neutral"

## How open the eyes are, and how they tilt.
##
## Tilt belongs to the eye state rather than to the expression, which is the
## whole reason the grid works. Narrowed eyes tilt inner-end-down, and that one
## fact does three jobs at once: narrowed under a frown is *cross*, narrowed
## under a flat mouth is *suspicious*, and narrowed under a smile is *devious*.
## Wide eyes tilt slightly the other way, which reads as open under a smile and
## as concern under a frown. Flat eyes have no tilt to give.
const EYES := {
	"full": {"squash": 1.18, "tilt": 7.0},
	"half": {"squash": 0.66, "tilt": -20.0},
	"flat": {"squash": 0.26, "tilt": 0.0},
}

## `curve` is signed: positive lifts the corners above the centre.
##
## The flat mouth is the widest of the three on purpose. A straight line drawn
## right across the face is not a milder smile or a milder frown -- it is its own
## reading, and the width is what stops it looking like a curve that failed.
const MOUTHS := {
	"smile": {"curve": 1.00, "half_width": 0.34},
	"flat": {"curve": 0.00, "half_width": 0.42},
	"frown": {"curve": -0.85, "half_width": 0.28},
}

## eye state -> mouth shape -> what that combination reads as.
##
## The single source of truth for which expressions exist. Adding a row or a
## column adds faces without touching anything else.
const GRID := {
	"full": {"smile": "happy", "flat": "neutral", "frown": "worried"},
	"half": {"smile": "devious", "flat": "suspicious", "frown": "cross"},
	"flat": {"smile": "relaxed", "flat": "deadpan", "frown": "tired"},
}

## Where the features sit, in head-normalised coordinates: u across, v up, both
## on [-1, 1] against the head's own semi-axes. Authored this way so one set of
## numbers serves a 0.105-radius Stalk head and a 0.185-radius Feli head without
## a per-type table.
const EYE_U: float = 0.40
const EYE_V: float = 0.19
const MOUTH_V: float = -0.34
## How far the mouth's centre travels from its corners at full curve.
const MOUTH_BOW: float = 0.19
## How finely the mouth's curve is sampled.
##
## **Renamed from `MOUTH_SEGMENTS`, and half its old justification is retired.**
## It read: "Seven is where the curve stops reading as a staircase at roster
## distance; more costs mesh instances on every actor on court." The first half
## still holds and the second does not -- a sample is now a pair of vertices in
## one swept mesh rather than a whole `BoxMesh` with its own inverted-hull
## outline, so the budget that pinned this at seven is gone. Fifteen because the
## cost is now vertices, and because the curve it is approximating is tightest at
## the corners of a muzzle, which is exactly where seven was coarsest.
const MOUTH_SAMPLES: int = 15

## **More than half of every eye used to be its own outline.** A Feli eye is
## authored 0.053 m across and `_ink_node` grew a 0.030 m inverted hull on every
## side of it, so what actually showed was 0.113 m -- the geometry was a minority
## of the mark. Worse, the hull is a fixed distance in metres while the box scales
## with the head, so a small-headed voli's eyes were proportionally much larger
## than a big-headed one's: the exact thing the head-normalised units above exist
## to prevent, undone downstream by a constant nobody connected to it.
##
## The hull also had to go somewhere. Grown out of a mark that thin it burst
## through the surrounding head, and the dark fringes that produced around the
## eyes are the "speckles", "eye bags" and "dotted lines" reported on faces that
## should be plain. Vegi's, having no muzzle to distract from them, read as a
## moustache.
##
## Raised by a fifth rather than doubled, and the first attempt is the instructive
## one. Compensating for the hull's *full* growth -- 0.060 m across, which is 0.34
## in normalised units on a 0.178 m head -- produced eyes half again too big,
## because most of that growth went sideways *into* the skull and was occluded.
## What ever showed was the box plus a thin rim, and a thin rim is what this
## replaces. Measured against the ink-collapsed render rather than against the
## arithmetic.
## How much of the eye the pupil is, across and down.
##
## A proportion rather than a size in head radii, so an expression that squashes
## the eye squashes the pupil with it and the pupil cannot end up outside the eye
## it belongs to. At the authored eye this is 0.16 by 0.15 head radii, roughly
## four times `WHISKER_ROOT_RADIUS` -- the thinnest mark this file believes
## survives the quantiser at roster distance.
const PUPIL_SHARE: float = 0.45
const EYE_WIDTH: float = 0.36
const EYE_HEIGHT: float = 0.34
const FEATURE_DEPTH: float = 0.10
const MOUTH_THICKNESS: float = 0.10
## Lift off the surface, in head radii. Enough that a feature never z-fights with
## the skull it is sitting on.
const SURFACE_LIFT: float = 0.02
## A muzzle is a much smaller sphere than a skull, so it curves away far faster
## under the same mouth.
##
## **This was 0.13, and it was treating the symptom.** At the skull's lift the
## outer *segments* sank into the muzzle and the smile came out looking like
## gritted teeth -- a row of separate dark chips rather than one stroke. Lifting
## the whole row clear of the surface hid the gaps by floating the mouth in front
## of the snout, which is a different wrong picture and the one the user
## eventually reported.
##
## The mouth is now a single swept stroke that carries its own `depth`, so
## nothing can sink relative to anything else and there is no gap to hide. Back
## to the skull's own lift: a mouth sits on a muzzle the way it sits on a face.
const MUZZLE_LIFT: float = SURFACE_LIFT
## And the mouth has to sit nearer the muzzle's middle. `MOUTH_V` is authored for
## a face with a whole skull under it; carried straight onto a muzzle it lands on
## the bottom lip and falls off the curve.
const MUZZLE_V_COMPRESS: float = 0.50

## Whiskers: how many a side, how long against the muzzle's radius, how thick at
## the root, where on the snout they root, and how far they splay.
##
## Long, because a whisker that stops at the edge of the snout is a bristle. Half
## again the muzzle's radius puts the tips outside the head's silhouette, which is
## the whole point -- they break the outline, and an outline is what this rig is
## read by. Thin enough to be a line and no thinner: they carry no ink hull (a
## 30 mm hull on a 4 mm whisker is a black rod), so their own geometry is the
## stroke and it has to survive the quantiser at roster distance.
const WHISKERS_PER_SIDE: int = 3
const WHISKER_LENGTH_FACTOR: float = 1.55
const WHISKER_ROOT_RADIUS: float = 0.042
const WHISKER_ROOT_U: float = 0.62
const WHISKER_ROOT_V: float = 0.05
## Fanned about the horizontal: one up, one level, one down. Symmetric so the
## middle whisker is the level one whatever the count.
const WHISKER_SPLAY_DEGREES: float = 21.0


## Every expression the grid produces, sorted so the order never depends on
## dictionary iteration.
static func names() -> Array[String]:
	var result: Array[String] = []
	for eye_state in GRID:
		for mouth_shape in GRID[eye_state]:
			result.append(str(GRID[eye_state][mouth_shape]))
	result.sort()
	return result


static func has(expression: String) -> bool:
	return not components(expression).is_empty()


## What an expression is made of: `[eye state, mouth shape]`, empty if unknown.
##
## Scanned rather than stored as a second table. Nine entries is nothing to walk,
## and a reverse map would be a copy of `GRID` that could disagree with it.
static func components(expression: String) -> Array[String]:
	for eye_state in GRID:
		for mouth_shape in GRID[eye_state]:
			if str(GRID[eye_state][mouth_shape]) == expression:
				return [str(eye_state), str(mouth_shape)]
	return []


## What a given pair reads as. The inverse of `components`.
static func label(eye_state: String, mouth_shape: String) -> String:
	return str(Dictionary(GRID.get(eye_state, {})).get(mouth_shape, NEUTRAL))


## A stable face per voli.
##
## Hashed from the id the same way `BodyTypeModels.produce_for` picks a produce,
## so a voli wears the same face every time you open the roster. A face that
## resampled on each refresh would read as a bug even while working exactly as
## specified.
##
## This is a placeholder for a real decision, not the decision: see
## `docs/design/CLUB_LIFE.md` on whether an expression is part of who a voli is
## or a report on how they are doing.
static func for_player(player_id: int) -> String:
	var ordered := names()
	return ordered[absi(hash("face:%d" % player_id)) % ordered.size()]


## Every feature of one face, as specs the actor can hand straight to
## `BodyTypeModels.build_mesh`.
##
## `radius` is the head's horizontal semi-axis and `half_height` its vertical
## one -- heads are slightly wide ellipsoids rather than spheres, so a face
## authored against a single radius would sit too high and too narrow.
##
## `mouth_override`, when given, moves the mouth off the skull and onto whatever
## is already sticking out of the face. See `_build_face` -- it is derived from
## the body type's own cosmetics rather than restated here, so a muzzle that
## moves takes its mouth with it.
##   `anchor`      -- head-local centre to draw the mouth around
##   `radius`      -- the muzzle's own horizontal semi-axis
##   `half_height` -- and its vertical one
##   `scale`       -- width multiplier, since a muzzle is narrower than a skull
##   `omit`        -- the part *is* the mouth; draw eyes only
static func parts(
	expression: String, radius: float, half_height: float,
	mouth_override: Dictionary = {}
) -> Array[Dictionary]:
	var pair := components(expression)
	if pair.is_empty():
		pair = components(NEUTRAL)
	var eye_spec: Dictionary = EYES[pair[0]]
	var mouth_spec: Dictionary = MOUTHS[pair[1]]

	var result: Array[Dictionary] = []
	var squash := float(eye_spec.get("squash", 1.0))
	var tilt := float(eye_spec.get("tilt", 0.0))
	for side in [-1.0, 1.0]:
		result.append({
			"name": "EyeL" if side < 0.0 else "EyeR",
			"shape": "box",
			"size": Vector3(
				EYE_WIDTH * radius,
				EYE_HEIGHT * radius * squash,
				FEATURE_DEPTH * radius,
			),
			"position": _surface(EYE_U * side, EYE_V, radius, half_height),
			## An eye is a mark in the face's own ink colour, like the mouth and the
			## whiskers. It is not an object sitting on a head, so nothing is drawn
			## around it.
			"ink": "none",
			## Mirrored, so a tilt moves the *inner* end on both sides rather than
			## rotating the whole face one way.
			##
			## Negated because the rig faces -Z: a positive rotation about Z reads
			## as *clockwise* to anyone standing in front of the voli, which lifts
			## the outer end rather than the inner one. Without this, worried and
			## cross wear each other's brows -- the mouths stay right and only the
			## eyes swap, which is the worst kind of wrong, because both faces
			## still look like perfectly good faces.
			"rotation": Vector3(0.0, 0.0, -tilt * side),
		})
		## The pupil, in the ink the eye did not take.
		##
		## An eye is one flat mark, so it says which way a voli is *facing* and
		## nothing about where they are looking. A pupil is the smallest thing
		## that adds the second: it is what a viewer reads a gaze off.
		##
		## **No new colour.** `player_actor_3d.gd` already picks the face's ink
		## from two, by the skin's luminance, so the contrast the pupil needs
		## already exists -- it takes the one the eye did not. Inventing a third
		## would be a colour that has to be checked against six skins and every
		## regional kit.
		##
		## Sized as a fraction of the eye rather than in head radii, so it stays
		## inside the eye whatever an expression's squash does to it. Well clear
		## of `WHISKER_ROOT_RADIUS`, which is this file's own floor for a mark that
		## survives the quantiser at roster distance.
		##
		## **Offset along the surface normal by both half-depths, not by a bigger
		## lift.** The first attempt doubled `SURFACE_LIFT`, which moved the
		## pupil's centre 3.9 mm forward while the eye's own half-depth is 9.7 --
		## so the pupil sat entirely inside the eye and nothing showed. A lift is
		## in head radii and a box's depth is not; what has to clear here is one
		## box past another, so the distance comes from the two boxes.
		##
		## Straight down -z rather than along the surface normal, which was the
		## second attempt. The normal leans outward and upward away from the
		## face's centre, so it carried the pupil out of the middle of the eye --
		## and a pupil that is not centred in its eye is a voli looking sideways,
		## permanently. Both boxes are axis-aligned apart from a shared roll, so
		## the direction one clears the other in is the face's own forward.
		result.append({
			"name": "PupilL" if side < 0.0 else "PupilR",
			"shape": "box",
			"size": Vector3(
				EYE_WIDTH * radius * PUPIL_SHARE,
				EYE_HEIGHT * radius * squash * PUPIL_SHARE,
				FEATURE_DEPTH * radius * PUPIL_SHARE,
			),
			"position": _surface(EYE_U * side, EYE_V, radius, half_height)
				- Vector3(
					0.0, 0.0,
					FEATURE_DEPTH * radius * (1.0 + PUPIL_SHARE) * 0.5,
				),
			"ink": "none",
			"rotation": Vector3(0.0, 0.0, -tilt * side),
		})

	if bool(mouth_override.get("omit", false)):
		return result

	var mouth_scale := float(mouth_override.get("scale", 1.0))
	var anchor: Variant = mouth_override.get("anchor")
	var half_width := float(mouth_spec.get("half_width", 0.2)) * mouth_scale
	var curve := float(mouth_spec.get("curve", 0.0))
	## Whose semi-axes the stroke is wrapping. On a muzzle these are the muzzle's,
	## which is what makes the mouth follow a snout instead of a skull.
	var wrap_radius := float(mouth_override.get("radius", radius)) \
		if anchor != null else radius
	var wrap_half_height := float(mouth_override.get("half_height", half_height)) \
		if anchor != null else half_height
	var lift := MUZZLE_LIFT if anchor != null else SURFACE_LIFT
	var step := 2.0 * half_width / float(MOUTH_SAMPLES - 1)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in range(MOUTH_SAMPLES):
		var u := -half_width + step * float(index)
		var along := u / maxf(half_width, 0.0001)
		## Parabola: at the corners the offset is zero, at the centre it is full.
		## A positive curve therefore drops the centre and leaves the corners
		## high, which is a smile.
		var v := MOUTH_V - curve * MOUTH_BOW * (1.0 - along * along)
		## Normalised against whichever body this stroke is being laid on. On the
		## muzzle path `u` is divided back out of `mouth_scale` because the span
		## was scaled into head units to begin with; `v` is compressed because
		## `MOUTH_V` is authored for a face with a whole skull under it and lands
		## on a muzzle's bottom lip carried straight across.
		var wrap_u := u / maxf(mouth_scale, 0.001) if anchor != null else u
		var wrap_v := v * MUZZLE_V_COMPRESS if anchor != null else v
		var seated: Array = _seat(
			wrap_u, wrap_v, mouth_override,
			wrap_radius, wrap_half_height, lift
		)
		var point: Vector3 = seated[0]
		points.append(point if anchor == null else (anchor as Vector3) + point)
		normals.append(seated[1])
	## **Both of these used the head's radius while the position used the
	## muzzle's**, which is a thickness and a depth authored for one object drawn
	## on another. On Feli that is an 18.5 mm bar standing 18.5 mm proud of a snout
	## whose entire height is 150 mm. The span already carried `mouth_scale`
	## through `step`; these two never did.
	## **A span scales with the snout; a line weight does not.**
	##
	## Both of these took `mouth_scale`, and half of that was the right fix: a
	## depth authored for a skull and carried onto a muzzle stood the mouth proud
	## of the snout, which is the defect the note above records. Thickness is a
	## different quantity. It is a *line weight*, and a line weight is about
	## surviving the quantiser at roster distance rather than about the size of
	## what it is drawn on -- the same argument `WHISKER_ROOT_RADIUS` makes for
	## the whiskers, which carry no scale at all.
	##
	## Measured with both scaled, against the eye, which is the mark that reads:
	## Vegi 0.34 of the eye's height and every muzzled body 0.12 to 0.13, a third
	## of it. That is the report that expressions cannot be made out on Feli and
	## Simi while Vegi is fine -- Vegi is the one body with no muzzle, so it is
	## the one whose mouth was never scaled down.
	var stroke_scale := mouth_scale if anchor != null else 1.0
	result.append({
		"name": "Mouth",
		"shape": "stroke",
		"points": points,
		"normals": normals,
		"thickness": MOUTH_THICKNESS * radius * 0.5,
		"depth": FEATURE_DEPTH * radius * stroke_scale,
		"position": Vector3.ZERO,
		"rotation": Vector3.ZERO,
		## **The same rule the whiskers needed, and the mouth needed it first.**
		## A 4 mm stroke inside a 30 mm inverted hull is a 64 mm black blob, which
		## on a tapered pad the size of a snout draws as a hash mark rather than as
		## a mouth. The stroke is already in the face's own ink colour: it *is* the
		## line, so nothing has to be drawn around it.
		"ink": "none",
	})
	if anchor != null and bool(mouth_override.get("whiskers", false)):
		result.append_array(_whiskers(
			anchor as Vector3, wrap_radius, wrap_half_height, mouth_override
		))
	return result


## Six lines off the snout, and they are lines rather than parts.
##
## A cat face carrying a nose and a mouth and nothing else leaves the whole lower
## head as one unbroken plane, which is what made Feli read flat next to Cani --
## Cani's folded ears and longer muzzle already break the same area up. Whiskers
## are the cheapest thing that fixes it and the only one that is unmistakably
## feline.
##
## Cones, because a whisker tapers to a point and a cone is the one primitive
## that already does. `ink: none` because the part *is* the stroke: the hull that
## draws every other part's edge would here be seven times the whisker's own
## width. They are face features rather than cosmetics so they take the face's
## own ink colour -- dark on a light skin, light on a dark one -- which is the
## same rule the mouth follows and means a black-furred voli's whiskers show.
static func _whiskers(
	anchor: Vector3, radius: float, half_height: float, override: Dictionary
) -> Array[Dictionary]:
	var whiskers: Array[Dictionary] = []
	var length := radius * WHISKER_LENGTH_FACTOR
	var middle := float(WHISKERS_PER_SIDE - 1) * 0.5
	for side: float in [-1.0, 1.0]:
		for index in range(WHISKERS_PER_SIDE):
			var step := (float(index) - middle) / maxf(middle, 1.0)
			var elevation := step * WHISKER_SPLAY_DEGREES
			var root: Vector3 = anchor + _seat(
				WHISKER_ROOT_U * side,
				WHISKER_ROOT_V - step * 0.10,
				override, radius, half_height, SURFACE_LIFT
			)[0]
			## A cone's axis is +Y, so aiming one outward is a quarter turn about
			## Z and the splay is that turn eased off. Rotating +Y by `tilt` about
			## Z gives `(-sin tilt, cos tilt)`, which is where the direction below
			## comes from -- derived rather than eyeballed, because a whisker
			## pointing the wrong way still renders.
			var tilt := -90.0 * side + elevation * -side
			var aim := Vector3(
				-sin(deg_to_rad(tilt)), cos(deg_to_rad(tilt)), 0.0
			)
			whiskers.append({
				"name": "Whisker%s%d" % ["L" if side < 0.0 else "R", index],
				"shape": "cone",
				"radius": radius * WHISKER_ROOT_RADIUS,
				"height": length,
				## A cone is centred on its own origin, so seating the fat end at
				## the snout means pushing the whole thing half a length along its
				## own aim.
				"position": root + aim * length * 0.5,
				"rotation": Vector3(0.0, 0.0, tilt),
				"ink": "none",
			})
	return whiskers


## Project a normalised (u, v) onto the front of the head's ellipsoid.
##
## The head is (x/radius)^2 + (y/half_height)^2 + (z/radius)^2 = 1, so with u and
## v already normalised against their own semi-axes the depth falls straight out.
## Forward is -Z, matching the rest of the rig.
## Where a face mark sits, on whichever kind of snout this is.
##
## A sphere muzzle curves, so a mark on it is projected onto an ellipsoid and
## carries the surface normal at that point. A wedge muzzle has a flat front pad,
## so a mark on it sits on that plane at a constant depth and faces straight
## forward. Returning both the point and its normal from one place is what lets
## `build_stroke` frame the mouth identically on either.
static func _seat(
	u: float, v: float, override: Dictionary,
	radius: float, half_height: float, lift: float
) -> Array:
	if not bool(override.get("flat", false)):
		return [
			_surface(u, v, radius, half_height, lift),
			_surface_normal(u, v, radius, half_height),
		]
	var taper_u := clampf(float(override.get("taper_width", 1.0)), 0.05, 1.0)
	var taper_v := clampf(float(override.get("taper_height", 1.0)), 0.05, 1.0)
	var reach := float(override.get("reach", radius))
	return [
		Vector3(
			u * radius * taper_u,
			v * half_height * taper_v,
			-(reach + lift * radius),
		),
		Vector3(0.0, 0.0, -1.0),
	]


## Which way the body faces at a projected (u, v).
##
## The gradient of the ellipsoid `(x/r)^2 + (y/h)^2 + (z/r)^2 = 1`, which is its
## outward normal. `build_stroke` frames the ribbon on this, so the stroke lies
## along the surface instead of standing off it at a fixed world angle -- the
## thing seven axis-aligned boxes could not do and the reason they opened into
## chips wherever the surface turned.
##
## `lift` is deliberately absent: the lift moves a point off the surface, and the
## direction the surface faces there does not change when you do.
static func _surface_normal(
	u: float, v: float, radius: float, half_height: float
) -> Vector3:
	var inside := clampf(1.0 - u * u - v * v, 0.0, 1.0)
	var depth := sqrt(inside)
	var normal := Vector3(
		u * radius / maxf(radius * radius, 0.000001),
		v * half_height / maxf(half_height * half_height, 0.000001),
		-depth * radius / maxf(radius * radius, 0.000001),
	)
	return Vector3(0.0, 0.0, -1.0) if normal.length() < 0.000001 \
		else normal.normalized()


static func _surface(
	u: float, v: float, radius: float, half_height: float,
	lift: float = SURFACE_LIFT
) -> Vector3:
	var inside := clampf(1.0 - u * u - v * v, 0.0, 1.0)
	var depth := sqrt(inside)
	return Vector3(
		u * radius,
		v * half_height,
		-(depth + lift) * radius,
	)
