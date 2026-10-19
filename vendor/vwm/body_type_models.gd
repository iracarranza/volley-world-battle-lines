extends RefCounted
class_name BodyTypeModels

## What each body type looks like, as data.
##
## `PlayerActor3D` was one hand-built rig: a capsule torso, a sphere head, four
## cylinders, and every attachment point written into `set_pose()` as a literal
## -- `left_arm.position = Vector3(-0.40, 1.52, 0.0)`. Six body types already
## existed in generation, carrying real height, mass and attribute deltas, and
## all six drew as that same capsule. A Feli and an Ursi differed in the
## simulation and were indistinguishable on the court.
##
## The rig cannot simply be swapped per type, because those literals only fit
## the proportions they were written for: a taller torso needs its shoulders
## higher or the arms grow out of its chest. So the attachment points move into
## the silhouette alongside the meshes, and `set_pose()` reads them. Posing then
## works for any body plan that can name a shoulder, a hip and a head.
##
## All six types are modelled. `Vegi` replaces `Homi` -- there is no human in
## this world, and the default body being "the normal one" was the only thing
## making the other five read as costumes. Vegi is now the no-lean body the way
## Landavol is the no-lean region: it exists so "unremarkable" has a home instead
## of every type needing an identity.
##
## The three animal types are told apart at the **ear** before anything else,
## because ears survive a silhouette when a torso profile does not: Feli pricks
## up, Cani drops, Ursi is round and set high, Simi is a flat disc on the side of
## the head. Everything below that -- limb thickness, leg length, where the mass
## sits -- is the second read.

## Body types with a silhouette of their own. Anything else falls back.
const MODELLED: Array[String] = ["Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi"]

const FALLBACK_TYPE: String = "Vegi"

## The shapes a Vegi grows in.
##
## These names are internal and stay internal. A Vegi is not "a Tomato" and is
## never labelled as one anywhere a player can read -- they are all just Vegi,
## and the produce is how the variety is generated rather than what the variety
## *is*. Surfacing the name turns a body into a species and invites a taxonomy
## nobody asked for; keeping it internal leaves a roster of Vegi who happen to
## look unlike each other, which is the intent.
##
## Fixed per player for their whole career, because a body you recognise across
## seasons is the point of drawing bodies at all.
##
## Six, with deliberately unlike silhouettes -- squat, tall, wide, waisted,
## rooted and stalky -- so one Vegi reads as a different Vegi at a glance from
## across the court rather than needing the colour to carry it.
## Five, and the count went *down* on purpose.
##
## Pumpkin and Turnip were both "a heavy round mass", which is the silhouette
## Ursi already owns outright and owns better -- a Vegi competing with a body
## type for the same read is a Vegi doing nothing. Pear is already the massive
## one among the produce and needs no help. Pepper takes their slot as the
## lobed, square-shouldered shape none of the others reach, and it is the reason
## palettes exist: a bell pepper is the one produce whose *colour* is the first
## thing anybody names about it.
const PRODUCE: Array[String] = [
	"Tomato", "Aubergine", "Pear", "Stalk", "Pepper",
]

const PRODUCE_BODIES := {
	"Tomato": {
		"skin": Color("d63b2a"), "crown": Color("3f7a35"),
		"crown_shape": "calyx",
		"torso": {"shape": "profile", "radius": 0.36, "height": 0.70,
			"profile": [Vector2(-1.0, 0.10), Vector2(-0.72, 0.29),
				Vector2(-0.20, 0.36), Vector2(0.28, 0.355),
				Vector2(0.72, 0.29), Vector2(1.0, 0.10)],
			"depth_scale": 0.90, "lobes": 6, "lobe_depth": 0.075},
		"torso_y": 1.02, "head_y": 1.46, "head_radius": 0.13,
		"shoulder": Vector2(0.31, 1.28), "rig_height": 1.80,
	},
	"Aubergine": {
		"skin": Color("54307a"), "crown": Color("4e8a3a"),
		"crown_shape": "hood",
		"torso": {"shape": "profile", "radius": 0.285, "height": 1.12,
			"profile": [Vector2(-1.0, 0.08), Vector2(-0.78, 0.20),
				Vector2(-0.35, 0.285), Vector2(0.08, 0.265),
				Vector2(0.58, 0.205), Vector2(1.0, 0.09)],
			"depth_scale": 0.82, "lobes": 5, "lobe_depth": 0.04},
		"torso_y": 1.16, "head_y": 1.78, "head_radius": 0.12,
		"shoulder": Vector2(0.27, 1.52), "rig_height": 2.06,
	},
	"Pear": {
		"skin": Color("b8c452"), "crown": Color("5c8a3c"),
		"crown_shape": "twig",
		## A pear is two masses, so it is the one produce with a second torso
		## lobe rather than a single scaled primitive -- the waist is the shape.
		"torso": {"shape": "profile", "radius": 0.37, "height": 0.92,
			"profile": [Vector2(-1.0, 0.10), Vector2(-0.78, 0.27),
				Vector2(-0.38, 0.385), Vector2(0.05, 0.34),
				Vector2(0.55, 0.185), Vector2(1.0, 0.075)], "depth_scale": 0.88},
		"torso_y": 0.94, "head_y": 1.62, "head_radius": 0.12,
		"shoulder": Vector2(0.26, 1.40), "rig_height": 1.92,
		"extra_lobe": {"radius": 0.22, "height": 0.48, "y": 1.36},
	},
	## The stalky one -- green onion, celery, sugarcane. Every other produce is
	## a mass with limbs on it; this is the one that is essentially vertical, so
	## it covers a silhouette none of the other five reach. The narrow torso is
	## the whole read, which is why it is the tallest and the thinnest at once.
	"Stalk": {
		"skin": Color("9dbf5c"), "crown": Color("cfe08a"),
		## A leek: a bulb at the base, a **parallel-sided** shaft above it, and a
		## flat cut top where the leaves come out.
		##
		## Two earlier profiles both tapered to a narrow rounded top, which is
		## the whole of the bad read -- the first bulged below mid-height, and
		## the replacement narrowed monotonically to 0.05. Neither is a plant.
		## Parallel sides plus a flat termination is, and it is the taper that
		## was doing the damage rather than the thinness. Max radius stays 0.19
		## so the traffic inflection still keys off the same number.
		"torso": {"shape": "profile", "radius": 0.19, "height": 1.36,
			"profile": [Vector2(-1.0, 0.165), Vector2(-0.88, 0.19),
				Vector2(-0.70, 0.148), Vector2(-0.20, 0.145),
				Vector2(0.40, 0.145), Vector2(0.80, 0.147),
				Vector2(1.0, 0.145)], "depth_scale": 0.86},
		"torso_y": 1.24, "head_y": 1.92, "head_radius": 0.105,
		"shoulder": Vector2(0.22, 1.60), "rig_height": 2.12,
		## Three sheath collars lying across the shaft, low, where a leek's
		## layers actually overlap. Horizontal is the point: it is the only
		## element in this vocabulary that interrupts a long upright silhouette,
		## and every previous version of these ribs ran vertically on a body
		## whose problem was that it was already too vertical.
		"ribs": [
			{"x": 0.0, "y": 0.86, "height": 0.36, "thickness": 0.050,
				"rotation": Vector3(0.0, 0.0, 90.0), "z": 0.0},
			{"x": 0.0, "y": 1.04, "height": 0.33, "thickness": 0.044,
				"rotation": Vector3(0.0, 0.0, 90.0), "z": 0.0},
			{"x": 0.0, "y": 1.21, "height": 0.31, "thickness": 0.038,
				"rotation": Vector3(0.0, 0.0, 90.0), "z": 0.0},
		],
		## The white base. `blush` was built for Turnip -- white below, purple on
		## the shoulder -- and went unused when Turnip was cut. A leek is the same
		## mechanism the other way up, and a hard horizontal colour break is the
		## cheapest silhouette-breaker there is.
		"blush": Color("edf2de"), "blush_y": -0.40, "blush_height": 0.46,
		"crown_shape": "blades",
	},
	## Square-shouldered and lobed, which is a shape none of the other four
	## reach: broad across the top and tapering to the bottom.
	##
	## **The lobes are the body, and getting that wrong is what made a cage.**
	## They were built on the Stalk's rib mechanism -- thin vertical capsules laid
	## on the surface of a sphere, in the crown colour. Five green rods standing
	## off a red ball is not a pepper with ridges on it; it is a ball in a cage,
	## and it read as one from every angle.
	##
	## A pepper's lobes are not ridges *on* a shape. They are the shape: four fat
	## vertical bulges packed round the axis, meeting in grooves rather than
	## sitting on a surface. So they are wide (0.215 against 0.058, near four
	## times), skin-coloured rather than crown, and set close enough to the axis
	## that adjacent lobes overlap -- centres 0.219 apart with radii of 0.215
	## each, so the union is continuous and the grooves are where two bulges meet.
	## Seen from above that is a clover, which is what a pepper's cross-section is.
	##
	## Each is stretched out of the sphere it starts as: narrowed across its own
	## width so the grooves stay legible, pushed out along the radius so the bulge
	## bulges. That needs a non-uniform scale, which no primitive here can express
	## -- a `SphereMesh` has one radius for both horizontal axes -- so the lobes
	## are what put a `scale` on a cosmetic part.
	"Pepper": {
		"skin": Color("c8332c"), "crown": Color("4f7c3a"),
		## The core is smaller than the shape it sits inside now, because it is no
		## longer the shape: it is what the kit, the shorts and the arms are
		## measured off, and the lobes are what anybody sees. Left at a radius the
		## lobes comfortably swallow, so it cannot poke out between two of them.
		"torso": {"shape": "profile", "radius": 0.34, "height": 0.76,
			"profile": [Vector2(-1.0, 0.16), Vector2(-0.72, 0.27),
				Vector2(-0.15, 0.325), Vector2(0.48, 0.34),
				Vector2(0.82, 0.29), Vector2(1.0, 0.16)],
			"sides": 32, "lobes": 4, "lobe_depth": 0.24,
			"depth_scale": 0.92},
		"torso_y": 1.04, "head_y": 1.56, "head_radius": 0.128,
		"shoulder": Vector2(0.34, 1.34), "rig_height": 1.88,
		## Rounder and shorter than the first cut, which flared. At height 0.76
		## with a 1.12 radial stretch the four lobes were tall ellipsoids whose
		## bottoms converged below the core, so the silhouette came to a point and
		## read as a bat rather than as a pepper -- the cage was gone and something
		## else had taken its place. A pepper is widest at the shoulder and *blunt*
		## underneath, so the lobes are wider across, shorter, and no longer pushed
		## out along the radius at all.
		"crown_shape": "cap",
	},
}


## Colourways, per body.
##
## Two volis of the same body type used to be the same colour, which meant the
## only thing separating them on a roster was a name -- and a roster is where you
## are supposed to *recognise* people. A palette is the cheapest identity there
## is: it costs no geometry, survives any distance the game is watched from, and
## it is the first thing anybody describes a teammate by.
##
## Bell peppers are why this exists. A pepper's colour is the first thing anybody
## names about it, so the produce that most needed variants is the one that made
## it obvious every body needed them.
##
## Deterministic per voli and fixed for their career, like the produce. `crown`
## is the secondary -- leaves, beak, ears, muzzle -- and it is chosen with the
## skin rather than separately, because the pairing is the palette.
const PALETTES := {
	"Feli": [
		{"skin": Color("c98f4e"), "crown": Color("f0dcc0")},
		{"skin": Color("6d6a66"), "crown": Color("d9d5cd")},
		{"skin": Color("2f2b2c"), "crown": Color("b9a98f")},
		{"skin": Color("d8b98a"), "crown": Color("8a5f3c")},		## Six added on the same rule as Simi: keep the authored four, then
		## fan hue around a value ladder, because value is what survives at
		## portrait size. One entry inverts a dark crown onto a light coat.
		{"skin": Color("e8e2d8"), "crown": Color("8a7f70")},  ## silver
		{"skin": Color("4f6470"), "crown": Color("cdd8de")},  ## blue
		{"skin": Color("7a4a30"), "crown": Color("e8c9a8")},  ## chocolate
		{"skin": Color("b0562f"), "crown": Color("f4dcc0")},  ## red
		{"skin": Color("9a9384"), "crown": Color("efe9dc")},  ## taupe
		{"skin": Color("5c4a55"), "crown": Color("ded0da")},  ## smoke
	],
	"Avi": [
		{"skin": Color("8fb7d6"), "crown": Color("e8a63c")},
		{"skin": Color("d9dfe4"), "crown": Color("d96a3c")},
		{"skin": Color("4a7f5e"), "crown": Color("e8c93c")},
		{"skin": Color("c46b8a"), "crown": Color("f2e0c0")},		## Six added on the same rule as Simi: keep the authored four, then
		## fan hue around a value ladder, because value is what survives at
		## portrait size. One entry inverts a dark crown onto a light coat.
		{"skin": Color("e8c33c"), "crown": Color("d9662c")},  ## canary
		{"skin": Color("6b4fa0"), "crown": Color("f0d94a")},  ## violet
		{"skin": Color("28303a"), "crown": Color("d9a83c")},  ## corvid
		{"skin": Color("c9432f"), "crown": Color("2f2a26")},  ## cardinal
		{"skin": Color("9ec46b"), "crown": Color("e85a2c")},  ## parakeet
		{"skin": Color("7a6a5a"), "crown": Color("e8dcc0")},  ## sparrow
	],
	"Cani": [
		{"skin": Color("8a6a45"), "crown": Color("e8ddc8")},
		{"skin": Color("3c3a3f"), "crown": Color("c9c2b4")},
		{"skin": Color("c9a06a"), "crown": Color("f4ecdc")},
		{"skin": Color("6f4a34"), "crown": Color("d8c3a0")},		## Six added on the same rule as Simi: keep the authored four, then
		## fan hue around a value ladder, because value is what survives at
		## portrait size. One entry inverts a dark crown onto a light coat.
		{"skin": Color("e5d9c2"), "crown": Color("7a6248")},  ## cream
		{"skin": Color("5d6b74"), "crown": Color("d5dde2")},  ## merle
		{"skin": Color("9d3f2a"), "crown": Color("f0cdb0")},  ## red
		{"skin": Color("232022"), "crown": Color("c8bda8")},  ## charcoal
		{"skin": Color("b8b3a8"), "crown": Color("6b6257")},  ## silver
		{"skin": Color("c2703a"), "crown": Color("f4dcc4")},  ## apricot
	],
	"Ursi": [
		{"skin": Color("4a3b34"), "crown": Color("d9c9b4")},
		{"skin": Color("1f1c1e"), "crown": Color("cdd6db")},
		{"skin": Color("8a6f52"), "crown": Color("efe3cd")},
		{"skin": Color("d6c6ad"), "crown": Color("6b5847")},		## Six added on the same rule as Simi: keep the authored four, then
		## fan hue around a value ladder, because value is what survives at
		## portrait size. One entry inverts a dark crown onto a light coat.
		{"skin": Color("f0ece2"), "crown": Color("6b5f52")},  ## polar
		{"skin": Color("b5673a"), "crown": Color("f2d9b8")},  ## cinnamon
		{"skin": Color("5a6a72"), "crown": Color("d8e0e4")},  ## glacier
		{"skin": Color("6e5f4a"), "crown": Color("e4dccb")},  ## grizzled
		{"skin": Color("3a2f3a"), "crown": Color("c9b8a8")},  ## sable
		{"skin": Color("8a7a3c"), "crown": Color("f4e8c0")},  ## honey
	],
	## **Ten, and spread on value first.** The four this replaces were all one
	## hue -- warm brown -- with two of them a step apart in value, so a squad
	## with three Simi in it read as the same voli three times. Value is what
	## survives at portrait size, so the ladder runs near-black to cream and the
	## hues fan out around it rather than clustering. The last entry inverts a
	## dark crown onto a light coat, which the Feli and Ursi tables already do.
	"Simi": [
		{"skin": Color("6f5a4e"), "crown": Color("f0d9bd")},
		{"skin": Color("2e2a2b"), "crown": Color("c4a888")},
		{"skin": Color("a08466"), "crown": Color("f4e6cf")},
		{"skin": Color("55402f"), "crown": Color("e0b98c")},
		{"skin": Color("7c7a76"), "crown": Color("dcd8cf")},
		{"skin": Color("9a5a3c"), "crown": Color("f2c9a0")},
		{"skin": Color("6b6b45"), "crown": Color("e6e0b8")},
		{"skin": Color("4a5560"), "crown": Color("cfd8de")},
		{"skin": Color("5a3f52"), "crown": Color("d9bcd0")},
		{"skin": Color("d9c3a2"), "crown": Color("7a5f45")},
	],
	"Tomato": [
		{"skin": Color("d63b2a"), "crown": Color("3f7a35")},
		{"skin": Color("e8b13a"), "crown": Color("4d7d38")},
		{"skin": Color("7d2a3a"), "crown": Color("4a7040")},
	],
	"Aubergine": [
		{"skin": Color("54307a"), "crown": Color("4e8a3a")},
		{"skin": Color("2b2140"), "crown": Color("6a9b46")},
		{"skin": Color("d8d2e0"), "crown": Color("5b8c3f")},
	],
	"Pear": [
		{"skin": Color("b8c452"), "crown": Color("5c8a3c")},
		{"skin": Color("caa23c"), "crown": Color("6b7a3a")},
		{"skin": Color("8f5a3a"), "crown": Color("5f7a42")},
	],
	"Stalk": [
		{"skin": Color("9dbf5c"), "crown": Color("cfe08a")},
		{"skin": Color("e4ebd2"), "crown": Color("8fbf5c")},
		{"skin": Color("6f9a4a"), "crown": Color("d6e6a0")},
	],
	## Five, because a bell pepper's colours are a known set and this is the
	## produce the whole palette idea came from.
	"Pepper": [
		{"skin": Color("c8332c"), "crown": Color("4f7c3a")},
		{"skin": Color("e8b43a"), "crown": Color("4f7c3a")},
		{"skin": Color("d97a1e"), "crown": Color("5a8440")},
		{"skin": Color("5d8f3f"), "crown": Color("3f6b32")},
		{"skin": Color("6b3f7a"), "crown": Color("4a7040")},
	],
}


## Which colourway a voli wears. Seeded from the id like `produce_for`, and
## deliberately a *different* hash string so body shape and colour do not
## correlate -- one hash driving both would make every Tomato red and every
## Stalk pale, which is the thing this is meant to prevent.
static func palette_for(body_key: String, player_id: int) -> Dictionary:
	var options: Array = PALETTES.get(body_key, [])
	if options.is_empty():
		return {}
	var index := absi(hash("palette:%s:%d" % [body_key, player_id])) % options.size()
	return Dictionary(options[index])


## The torso's radius a fraction of the way up from its centre, so a part worn
## on it can be sized to where it actually sits. `up` is in units of the torso's
## own vertical semi-axis.
##
## A sphere torso narrows toward the top and a capsule does not, and a single
## constant cannot serve both -- which is how the kit band ended up either
## buried or floating depending on which produce wore it.
## The torso's own half-width at a height, as a fraction of its semi-height.
##
## **Capsules were returning a constant**, which is the whole profile of a
## cylinder and only the middle band of a capsule. A capsule is flat through the
## centre and turns in through two hemispherical caps: on the standard torso the
## caps start 0.130 from the middle, so a stripe 0.54 long spends more than half
## its length in a region where the body has already narrowed. Placed on the
## constant radius it hangs off the shirt at both ends, which is exactly what
## the tall patterns were doing.
static func _torso_radius_at(torso: Dictionary, up: float) -> float:
	var radius := float(torso.get("radius", 0.32))
	var shape := str(torso.get("shape", "sphere"))
	if shape == "profile":
		var profile: Array = torso.get("profile", [])
		if profile.is_empty():
			return radius
		var normalized := clampf(up, -1.0, 1.0)
		for index in range(profile.size() - 1):
			var lower: Vector2 = profile[index]
			var upper: Vector2 = profile[index + 1]
			if normalized <= upper.x:
				return lerpf(lower.y, upper.y, inverse_lerp(lower.x, upper.x, normalized))
		return float((profile.back() as Vector2).y)
	if shape == "capsule":
		var semi := float(torso.get("height", 1.0)) * 0.5
		## Where the cylinder ends and the cap begins.
		var straight := maxf(semi - radius, 0.0)
		var y := absf(clampf(up, -1.0, 1.0)) * semi
		if y <= straight:
			return radius
		var into_cap := minf(y - straight, radius)
		return radius * sqrt(maxf(1.0 - pow(into_cap / radius, 2.0), 0.04))
	if shape != "sphere":
		return radius
	var t := clampf(up, 0.0, 0.98)
	return radius * sqrt(maxf(1.0 - t * t, 0.04))


## How far a mark's underside sinks into the body it lies on.
##
## Small and deliberately non-zero. A patch whose inner face is exactly on the
## surface leaves a hairline of body colour showing between the two wherever the
## tessellation of one disagrees with the other, and a shirt seam that flickers
## at the edge is worse than one buried three millimetres.
const PATCH_BITE: float = 0.003
## The longest a patch quad may be along either axis before it is subdivided
## again. Small enough that a panel wrapping a 0.31 m torso never shows a facet;
## large enough that a 12 mm tick stays two triangles.
const PATCH_STEP: float = 0.028


## A mark that lies **on** a body rather than a box standing in front of one.
##
## **Why this exists, since the previous three attempts each sounded sufficient.**
## A kit mark used to be a stack of `BoxMesh` segments, each one flat, each one
## placed at the radius its own height gave it. Through the barrel of a torso
## that is fine, because the radius does not change. Through the caps it is not:
## a capsule of radius 0.308 loses about 10 mm of radius between one segment of a
## 0.52 m panel and the next, while the panel is only 12 mm deep. Every joint
## between two segments was therefore a step nearly as tall as the mark was
## thick, and every step showed its own horizontal top face -- lit from above by
## the key, which is why they read as bright dashes scattered through the *upper*
## half of a panel and not the lower, and why the outline stepped instead of
## curving. Three repairs missed it because all three assumed the defect was in
## how the boxes were *seated* rather than in their being boxes at all: removing
## the 6% segment overlap, ruling out coplanar z-fighting, and anchoring the
## inner face instead of the centre each changed nothing measurable, and the
## per-segment dump showed the geometry was doing exactly what it was told.
##
## A box cannot follow a curve. So a mark is now a **patch**: a tessellated shell
## whose vertices are evaluated on the body's own profile, extruded `depth`
## outward and `PATCH_BITE` inward. It curves because its vertices curve.
##
## Three things the box stack could not do fall out of this for free -- a mark
## wider than the flat of the body no longer floats at its edges, a tapering
## stroke tapers continuously rather than in steps, and a rolled stroke shears
## along the surface instead of tilting a slab off it.
##
## `rows` runs top to bottom, each entry `{y, radius, u, half}`: the height, the
## body's radius there, the arc-centre of the mark and its half-width, both in
## metres of arc. `reference_radius` converts arc to angle and is held constant
## down the mark, because a vertical line on a body is a line of constant
## longitude -- deriving the angle per row instead is what splayed Blôc's
## outermost stripe from 50 degrees at its middle to 60 at its ends.
static func build_surface_patch(
	rows: Array, face: float, reference_radius: float, depth: float
) -> ArrayMesh:
	if rows.size() < 2:
		return ArrayMesh.new()
	var columns := 2
	for row in rows:
		columns = maxi(
			columns, int(ceil(float(row["half"]) * 2.0 / PATCH_STEP))
		)
	columns = mini(columns, 12)
	var outer: Array = []
	var inner: Array = []
	for row in rows:
		var ring_out: Array = []
		var ring_in: Array = []
		var radius := float(row["radius"])
		var up := float(row["y"])
		var half := float(row["half"])
		for column in range(columns + 1):
			var arc := float(row["u"]) + lerpf(
				-half, half, float(column) / float(columns)
			)
			var theta := arc / maxf(reference_radius, 0.001)
			ring_out.append(_patch_point(radius + depth, theta, up, face))
			ring_in.append(_patch_point(radius - PATCH_BITE, theta, up, face))
		outer.append(ring_out)
		inner.append(ring_in)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := rows.size() - 1
	for row in range(last):
		for column in range(columns):
			## Outward, then the same shell reversed for the underside.
			_patch_quad(
				tool, face,
				outer[row][column], outer[row + 1][column],
				outer[row + 1][column + 1], outer[row][column + 1]
			)
			_patch_quad(
				tool, face,
				inner[row][column + 1], inner[row + 1][column + 1],
				inner[row + 1][column], inner[row][column]
			)
		## The two long edges: the visible rim of a seam or a panel.
		_patch_quad(
			tool, face,
			outer[row][0], inner[row][0], inner[row + 1][0], outer[row + 1][0]
		)
		_patch_quad(
			tool, face,
			inner[row][columns], outer[row][columns],
			outer[row + 1][columns], inner[row + 1][columns]
		)
	for column in range(columns):
		_patch_quad(
			tool, face,
			inner[0][column], outer[0][column],
			outer[0][column + 1], inner[0][column + 1]
		)
		_patch_quad(
			tool, face,
			outer[last][column], inner[last][column],
			inner[last][column + 1], outer[last][column + 1]
		)
	## Per-triangle, deliberately. Averaging across shared vertices would smooth
	## the rim into the face and lose the edge that makes a panel read as applied
	## rather than printed; the shell is subdivided finely enough that flat
	## normals on it are indistinguishable from smooth ones.
	tool.generate_normals()
	return tool.commit()


static func _patch_point(
	radius: float, theta: float, up: float, face: float
) -> Vector3:
	return Vector3(radius * sin(theta), up, face * radius * cos(theta))


## One quad, wound so its front face points away from the body.
##
## The back of a shirt is the same construction reflected, and reflection
## reverses handedness -- so a winding that faces outward on the chest faces
## *into* the body on the back. Flipping here rather than at every call site is
## the difference between one rule and sixteen chances to get it wrong.
## A single stroke laid along a curve on a body, instead of a row of chips.
##
## **The same defect `build_surface_patch` above was written for, one face
## further in.** A mouth was seven axis-aligned `BoxMesh` segments placed along a
## parabola and never rotated, which on a skull is survivable and on a muzzle is
## not: a 0.10 m snout curves away far faster than a 0.185 m head, so toward the
## corners each box left the surface at a different depth and the stroke opened
## into a row of separate dark chips. It looked like bared teeth, and the
## measured repair at the time was to raise `MUZZLE_LIFT` to 0.13 -- which does
## not close the gaps, it floats the whole row in front of the snout.
##
## The other half was invisible and worse. `PlayerActor3D._ink_node` gives every
## mesh its own inverted hull, so seven boxes carried **seven independent 30 mm
## black outlines**, which is what actually drew the chips. One mesh has one
## outline, and `BACKLOG.md`'s open note on roster-distance line noise -- "two
## outlines at slightly different offsets is most of the noise" -- gets seven
## fewer of them per face.
##
## `points` is the centreline already projected onto the body, `normals` the
## outward surface normal at each. The ribbon is framed per sample from those two,
## so it shears along the surface the way `build_surface_patch` does rather than
## tilting a slab off it; `thickness` is the half-width across the stroke and
## `depth` how far it stands proud, both in metres.
## A snout: a box that tapers toward its front face.
##
## **The angular jaw is the point, not a side effect.** A sphere muzzle gives a
## round bulge with no jawline at all, and the study's prism gave a straight jaw
## meeting a corner -- which reads as a snout on a body drawn entirely from flat
## planes, and which is what was chosen. Eight vertices, front face smaller than
## the back, so the taper is the whole shape.
##
## Sized from `half_width` and `half_height` -- the same envelope a sphere muzzle
## published as `radius` and `height * 0.5` -- because `PlayerActor3D._mouth_override`
## and `_featured_muzzle` both read a muzzle's size by those names and would
## otherwise have to learn a second vocabulary for the same quantity.
## **Width and height taper independently, and collapsing them was wrong.** A
## single ratio makes the front pad a scale model of the back, which is a cone
## with corners; a snout narrows faster across than it does top-to-bottom, and
## that difference is the jawline. The study this shape was taken from used
## 0.64 across against 0.71 down on the same muzzle.
static func build_wedge(
	half_width: float,
	half_height: float,
	depth: float,
	taper_width: float,
	taper_height: float,
) -> ArrayMesh:
	var back := depth * 0.5
	var front := -depth * 0.5
	var front_w := half_width * taper_width
	var front_h := half_height * taper_height
	var b := [
		Vector3(-half_width, half_height, back), Vector3(half_width, half_height, back),
		Vector3(half_width, -half_height, back), Vector3(-half_width, -half_height, back),
	]
	var f := [
		Vector3(-front_w, front_h, front), Vector3(front_w, front_h, front),
		Vector3(front_w, -front_h, front), Vector3(-front_w, -front_h, front),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	## Front, back, then the four tapering sides.
	##
	## **Wound with `face = -1`, and the first version was not.** `_patch_quad`
	## emits `a-b-c` / `a-c-d`, and this codebase's front face for that order is
	## the *negation* of the geometric cross product -- so a front face listed
	## corner-clockwise as seen from outside points inward. Every wedge came out
	## inside-out: the muzzle itself was culled and what showed through was the
	## interior of its own black ink hull, which reads as a snout-shaped hole.
	## `_limb_mesh` records the same trap in the same file: reversed winding made
	## an inverted-hull outline "fill the limb solid black".
	_patch_quad(tool, -1.0, f[0], f[1], f[2], f[3])
	_patch_quad(tool, -1.0, b[1], b[0], b[3], b[2])
	_patch_quad(tool, -1.0, b[0], b[1], f[1], f[0])
	_patch_quad(tool, -1.0, b[2], b[3], f[3], f[2])
	_patch_quad(tool, -1.0, b[3], b[0], f[0], f[3])
	_patch_quad(tool, -1.0, b[1], b[2], f[2], f[1])
	tool.generate_normals()
	return tool.commit()


## A tapered feather fan, broad where it grows out of a limb and narrow at the tip.
##
## **A box cannot be a wing for the same reason it could not be a mouth.** The Avi
## wings were one `BoxMesh` each, 0.40 m deep at the shoulder and 0.40 m deep at
## the wrist, which is the profile of a shield rather than of plumage -- and the
## file's own comment above them already claimed "Feathers, not panels" over a
## single constant-section slab. A wing's whole read is that it grows *out of*
## something and runs out at the end.
##
## Swept along -y from the root, because that is the direction a limb hangs in
## the rig and the fan is parented to a limb. `sweep` trails the tip backward in
## +z so the trailing edge rakes instead of squaring off; zero is a straight fan.
## A blade still wrapped around the thing it grew out of.
##
## A leek's shaft *is* the rolled bundle of its blade bases: each blade is a
## C-shaped sheath enclosing the ones inside it, and only its upper length peels
## away and flattens. Four versions of the crown drew every blade as a flat box,
## which is why they read as protrusions stuck on a stem rather than as leaves --
## a plank cannot enclose anything.
##
## The arc is centred on local +X and swept about local +Y, so a sheath is placed
## on the shaft axis rather than beside it, and `yaw` turns which way it opens.
## Nesting is then just a radius: an outer blade at a larger radius encloses an
## inner one at a smaller, the way the vegetable does it.
static func build_sheath(
	radius: float,
	arc_degrees: float,
	height: float,
	thickness: float,
	taper: float = 1.0,
) -> ArrayMesh:
	var arc_steps := 8
	var half := maxf(thickness, 0.001) * 0.5
	var half_height := height * 0.5
	var outer: Array = [[], []]
	var inner: Array = [[], []]
	for level in range(2):
		var y := -half_height if level == 0 else half_height
		## The mouth of the sheath opens as it rises, which is the taper.
		var level_arc := deg_to_rad(arc_degrees) * (1.0 if level == 0 else taper)
		for index in range(arc_steps + 1):
			var angle := -level_arc * 0.5 \
				+ level_arc * float(index) / float(arc_steps)
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			outer[level].append(direction * (radius + half) + Vector3(0.0, y, 0.0))
			inner[level].append(direction * (radius - half) + Vector3(0.0, y, 0.0))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(arc_steps):
		var step := index + 1
		## Convex face outward, concave face inward, wound opposite ways.
		_patch_quad(tool, 1.0,
			outer[0][index], outer[0][step], outer[1][step], outer[1][index])
		_patch_quad(tool, 1.0,
			inner[1][index], inner[1][step], inner[0][step], inner[0][index])
		## The rims, which are the edges a viewer actually reads the curl from.
		_patch_quad(tool, 1.0,
			outer[1][index], outer[1][step], inner[1][step], inner[1][index])
		_patch_quad(tool, 1.0,
			inner[0][index], inner[0][step], outer[0][step], outer[0][index])
	var last := arc_steps
	## The two cut sides, so the shell has a visible thickness where it ends.
	_patch_quad(tool, 1.0,
		outer[0][0], inner[0][0], inner[1][0], outer[1][0])
	_patch_quad(tool, 1.0,
		inner[0][last], outer[0][last], outer[1][last], inner[1][last])
	tool.generate_normals()
	return tool.commit()


static func build_fan(
	root_chord: float,
	tip_chord: float,
	span: float,
	thickness: float,
	sweep: float = 0.0,
) -> ArrayMesh:
	var steps := 6
	var half := maxf(thickness, 0.001) * 0.5
	var front: Array = []
	var back: Array = []
	for index in range(steps + 1):
		var along := float(index) / float(steps)
		var chord := lerpf(root_chord, tip_chord, along)
		var down := -span * along
		## The leading edge stays on the limb's own line; the chord and the rake
		## both grow backward from it, so the fan never drifts in front of the arm
		## it belongs to.
		var lead := sweep * along
		front.append(Vector3(0.0, down, lead))
		back.append(Vector3(0.0, down, lead + chord))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := Vector3(half, 0.0, 0.0)
	for index in range(steps):
		var step := index + 1
		_patch_quad(tool, 1.0,
			front[index] + side, front[step] + side,
			back[step] + side, back[index] + side)
		_patch_quad(tool, 1.0,
			back[index] - side, back[step] - side,
			front[step] - side, front[index] - side)
		## The leading and trailing edges, which is where the taper actually shows.
		_patch_quad(tool, 1.0,
			front[index] - side, front[step] - side,
			front[step] + side, front[index] + side)
		_patch_quad(tool, 1.0,
			back[index] + side, back[step] + side,
			back[step] - side, back[index] - side)
	var last := steps
	_patch_quad(tool, 1.0,
		front[0] + side, back[0] + side, back[0] - side, front[0] - side)
	_patch_quad(tool, 1.0,
		front[last] - side, back[last] - side, back[last] + side, front[last] + side)
	tool.generate_normals()
	return tool.commit()


static func build_stroke(
	points: PackedVector3Array,
	normals: PackedVector3Array,
	thickness: float,
	depth: float,
) -> ArrayMesh:
	var count := points.size()
	if count < 2 or normals.size() != count:
		return ArrayMesh.new()
	var outer_up: Array = []
	var outer_down: Array = []
	var inner_up: Array = []
	var inner_down: Array = []
	for index in range(count):
		## Central difference along the stroke, one-sided at the ends. The
		## direction the stroke is *going* is what decides which way its width
		## lies, and taking it from a neighbour rather than from the authored
		## parabola keeps the frame correct for any curve a caller supplies.
		var ahead: Vector3 = points[mini(index + 1, count - 1)]
		var behind: Vector3 = points[maxi(index - 1, 0)]
		var along := ahead - behind
		if along.length() < 0.000001:
			along = Vector3(1.0, 0.0, 0.0)
		along = along.normalized()
		var out := normals[index]
		out = Vector3(0.0, 0.0, -1.0) if out.length() < 0.000001 else out.normalized()
		## Across the stroke, tangent to the surface: perpendicular to both the
		## sweep and the normal. This is the axis a box could not follow, because a
		## box's own axes are the world's.
		var across := out.cross(along)
		across = Vector3(0.0, 1.0, 0.0) if across.length() < 0.000001 \
			else across.normalized()
		var centre: Vector3 = points[index]
		var proud := centre + out * depth
		var bitten := centre - out * PATCH_BITE
		outer_up.append(proud + across * thickness)
		outer_down.append(proud - across * thickness)
		inner_up.append(bitten + across * thickness)
		inner_down.append(bitten - across * thickness)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(count - 1):
		var step := index + 1
		## Face out, face in, then the two long edges -- the same four-walled
		## shell `build_surface_patch` builds, swept along a curve instead of
		## stacked in rows.
		_patch_quad(tool, 1.0,
			outer_up[index], outer_up[step], outer_down[step], outer_down[index])
		_patch_quad(tool, 1.0,
			inner_down[index], inner_down[step], inner_up[step], inner_up[index])
		_patch_quad(tool, 1.0,
			inner_up[index], inner_up[step], outer_up[step], outer_up[index])
		_patch_quad(tool, 1.0,
			outer_down[index], outer_down[step], inner_down[step], inner_down[index])
	## The two ends, so a stroke seen from the side is a solid and not a trough.
	var last := count - 1
	_patch_quad(tool, 1.0,
		inner_up[0], inner_down[0], outer_down[0], outer_up[0])
	_patch_quad(tool, 1.0,
		outer_up[last], outer_down[last], inner_down[last], inner_up[last])
	tool.generate_normals()
	return tool.commit()


static func _patch_quad(
	tool: SurfaceTool, face: float, a: Vector3, b: Vector3, c: Vector3, d: Vector3
) -> void:
	if face >= 0.0:
		tool.add_vertex(a)
		tool.add_vertex(b)
		tool.add_vertex(c)
		tool.add_vertex(a)
		tool.add_vertex(c)
		tool.add_vertex(d)
		return
	tool.add_vertex(a)
	tool.add_vertex(d)
	tool.add_vertex(c)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)


## What grows out of the top. One shape per produce rather than one stem and two
## leaves for all of them.
##
## Every Vegi wearing the same crown meant the head was the one place they were
## identical, which is the worst place to be identical -- it is where the eye
## goes first and where the face already lives. These are also chosen to *not*
## sit at eye level: the old leaves stuck straight out sideways across the face,
## which was the collision complaint.
static func _produce_crown(body: Dictionary) -> Array:
	var top := float(body.head_y) + float(body.head_radius) * 0.92
	match str(body.get("crown_shape", "calyx")):
		"hood":
			## Aubergine. A broad calyx that caps the head rather than sprouting
			## from it, angled back so it never crosses the face.
			return [
				{
					"name": "Hood", "parent": "BodyPivot", "shape": "cone",
					"radius": float(body.head_radius) * 1.48, "height": 0.19,
					"position": Vector3(0.0, top + 0.05, 0.03),
					"rotation": Vector3(-16.0, 0.0, 0.0), "color": "crown",
				},
				{
					## **A stem grows out of its own calyx, not beside it.**
					##
					## The hood is tilted -16 degrees and offset 0.03 forward;
					## this stood upright at 0.02, so the cone pointed one way and
					## the stalk left from a different spot on a different axis.
					## Reading as off-centre is exactly what two parts that should
					## share an axis and do not look like. Both numbers now come
					## from the hood above rather than being stated twice.
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.03, "bottom_radius": 0.042, "height": 0.13,
					"position": Vector3(0.0, top + 0.15, 0.03),
					"rotation": Vector3(-16.0, 0.0, 0.0), "color": "crown",
				},
			]
		"twig":
			## Pear. A pear has a bare stalk and nothing else, and it is the one
			## produce whose silhouette is already doing enough work.
			return [
				{
					## **The lean stays, the list does not.** A pear stalk leans,
					## which is the -9 degrees of pitch. The 6 degrees of *roll*
					## tipped it sideways off the body's own axis, and with no
					## crown here for it to belong to there is nothing that offset
					## is relative to -- every other produce puts its crown at
					## exactly 0.0. Roll and the 0.01 shift removed; the pitch is
					## character and is kept.
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.022, "bottom_radius": 0.038, "height": 0.26,
					"position": Vector3(0.0, top + 0.11, 0.0),
					"rotation": Vector3(-9.0, 0.0, 0.0), "color": "crown",
				},
			]
		"blades":
			## A forked pair of tubular shoots.
			##
			## The primary rises from the stalk, then bends up-left.
			## A smaller secondary shoot begins at that exact bend and travels
			## up-right. Unlike the former blade crown, neither shoot is a flat leaf:
			## both are continuations of the stalk's tubular growth.

			var shaft_top := float(body.torso_y) \
				+ float(body.torso.get("height", 1.36)) * 0.5

			var shoot_radius := float(body.head_radius) * 0.20
			var fork_yaw := 15.0
			var fork_yaw_radians := deg_to_rad(fork_yaw)

			var shoots: Array = []

			## Shared upright portion of the primary.
			var stem_length := 0.22
			var stem_base := Vector3(0.0, shaft_top - 0.08, 0.0)
			var bend_point := stem_base + Vector3.UP * stem_length

			shoots.append({
				"name": "PrimaryShootStem",
				"parent": "BodyPivot",
				"shape": "cylinder",
				"radius": shoot_radius,
				"height": stem_length,
				"position": stem_base + Vector3.UP * stem_length * 0.5,
				"rotation": Vector3(0.0, fork_yaw, 0.0),
				"color": "crown",
			})

			## PRIMARY
			##
			## Cylinder begins aligned to +Y.
			## Rotating +45 degrees around Z points it up-left:
			##
			##       ↖
			##        \
			##         bend
			var primary_lean := 55.0
			var primary_length := 0.32
			var primary_radians := deg_to_rad(primary_lean)

			var primary_direction := Vector3(
				-sin(primary_radians),
				cos(primary_radians),
				0.0
			).rotated(Vector3.UP, fork_yaw_radians)

			shoots.append({
				"name": "PrimaryShoot",
				"parent": "BodyPivot",
				"shape": "cylinder",
				"radius": shoot_radius,
				"height": primary_length,
				"position": bend_point \
					+ primary_direction * primary_length * 0.5,
				"rotation": Vector3(0.0, fork_yaw, primary_lean),
				"color": "crown",
			})

			## SECONDARY
			##
			## Starts at precisely the primary bend.
			## -45 degrees around Z gives the opposite upward diagonal.
			var secondary_lean := -55.0
			var secondary_length := 0.28
			var secondary_radius := 0.78
			var secondary_radians := deg_to_rad(secondary_lean)

			var secondary_direction := Vector3(
				-sin(secondary_radians),
				cos(secondary_radians),
				0.0
			).rotated(Vector3.UP, fork_yaw_radians)

			shoots.append({
				"name": "SecondaryShoot",
				"parent": "BodyPivot",
				"shape": "cylinder",
				"radius": secondary_radius,
				"height": secondary_length,
				"position": bend_point \
					+ secondary_direction * secondary_length * 0.5,
				"rotation": Vector3(0.0, fork_yaw, secondary_lean),
				"color": "crown",
			})

			return shoots
		"cap":
			## Pepper. A flat cap disc with a short thick stem through it.
			return [
				{
					"name": "Cap", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": float(body.head_radius) * 1.02,
					"bottom_radius": float(body.head_radius) * 1.26,
					"height": 0.055,
					"position": Vector3(0.0, top + 0.02, 0.0), "color": "crown",
				},
				{
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.032, "bottom_radius": 0.046, "height": 0.14,
					"position": Vector3(0.0, top + 0.10, 0.0), "color": "crown",
				},
			]
		_:
			## Tomato. A star calyx, laid flat on the crown of the head where it
			## reads as a tomato's five points rather than as ears.
			var points: Array = [
				{
					"name": "Stem", "parent": "BodyPivot", "shape": "cylinder",
					"top_radius": 0.028, "bottom_radius": 0.042, "height": 0.14,
					"position": Vector3(0.0, top + 0.07, 0.0), "color": "crown",
				},
			]
			for index in range(5):
				var angle := TAU * float(index) / 5.0
				points.append({
					"name": "Calyx%d" % index, "parent": "BodyPivot",
					"shape": "box", "size": Vector3(0.055, 0.022, 0.18),
					"position": Vector3(
						sin(angle) * float(body.head_radius) * 0.62,
						top + 0.01,
						cos(angle) * float(body.head_radius) * 0.62,
					),
					"rotation": Vector3(-14.0, rad_to_deg(angle), 0.0),
					"color": "crown",
				})
			return points


## Deterministic per player, so a Vegi is the same aubergine every match, in
## every screen, for their whole career. Seeded from the id rather than drawn
## from any RNG: the generation stream is shared, and taking a value from it
## here would reroll every player created afterwards.
static func produce_for(player_id: int) -> String:
	var index := absi(hash("vegi:%d" % player_id)) % PRODUCE.size()
	return PRODUCE[index]


static func is_modelled(body_type: String) -> bool:
	return body_type in MODELLED


## One shared body, described as fractions of a player's own height.
##
## The three type functions below were each authored as a complete skeleton, so
## every one of them restated the whole figure in order to say the one or two
## things that make it distinctive. Restating the whole figure is how they drifted
## away from each other and away from a person: Feli's shoulders sat at 0.745 of
## its height and Avi's at 0.750, against roughly 0.82 on a human, while both
## hung arms long enough to put the hands at 0.30-0.32 where a person's fingertips
## reach about 0.38. Low shoulders and long arms is not a neutral pair of errors
## -- together they read as simian, which is a thing the silhouette says about a
## player that nobody chose to say.
##
## So the shared figure lives here once, and a body type is a *pull away from it*
## rather than a replacement for it. Long arms remain available to a body type
## that should have them, and remain available to an individual player whose
## attributes earn them; what is no longer available is a whole species reading
## as ape because its skeleton was drawn freehand.
const UNIVERSAL_RATIOS := {
	"shoulder_y": 0.815,
	"shoulder_x": 0.170,
	## Where the fingertips land. Arm length is derived from this and the
	## shoulder rather than set directly, because the reach is the thing the eye
	## actually reads and the length is only how you get there.
	"hand_y": 0.395,
	## Raised, and `leg_height` grown to match, so the extra room becomes leg
	## rather than a longer gap. The hip block above it was also deep enough to
	## eat the top of the thigh, which is what made the joint read as a bubble
	## with legs under it instead of a waist.
	"hip_y": 0.545,
	"hip_x": 0.075,
	"torso_height": 0.420,
	"torso_radius": 0.145,
	"head_radius": 0.088,
	"head_y": 0.930,
	"leg_height": 0.370,
}

## How far a body type is allowed to pull the shared figure.
##
## At 1.0 each type is exactly the skeleton it was authored as; at 0.0 the three
## are identical and only their cosmetics differ. The drafts read too strongly --
## the type was the whole body rather than a note on top of one -- so the pull is
## a minority share. Identity is meant to arrive through the parts that are
## *added* (a tail, a beak and crest, a produce torso), which stay at full
## strength below, not through rebuilding the frame.
## A `static var` rather than a `const` so a draft can turn it and look. It is
## the one honest answer to "can the types be exaggerated systematically" -- they
## can, because every type *is* authored as a full skeleton and then pulled toward
## the shared one. Turning this up does not invent anything; it stops discarding
## what each type already says about itself.
static var type_expression: float = 0.82

## Whether the kit is drawn as garments with edges, or stays paint on the
## body. Same reason as the flag above: two candidates, rendered rather than
## argued about. See `_add_garments`.
static var draw_garments: bool = true

## How far a body part's outline is grown outside it, in metres.
##
## **Owned here rather than in `player_actor_3d.gd`, which is where it used to
## live and where it is still applied.** The rig grows the hull; the body models
## have to clear it, because a garment authored without knowing the outline's
## weight is a garment the outline renders through -- measured on every body type
## and every sleeve in `docs/review/GARMENT_INK_CLEARANCE.md`. The model is the
## lower layer and the rig already depends on it, so this is the direction that
## does not need a cycle.
static var body_ink_metres: float = 0.018

## The two garment classes, over the same six cuts.
##
## A kit was the only clothing that existed, so anyone who needed dressing got
## dressed as a player -- which is why the creator showed a manager in club teal
## before that manager had a club. A manager in a strip is a category error a
## viewer reads instantly and no palette fixes it. See
## `docs/design/THE_VOLI_BODY.md` §2.
const GARMENT_KIT := "kit"
const GARMENT_FORMAL := "formal"

## Thigh share of total leg length. Slightly over half, which is roughly true and
## is the ratio that keeps a folded knee reading as a knee.
##
## **Owned here rather than in `player_actor_3d.gd`, for the reason
## `body_ink_metres` is.** The rig splits the leg into two bones on this number,
## and a garment that covers the leg has to be cut to the same two -- a single
## shell over both is a rigid tube through a joint that bends. Two copies of the
## ratio would be two facts that can disagree, and the one that would win is
## whichever was read first.
const THIGH_SHARE: float = 0.54


## The full description of one player's body: meshes, attachment points,
## colours and cosmetic parts.
##
## `choices` is how a body stops being a consequence of an id.
##
## Every axis below -- the produce a Vegi grows as, the colourway, the coat --
## was a hash of the player id, which is exactly right for the forty volis the
## world generates and exactly wrong for the one the player makes. A generated
## voli should be a surprise; a chosen one should be a choice. The hash stays as
## the default for every caller that names nothing, so a roster is unchanged and
## only the character creator passes anything here.
##
## Unrecognised values fall back to the hash rather than to a fixed body,
## because a save carrying a produce that a later version removed should look
## like *a* voli rather than like the first one in a list.
const UPPER_ARM_SHARE: float = 0.46

## Wing joints are authored per pose as degrees on a left wing; the right is mirrored.
## shoulder/elbow swing out of the arm's plane (z), wrist folds (z), spread fans
## the three tip feathers (x). Limits clamp every pose that reaches the wing.
const AVI_WING := {
	"limits": {
		"WingShoulder": {"z": Vector2(0.0, 70.0)},
		"WingElbow": {"z": Vector2(0.0, 50.0)},
		"WingWrist": {"z": Vector2(-20.0, 45.0)},
		"WingTipSpread": {"x": Vector2(0.0, 30.0)},
	},
	"poses": {
		"tucked": {"shoulder": 0.0, "elbow": 0.0, "wrist": -8.0, "spread": 0.0},
		"balance": {"shoulder": 42.0, "elbow": 24.0, "wrist": 0.0, "spread": 24.0},
		"block": {"shoulder": 20.0, "elbow": 14.0, "wrist": 4.0, "spread": 16.0},
		"flare": {"shoulder": 32.0, "elbow": 18.0, "wrist": 2.0, "spread": 20.0},
	},
}

const CORE_LIMITS := {
	"arm": {"x": Vector2(-200.0, 200.0), "y": Vector2(-120.0, 120.0), "z": Vector2(-120.0, 120.0)},
	"elbow": {"x": Vector2(-40.0, 180.0)},
	"wrist": {"x": Vector2(-90.0, 90.0), "y": Vector2(-90.0, 90.0), "z": Vector2(-90.0, 90.0)},
	"leg": {"x": Vector2(-160.0, 160.0), "y": Vector2(-90.0, 90.0), "z": Vector2(-90.0, 90.0)},
	"knee": {"x": Vector2(-160.0, 40.0)},
}


## The rig as data: every joint below `BodyPivot`, parents before children.
## `path` is relative to the actor; `meshes` names the MeshInstance3D children
## the actor creates on that joint. -- VOLI_RIG_AS_DATA.md
static func rig(silhouette_spec: Dictionary) -> Dictionary:
	var shoulder: Vector2 = silhouette_spec.get("shoulder", Vector2(0.40, 1.52))
	var hip: Vector2 = silhouette_spec.get("hip", Vector2(0.16, 0.48))
	var arm_height := float(silhouette_spec.get("arm", {}).get("height", 0.88))
	var leg_height := float(silhouette_spec.get("leg", {}).get("height", 0.74))
	var upper := arm_height * UPPER_ARM_SHARE
	var fore := arm_height - upper
	var thigh := leg_height * THIGH_SHARE
	var wing: Dictionary = silhouette_spec.get("rig", {}).get("wing", {})
	var joints: Array = []
	for side in ["Left", "Right"]:
		var side_sign := -1.0 if side == "Left" else 1.0
		var arm_path := "BodyPivot/%sArm" % side
		joints.append({"path": arm_path, "position": Vector3(side_sign * shoulder.x, shoulder.y, 0.0),
			"limits": CORE_LIMITS.arm, "meshes": ["Mesh"]})
		joints.append({"path": arm_path + "/Elbow", "position": Vector3(0.0, -upper, 0.0),
			"limits": CORE_LIMITS.elbow, "meshes": ["Mesh"]})
		joints.append({"path": arm_path + "/Elbow/Wrist", "position": Vector3(0.0, -fore, 0.0),
			"limits": CORE_LIMITS.wrist, "meshes": []})
		if not wing.is_empty():
			var lim: Dictionary = wing.limits
			joints.append({"path": arm_path + "/WingShoulder", "position": Vector3.ZERO,
				"limits": lim.WingShoulder, "meshes": []})
			joints.append({"path": arm_path + "/Elbow/WingElbow", "position": Vector3.ZERO,
				"limits": lim.WingElbow, "meshes": []})
			joints.append({"path": arm_path + "/Elbow/WingElbow/WingWrist",
				"position": Vector3(0.0, -fore, 0.0), "limits": lim.WingWrist, "meshes": []})
			for tip in [1, 2, 3]:
				joints.append({"path": arm_path + "/Elbow/WingElbow/WingWrist/WingTipSpread%d" % tip,
					"position": Vector3.ZERO, "limits": lim.WingTipSpread, "meshes": [],
					"spread_share": float(tip - 2)})
		var leg_path := "BodyPivot/%sLeg" % side
		joints.append({"path": leg_path, "position": Vector3(side_sign * hip.x, hip.y, 0.0),
			"limits": CORE_LIMITS.leg, "meshes": ["Mesh"]})
		joints.append({"path": leg_path + "/Knee", "position": Vector3(0.0, -thigh, 0.0),
			"limits": CORE_LIMITS.knee, "meshes": ["Mesh", "Shoe"]})
	return {"joints": joints, "wing": wing}



static func silhouette(
	body_type: String, player_id: int, choices: Dictionary = {}
) -> Dictionary:
	var resolved := body_type if is_modelled(body_type) else FALLBACK_TYPE
	var authored: Dictionary
	var produce_key := chosen_produce(player_id, choices)
	## Which colourway this voli wears. Keyed by produce for a Vegi and by type
	## for everyone else, so a palette is a property of the *shape* rather than
	## of the species -- a Tomato's colours have nothing to say about a Stalk's.
	var palette_key := produce_key if resolved == "Vegi" else resolved
	match resolved:
		"Feli":
			authored = _feli()
		"Avi":
			authored = _avi()
		"Cani":
			authored = _cani()
		"Ursi":
			authored = _ursi()
		"Simi":
			authored = _simi()
		_:
			authored = _vegi(produce_key)
	var palette := chosen_palette(palette_key, player_id, choices)
	if not palette.is_empty():
		authored["skin"] = palette.skin
		authored["crown"] = palette.crown
	## Blend to the shared figure, then lay this voli's own proportions over it,
	## and only then mark the body.
	##
	## Marking used to run first, on the authored skeleton, which was wrong twice
	## over. `_mark_on_face` sizes and places a mark from `head.radius` and
	## `_mark_on_arm` from `arm.top_radius`, so a mark placed before the blend was
	## measured against a head the blend then resized -- latent and small, but a
	## mark drawn against dimensions the body does not have. Features make it
	## neither: a heavy voli's arm is 14% thicker, and a stripe placed on the
	## light one's arm would sit inside it.
	##
	## The palette still comes first, because a mark is a colour laid on a skin
	## and the skin is not known until the line above.
	var featured := _apply_features(
		_toward_universal(authored),
		chosen_features(resolved, player_id, choices),
	)
	var marked := _add_markings(
		_add_nose(featured), resolved,
		player_id, chosen_marking(resolved, player_id, choices),
	)
	## Which of the two garment classes this body is dressed in. Rides `choices`
	## like every other authored axis, so a manager is dressed by the same call a
	## player is and nothing downstream has to know which it got.
	var garment := str(choices.get("garment", GARMENT_KIT))
	return _add_neck(
		_add_garments(marked, garment) if draw_garments else marked
	)


## The three chosen-or-hashed axes, each written once so the picker and the rig
## cannot disagree about what a choice means.
##
## Named rather than inlined into `silhouette` because the character creator has
## to ask the same questions to build its option lists: "which produce is this
## body wearing right now" is the same question whether it is being drawn or
## being offered.
static func chosen_produce(player_id: int, choices: Dictionary) -> String:
	var named := str(choices.get("produce", ""))
	return named if named in PRODUCE else produce_for(player_id)


static func chosen_palette(
	body_key: String, player_id: int, choices: Dictionary
) -> Dictionary:
	var options: Array = PALETTES.get(body_key, [])
	var index := int(choices.get("palette_index", -1))
	if options.is_empty() or index < 0 or index >= options.size():
		return palette_for(body_key, player_id)
	return Dictionary(options[index])


static func chosen_marking(
	body_key: String, player_id: int, choices: Dictionary
) -> String:
	var named := str(choices.get("marking", ""))
	return named if named in marking_options(body_key) \
		else marking_for(body_key, player_id)


## The distinct coats a body can wear, in a stable order.
##
## `MARKINGS` is weighted by repetition, which is the right shape for drawing
## one at random and the wrong shape for a menu -- offered as-is it would list
## "none" three times. Deduplicated here rather than there, because the
## weighting is load-bearing for every voli the world generates and only the
## picker wants it flattened.
static func marking_options(body_key: String) -> Array[String]:
	var seen: Array[String] = []
	for marking in Array(MARKINGS.get(body_key, MARKINGS["Vegi"])):
		if not seen.has(str(marking)):
			seen.append(str(marking))
	return seen


## How many colourways this body has, so a picker can index them without
## reaching into the table.
static func palette_count(body_key: String) -> int:
	return Array(PALETTES.get(body_key, [])).size()


## Which palette table a body type reads, which is the produce for a Vegi and
## the type itself for everybody else.
static func palette_key(body_type: String, produce_name: String) -> String:
	var resolved := body_type if is_modelled(body_type) else FALLBACK_TYPE
	return produce_name if resolved == "Vegi" else resolved


## What a voli is marked with, and how often.
##
## Bodies were shape and one colour, which is two axes for a whole roster: any
## two Tomatoes on the same colourway were the same voli. Sports games solve this
## with faces -- hair, features, eye colour -- and these are vegetables and
## animals, so what they have instead is **coat**: how a body is patterned, which
## is the thing that actually distinguishes one tabby from another cat.
##
## Weighted by repetition rather than by a number beside each name. A list read
## with one index is a table anybody can check by counting, and the alternative
## -- a dictionary of floats summing to one -- is a thing to get wrong silently.
##
## `none` is in every list and is the most common single entry everywhere. A
## marking that every voli has is not a marking, it is a species trait; the
## unmarked ones are what make a marked one worth noticing.
const MARKINGS := {
	"Feli": ["none", "none", "tabby", "tabby", "patch", "scar"],
	"Cani": ["none", "none", "spots", "spots", "blaze", "patch", "scar"],
	"Avi": ["none", "none", "speckle", "speckle", "blaze", "scar"],
	"Ursi": ["none", "none", "blaze", "patch", "scar"],
	"Simi": ["none", "none", "patch", "speckle", "scar"],
	## Produce are marked too, and a vegetable's marks are its own: a stripe down
	## a squash, freckling on a pear. Rarer than an animal's, because a coat is
	## what an animal is covered in and a vegetable's skin is mostly plain.
	"Vegi": ["none", "none", "none", "speckle", "blaze", "scar"],
}


## Which marking this voli carries.
##
## A third hash string, like `produce_for` and `palette_for` have their own. The
## point of separate strings is that shape, colour and coat do not correlate --
## one hash driving two of them would tie every spotted Cani to one colourway,
## which is exactly the sameness this is meant to break up.
static func marking_for(body_key: String, player_id: int) -> String:
	var options: Array = MARKINGS.get(body_key, MARKINGS["Vegi"])
	if options.is_empty():
		return "none"
	return str(options[absi(hash("marks:%d" % player_id)) % options.size()])


## What a voli's *body* is, beyond its species.
##
## Colour and coat gave the animals ten colourways and five coats, which is a lot
## of looks and still only two axes -- and both of them are paint. A Vegi reads as
## an individual across a squad because its **shape** varies: a Pear is not a
## Stalk from any distance. The animals had exactly one shape per species, so two
## Cani on the same colourway with the same coat were the same drawing twice.
##
## These are the shape axes the animals were missing. Three of them, hashed off
## three separate strings for the same reason `marks:` is separate from
## `palette:` -- an ear length that correlated with a colourway would be a fourth
## way of saying the third one.
##
## Weighted by repetition, like `MARKINGS`, and for the same reason: `standard`
## is the plurality of every axis, so most volis carry one or two notes rather
## than three and about a fifth are plain on all three. A feature every voli has
## is not a feature. Twenty-seven distinct shapes per family, on top of the ten
## colourways and the coats.
##
## Five entries, and the count matters -- see `feature_for`, which is where the
## rest of this is recorded. These were authored as four-entry lists drawn the
## way every other axis here is drawn, and the three came out perfectly
## correlated: every small-eared voli was also short-muzzled and also heavy,
## three names for one axis.
const FEATURE_AXES := {
	"ears": ["standard", "standard", "standard", "small", "tall"],
	"muzzle": ["standard", "standard", "standard", "short", "long"],
	"build": ["standard", "standard", "standard", "light", "heavy"],
}

## Which families have a face built out of parts these axes can reach.
##
## Vegi's head is produce and Avi's is a beak and crest, so neither has an ear or
## a muzzle to vary; they are held back until their own axes are authored rather
## than given a silently-inert entry in the table above. The other four all carry
## a named `EarLeft`/`EarRight` pair and a `Muzzle`, which is all these axes ask
## for -- though not all in the same geometry, which is what `_featured_ear` is
## about.
const FEATURED_BODIES: Array[String] = ["Feli", "Cani", "Ursi", "Simi"]

## Ear size, and how the pair sits off the skull.
##
## Four keys because there are two ear geometries in the roster and one set of
## multipliers cannot serve both honestly. Feli and Cani wear **cones**, where
## length and base width are independent and the pair's carriage is a rotation;
## Ursi and Simi wear **spheres**, where a round ear that grows taller without
## growing wider stops being a round ear, so a single `size` drives both and the
## carriage is how far apart they sit.
##
## `splay` is added to the **magnitude** of the authored z rotation, keeping its
## sign, which is what stops this axis erasing the difference between the cone
## families. Feli's ears stand at 14 degrees and Cani's hang at 152; a longer ear
## is 19 and 157 respectively -- more cat and more hound, never the other one.
## `spread` is the sphere families' equivalent: a bear's ears being wide-set or
## close-set is the readable half of that silhouette.
const EAR_FEATURES := {
	"small": {"length": 0.78, "width": 0.92, "splay": -4.0, "size": 0.80, "spread": 0.93},
	"standard": {"length": 1.0, "width": 1.0, "splay": 0.0, "size": 1.0, "spread": 1.0},
	"tall": {"length": 1.30, "width": 0.94, "splay": 5.0, "size": 1.26, "spread": 1.08},
}

## Snout size and how far it carries in front of the face.
##
## Expressed as radius, height and position rather than as an instance `scale`,
## because `PlayerActor3D._mouth_override` builds the mouth by reading this
## part's radius, height and position by name and does *not* read its scale. A
## scaled muzzle would draw a mouth that no longer wrapped it -- the exact defect
## the override's own comment records having been caught once already.
const MUZZLE_FEATURES := {
	"short": {"size": 0.86, "reach": 0.020},
	"standard": {"size": 1.0, "reach": 0.0},
	"long": {"size": 1.12, "reach": -0.045},
}

## How much body there is around the same skeleton. Girth is the torso, the
## shorts and the joint spacing; limb is the thickness of arms and legs.
##
## Deliberately **not** height. Rig height is what a body type says about itself
## and what the universal blend is protecting, and a per-voli height axis is a
## separate question -- attributes have a claim on it that a hash does not.
const BUILD_FEATURES := {
	"light": {"girth": 0.90, "limb": 0.88},
	"standard": {"girth": 1.0, "limb": 1.0},
	"heavy": {"girth": 1.11, "limb": 1.14},
}


static func has_features(body_type: String) -> bool:
	return body_type in FEATURED_BODIES


## The distinct values of one axis, in a stable order, for a picker -- the same
## deduplication `marking_options` does, and for the same reason: the table is
## weighted for drawing and a menu wants it flattened.
static func feature_options(axis: String) -> Array[String]:
	var seen: Array[String] = []
	for value in Array(FEATURE_AXES.get(axis, [])):
		if not seen.has(str(value)):
			seen.append(str(value))
	return seen


## Which value of one axis this voli carries.
##
## **The id goes first, and every other axis in this file has it last.** That is
## not a style difference, it is the fix for a defect the other axes are only
## accidentally clear of, and it cost a probe to find.
##
## Written the usual way -- `hash("ears:%d")`, `hash("muzzle:%d")`,
## `hash("build:%d")` -- the three axes came out perfectly correlated: over 4,000
## ids they drew 4 of the 27 shapes they can express, every small-eared voli also
## short-muzzled and also heavy. Per-axis counts looked perfect, which is what
## made it worth measuring the *joint* distribution instead: an axis moving in
## lockstep with another is still individually well distributed, so the obvious
## instrument cannot see this at all.
##
## Godot's `String.hash` is djb2, `h = 33 * h + c`, so a string built as
## prefix-then-id hashes to `H(prefix) * 33^m + S(id)` where `m` is the id's
## length. Two axes sharing an id therefore differ by `(H_a - H_b) * 33^m` -- a
## value that does not depend on the id at all. **A constant offset, at every
## modulus.** Changing the list size cannot help; five entries drew 4 of 27 the
## same as four did.
##
## Putting the id first makes the axis word the suffix, and the three words are
## different lengths, so the id is multiplied by a different power of 33 in each
## and the offset stops being constant. That still needs a non-power-of-two
## table, because 33 is congruent to 1 modulo any power of two and those
## differing powers collapse back to equal -- which is the second half of the
## same bug, and why `FEATURE_AXES` has five entries rather than four.
##
## `probe_feature_independence.gd` keeps both broken forms alongside this one and
## fails below 27 of 27. The older axes here -- `marks:`, `palette:`, `vegi:` --
## are all prefix-then-id and so are all constant offsets of each other; they
## read as independent only because 5, 6, 7 and 10 are pairwise coprime enough
## that the residues spread. That is luck, not design, and it is the thing to
## remember before adding a fourth.
static func feature_for(axis: String, player_id: int) -> String:
	var options: Array = FEATURE_AXES.get(axis, [])
	if options.is_empty():
		return "standard"
	return str(options[absi(hash("%d:%s" % [player_id, axis])) % options.size()])


## This voli's three shape notes, chosen or hashed, as one dictionary.
##
## Empty for a body with no parts to vary, so `_apply_features` is a no-op for
## the four families that have not been given axes yet rather than something
## every caller has to remember to skip.
static func chosen_features(
	body_key: String, player_id: int, choices: Dictionary
) -> Dictionary:
	if not has_features(body_key):
		return {}
	var features := {}
	for axis in FEATURE_AXES:
		var axis_key := str(axis)
		var named := str(choices.get(axis_key, ""))
		features[axis_key] = named if named in feature_options(axis_key) \
			else feature_for(axis_key, player_id)
	return features


## Lay this voli's own proportions over the resolved figure.
##
## Runs **after** the universal blend, not before it, and the distinction is the
## whole design. The blend exists to stop a *species* skeleton drifting away from
## a person, and it discards 55% of whatever an authored body claims. A feature
## is not a species claim -- it is one voli being broader or longer-eared than
## the next one of the same species -- so putting it before the blend would quote
## it at 45% strength and the axis would barely read. Extras were never blended
## at all, for the same reason stated at `_toward_universal`: identity arrives
## through what is added.
static func _apply_features(spec: Dictionary, features: Dictionary) -> Dictionary:
	if features.is_empty():
		return spec
	var featured := spec.duplicate(true)
	var build: Dictionary = BUILD_FEATURES.get(
		str(features.get("build", "standard")), BUILD_FEATURES["standard"]
	)
	var girth := float(build.girth)
	var limb := float(build.limb)
	if girth != 1.0:
		var torso: Dictionary = Dictionary(featured.get("torso", {}))
		if torso.has("radius"):
			torso["radius"] = float(torso.radius) * girth
		## Purpose-built bodies use a vertical radius profile instead of one
		## primitive radius. Scale every section so build remains an independent
		## axis after the authored silhouettes replaced capsules and spheres.
		if torso.has("profile"):
			var scaled_profile: Array[Vector2] = []
			for raw_section in Array(torso.profile):
				var section: Vector2 = raw_section
				scaled_profile.append(Vector2(section.x, section.y * girth))
			torso["profile"] = scaled_profile
		featured["torso"] = torso
		## **The `shorts` box in every body spec is never drawn**, so nothing is
		## scaled here. `_build_silhouette` builds a mesh from it and
		## `_apply_physical_profile` immediately replaces that mesh with a section
		## of the torso's own profile -- the second one runs after the first and
		## wins. An earlier version of this function scaled `shorts.size` believing
		## it dressed the voli; it dressed a mesh that is overwritten a line later.
		## Girth still reaches the shorts, because they are sampled from the torso
		## radius that girth *does* move.
		## Only the half-width moves. Shoulder and hip *heights* are the blended
		## skeleton and a broader voli is not a differently-jointed one.
		var shoulder := Vector2(featured.get("shoulder", Vector2(0.34, 1.5)))
		featured["shoulder"] = Vector2(shoulder.x * girth, shoulder.y)
		var hip := Vector2(featured.get("hip", Vector2(0.15, 0.46)))
		featured["hip"] = Vector2(hip.x * girth, hip.y)
	if limb != 1.0:
		for key in ["arm", "leg"]:
			var bone: Dictionary = Dictionary(featured.get(key, {}))
			if bone.is_empty():
				continue
			for radius_key in ["top_radius", "bottom_radius"]:
				if bone.has(radius_key):
					bone[radius_key] = float(bone[radius_key]) * limb
			featured[key] = bone
		## Shoes come in two shapes: a capsule with a radius for most, a box with
		## a size for Simi. Handling only the first left one family's feet at a
		## constant width while its legs thickened around them -- the silent kind
		## of miss, because a shoe that never changes still renders.
		var shoe: Dictionary = Dictionary(featured.get("shoe", {}))
		if shoe.has("radius"):
			shoe["radius"] = float(shoe.radius) * limb
			featured["shoe"] = shoe
		elif shoe.has("size"):
			var shoe_size: Vector3 = shoe.size
			shoe["size"] = Vector3(
				shoe_size.x * limb, shoe_size.y, shoe_size.z
			)
			featured["shoe"] = shoe
	var ears: Dictionary = EAR_FEATURES.get(
		str(features.get("ears", "standard")), EAR_FEATURES["standard"]
	)
	var muzzle: Dictionary = MUZZLE_FEATURES.get(
		str(features.get("muzzle", "standard")), MUZZLE_FEATURES["standard"]
	)
	## Where the head actually is, for the sphere-ear branch. Read after the build
	## block above, because nothing there moves the head -- girth is width and the
	## head is not part of it -- but reading it here keeps the ordering honest if
	## that ever stops being true.
	var head_centre := Vector3(0.0, float(featured.get("head_y", 1.74)), 0.0)
	var extras: Array = []
	for raw_part in Array(featured.get("extras", [])):
		var part := Dictionary(raw_part).duplicate(true)
		match str(part.get("name", "")):
			"EarLeft", "EarRight":
				extras.append(_featured_ear(part, ears, head_centre))
			"Muzzle":
				extras.append(_featured_muzzle(part, muzzle))
			_:
				extras.append(part)
	featured["extras"] = extras
	return featured


## An ear at its new size, still attached where it was.
##
## Both branches below are the same rule -- hold the join to the skull fixed and
## let the ear grow away from it -- applied to the two different places a join
## actually is. Neither needed measuring; each falls out of the geometry.
##
## **Cone** (Feli, Cani). The mesh is centred on its own origin with the apex up,
## so growing one without moving it buries the base in the skull or lifts it off.
## The base sits at local `(0, -h/2)`, which a z rotation of theta puts at
## `(h/2 * sin, -h/2 * cos)`; holding that point fixed while the height changes
## by `delta` asks the centre to move by `(-delta/2 * sin, delta/2 * cos)`.
##
## That one expression is why the cone families share the axis. Feli's ears stand
## (cos near +1) so a longer one grows *upward* from a fixed skull join; Cani's
## hang past horizontal (cos near -0.9) so the same term grows the ear *downward*
## from a fixed top.
##
## **Sphere** (Ursi, Simi). A round ear sits *on* the skull rather than rooted in
## it, so the fixed thing is the contact with the head's surface: a ball of
## radius r touching a head centred at `head_centre` has its own centre exactly r
## further out along that line. Grow the radius by `delta` and the centre moves
## `delta` outward, which is why this branch needs the head's centre passed in
## and the cone branch does not.
static func _featured_ear(
	part: Dictionary, ears: Dictionary, head_centre: Vector3
) -> Dictionary:
	var position: Vector3 = part.get("position", Vector3.ZERO)
	var ear_shape := str(part.get("shape", "sphere"))
	if ear_shape in ["cone", "profile"]:
		var authored_height := float(part.get("height", 0.22))
		var height := authored_height * float(ears.length)
		part["height"] = height
		part["radius"] = float(part.get("radius", 0.08)) * float(ears.width)
		if ear_shape == "profile":
			var widened: Array[Vector2] = []
			for raw_point in part.get("profile", []):
				var point: Vector2 = raw_point
				widened.append(Vector2(point.x, point.y * float(ears.width)))
			part["profile"] = widened
		var rotation: Vector3 = part.get("rotation", Vector3.ZERO)
		var splay := float(ears.splay)
		var turned := rotation.z + (splay if rotation.z >= 0.0 else -splay)
		part["rotation"] = Vector3(rotation.x, rotation.y, turned)
		var radians := deg_to_rad(turned)
		var delta := (height - authored_height) * 0.5
		part["position"] = position + Vector3(
			-delta * sin(radians), delta * cos(radians), 0.0
		)
		return part
	var size := float(ears.size)
	var authored_radius := float(part.get("radius", 0.075))
	var radius := authored_radius * size
	part["radius"] = radius
	part["height"] = float(part.get("height", 0.13)) * size
	## Spread first, so the outward correction is computed along the line the ear
	## actually ends up on rather than the one it started on.
	var spread := Vector3(position.x * float(ears.spread), position.y, position.z)
	var outward := spread - head_centre
	part["position"] = spread if outward.length() < 0.001 \
		else spread + outward.normalized() * (radius - authored_radius)
	return part


## How much of a muzzle's radius the nose takes, how flat it is, how high up the
## snout it sits, and how far it sinks into it.
##
## **All four were measured off a render, and the first attempt got three wrong.**
## It was a quarter-radius sphere seated two thirds up and standing 0.72 of the
## snout's depth proud, and it came out as a bauble bolted to the face -- because
## a cosmetic carries a 0.030 m inverted hull, and a 25 mm nose is therefore
## *smaller than its own outline*. The ring dominated the mark and the protrusion
## caught the key light, so the one thing on the face that reads was a bright
## disc with a heavy circle round it.
##
## A nose is wide, low and mostly *in* the snout. Wider than half the muzzle so
## the outline is a rim rather than the subject; flattened front-to-back so it is
## a dome and not a ball; high on the snout where a muzzle's own profile is
## broadest; and sunk far enough that its silhouette merges with the snout
## instead of sitting on it. It also takes the body's lighter pen -- the crown
## weight exists for a part that carries a type's identity at thumbnail size, and
## this one is read at conversational distance if at all.
## **Measured against the pad it sits on, not the muzzle's widest section.** It
## was 0.46 of the back half-width, which on a strongly tapered snout is most of
## the front face: Feli's nose came out 0.72 of its own pad's half-width and
## pinched the face shut, reading as small-featured rather than as small-nosed.
## Cani carried the identical ratio and showed it far less, because a longer
## snout has more surface either side of the nose for the eye to land on.
##
## A half, of the pad. The blunter the muzzle the wider the pad and the bigger
## the nose that follows -- which is the right relationship and the one the old
## constant could not express, because it never knew the taper existed.
const NOSE_PAD_FRACTION: float = 0.50
const NOSE_FLATTEN: float = 0.62
const NOSE_HEIGHT_FRACTION: float = 0.74
const NOSE_SINK: float = 0.52


## The crown-coloured mark on a skin-coloured snout.
##
## **Why the muzzle stopped being crown-coloured, and why this replaces it.**
## All four muzzled types authored the whole snout as `crown`, which on Feli is
## `f0dcc0` against a `c98f4e` head -- a near-white patch with a hard edge across
## the middle of a tan face. It read as a mask rather than as a snout, and it
## made the mouth worse in two directions at once: the mouth's ink colour is
## chosen from *skin* luminance, so Feli's dark stroke sat on near-white and read
## as a bared row, while Ursi's dark `4a3b34` skin selects the *light* stroke and
## put a pale mouth on a pale muzzle where it nearly vanished. Colouring the
## muzzle `skin` gives the mouth the same contrast against the snout that it has
## against the head, on every type.
##
## The two-tone reading `crown` was there for survives as a nose, which is the
## place a real muzzle is actually a different colour.
##
## **Derived here rather than authored four times.** `_featured_muzzle` scales a
## muzzle by `MUZZLE_FEATURES` and slides it along -z, so a nose with an absolute
## position would sit correctly on a standard muzzle and float off a short or a
## long one. Reading the muzzle *after* the feature axis has run makes one rule
## serve four types and follow the axis for nothing -- the same choice
## `PlayerActor3D._mouth_override` makes, and for the reason it states: a second
## copy of these numbers would be a constant wearing the muzzle's name.
##
## Size stays in `radius`/`height`/`position` and never in an instance `scale`,
## which is the constraint `MUZZLE_FEATURES` states above and which exists
## because `_mouth_override` reads those three by name.
static func _add_nose(spec: Dictionary) -> Dictionary:
	var extras: Array = Array(spec.get("extras", []))
	var muzzle := {}
	for raw_part in extras:
		var part := Dictionary(raw_part)
		if str(part.get("name", "")) == "Muzzle":
			muzzle = part
			break
	## A beak *is* the snout and the mouth both -- Avi gets no muzzle and no
	## mouth, and it must not get a nose stuck to its face either.
	if muzzle.is_empty():
		return spec
	var radius := float(muzzle.get("radius", 0.10))
	var half_height := float(muzzle.get("height", radius * 2.0)) * 0.5
	var centre: Vector3 = muzzle.get("position", Vector3.ZERO)
	var up := NOSE_HEIGHT_FRACTION
	## **A wedge has a front plane; a sphere has a front curve.** On the plane the
	## nose sits at a fixed depth wherever it is on the face, and the pad it sits
	## on has already tapered in, so the height is measured against the tapered
	## face rather than the muzzle's widest section. On a sphere how far forward
	## the surface is still depends on how high up it you are.
	var wedge := str(muzzle.get("shape", "sphere")) == "wedge"
	var taper := clampf(float(muzzle.get("taper_height", 1.0)), 0.05, 1.0) if wedge else 1.0
	var taper_width := clampf(
		float(muzzle.get("taper_width", 1.0)), 0.05, 1.0
	) if wedge else 1.0
	var nose_radius := radius * taper_width * NOSE_PAD_FRACTION
	var forward := 1.0 if wedge else sqrt(maxf(1.0 - up * up, 0.0))
	var reach := float(muzzle.get("depth", radius * 2.0)) * 0.5 if wedge else radius
	var noses := extras.duplicate(true)
	noses.append({
		"name": "Nose", "parent": str(muzzle.get("parent", "BodyPivot")),
		"shape": "sphere",
		"radius": nose_radius, "height": nose_radius * 2.0 * NOSE_FLATTEN,
		"position": Vector3(
			centre.x,
			centre.y + half_height * taper * up,
			centre.z - reach * forward * (1.0 if wedge else NOSE_SINK)
				+ (nose_radius * NOSE_FLATTEN * NOSE_SINK if wedge else 0.0),
		),
		"color": "crown", "ink": "body",
	})
	var carried := spec.duplicate(true)
	carried["extras"] = noses
	return carried


static func _featured_muzzle(part: Dictionary, muzzle: Dictionary) -> Dictionary:
	var size := float(muzzle.size)
	part["radius"] = float(part.get("radius", 0.10)) * size
	part["height"] = float(part.get("height", 0.15)) * size
	## **Reach scales too, now that a muzzle has one.** A wedge carries its
	## projection in `depth`, and a "long muzzle" that grew only in section would
	## be a fatter face rather than a longer one -- which is the opposite of what
	## the axis is named for.
	if part.has("depth"):
		part["depth"] = float(part.depth) * size
	var position: Vector3 = part.get("position", Vector3.ZERO)
	## The snout carries forward on -z, which is the direction both authored
	## muzzles already sit in front of their heads.
	part["position"] = Vector3(
		position.x, position.y, position.z + float(muzzle.reach)
	)
	return part


## Where a mark sits: on the face, or along an arm.
##
## **Not on the torso, which is where these started and where they were wrong.**
## An animal wears a full singlet, so every stripe and spot was being drawn on
## the shirt -- a tabby's bars came out as printed sportswear. A coat is on skin,
## and the skin a dressed voli actually shows is the head and the limbs.
##
## That also makes the marks move with the body, because an arm is a bone rather
## than a fixed place: a mark parented to `LeftArm` swings with the swing. Which
## is correct, and is the reason this could not be done by nudging the old
## positions -- it needed a different parent.
const ARM_PARENTS: Array[String] = ["BodyPivot/LeftArm", "BodyPivot/RightArm"]


## A mark on the head, placed in the head's own radius.
##
## `side` is -1 to 1 across the face, `up` is a share of the radius above centre,
## and the mark is pushed to the front of the skull and squashed flat against it.
static func _mark_on_face(
	spec: Dictionary, side: float, up: float, size: float
) -> Dictionary:
	var head_radius := float(spec.get("head", {}).get("radius", 0.13))
	return {
		"parent": "BodyPivot",
		"position": Vector3(
			side * head_radius * 0.46,
			float(spec.get("head_y", 1.7)) + up * head_radius,
			head_radius * 0.74
		),
		"radius": head_radius * size, "height": head_radius * size,
		"scale": Vector3(1.0, 1.0, 0.34),
	}


## And one along an arm, `down` being a share of the arm's length from the
## shoulder. The arm hangs down its own -y, so this is a negative offset.
static func _mark_on_arm(
	spec: Dictionary, which: int, down: float, size: float
) -> Dictionary:
	var arm: Dictionary = spec.get("arm", {})
	var arm_length := float(arm.get("height", 0.72))
	var arm_radius := float(arm.get("top_radius", 0.06))
	return {
		"parent": ARM_PARENTS[absi(which) % ARM_PARENTS.size()],
		"position": Vector3(0.0, -down * arm_length, arm_radius * 0.62),
		"radius": arm_radius * size, "height": arm_radius * size,
		"scale": Vector3(1.0, 1.0, 0.42),
	}


## One mark, as a cosmetic part. `roll` turns it in its own plane, which is what
## makes a stripe lean and a scar cut across rather than sit square.
static func _mark(
	mark_name: String, placed: Dictionary, ink: Color, roll: float,
	shape: Vector3 = Vector3.ZERO
) -> Dictionary:
	return {
		"name": mark_name, "parent": str(placed.parent), "shape": "sphere",
		"radius": float(placed.radius), "height": float(placed.height),
		"position": placed.position,
		"rotation": Vector3(0.0, 0.0, roll),
		"scale": placed.scale if shape == Vector3.ZERO else shape,
		"color_value": ink,
	}


## Lay this voli's coat on.
##
## Deterministic from the id, so a voli's coat is a property of that voli and not
## of when they happened to be drawn.
static func _add_markings(
	spec: Dictionary, body_key: String, player_id: int, marking: String = ""
) -> Dictionary:
	if marking.is_empty():
		marking = marking_for(body_key, player_id)
	if marking == "none":
		return spec
	var skin: Color = spec.get("skin", Color("c8332c"))
	## Marks read as the same animal in a different tone, so they come off the
	## skin rather than out of a palette of their own. A scar is the exception --
	## it is not coat, it is where coat stopped growing.
	var ink := skin.darkened(0.34) if skin.get_luminance() > 0.22 \
		else skin.lightened(0.30)
	var pale := skin.lightened(0.55)
	var extras: Array = spec.get("extras", [])
	var seed_offset := absi(hash("coat:%d" % player_id))
	var side := 1.0 if (seed_offset & 1) == 0 else -1.0
	match marking:
		"tabby":
			## Bars across the brow and rings down the arms, which is where a
			## tabby's stripes are on an animal wearing a shirt.
			for index in range(3):
				extras.append(_mark(
					"Tabby%d" % (index + 1),
					_mark_on_face(spec, 0.0, 0.44 - float(index) * 0.26, 0.78),
					ink, float((seed_offset >> index) & 3) * 4.0 - 6.0,
					Vector3(1.0, 0.20, 0.30)
				))
			for index in range(4):
				extras.append(_mark(
					"TabbyArm%d" % (index + 1),
					_mark_on_arm(spec, index, 0.34 + float(index / 2) * 0.22, 1.5),
					ink, 0.0, Vector3(1.25, 0.26, 0.50)
				))
			for cheek in [-1.0, 1.0]:
				extras.append(_mark(
					"TabbyCheek%s" % ("Left" if cheek < 0.0 else "Right"),
					_mark_on_face(spec, cheek * 0.72, -0.16, 0.52), ink,
					cheek * 24.0, Vector3(1.2, 0.20, 0.30)
				))
		"spots":
			for index in range(6):
				extras.append(_mark(
					"Spot%d" % (index + 1),
					_mark_on_arm(
						spec, index, 0.20 + float(index / 2) * 0.24,
						1.05 + float((seed_offset >> index) & 3) * 0.14
					), ink, 0.0
				))
			extras.append(_mark(
				"SpotFace", _mark_on_face(spec, side * 0.7, -0.20, 0.48), ink, 0.0
			))
		"blaze":
			## A stripe up the muzzle, which is where a blaze is on an animal.
			extras.append(_mark(
				"Blaze", _mark_on_face(spec, 0.0, 0.06, 0.46),
				skin.lightened(0.30).lerp(Color("f2e6c8"), 0.35), 0.0,
				Vector3(1.0, 3.2, 0.30)
			))
		"patch":
			## Over one eye. Which eye is the voli's own, because a patch always
			## on the left is a uniform rather than a marking.
			extras.append(_mark(
				"Patch", _mark_on_face(spec, side * 0.62, 0.20, 0.95), ink, 0.0
			))
		"speckle":
			for index in range(5):
				var turn := float((seed_offset >> (index * 3)) & 7) / 8.0
				extras.append(_mark(
					"Speckle%d" % (index + 1),
					_mark_on_face(
						spec, (turn - 0.5) * 1.5, 0.36 - float(index) * 0.17, 0.28
					), ink, 0.0
				))
		"scar":
			## Pale, thin and at an angle, because a scar is the one mark here
			## that is not coat -- it is where coat stopped growing. Across the
			## face and along the forearm, the two places a scar is ever seen.
			extras.append(_mark(
				"Scar", _mark_on_face(spec, side * 0.28, 0.16, 1.10), pale,
				38.0 if side > 0.0 else -38.0, Vector3(1.0, 0.13, 0.26)
			))
			extras.append(_mark(
				"ScarArm", _mark_on_arm(spec, int(seed_offset), 0.52, 1.25),
				pale, 22.0, Vector3(0.34, 1.5, 0.42)
			))
	spec["extras"] = extras
	return spec


## Close the gap between the torso and the head, whatever the blend left there.
##
## `_toward_universal` pulls `head_y` toward the shared figure but leaves the
## torso where the type authored it, so the two move apart by however far that
## type disagreed with the reference. On the round produce that is most of a
## head's height, and a head hanging clear of the shoulders reads as broken
## rather than as long-necked.
##
## Fixing it by re-authoring every `head_y` would be a set of constants tuned
## against the blend -- correct until the blend moves, and silently wrong after.
## A neck sized from the two things it spans is correct by construction, and it
## is also just a real part of a body.
## The four joints the rig already turns on but has never drawn.
##
## `player_actor_3d.tscn` gives every limb two capsule segments meeting at a
## pivot: `LeftArm`'s own origin is the shoulder, `LeftArm/Elbow` is the elbow,
## and the leg is built the same way at the hip and the knee. The pivots bend
## correctly and carry no geometry, so a limb is two tapered capsules whose ends
## simply stop next to each other -- which is what makes an arm read as stacked
## sausages rather than as an arm.
##
## This is the same repair `_add_neck` below already makes at the one junction
## somebody noticed: "a short collar of neck at the join is what stops a sphere
## head reading as balanced on a sphere body". The other four junctions have the
## same problem and never got the same treatment.
##
## **It is not the unified-mesh work**, and the distinction is worth keeping. A
## smooth-union body is one continuous surface with no seams anywhere and one
## outline around the whole of it; this is eight spheres parked on pivots that
## already exist. It buys most of the same read for a fraction of the cost, and
## it leaves every mesh, material and ink hull where they are.
##
## Each sphere is sized from the limb radii that actually meet at that joint, so
## a heavy voli's elbow is a heavy voli's elbow without anything being restated.
## Slightly proud of both -- a joint that merely matches its limbs leaves the
## seam exactly where it was.
## A `static var`, like `type_expression`, because the first
## value tried reads as a knuckle rather than as a joint and the difference
## between "filled" and "doll-jointed" is one number nobody should have to argue
## about without looking at both.
## The kit, as garments rather than as paint.
##
## A voli's clothing has been two things: the torso capsule painted the club's
## colour, and a section of that same capsule painted darker for shorts. Nothing
## is *worn* -- the body is simply a different colour below the neck, which is
## why the silhouette says "primitive" no matter how it is lit. Miis and clay
## figures read as dressed because the garment is a **shell with edges**: a
## sleeve that ends partway down the arm, a short leg that ends above the knee,
## a hem you can see.
##
## These are the two edges that do the most work, and both are cheap: they hang
## off limb bones that already exist, so they travel with every pose, and they
## take the `kit` colour key, so a club's strip dresses them with no new plumbing.
##
## The shorts legs also fix the defect that prompted this. The shorts are a
## section of the torso's profile, so from the front their silhouette is a
## trapezoid and each thigh crosses its lower corner -- a leg passing through the
## *side* of a garment rather than out of the bottom of it. A short kit-coloured
## sleeve around the top of each thigh is what a pair of shorts actually is, and
## the corner stops being a place a leg comes out of.
## The radius to build a garment from, so its narrow end clears what it covers.
##
## `narrow` is the multiplier the garment's tightest end already uses. Returning
## a *base* rather than a finished radius is what keeps the flare: the caller
## applies both of its own multipliers to this, so a shell that was 1.30 at the
## cuff and 1.34 at the hem stays 1.30 and 1.34 of something slightly larger,
## rather than being lifted at one end and pinched at the other.
##
## **The standoff is one line width, and that is a derivation rather than a
## taste.** A garment sitting exactly `body_ink_metres` off the limb sits *on*
## the limb's outline -- two coincident parallel surfaces with no depth bias, a
## per-pixel coin flip, and the dash that prompted this. The only non-arbitrary
## distance available is the thickness of the line being cleared, so the garment
## stands one line clear of it.
##
## The `maxf` does not currently bind on any body, and that is worth stating
## rather than implying otherwise: it lifts whenever the limb is thinner than
## `2 * body_ink_metres / (narrow - 1)`, which is 0.12 m for a sleeve, and the
## widest arm in the roster is Ursi's at 0.081. Every body grows. It is kept
## because it is the correct floor, not because it is currently doing anything.
static func _clearing_radius(limb_radius: float, narrow: float) -> float:
	return maxf(
		limb_radius, (limb_radius + body_ink_metres * 2.0) / maxf(narrow, 0.01)
	)


## The produce's own profile, worn as a shirt.
static func _produce_singlet(spec: Dictionary, colour: String) -> Dictionary:
	var torso: Dictionary = spec.get("torso", {})
	var profile: Array = torso.get("profile", [])
	if profile.size() < 2 or not torso.has("height"):
		return {}
	var half := float(torso.height) * 0.5
	if half <= 0.0:
		return {}
	var widest := 0.0
	for raw in profile:
		widest = maxf(widest, float((raw as Vector2).y))
	if widest <= 0.0:
		return {}
	## Where the shape stops being a body and starts being a base.
	var hem := -0.6
	for raw in profile:
		var ring: Vector2 = raw
		if ring.y >= widest * 0.6:
			hem = ring.x
			break
	var shoulder := Vector2(spec.get("shoulder", Vector2(0.3, 1.3)))
	var neck := clampf(
		(shoulder.y - float(spec.get("torso_y", 1.1))) / half, hem + 0.2, 0.95
	)
	## One line width off the skin, the same standoff every other garment takes.
	var clearance := body_ink_metres * 2.0
	var rings: Array[Vector2] = [
		Vector2(hem, _torso_radius_at(torso, hem) + clearance)
	]
	for raw in profile:
		var ring: Vector2 = raw
		if ring.x > hem and ring.x < neck:
			rings.append(Vector2(ring.x, ring.y + clearance))
	rings.append(Vector2(neck, _torso_radius_at(torso, neck) + clearance))
	return {
		"name": "Singlet", "parent": "BodyPivot", "shape": "profile",
		"profile": rings,
		"height": float(torso.height),
		"radius": float(torso.get("radius", widest)) + clearance,
		"depth_scale": float(torso.get("depth_scale", 1.0)),
		"lobes": int(torso.get("lobes", 0)),
		"lobe_depth": float(torso.get("lobe_depth", 0.0)),
		"position": Vector3(0.0, float(spec.get("torso_y", 1.1)), 0.0),
		## The body's line, not a cosmetic's: this is a garment over a torso and
		## takes the weight the torso takes.
		"ink": "body",
		"color": colour,
	}


static func _add_garments(
	spec: Dictionary, garment: String = GARMENT_KIT
) -> Dictionary:
	var arm: Dictionary = spec.get("arm", {})
	var leg: Dictionary = spec.get("leg", {})
	var arm_radius := float(arm.get("top_radius", 0.065))
	var arm_length := float(arm.get("height", 0.84))
	var leg_radius := float(leg.get("top_radius", 0.105))
	var leg_length := float(leg.get("height", 0.66))
	var extras: Array = spec.get("extras", [])
	## **The same cuts, worn longer.** A formal shirt is the singlet's sleeve
	## carried to the elbow and trousers are the shorts leg carried past the knee
	## -- so the tailoring problem is solved once and both classes hang off it,
	## which is the whole reason the two were separated rather than one being
	## special-cased. Avi's wing opening is the same opening in a jacket.
	var formal := garment == GARMENT_FORMAL
	var sleeve_share := 0.62 if formal else 0.24
	var leg_share := 0.92 if formal else 0.39
	var shirt_colour := "formal" if formal else "kit"
	var trouser_colour := "formal_dark" if formal else "shorts"
	for side in ["Left", "Right"]:
		## A sleeve over the top of the upper arm, flaring very slightly so its
		## hem stands off the limb instead of shrink-wrapping it. Proud of the
		## arm by a clear margin -- a garment that matches the body's radius is
		## a paint job again.
		var sleeve_radius := _clearing_radius(arm_radius, 1.30)
		extras.append({
			"name": "Sleeve%s" % side, "parent": "BodyPivot/%sArm" % side,
			"shape": "cylinder",
			"top_radius": sleeve_radius * 1.30,
			"bottom_radius": sleeve_radius * 1.34,
			"height": arm_length * sleeve_share,
			"position": Vector3(
				0.0, -arm_length * (0.10 + (sleeve_share - 0.24) * 0.5), 0.0
			),
			"color": shirt_colour,
		})
		## Longer than the first draft, and the reason is a measurement rather
		## than taste. The hip sits at y 0.769 and the knee at 0.413, so the cuff
		## already covered most of the thigh -- but the shirt runs down to 0.595,
		## which left only 0.083 m of it visible. The shirt hem and the shorts hem
		## were nearly the same line, so there was no garment to see. Extending
		## the cuff toward the knee is what buys visible shorts; widening it would
		## only have made a wider invisible thing.
		var shorts_radius := _clearing_radius(leg_radius, 1.28)
		if formal:
			## **A trouser is cut to both bones, because the leg is two.**
			##
			## The shorts hang off the thigh bone alone, which is correct for
			## shorts -- they end above the knee, so nothing of them ever crosses
			## the joint. A trouser carried the same way is one rigid tube through
			## a knee that bends: it reads right standing still and wrong the
			## moment anybody folds a leg, which is why this went unseen until the
			## kit gained a second class.
			##
			## Each half is sized from the radius the bone it covers is drawn at,
			## and each clears its own limb's outline. The shank's is the leg's
			## bottom radius, which is exactly what the rig hands the shank mesh.
			var thigh_length := leg_length * THIGH_SHARE
			var shank_length := leg_length - thigh_length
			var shank_radius := _clearing_radius(
				float(leg.get("bottom_radius", leg_radius * 0.8)), 1.28
			)
			extras.append({
				"name": "TrouserThigh%s" % side,
				"parent": "BodyPivot/%sLeg" % side, "shape": "cylinder",
				"top_radius": shorts_radius * 1.28,
				"bottom_radius": shorts_radius * 1.30,
				"height": thigh_length * 0.96,
				"position": Vector3(0.0, -thigh_length * 0.5, 0.0),
				"color": trouser_colour,
			})
			## Stops short of the ankle rather than running to the floor: the
			## shoe is most of this rig's lower leg, and a trouser drawn over it
			## is a trouser with no shoe in it.
			extras.append({
				"name": "TrouserShank%s" % side,
				"parent": "BodyPivot/%sLeg/Knee" % side, "shape": "cylinder",
				"top_radius": shank_radius * 1.28,
				"bottom_radius": shank_radius * 1.34,
				"height": shank_length * 0.80,
				"position": Vector3(0.0, -shank_length * 0.40, 0.0),
				"color": trouser_colour,
			})
		else:
			extras.append({
				"name": "ShortsLeg%s" % side, "parent": "BodyPivot/%sLeg" % side,
				"shape": "cylinder",
				## Flared at the hem, which is the difference between shorts and
				## tights: a leg opening stands off the thigh.
				"top_radius": shorts_radius * 1.28,
				"bottom_radius": shorts_radius * 1.40,
				"height": leg_length * leg_share,
				"position": Vector3(
					0.0, -leg_length * (0.18 + (leg_share - 0.39) * 0.5), 0.0
				),
				"color": trouser_colour,
			})
		## **No sock top.** It was built, measured and removed rather than kept.
		##
		## The knee sits at y 0.413 and the shoe's own bounds reach 0.388, so this
		## body has 0.025 m of visible shin -- the shoe capsule is effectively the
		## whole lower leg. A sock band sized to read at all came out spanning
		## 0.208 to 0.509: across the shoe at one end and over the knee at the
		## other, which is not a sock, it is a stripe painted through two joints.
		##
		## The gap is not a garment problem and cannot be fixed by a garment. Volis
		## have no shin to dress, and giving them one is a change to the shoe or to
		## the leg proportions -- a body decision, not a kit decision.
	## A collar at the neck opening -- one ring, trim coloured, sitting on the
	## torso's top where the shirt actually ends. The neck is drawn by `_add_neck`
	## after this, and passes through the ring rather than being covered by it.
	var torso: Dictionary = spec.get("torso", {})
	var neck_radius := float(Dictionary(spec.get("head", {})).get("radius", 0.18))
	## **A produce wears a shirt cut to the produce.**
	##
	## This section has now had three answers and the first two were rejected for
	## the same reason: a belt and then a collar, both *rings* laid across the one
	## shape that carries the identity, reading as neither clothing nor body. That
	## objection is sound and it is an objection to a band, not to a garment. A
	## singlet has a neckline and a hem -- two garment edges -- and it follows the
	## produce's own profile, lobes and depth scale, so a pepper's ribs stay ribbed
	## under it and a tomato stays round. Nothing is cut in two.
	##
	## Both edges come off the body rather than being placed. The neckline sits at
	## the shoulder the produce already declares; the hem sits at the lowest ring
	## still carrying most of the torso's width, which is where that shape stops
	## being a body and starts being a base -- and is where a garment would
	## naturally be cut on it.
	if str(spec.get("torso_material", "kit")) == "skin":
		var singlet := _produce_singlet(spec, shirt_colour)
		if not singlet.is_empty():
			extras.append(singlet)
	## NOTE the height is re-seated by `_apply_physical_profile` once the torso has
	## NOTE its final scale; this is the authored placement, not the drawn one
	var torso_top := float(spec.get("torso_y", 1.1)) \
		+ float(torso.get("height", 0.9)) * 0.5
	extras.append({
		"name": "Collar", "parent": "BodyPivot", "shape": "cylinder",
		"top_radius": neck_radius * 0.86, "bottom_radius": neck_radius * 1.02,
		"height": neck_radius * 0.30,
		"position": Vector3(0.0, torso_top - neck_radius * 0.12, 0.0),
		"color": "trim",
	})
	spec["extras"] = extras
	return spec


static func _add_neck(spec: Dictionary) -> Dictionary:
	var torso: Dictionary = spec.get("torso", {})
	var head: Dictionary = spec.get("head", {})
	var torso_top := float(spec.get("torso_y", 1.1)) \
		+ float(torso.get("height", 0.8)) * 0.5
	var head_bottom := float(spec.get("head_y", 1.8)) \
		- float(head.get("height", 0.3)) * 0.5
	## Always drawn, even when the two already meet: a short collar of neck at
	## the join is what stops a sphere head reading as balanced on a sphere body.
	var span := maxf(head_bottom - torso_top, 0.0) + 0.06
	var extras: Array = spec.get("extras", [])
	extras.append({
		"name": "Neck", "parent": "BodyPivot", "shape": "cylinder",
		"top_radius": float(head.get("radius", 0.13)) * 0.52,
		"bottom_radius": float(head.get("radius", 0.13)) * 0.72,
		"height": span,
		"position": Vector3(0.0, torso_top + span * 0.5 - 0.03, 0.0),
		"color": "skin",
	})
	spec["extras"] = extras
	return spec


## Blends an authored skeleton toward the shared figure.
##
## Only proportions are touched. Colours, materials, shapes and the whole
## `extras` list pass through untouched, because those are what the type is
## supposed to be saying.
static func _toward_universal(spec: Dictionary) -> Dictionary:
	var rig := float(spec.get("rig_height", 2.0))
	if rig <= 0.0:
		return spec
	var blended := spec.duplicate(true)
	var shoulder := Vector2(spec.get("shoulder", Vector2(0.34, 1.5)))
	var hip := Vector2(spec.get("hip", Vector2(0.15, 0.46)))
	var arm: Dictionary = Dictionary(spec.get("arm", {}))
	var authored_hand := shoulder.y - float(arm.get("height", 0.8))
	var shoulder_y := _pull(shoulder.y, UNIVERSAL_RATIOS.shoulder_y * rig)
	var hand_y := _pull(authored_hand, UNIVERSAL_RATIOS.hand_y * rig)
	blended["shoulder"] = Vector2(
		_pull(shoulder.x, UNIVERSAL_RATIOS.shoulder_x * rig), shoulder_y
	)
	blended["hip"] = Vector2(
		_pull(hip.x, UNIVERSAL_RATIOS.hip_x * rig),
		_pull(hip.y, UNIVERSAL_RATIOS.hip_y * rig),
	)
	## Derived, so the reach is what was blended and the bone follows. Floored
	## well clear of zero: a degenerate arm is a worse failure than a long one.
	arm["height"] = maxf(shoulder_y - hand_y, 0.25)
	blended["arm"] = arm
	var leg: Dictionary = Dictionary(spec.get("leg", {}))
	if leg.has("height"):
		leg["height"] = _pull(
			float(leg.height), UNIVERSAL_RATIOS.leg_height * rig
		)
		blended["leg"] = leg
	var head: Dictionary = Dictionary(spec.get("head", {}))
	if head.has("radius"):
		var head_radius := _pull(
			float(head.radius), UNIVERSAL_RATIOS.head_radius * rig
		)
		head["radius"] = head_radius
		if head.has("height"):
			head["height"] = head_radius * 1.9
		blended["head"] = head
	var authored_head_y := float(spec.get("head_y", rig * 0.9))
	var blended_head_y := _pull(authored_head_y, UNIVERSAL_RATIOS.head_y * rig)
	blended["head_y"] = blended_head_y
	blended["extras"] = _carry_head_extras(
		Array(spec.get("extras", [])),
		authored_head_y,
		float(Dictionary(spec.get("head", {})).get("height", 0.3)) * 0.5,
		blended_head_y - authored_head_y,
	)
	## The produce torso is the Vegi's whole identity and its proportions are the
	## cosmetic, so it is left alone. The other two carry the kit on the torso and
	## are pulled like any other bone.
	if str(spec.get("torso_material", "kit")) != "skin":
		var torso: Dictionary = Dictionary(spec.get("torso", {}))
		if torso.has("height"):
			torso["height"] = _pull(
				float(torso.height), UNIVERSAL_RATIOS.torso_height * rig
			)
		if torso.has("radius"):
			torso["radius"] = _pull(
				float(torso.radius), UNIVERSAL_RATIOS.torso_radius * rig
			)
		blended["torso"] = torso
	return blended


## How far below the authored head a part may sit and still count as worn on it,
## as a multiple of the head's own height.
##
## One, so the band runs from the chin down by another head height. Ears and
## crests sit *above* the head and are caught by having no upper bound at all;
## tails, tail feathers and produce lobes are all a torso's length below and are
## not caught by anything. Derived from the head rather than listed by name,
## because the list would be the thing that goes stale -- a new horn or a jowl
## should follow the head without anybody adding it here.
const HEAD_EXTRA_REACH: float = 1.0


## Carry everything worn on the head with the head when the blend moves it.
##
## **The muzzle was standing still while the face walked away.** `_toward_universal`
## pulls `head_y` toward the shared figure, and every extra's position is absolute
## in `BodyPivot` space, so a type whose head disagreed with the reference had its
## snout, ears and crest left behind by exactly that disagreement. Measured, Feli's
## head rises 0.0455 m under the blend and Cani's 0.0330 -- so Feli's muzzle sank
## nearly half a centimetre further down its own face than Cani's did, on two
## bodies authored with the same head.
##
## That is not a small cosmetic drift, because `PlayerActor3D._mouth_override`
## anchors the mouth at `muzzle.position.y - head.position.y`: the *unblended*
## muzzle against the *blended* head. So the mouth inherited the whole error, and
## the nose derived from the muzzle inherited it again.
##
## `_add_neck` already exists because the same blend opened a gap at the *other*
## end of the head, and its comment states the rule this follows: re-authoring
## every `head_y` against the blend would be "correct until the blend moves, and
## silently wrong after". A part that moves with the head by construction cannot
## go stale.
static func _carry_head_extras(
	extras: Array, authored_head_y: float, head_half_height: float, shift: float
) -> Array:
	if absf(shift) < 0.000001:
		return extras.duplicate(true)
	var floor_y := authored_head_y - head_half_height \
		- head_half_height * 2.0 * HEAD_EXTRA_REACH
	var carried: Array = []
	for raw_part in extras:
		var part := Dictionary(raw_part).duplicate(true)
		## Only what hangs off the body's own trunk. A wing is parented to an arm
		## and moves with the shoulder; nothing on a limb has an opinion about
		## where the head went.
		var parent := str(part.get("parent", "BodyPivot"))
		var position: Vector3 = part.get("position", Vector3.ZERO)
		if parent == "BodyPivot" and position.y >= floor_y:
			part["position"] = Vector3(
				position.x, position.y + shift, position.z
			)
		carried.append(part)
	return carried


static func _pull(authored: float, universal: float) -> float:
	return universal + (authored - universal) * type_expression


## A vegetable that plays volleyball.
##
## The produce is the torso rather than a head on a humanoid frame, because the
## silhouette has to survive being 40 pixels tall on a wide court shot. The kit
## therefore cannot be the torso colour the way it is for the other two -- it
## would paint over the whole body -- so it becomes a band around the middle
## and the produce keeps its own skin.
static func _vegi(produce: String) -> Dictionary:
	var body: Dictionary = PRODUCE_BODIES.get(produce, PRODUCE_BODIES["Tomato"])
	var torso: Dictionary = body.torso
	var shoulder: Vector2 = body.shoulder
	var extras: Array = _produce_crown(body)
	## **No band at all on a produce, and that is the third answer to this.**
	##
	## It was a belt, then a collar, and both were the same mistake at different
	## heights: a produce's torso is its *skin*, and skin is the whole of what
	## says which produce this is. Any ring drawn across it cuts the one shape
	## carrying the identity in two, and at a glance it reads as neither clothing
	## nor body -- a green band somebody could not name.
	##
	## The animals keep their singlet, because an animal's torso is clothed and
	## the kit is what covers it. A produce wears the shorts and nothing else,
	## which is also the honest reading of a tomato in a volleyball match.
	if body.has("lobes"):
		## Round the axis at even angles, each turned to face outward so its own
		## scale means "across the bulge" and "out along the radius" rather than
		## world x and z. Generated rather than tabulated: five hand-written rib
		## positions is five chances to put one at the wrong angle, and the whole
		## claim of the shape is that they are evenly spaced.
		var lobes: Dictionary = body.lobes
		var lobe_count := int(lobes.get("count", 4))
		for lobe_index in range(lobe_count):
			var angle := TAU * float(lobe_index) / float(lobe_count)
			extras.append({
				"name": "Lobe%d" % (lobe_index + 1), "parent": "BodyPivot",
				"shape": "sphere",
				"radius": float(lobes.get("radius", 0.2)),
				"height": float(lobes.get("height", 0.7)),
				"position": Vector3(
					sin(angle) * float(lobes.get("offset", 0.15)),
					float(lobes.get("y", 1.0)),
					cos(angle) * float(lobes.get("offset", 0.15))
				),
				"rotation": Vector3(0.0, rad_to_deg(angle), 0.0),
				"scale": Vector3(
					float(lobes.get("across", 0.86)), 1.0,
					float(lobes.get("out", 1.1))
				),
				"color": "skin",
			})
	if body.has("ribs"):
		## A stalk is a bundle, not a tube. Without these the narrowest torso in
		## the set reads as a length of pipe with a face on it.
		var rib_index := 0
		for raw_rib in body.ribs:
			var rib: Dictionary = raw_rib
			rib_index += 1
			extras.append({
				"name": "Rib%d" % rib_index, "parent": "BodyPivot",
				"shape": "capsule",
				"height": float(rib.height),
				"radius": float(rib.get("thickness", 0.045)),
				"position": Vector3(
					float(rib.x), float(rib.y), float(rib.get("z", 0.04))
				),
				## Capsules stand on Y unless told otherwise. A collar lying
				## across the body is the one element that breaks a long
				## vertical silhouette, and nothing else in the vocabulary does.
				"rotation": rib.get("rotation", Vector3.ZERO),
				"color": "crown",
			})
	if body.has("blush"):
		## A turnip is white below and purple on the shoulder. Same rule as the
		## kit band: the cap is a fraction *larger* than the body so it encloses
		## it cleanly, rather than a fraction smaller and coincident with it.
		extras.append({
			"name": "Blush", "parent": "BodyPivot", "shape": "sphere",
			"radius": float(torso.get("radius", 0.42)) * 1.04,
			"height": float(torso.get("height", 0.80)) \
				* float(body.get("blush_height", 0.58)),
			## Turnip wore this on the shoulder; a leek wears it at the base, so
			## the anchor is per-body rather than the +0.20 that was hardcoded.
			"position": Vector3(
				0.0, float(body.torso_y) + float(body.get("blush_y", 0.20)), 0.0
			),
			"color_value": body.blush,
		})
	return {
		"produce": produce,
		"torso": torso,
		"torso_y": float(body.torso_y),
		"torso_material": "skin",
		"shorts": {"shape": "box", "size": Vector3(0.42, 0.20, 0.30)},
		"shorts_y": float(body.torso_y) - float(torso.get("height", 0.7)) * 0.55,
		"head": {"shape": "sphere", "radius": float(body.head_radius),
			"height": float(body.head_radius) * 1.9},
		"head_y": float(body.head_y),
		"arm": {"top_radius": 0.055, "bottom_radius": 0.07, "height": 0.72},
		"leg": {"top_radius": 0.085, "bottom_radius": 0.07, "height": 0.56},
		"shoe": {"shape": "capsule", "radius": 0.10, "height": 0.28},
		"shoulder": shoulder,
		"hip": Vector2(0.15, 0.44),
		"rig_height": float(body.rig_height),
		"skin": Color(body.skin),
		"crown": Color(body.crown),
		"extras": extras,
	}


## Lean, low and quick. Feli trades stamina and discipline for explosiveness and
## lateral speed, so the silhouette is built to read as *coiled*: a shorter
## torso carried low, digitigrade legs with a short shank, and a tail that gives
## the eye something to track when they change direction.
static func _feli() -> Dictionary:
	return {
		"torso": {"shape": "profile", "radius": 0.29, "height": 0.94,
			"profile": [Vector2(-1.0, 0.13), Vector2(-0.72, 0.22),
				Vector2(-0.05, 0.245), Vector2(0.55, 0.29),
				Vector2(1.0, 0.14)], "depth_scale": 0.72},
		"torso_y": 1.10,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.50, 0.22, 0.34)},
		"shorts_y": 0.62,
		"head": {"shape": "sphere", "radius": 0.185, "height": 0.34},
		"head_y": 1.74,
		"arm": {"top_radius": 0.065, "bottom_radius": 0.08, "height": 0.84},
		## Short shank, long thigh: the leg reads as bent even when the pose
		## code has it straight, which is what makes a digitigrade stance work
		## without giving the rig an extra joint it would have to animate.
		"leg": {"top_radius": 0.105, "bottom_radius": 0.075, "height": 0.66},
		"shoe": {"shape": "capsule", "radius": 0.11, "height": 0.26},
		"shoulder": Vector2(0.36, 1.46),
		"hip": Vector2(0.16, 0.46),
		"rig_height": 1.96,
		"skin": Color("c98f4e"),
		"crown": Color("f0dcc0"),
		## The one thing a cat face cannot do without. Feli's snout is short and
		## round, so with a nose and a mouth on it and nothing else the whole lower
		## face is one unbroken plane -- which is most of why it read as flat
		## beside Cani, whose folded ears and longer muzzle already break it up.
		"whiskers": true,
		"extras": [
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.085, "height": 0.22,
				"position": Vector3(-0.11, 1.92, 0.0),
				"rotation": Vector3(0.0, 0.0, 14.0), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.085, "height": 0.22,
				"position": Vector3(0.11, 1.92, 0.0),
				"rotation": Vector3(0.0, 0.0, -14.0), "color": "skin",
			},
			{
				## **Proportioned as a cat's, which it was not.** Feli authored
				## 0.10 x 0.15 against Cani's 0.095 x 0.14 on an identical 0.185
				## head -- wider and taller -- while projecting 0.15 forward
				## against Cani's 0.19. A snout fat in section and short in reach
				## is a bulge, and the nose, the mouth and the whiskers are all
				## sized and seated off it, so one oversized muzzle put three
				## oversized features on a face with no room for them. Cani read
				## as correct under the same rules because Cani's muzzle already
				## was the right shape.
				##
				## A cat: short, narrow, shallow, and strongly tapered to a small
				## front pad. The `taper` is what carries the jawline -- 0.66
				## leaves a clear angle from cheek to pad without turning the head
				## into a snout on a stick.
				"name": "Muzzle", "parent": "BodyPivot", "shape": "wedge", "ink": "body",
				"radius": 0.092, "height": 0.104,
				"depth": 0.150, "taper_width": 0.64, "taper_height": 0.70,
				"position": Vector3(0.0, 1.706, -0.170), "color": "skin",
			},
			## Hung off the hips rather than the torso so it swings with the
			## stride the pose code already drives, instead of sitting rigid.
			## Swept up and back off the hips. The first pass angled it down and
			## forward, which put a brown stick alongside the shins and read as
			## a third leg -- the one silhouette mistake that actively costs
			## legibility rather than merely looking plain.
			{
				"name": "Tail", "parent": "BodyPivot", "shape": "cylinder",
				## Shorter, and rooted further in. At 0.72 the tail read from
				## directly behind as a tan bar straight down the middle of the
				## kit: a tail sweeping back at the camera foreshortens into a
				## stripe, and length is what made the stripe long.
				##
				## Measured rather than eyeballed, because the first attempt at
				## this was signed the wrong way round and confidently reported
				## the tip as the root. A cylinder's local `(0,-1,0)` end rotates
				## about X to `(0,-cos,-sin)`; the root therefore lands at z 0.022
				## against a torso surface at 0.308, buried 0.286 m, while the tip
				## still stands 0.19 m clear of the body. Both ends are where a
				## tail's ends belong.
				"top_radius": 0.03, "bottom_radius": 0.055, "height": 0.52,
				## Out of the seat of the shorts, which is where a tail leaves an
				## animal. It sat at 1.10 for one pass -- raised there to clear a
				## hem it was hanging below -- and 1.10 is the *middle of the
				## back* on a torso spanning 0.595 to 1.510: a tail growing out
				## of the spine. Lowered to the hip and swept back harder instead,
				## so it leaves the garment rather than the ribcage and still ends
				## above the seat's own bottom.
				## Raised again. At 0.78 the root sat 0.079 m above the torso's own
				## lowest point -- near the crotch, where the capsule has already
				## narrowed toward its cap, so the tail showed between the legs
				## from the front. Higher up the body is at full width and the
				## same root is deeply inside it.
				"position": Vector3(0.0, 0.90, 0.26),
				"rotation": Vector3(66.0, 0.0, 0.0), "color": "skin",
			},
		],
	}


## Tall, light and long-armed. Avi carries the wingspan bonus and the jump
## reach, and pays for it in reception stability -- a body that is all leverage
## and no ballast. The wing fans hang off the arm nodes so they travel with
## every pose the rig already has, which is what makes a block read as a wall
## rather than as two thin sticks.
static func _avi() -> Dictionary:
	return {
		"torso": {"shape": "profile", "radius": 0.27, "height": 1.10,
			"profile": [Vector2(-1.0, 0.10), Vector2(-0.70, 0.17),
				Vector2(-0.12, 0.20), Vector2(0.54, 0.27),
				Vector2(1.0, 0.11)], "depth_scale": 0.58},
		"torso_y": 1.20,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.44, 0.20, 0.32)},
		"shorts_y": 0.64,
		"head": {"shape": "sphere", "radius": 0.155, "height": 0.30},
		"head_y": 1.94,
		"arm": {"top_radius": 0.05, "bottom_radius": 0.065, "height": 0.98},
		"leg": {"top_radius": 0.08, "bottom_radius": 0.055, "height": 0.80},
		"shoe": {"shape": "box", "size": Vector3(0.20, 0.06, 0.30)},
		"shoulder": Vector2(0.32, 1.62),
		"hip": Vector2(0.13, 0.50),
		"rig_height": 2.16,
		"rig": {"wing": AVI_WING},
		"skin": Color("8fb7d6"),
		"crown": Color("e8a63c"),
		"extras": [
			{
				"name": "Beak", "parent": "BodyPivot", "shape": "cone",
				"radius": 0.075, "height": 0.26,
				"position": Vector3(0.0, 1.92, -0.18),
				"rotation": Vector3(-90.0, 0.0, 0.0), "color": "crown",
			},
			{
				"name": "Crest", "parent": "BodyPivot", "shape": "box",
				"size": Vector3(0.03, 0.22, 0.20),
				"position": Vector3(0.0, 2.10, 0.03),
				"rotation": Vector3(-14.0, 0.0, 0.0), "color": "crown",
			},
			## **A wing folds at the elbow, and this one could not.**
			##
			## It was one 0.86 m box per side hung off `LeftArm` -- the *upper*
			## bone -- while the arm is a two-bone chain of 0.45 and 0.53. So the
			## fan spanned a joint it was not attached across, and every pose that
			## bends the elbow tore it off the limb. That is why `AVI - BLOCK`
			## detached far worse than `AVI - REST` in the study renders: at rest
			## the arm is nearly straight and the lie is cheap.
			##
			## Two fans per side, one per bone, is both the fix and the anatomy:
			## coverts on the upper arm, primaries on the forearm, and the wing
			## folds because the rig folds.
			##
			## **"Feathers, not panels" was written over a constant-section slab.**
			## 0.40 m of chord at the shoulder and 0.40 m at the wrist is a shield.
			## `build_fan` tapers, and the primaries carry a rake so the trailing
			## edge runs out instead of squaring off.
			##
			## **And they are opaque again.** The 0.55 alpha was buying back
			## silhouette these ate as slabs; tapered, they eat far less. It was
			## also never doing what it looked like it was doing -- `_ink_node`
			## gives every mesh an opaque inverted hull, so a see-through wing was
			## carrying a solid 30 mm black contour, which is the single strongest
			## cue that a thing is a separate object. `ink` puts them on the body's
			## own 0.018 m pen instead of the crown weight: `BACKLOG.md` justifies
			## that heavier line because "a crown is the smallest thing on a figure
			## and carries the whole identity of its type", and a wing is the one
			## cosmetic that argument excludes -- it is the largest thing on the
			## figure.
			{
				"name": "WingCovertLeft", "parent": "BodyPivot/LeftArm/WingShoulder",
				"shape": "fan",
				"root_chord": 0.30, "tip_chord": 0.23,
				"span": 0.45, "thickness": 0.05, "sweep": 0.02,
				"position": Vector3(-0.042, 0.0, -0.045),
				"rotation": Vector3(0.0, 0.0, 4.0),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingPrimaryLeft", "parent": "BodyPivot/LeftArm/Elbow/WingElbow",
				"shape": "fan",
				"root_chord": 0.23, "tip_chord": 0.09,
				"span": 0.53, "thickness": 0.04, "sweep": 0.06,
				"position": Vector3(-0.042, 0.0, -0.045),
				"rotation": Vector3(0.0, 0.0, 3.0),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingCovertRight", "parent": "BodyPivot/RightArm/WingShoulder",
				"shape": "fan",
				"root_chord": 0.30, "tip_chord": 0.23,
				"span": 0.45, "thickness": 0.05, "sweep": 0.02,
				"position": Vector3(0.042, 0.0, -0.045),
				"rotation": Vector3(0.0, 0.0, -4.0),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingPrimaryRight", "parent": "BodyPivot/RightArm/Elbow/WingElbow",
				"shape": "fan",
				"root_chord": 0.23, "tip_chord": 0.09,
				"span": 0.53, "thickness": 0.04, "sweep": 0.06,
				"position": Vector3(0.042, 0.0, -0.045),
				"rotation": Vector3(0.0, 0.0, -3.0),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingTipLeft1", "parent": "BodyPivot/LeftArm/Elbow/WingElbow/WingWrist/WingTipSpread1",
				"shape": "fan",
				"root_chord": 0.08, "tip_chord": 0.03,
				"span": 0.14, "thickness": 0.03, "sweep": 0.03,
				"position": Vector3(-0.042, 0.0, -0.045),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingTipLeft2", "parent": "BodyPivot/LeftArm/Elbow/WingElbow/WingWrist/WingTipSpread2",
				"shape": "fan",
				"root_chord": 0.08, "tip_chord": 0.03,
				"span": 0.14, "thickness": 0.03, "sweep": 0.03,
				"position": Vector3(-0.042, 0.0, -0.045),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingTipLeft3", "parent": "BodyPivot/LeftArm/Elbow/WingElbow/WingWrist/WingTipSpread3",
				"shape": "fan",
				"root_chord": 0.08, "tip_chord": 0.03,
				"span": 0.14, "thickness": 0.03, "sweep": 0.03,
				"position": Vector3(-0.042, 0.0, -0.045),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingTipRight1", "parent": "BodyPivot/RightArm/Elbow/WingElbow/WingWrist/WingTipSpread1",
				"shape": "fan",
				"root_chord": 0.08, "tip_chord": 0.03,
				"span": 0.14, "thickness": 0.03, "sweep": 0.03,
				"position": Vector3(0.042, 0.0, -0.045),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingTipRight2", "parent": "BodyPivot/RightArm/Elbow/WingElbow/WingWrist/WingTipSpread2",
				"shape": "fan",
				"root_chord": 0.08, "tip_chord": 0.03,
				"span": 0.14, "thickness": 0.03, "sweep": 0.03,
				"position": Vector3(0.042, 0.0, -0.045),
				"color": "skin", "ink": "body",
			},
			{
				"name": "WingTipRight3", "parent": "BodyPivot/RightArm/Elbow/WingElbow/WingWrist/WingTipSpread3",
				"shape": "fan",
				"root_chord": 0.08, "tip_chord": 0.03,
				"span": 0.14, "thickness": 0.03, "sweep": 0.03,
				"position": Vector3(0.042, 0.0, -0.045),
				"color": "skin", "ink": "body",
			},
			{
				"name": "TailFeathers", "parent": "BodyPivot", "shape": "box",
				"size": Vector3(0.34, 0.05, 0.44),
				"position": Vector3(0.0, 0.72, 0.26),
				"rotation": Vector3(24.0, 0.0, 0.0), "color": "crown",
			},
		],
	}


## One primitive from one spec dictionary. Everything is a Godot primitive on
## purpose: the existing rig already was, there is no asset pipeline in this
## project, and a silhouette assembled from primitives can be tuned by editing
## a number in this file rather than by re-exporting a mesh.
## How many sides a lathed limb has, and how many rings each rounded end gets.
##
## Twelve is the same count the capsules use, so a limb sits beside a torso
## without one of them looking faceted next to the other. Three cap rings is the
## fewest that still reads as round at the shoulder, which is where a limb meets
## a body and where a flat lid is most obvious.
const LIMB_SIDES: int = 12
const LIMB_CAP_RINGS: int = 3


## A limb: tapered along its length and rounded at both ends.
##
## **This is the shape the complaint was about.** Arms and legs were
## `CylinderMesh`, and a cylinder has flat lids -- so a voli was a produce with
## four rods stuck in it, and no amount of colour or pose fixed that, because the
## problem was the geometry ending in a disc. A limb narrows toward the wrist or
## ankle and finishes in a dome, and those two facts are most of what separates a
## drawn body from an assembled one.
##
## Lathed by hand rather than reached for from the primitives, because Godot has
## no tapered capsule: `CapsuleMesh` has one radius and `CylinderMesh` has two
## radii and no caps worth the name. The profile is a bottom hemisphere scaled to
## the bottom radius, a straight taper, and a top hemisphere scaled to the top
## radius -- so a limb is one surface from end to end and the ends belong to it.
static func _limb_mesh(
	top_radius: float, bottom_radius: float, height: float
) -> Mesh:
	var top := maxf(top_radius, 0.004)
	var bottom := maxf(bottom_radius, 0.004)
	var shaft := maxf(height - top - bottom, 0.001)
	## Each ring as (height above the base, radius there).
	var profile: Array[Vector2] = []
	for ring in range(LIMB_CAP_RINGS + 1):
		var angle := PI * 0.5 * (float(ring) / float(LIMB_CAP_RINGS))
		profile.append(Vector2(
			bottom - cos(angle) * bottom, sin(angle) * bottom
		))
	profile.append(Vector2(bottom + shaft, top))
	for ring in range(1, LIMB_CAP_RINGS + 1):
		var angle := PI * 0.5 * (float(ring) / float(LIMB_CAP_RINGS))
		profile.append(Vector2(
			bottom + shaft + sin(angle) * top, cos(angle) * top
		))
	## Centred on the origin like every other primitive here, so a limb can be
	## dropped in where a cylinder was without moving anything that positions it.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(profile.size() - 1):
		var lower: Vector2 = profile[index]
		var upper: Vector2 = profile[index + 1]
		for side in range(LIMB_SIDES):
			var a := TAU * float(side) / float(LIMB_SIDES)
			var b := TAU * float(side + 1) / float(LIMB_SIDES)
			var points := [
				Vector3(cos(a) * lower.y, lower.x - height * 0.5, sin(a) * lower.y),
				Vector3(cos(b) * lower.y, lower.x - height * 0.5, sin(b) * lower.y),
				Vector3(cos(b) * upper.y, upper.x - height * 0.5, sin(b) * upper.y),
				Vector3(cos(a) * upper.y, upper.x - height * 0.5, sin(a) * upper.y),
			]
			## Wound outward. Reversed, this built every limb inside-out: the
			## flat-shaded fill hid it, and an inverted-hull outline did not --
			## the ink twin showed its near side and filled the limb solid black
			## instead of drawing a rim round it. Normals face out now, which
			## lighting wanted anyway.
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(points[corner])
	surface.generate_normals()
	return surface.commit()


## A deliberately authored body contour. The profile is a sequence of
## Vector2(vertical fraction, radius) rings from -1 at the seat to +1 at the
## shoulder. Unlike scaling a capsule, moving one ring changes only that part of
## the body: a pear can have a low belly and a narrow neck, a Cani can carry a
## chest, and an Ursi can settle its mass through the hips.
static func _profile_mesh(spec: Dictionary) -> Mesh:
	var profile: Array = spec.get("profile", [])
	if profile.size() < 2:
		return CapsuleMesh.new()
	var height := float(spec.get("height", 1.0))
	var sides := int(spec.get("sides", 20))
	var lobes := int(spec.get("lobes", 0))
	var lobe_depth := float(spec.get("lobe_depth", 0.0))
	var depth_scale := float(spec.get("depth_scale", 1.0))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		var lower: Vector2 = profile[ring]
		var upper: Vector2 = profile[ring + 1]
		for side in range(sides):
			var a := TAU * float(side) / float(sides)
			var b := TAU * float(side + 1) / float(sides)
			var lower_a := lower.y * (1.0 + lobe_depth * cos(float(lobes) * a))
			var lower_b := lower.y * (1.0 + lobe_depth * cos(float(lobes) * b))
			var upper_a := upper.y * (1.0 + lobe_depth * cos(float(lobes) * a))
			var upper_b := upper.y * (1.0 + lobe_depth * cos(float(lobes) * b))
			var points := [
				Vector3(cos(a) * lower_a, lower.x * height * 0.5, sin(a) * lower_a * depth_scale),
				Vector3(cos(b) * lower_b, lower.x * height * 0.5, sin(b) * lower_b * depth_scale),
				Vector3(cos(b) * upper_b, upper.x * height * 0.5, sin(b) * upper_b * depth_scale),
				Vector3(cos(a) * upper_a, upper.x * height * 0.5, sin(a) * upper_a * depth_scale),
			]
			for corner in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(points[corner])
	surface.index()
	surface.generate_normals()
	return surface.commit()


static func build_mesh(spec: Dictionary) -> Mesh:
	match str(spec.get("shape", "capsule")):
		"profile":
			return _profile_mesh(spec)
		"limb":
			return _limb_mesh(
				float(spec.get("top_radius", 0.09)),
				float(spec.get("bottom_radius", 0.07)),
				float(spec.get("height", 0.5)),
			)
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = float(spec.get("radius", 0.3))
			sphere.height = float(spec.get("height", 0.6))
			sphere.radial_segments = 14
			sphere.rings = 7
			return sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = float(spec.get("top_radius", 0.1))
			cylinder.bottom_radius = float(spec.get("bottom_radius", 0.1))
			cylinder.height = float(spec.get("height", 0.5))
			cylinder.radial_segments = 10
			return cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = float(spec.get("radius", 0.1))
			cone.height = float(spec.get("height", 0.25))
			cone.radial_segments = 8
			return cone
		"box":
			var box := BoxMesh.new()
			box.size = spec.get("size", Vector3(0.2, 0.2, 0.2))
			return box
		"stroke":
			## Positions and normals arrive already projected onto the body the
			## stroke lies on, because only the caller knows what that body is --
			## a mouth wraps a head on one voli and a muzzle on the next.
			return build_stroke(
				PackedVector3Array(spec.get("points", PackedVector3Array())),
				PackedVector3Array(spec.get("normals", PackedVector3Array())),
				float(spec.get("thickness", 0.01)),
				float(spec.get("depth", 0.01)),
			)
		"wedge":
			## `radius` and `height` rather than a half-width and a half-height,
			## because a muzzle's size is read by those two names in two other
			## files and a second vocabulary for one quantity is how they drift.
			return build_wedge(
				float(spec.get("radius", 0.09)),
				float(spec.get("height", 0.12)) * 0.5,
				float(spec.get("depth", 0.12)),
				clampf(float(spec.get("taper_width", 0.66)), 0.05, 1.0),
				clampf(float(spec.get("taper_height", 0.72)), 0.05, 1.0),
			)
		"sheath":
			return build_sheath(
				float(spec.get("radius", 0.14)),
				float(spec.get("arc", 170.0)),
				float(spec.get("height", 0.3)),
				float(spec.get("thickness", 0.018)),
				clampf(float(spec.get("taper", 1.0)), 0.05, 1.4),
			)
		"fan":
			return build_fan(
				float(spec.get("root_chord", 0.3)),
				float(spec.get("tip_chord", 0.12)),
				float(spec.get("span", 0.5)),
				float(spec.get("thickness", 0.03)),
				float(spec.get("sweep", 0.0)),
			)
		_:
			var capsule := CapsuleMesh.new()
			capsule.radius = float(spec.get("radius", 0.3))
			capsule.height = float(spec.get("height", 1.0))
			capsule.radial_segments = 12
			capsule.rings = 6
			return capsule


## Broad, upright and built to keep going. Cani is the endurance body: a wider
## chest than Feli carries the stamina and transition-speed bonus, and the legs
## are plantigrade rather than digitigrade, which is the fastest way to tell the
## two animals apart from a distance -- Feli reads as coiled, Cani reads as
## *standing*. The ears drop instead of pricking up, for the same reason.
static func _cani() -> Dictionary:
	return {
		"torso": {"shape": "profile", "radius": 0.325, "height": 1.00,
			"profile": [Vector2(-1.0, 0.14), Vector2(-0.70, 0.235),
				Vector2(-0.12, 0.27), Vector2(0.48, 0.325),
				Vector2(1.0, 0.16)], "depth_scale": 0.88},
		"torso_y": 1.14,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.54, 0.22, 0.36)},
		"shorts_y": 0.62,
		"head": {"shape": "sphere", "radius": 0.185, "height": 0.35},
		"head_y": 1.80,
		"arm": {"top_radius": 0.075, "bottom_radius": 0.09, "height": 0.86},
		"leg": {"top_radius": 0.115, "bottom_radius": 0.085, "height": 0.74},
		"shoe": {"shape": "capsule", "radius": 0.115, "height": 0.28},
		"shoulder": Vector2(0.38, 1.50),
		"hip": Vector2(0.17, 0.48),
		"rig_height": 2.00,
		"skin": Color("8a6a45"),
		"crown": Color("e8ddc8"),
		"extras": [
			## Rotated past horizontal so they hang rather than point. A cone
			## tipped 150 degrees reads as a drop ear at any distance the game is
			## watched from; the same cone at 14 degrees is a cat.
			##
			## Set outboard at 0.195 rather than the authored 0.150, because 0.150
			## is *inside* the skull: the head blends to a radius near 0.180, so a
			## drop ear centred nearer than that hung within the head's own
			## outline and showed as a sliver of contour rather than as an ear.
			## Found by walking the per-voli ear axis and seeing all three lengths
			## read the same -- a feature that cannot be seen is not a feature.
			## Lifted 0.02 with it so the wider seat still meets the skull.
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "profile",
				"radius": 0.11, "height": 0.30,
				"profile": [Vector2(-1.0, 0.025), Vector2(-0.58, 0.085),
					Vector2(0.30, 0.11), Vector2(1.0, 0.065)],
				"depth_scale": 0.42,
				"position": Vector3(-0.195, 1.88, 0.02),
				"rotation": Vector3(0.0, 0.0, 152.0), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "profile",
				"radius": 0.11, "height": 0.30,
				"profile": [Vector2(-1.0, 0.025), Vector2(-0.58, 0.085),
					Vector2(0.30, 0.11), Vector2(1.0, 0.065)],
				"depth_scale": 0.42,
				"position": Vector3(0.195, 1.88, 0.02),
				"rotation": Vector3(0.0, 0.0, -152.0), "color": "skin",
			},
			## Longer and lower than Feli's. `PlayerActor3D._mouth_override` reads
			## this by name, so the face draws its mouth onto the muzzle instead of
			## burying it inside.
			{
				## A dog: the long one. Deeper than it is wide and nearly twice
				## Feli's reach, with a gentler taper so the jaw runs straight
				## rather than pinching -- which is why the prism flattered this
				## face first and Feli's second.
				"name": "Muzzle", "parent": "BodyPivot", "shape": "wedge", "ink": "body",
				"radius": 0.090, "height": 0.109,
				"depth": 0.238, "taper_width": 0.63, "taper_height": 0.68,
				"position": Vector3(0.0, 1.740, -0.208), "color": "skin",
			},
			{
				"name": "Tail", "parent": "BodyPivot", "shape": "cylinder",
				## Same shortening and the same reason as Feli's.
				"top_radius": 0.035, "bottom_radius": 0.06, "height": 0.46,
				## Same correction as Feli's: out of the seat, not out of the
				## spine.
				"position": Vector3(0.0, 0.88, 0.23),
				"rotation": Vector3(68.0, 0.0, 0.0), "color": "skin",
			},
		],
	}


## Heavy, low and immovable. Ursi trades acceleration and lateral speed for
## reception stability, attack power and composure, and the silhouette says so
## before the numbers do: the widest torso in the game on the shortest legs, so
## the mass sits low and nothing about it suggests it changes direction quickly.
##
## The limbs are thick rather than long. That matters against Avi, which is the
## other body built around a wall -- Avi makes a wall by being tall and wide with
## nothing to it, Ursi makes one by being dense.
static func _ursi() -> Dictionary:
	return {
		"torso": {"shape": "profile", "radius": 0.39, "height": 1.02,
			"profile": [Vector2(-1.0, 0.18), Vector2(-0.72, 0.33),
				Vector2(-0.10, 0.39), Vector2(0.50, 0.375),
				Vector2(1.0, 0.20)], "depth_scale": 0.96},
		"torso_y": 1.10,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.62, 0.22, 0.42)},
		"shorts_y": 0.60,
		"head": {"shape": "sphere", "radius": 0.20, "height": 0.36},
		"head_y": 1.74,
		"arm": {"top_radius": 0.095, "bottom_radius": 0.105, "height": 0.80},
		"leg": {"top_radius": 0.135, "bottom_radius": 0.10, "height": 0.64},
		"shoe": {"shape": "capsule", "radius": 0.13, "height": 0.30},
		"shoulder": Vector2(0.44, 1.46),
		"hip": Vector2(0.20, 0.46),
		"rig_height": 1.92,
		## Dark enough that the face palette flips to its light ink, which is the
		## check that rule was written for.
		"skin": Color("4a3b34"),
		"crown": Color("d9c9b4"),
		"extras": [
			## Small, round, set high and wide. Ears are the whole reason a bear
			## reads as a bear at silhouette scale.
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.075, "height": 0.13,
				"position": Vector3(-0.17, 1.87, 0.0), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.075, "height": 0.13,
				"position": Vector3(0.17, 1.87, 0.0), "color": "skin",
			},
			{
				## A bear: broad and blunt. The widest muzzle on the roster and
				## the least tapered, so the jaw is a shelf rather than a point.
				"name": "Muzzle", "parent": "BodyPivot", "shape": "wedge", "ink": "body",
				"radius": 0.100, "height": 0.100,
				"depth": 0.175, "taper_width": 0.66, "taper_height": 0.72,
				"position": Vector3(0.0, 1.680, -0.186), "color": "skin",
			},
		],
	}


## All reach and no weight, and deliberately *not* a person.
##
## The first Simi was a human with long arms, which is the one failure mode this
## body cannot have -- the roster is animals and produce, and the moment one type
## reads as an ordinary human being it becomes the default everyone else is a
## costume of. That is exactly why Homi was retired; drawing it back in under
## another name would undo the same decision twice.
##
## The fix is proportion rather than decoration. The arms are the longest in the
## game and the legs the shortest, so the hands hang near the knees; the shoulders
## are wide and set *low*; and the head is small and sits close to them with
## almost no neck. Nothing about the standing silhouette is upright-human, and
## none of it needs a costume to say so. The flat side-discs went with it -- ears
## in a human's place on a human's head was half the problem.
static func _simi() -> Dictionary:
	return {
		"torso": {"shape": "profile", "radius": 0.325, "height": 0.76,
			"profile": [Vector2(-1.0, 0.12), Vector2(-0.65, 0.205),
				Vector2(-0.05, 0.25), Vector2(0.58, 0.325),
				Vector2(1.0, 0.18)], "depth_scale": 0.75},
		"torso_y": 0.98,
		"torso_material": "kit",
		"shorts": {"shape": "box", "size": Vector3(0.46, 0.20, 0.32)},
		"shorts_y": 0.56,
		"head": {"shape": "sphere", "radius": 0.145, "height": 0.25},
		"head_y": 1.44,
		"arm": {"top_radius": 0.062, "bottom_radius": 0.08, "height": 1.20},
		"leg": {"top_radius": 0.10, "bottom_radius": 0.072, "height": 0.54},
		"shoe": {"shape": "box", "size": Vector3(0.21, 0.06, 0.32)},
		## Wide and low. A shoulder line below the head's own radius is what
		## makes a body read as hunched without posing it that way.
		"shoulder": Vector2(0.38, 1.26),
		"hip": Vector2(0.13, 0.42),
		"rig_height": 1.66,
		"skin": Color("6f5a4e"),
		"crown": Color("f0d9bd"),
		"extras": [
			## Small, low and set well back, nothing like a human ear's place.
			{
				"name": "EarLeft", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.052, "height": 0.085,
				"position": Vector3(-0.135, 1.42, 0.045), "color": "skin",
			},
			{
				"name": "EarRight", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.052, "height": 0.085,
				"position": Vector3(0.135, 1.42, 0.045), "color": "skin",
			},
			## A heavy brow over a short muzzle. The muzzle is what takes the
			## mouth off the skull -- `_mouth_override` reads it by name -- and a
			## face with its mouth on a snout is not a human face.
			{
				"name": "BrowLeft", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.068, "height": 0.045,
				"position": Vector3(-0.052, 1.505, -0.122),
				"rotation": Vector3(-12.0, 0.0, -9.0),
				"scale": Vector3(1.35, 1.0, 0.48), "color": "crown",
			},
			{
				"name": "BrowRight", "parent": "BodyPivot", "shape": "sphere",
				"radius": 0.068, "height": 0.045,
				"position": Vector3(0.052, 1.505, -0.122),
				"rotation": Vector3(-12.0, 0.0, 9.0),
				"scale": Vector3(1.35, 1.0, 0.48), "color": "crown",
			},
			{
				## A monkey: small and prognathous -- little section, but it
				## carries forward, which with the curved brow above it is the
				## whole read.
				"name": "Muzzle", "parent": "BodyPivot", "shape": "wedge", "ink": "body",
				"radius": 0.070, "height": 0.078,
				"depth": 0.145, "taper_width": 0.62, "taper_height": 0.70,
				"position": Vector3(0.0, 1.394, -0.140), "color": "skin",
			},
		],
	}
