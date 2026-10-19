class_name RegionalKits
extends RefCounted

## What a club from each region wears, and how the shirt is built.
##
## **Presentation data, deliberately not on `regions.gd`.** That table is what
## the world and the simulation are made of -- principles, adjacency, fatigue
## resistance, naming. A kit colour decides nothing and predicts nothing; it is
## only how a club is drawn. Keeping the two apart means a renderer can be
## rewritten without touching a file the simulator reads, and a region can gain
## a strip without a save-format question.
##
## Until this existed every club in the world wore the same two colours:
## `player_actor_3d.gd` painted the torso from `UIPalette` keyed on
## `is_home_team` alone, so a Xérvyan side and a Hitōuen side were the same teal.
## The palettes and patterns below were drawn and reviewed in
## `tools/run_venue_probe.gd`, which now reads them from here rather than
## carrying its own copy -- one table, so a kit cannot be right in a render and
## wrong in a match.

## The home strip per region.
##
## **Every one is dark, and nothing sits in the middle.** A kit is seen against a
## terracotta floor and a midtone disappears into it -- the first pass was picked
## against the interface's own background, which is the wrong ground, and cost
## nine of fourteen their contrast.
##
## Measured against the court's albedo they run from 1.82:1 (Bompaçao) to 5.61:1
## (A'ace). The floor of that range used to be Spëddigh at 1.85; it moved when the
## six regions that had no drawn strip were recoloured to their design sheets.
## Every one of the fourteen still clears the 1.6 gate in `test_runner.gd`, which
## was checked before the palette changed rather than after it failed. A midtone tan or olive scores 1.12, which is the gap the gate in
## `test_runner.gd` sits in. An earlier draft of that gate asserted 3:1 and
## failed twelve of these -- that figure belonged to the court *surface* pass and
## had never been measured against a kit.
const KITS := {
	"Landavol": Color("35393A"),
	"Spëddigh": Color("1F4E6B"),
	"Pāwa Hitō": Color("26355C"),
	"Blôc du Larg": Color("414055"),
	"Xérvu": Color("3A2415"),
	"Taktikã": Color("1E2124"),
	"Ĭspayk": Color("0C4F52"),
	"A'ace": Color("0B0F14"),
	"Tãul ys Feynt": Color("2F4038"),
	"Lo-ong Ralī": Color("3A2331"),
	"Bompaçao": Color("3E4A47"),
	"Rhėn Tempaol": Color("123F5A"),
	"Kutré Lyn": Color("2B2B2D"),
	"Zaitgaist": Color("3E464E"),
}

## The visitors' change strip.
##
## Every home kit above is dark by necessity, so the away side has to be the
## light one -- two dark teams on one terracotta floor and nobody can tell who
## touched the ball. Universal for now, by explicit direction; the eventual
## version keeps each region's *construction* in dark trim on this ground, which
## is why the pattern tables below are keyed by region and not by kit colour.
const AWAY_KIT := Color("E4E0D6")

## How each region's shirt is built, which is what survives grayscale.
##
## **Construction, not colour.** The kits cannot be told apart by hue without
## making them louder, and making them louder undoes the contrast work that got
## them readable at all. Panels, seams, bands and their spacing are value
## structure, so a side stays nameable in a black-and-white frame and at the
## distance a match is actually watched from.
##
## `trim` is how far the marks sit from the kit in value -- lighter for all of
## them, since a dark kit can only be marked by something paler.
const BUILD := {
	## The template every other kit is a deviation from. Not an absence of
	## design: a placket and a collar, cleanly made, so it reads as the canonical
	## strip rather than as one nobody finished.
	"Landavol": {"pattern": "reference", "trim": 0.34},
	## Compressed and repeated -- short marks, many of them, close together. The
	## same thing the region does to a rally.
	"Spëddigh": {"pattern": "ticks", "trim": 0.40},
	## Broad athletic panels running with the body, so the shape reads as motion
	## even standing still.
	"Pāwa Hitō": {"pattern": "panels", "trim": 0.30},
	## Vertical divisions, structural and evenly spaced: the kit is built like
	## the thing the region believes in.
	"Blôc du Larg": {"pattern": "columns", "trim": 0.36},
	## Irregular, rhythmic accents -- uneven spacing that still keeps a beat.
	"Xérvu": {"pattern": "rhythm", "trim": 0.46},
	## Precise geometric seams. Thin, exact, and nothing decorative.
	"Taktikã": {"pattern": "seams", "trim": 0.30},
	## The old strip, one broad chest band, essentially unchanged for decades.
	"Ĭspayk": {"pattern": "heritage", "trim": 0.38},
	## Immaculate and technical, and covered in the people who paid for it.
	"A'ace": {"pattern": "sponsored", "trim": 0.42},
	## The six that had no drawn strip. Their design sheets arrived together with
	## a recolour of exactly these six and nothing else, which is what
	## `FALLBACK_PATTERN` below was keeping the list for.
	##
	## Angled seams that change direction at a panel rather than running through
	## it -- a line that redirects is the region's whole idea.
	"Tãul ys Feynt": {"pattern": "finesse", "trim": 0.34},
	## Continuity, not count: two lines that cross the whole shirt and carry on
	## down the shorts without a break.
	"Lo-ong Ralī": {"pattern": "endurance", "trim": 0.32},
	## One broad band set *low*, which is what separates it from Ĭspayk's chest
	## band: a platform, not a sash.
	"Bompaçao": {"pattern": "platform", "trim": 0.30},
	## A fan off one shoulder that stops before mid-chest. The truncation is the
	## design -- lines that start high and resolve quickly.
	"Rhėn Tempaol": {"pattern": "early", "trim": 0.36},
	## One seam that splits, with hard corners rather than curves: several
	## possible endings from a single setup.
	"Kutré Lyn": {"pattern": "forked", "trim": 0.34},
	## **Not a pattern -- a pointer.** Resolved in `pattern_for` to whoever last
	## won the Sixnet. See the note there.
	"Zaitgaist": {"pattern": "borrowed", "trim": 0.33},
}

## Three deliberate passes for every regional strip.
##
## These are kept beside the selected construction because iteration is part of
## the design's provenance. Without it, a later simplification cannot tell an
## abandoned idea from an accidental omission. Pass 1 preserves the original
## read, pass 2 fits it to the separated shirt/sleeve/shorts garment system, and
## pass 3 pushes the region's gesture far enough to survive match distance and
## the full Voli proportion range. `selected` is an index into `attempts`.
const ITERATIONS := {
	"Landavol": {
		"attempts": ["Quiet placket", "Collar-and-cuff canon", "Architect's baseline"],
		"selected": 2,
	},
	"Spëddigh": {
		"attempts": ["Twin tick rows", "Compressed yoke", "Full-kit pulse"],
		"selected": 2,
	},
	"Pāwa Hitō": {
		"attempts": ["Straight side bars", "Shoulder-to-hem panels", "Kinetic sweep"],
		"selected": 2,
	},
	"Blôc du Larg": {
		"attempts": ["Three columns", "Seven structural bays", "Nine-pier facade"],
		"selected": 2,
	},
	"Xérvu": {
		"attempts": ["Uneven chest beats", "Vertical syncopation", "Struck rhythm"],
		"selected": 2,
	},
	"Taktikã": {
		"attempts": ["Fine centre seam", "Measured grid", "Court schematic"],
		"selected": 2,
	},
	"Ĭspayk": {
		"attempts": ["Chest stripe", "Heritage ring", "Bound archive band"],
		"selected": 2,
	},
	"A'ace": {
		"attempts": ["Sponsor plaque", "Paid patchwork", "Broadcast billboard"],
		"selected": 2,
	},
	"Tãul ys Feynt": {
		"attempts": ["Angled seams", "Redirected pairs", "Double feint"],
		"selected": 2,
	},
	"Lo-ong Ralī": {
		"attempts": ["Long torso rails", "Waist-spanning rails", "Unbroken circuit"],
		"selected": 2,
	},
	"Bompaçao": {
		"attempts": ["Low stripe", "Platform ring", "Load-bearing base"],
		"selected": 2,
	},
	"Rhėn Tempaol": {
		"attempts": ["Shoulder rays", "Descending fan", "First-tempo burst"],
		"selected": 2,
	},
	"Kutré Lyn": {
		"attempts": ["Split seam", "Hard three-way fork", "Decision tree"],
		"selected": 2,
	},
	"Zaitgaist": {
		"attempts": ["Whole champion copy", "Single quoted mark", "Two-motif remix"],
		"selected": 2,
	},
}

## The default a region without its own construction falls back to.
##
## **Named, rather than silently borrowed.** Six minor regions have no drawn
## strip yet, and the honest state is that they wear the reference build -- not
## that they wear Landavol's. The distinction matters the day one of them gets
## its own: this constant is the list of what is still owed.
const FALLBACK_PATTERN := "reference"
const FALLBACK_TRIM := 0.34

## Where each pattern's marks sit, in torso-local metres.
##
## The chest is roughly 0.42 across and 0.5 tall, and 0.112 is just clear of the
## torso's own surface. Each entry is `[size, offset]`; the offset is mirrored to
## the back by the builder, because a kit carries its construction round the body
## and half of any frame is backs.
## Where each pattern's marks sit, in torso-local metres.
##
## **Re-authored at the scale the design sheets actually draw.** The old table
## was small and central -- a 0.30 plaque on a body 0.62 across -- and that was
## not a style choice, it was the geometry: every mark was placed on one flat
## plane, which only touches the body on the centre line, so anything wide
## floated off the shirt. `_build_kit_marks` now puts a mark on the cylinder at
## its own angle, so a stripe can reach the side seam and a band can ring the
## body. The sizes below assume that.
##
## `x` is the offset around the body, not a chord: it is fed to `asin(x / r)`, so
## it saturates at the radius and a mark authored past it piles up at the side.
## Keep offsets inside about 0.28.
##
## An entry is `[size, offset]`, optionally `+ roll_degrees`, optionally
## `+ place` where place is `torso` (default), `sleeves`, `legs` or `band`.
## `band` ignores size.x and builds a ring, which is the only way to get a mark
## that truly goes edge to edge.
const MARKS := {
	## A placket and a collar, cleanly made. The canon is defined by having
	## almost nothing: one short vertical opening at the centre chest and a yoke
	## rule at the shoulders.
	"reference": [
		[Vector3(0.103, 0.137, 0.010), Vector3(0.0, 0.30, 0.112)],
		[Vector3(0.024, 0.030, 0.012), Vector3(0.0, 0.365, 0.112)],
		## Piping at the sleeve hem, which the canon has and nothing else does.
		[Vector3(0.11, 0.016, 0.012), Vector3(0.0, -0.11, 0.0), 0.0, "sleeves"],
		[Vector3(0.12, 0.014, 0.012), Vector3(0.0, -0.24, 0.0), 0.0, "legs"],
	],
	## Two broad panels running the full height of the shirt, set out near the
	## side seams and carried onto the thigh so the sweep reads shoulder to hem.
	"panels": [
		## Curved, which a single box could not be: widest at the chest, narrowed
		## to 62% at the waist, and bowing 0.045 inward as it descends so it
		## follows the ribcage instead of hanging straight.
		[
			Vector3(0.154, 0.52, 0.012), Vector3(-0.17, 0.0, 0.112), 0.0, "torso",
			{"segments": 18, "waist": 0.62, "bow": 0.045},
		],
		[
			Vector3(0.154, 0.52, 0.012), Vector3(0.17, 0.0, 0.112), 0.0, "torso",
			{"segments": 18, "waist": 0.62, "bow": -0.045},
		],
		[Vector3(0.13, 0.40, 0.012), Vector3(0.0, -0.10, 0.0), 0.0, "legs"],
		[Vector3(0.10, 0.16, 0.012), Vector3(0.0, -0.04, 0.0), 0.0, "sleeves"],
	],
	## Thin, exact, and nothing decorative: two horizontals and one vertical,
	## reaching most of the way across so the diagram reads as structure rather
	## than as a badge.
	"seams": [
		[Vector3(0.46, 0.012, 0.010), Vector3(0.0, 0.09, 0.112)],
		[Vector3(0.38, 0.012, 0.010), Vector3(0.0, -0.13, 0.112)],
		[Vector3(0.012, 0.50, 0.010), Vector3(0.0, 0.0, 0.112)],
		[Vector3(0.08, 0.010, 0.010), Vector3(0.0, -0.03, 0.0), 0.0, "sleeves"],
		[Vector3(0.010, 0.34, 0.010), Vector3(0.0, -0.10, 0.0), 0.0, "legs"],
	],
	## Immaculate and covered in the people who paid for it. Blocks only -- the
	## wordmarks the sheets show are deliberately not here, because a kit carries
	## no text but its number.
	"sponsored": [
		[Vector3(0.34, 0.085, 0.012), Vector3(0.0, 0.19, 0.112)],
		[Vector3(0.13, 0.065, 0.012), Vector3(-0.17, 0.05, 0.112)],
		[Vector3(0.13, 0.065, 0.012), Vector3(0.17, 0.05, 0.112)],
		[Vector3(0.28, 0.055, 0.012), Vector3(0.0, -0.16, 0.112)],
		[Vector3(0.09, 0.045, 0.012), Vector3(0.0, -0.02, 0.0), 0.0, "sleeves"],
		[Vector3(0.11, 0.070, 0.012), Vector3(0.0, -0.12, 0.0), 0.0, "legs"],
	],
	## One broad chest band, right round the body. A ring rather than a plaque:
	## the old version stopped at 0.40 across and left the flanks bare, which is
	## a sash, and the point of this strip is that it is *unchanged for decades*
	## and goes all the way round.
	"heritage": [
		[Vector3(0.0, 0.201, 0.014), Vector3(0.0, 0.09, 0.112), 0.0, "band"],
		## Thin darker edging top and bottom -- rules that have to read against
		## the band rather than against the shirt, so they take the shade ink.
		[
			Vector3(0.0, 0.012, 0.016), Vector3(0.0, 0.196, 0.112), 0.0, "band",
			{"ink": "shade"},
		],
		[
			Vector3(0.0, 0.012, 0.016), Vector3(0.0, -0.016, 0.112), 0.0, "band",
			{"ink": "shade"},
		],
		[Vector3(0.12, 0.080, 0.014), Vector3(0.0, -0.08, 0.0), 0.0, "sleeves"],
		[Vector3(0.14, 0.080, 0.014), Vector3(0.0, -0.18, 0.0), 0.0, "legs"],
	],
	## Angled seams in pairs, the second of each continuing the first at a
	## different angle. That redirection is the pattern -- a straight line at 18
	## degrees is a tilted stripe; a line that arrives at 18 and leaves at -22 is
	## a feint. Long enough now to actually cross the panels they redirect around.
	"finesse": [
		[Vector3(0.016, 0.256, 0.010), Vector3(-0.17, -0.02, 0.112), 18.0],
		[Vector3(0.016, 0.20, 0.010), Vector3(-0.10, -0.24, 0.112), -22.0],
		[Vector3(0.016, 0.250, 0.010), Vector3(0.18, -0.04, 0.112), -18.0],
		[Vector3(0.016, 0.18, 0.010), Vector3(0.11, -0.25, 0.112), 20.0],
		[Vector3(0.012, 0.16, 0.010), Vector3(0.0, -0.04, 0.0), 24.0, "sleeves"],
		[Vector3(0.014, 0.28, 0.010), Vector3(0.0, -0.12, 0.0), -28.0, "legs"],
	],
	## Two lines, each the full height of the shirt, each carrying on down the
	## shorts. The count stays low on purpose: what says endurance is that
	## nothing interrupts them, and a dense field would read as rhythm instead.
	"endurance": [
		[Vector3(0.015, 0.805, 0.010), Vector3(-0.14, 0.0, 0.112), 3.0],
		[Vector3(0.015, 0.805, 0.010), Vector3(0.14, 0.0, 0.112), -3.0],
		## Two on the thigh, offset to sit under the two on the shirt, so the
		## line a viewer follows across the waist is the same line.
		[Vector3(0.014, 0.44, 0.010), Vector3(-0.035, -0.10, 0.0), 0.0, "legs"],
		[Vector3(0.014, 0.44, 0.010), Vector3(0.035, -0.10, 0.0), 0.0, "legs"],
		[Vector3(0.014, 0.20, 0.010), Vector3(0.0, -0.06, 0.0), 0.0, "sleeves"],
	],
	## Low and broad, and a ring for the same reason as Ĭspayk's: a platform that
	## stops at the flanks is not a platform. Ĭspayk sits at +0.09 and reads as a
	## sash; this sits at -0.11 and reads as something to stand on -- the same
	## shape saying a different thing purely by where it is.
	"platform": [
		[Vector3(0.0, 0.229, 0.014), Vector3(0.0, -0.11, 0.112), 0.0, "band"],
		[Vector3(0.13, 0.105, 0.014), Vector3(0.0, -0.19, 0.0), 0.0, "legs"],
		[Vector3(0.11, 0.028, 0.012), Vector3(0.0, -0.12, 0.0), 0.0, "sleeves"],
	],
	## A fan off one shoulder, spreading as it falls, every line stopping above
	## mid-chest. **The only asymmetric pattern here**, and it survives mirroring
	## because `marks_for` negates x and z together, so the fan stays on the
	## shoulder it was drawn on.
	"early": [
		## Steep at the shoulder and flattening as the fan spreads, which is the
		## way round the spec states and the reverse of how this first shipped:
		## 26 to 52 read as a fan closing inward, not opening downward.
		[Vector3(0.014, 0.26, 0.010), Vector3(-0.175, 0.10, 0.112), 30.0],
		[Vector3(0.014, 0.24, 0.010), Vector3(-0.140, 0.09, 0.112), 25.0],
		[Vector3(0.014, 0.21, 0.010), Vector3(-0.105, 0.08, 0.112), 20.0],
		[Vector3(0.014, 0.17, 0.010), Vector3(-0.070, 0.07, 0.112), 15.0],
		[Vector3(0.012, 0.14, 0.010), Vector3(0.0, 0.0, 0.0), 30.0, "sleeves"],
		[Vector3(0.014, 0.22, 0.010), Vector3(0.0, -0.10, 0.0), 34.0, "legs"],
	],
	## One seam down from the shoulder that splits in two, plus a single
	## unbranched line on the other side so the halves do not answer each other.
	## The corners are hard -- 40 and -34 off a stem at 12 -- because a curve
	## would read as flow and the region is about discrete choices.
	"forked": [
		[Vector3(0.015, 0.26, 0.010), Vector3(-0.16, 0.267, 0.112), 12.0],
		[Vector3(0.015, 0.26, 0.010), Vector3(-0.215, 0.007, 0.112), 44.0],
		[Vector3(0.015, 0.26, 0.010), Vector3(-0.07, 0.007, 0.112), -44.0],
		[Vector3(0.015, 0.20, 0.010), Vector3(0.19, 0.08, 0.112), -14.0],
		[Vector3(0.014, 0.18, 0.010), Vector3(0.0, -0.06, 0.0), 36.0, "sleeves"],
		[Vector3(0.014, 0.26, 0.010), Vector3(0.0, -0.12, 0.0), -40.0, "legs"],
	],
}


## The strip a region's clubs wear, or the change strip when it has no region.
static func kit_for(region: String) -> Color:
	return Color(KITS.get(region, AWAY_KIT))


static func has_kit(region: String) -> bool:
	return KITS.has(region)


static func away_kit() -> Color:
	return AWAY_KIT


## Which construction a region wears.
##
## **Zaitgaist resolves to somebody else's.** Its `BUILD` entry is the sentinel
## `borrowed`, and the region has no strip of its own by design: `player_generator`
## records that "Zaitgaist has no tradition of its own -- its specialty comes
## entirely from `region_overlay`, rewritten each season to mirror whoever last
## won the Sixnet", and `SixnetLeague` keeps it as `ZEITGEIST_REGION`, the one
## region that ignores geography.
##
## So the kit does what the roster already does. `champion` is passed in rather
## than read from `CareerManager`, because this file is presentation data and
## reaching into career state from here is the coupling its own header refuses.
## An empty champion -- a new career, nobody has won anything -- falls through to
## the reference build, which is both the honest state and the right one: an
## enclave with nothing to copy yet wears the canon.
const BORROWED_PATTERN := "borrowed"

static func pattern_for(region: String, champion: String = "") -> String:
	var named := str(Dictionary(BUILD.get(region, {})).get("pattern", FALLBACK_PATTERN))
	if named != BORROWED_PATTERN:
		return named
	## Guarded against pointing at itself, which is not a hypothetical: Zaitgaist
	## can win the Sixnet, and a pointer that resolves to its own sentinel would
	## recurse.
	if champion.is_empty() or champion == region:
		return FALLBACK_PATTERN
	return pattern_for(champion)


static func trim_for(region: String) -> float:
	return float(Dictionary(BUILD.get(region, {})).get("trim", FALLBACK_TRIM))


## The colour the marks are made in: the kit, lifted.
static func trim_colour(region: String) -> Color:
	return kit_for(region).lightened(trim_for(region))


## Every mark on this region's shirt, front and back, as `[size, offset]` pairs.
##
## The two repeating patterns are generated rather than listed, because their
## whole character is a count and a spacing -- writing out eight tick positions
## invites one of them being edited and the rhythm quietly breaking.
static func marks_for(region: String, champion: String = "", attempt: int = -1) -> Array:
	var pattern := pattern_for(region, champion)
	var chosen_attempt := attempt
	if chosen_attempt < 0:
		chosen_attempt = int(Dictionary(ITERATIONS.get(region, {})).get("selected", 2))
	chosen_attempt = clampi(chosen_attempt, 0, 2)
	var front: Array = []
	match pattern:
		"ticks":
			## Dense short ticks in horizontal bands -- a shoulder yoke, a hem, a
			## sleeve cuff -- reading as a dashed rule rather than as dots.
			##
			## Nine per band across the full width instead of two columns of four
			## near the middle: the compression *is* the design, and four marks
			## cannot be compressed.
			for band in [0.235, -0.235]:
				for i in range(19):
					front.append([
						## 3:1 tall to wide at 4% of torso height, on a pitch of
						## two tick widths -- a tick and a gap the same size,
						## which is what makes it a dashed rule and not dots.
						Vector3(0.0122, 0.0366, 0.011),
						Vector3(-0.234 + float(i) * 0.026, band, 0.112),
					])
			for i in range(5):
				front.append([
					Vector3(0.0110, 0.0330, 0.011),
					Vector3(-0.046 + float(i) * 0.023, -0.05, 0.0), 0.0, "sleeves",
				])
			## The shorts hem carries a band too, which the spec lists and the
			## first pass left off.
			for i in range(5):
				front.append([
					Vector3(0.0110, 0.0330, 0.011),
					Vector3(-0.046 + float(i) * 0.023, -0.24, 0.0), 0.0, "legs",
				])
		"columns":
			## Seven pinstripes edge to edge, full height, carried onto the shorts
			## so the rhythm survives the waist break.
			##
			## Three stripes across the middle third was a panel with gaps; a
			## column is only structural if there are enough of them to divide the
			## whole body.
			## Twelve at 1.5% of chest width on a 7% pitch. Seven at 3.6% read as
			## panels with gaps, which is the one thing the design says it is not.
			## Nine, not twelve. The pitch and the stripe width are what the spec
			## fixes; the *count* is what decides how far round the body the
			## outermost one sits, and twelve put it at 50 degrees -- on the
			## flank, where a front-on viewer reads it as coming off the shoulder.
			## Nine keeps the outermost at 34 degrees and still divides the whole
			## front.
			for col in range(9):
				front.append([
					Vector3(0.0092, 0.54, 0.011),
					Vector3(-0.172 + float(col) * 0.0431, 0.0, 0.112),
				])
			## Carried onto the shorts on the same pitch, so the rhythm survives
			## the waist break -- the detail that makes it read as architecture.
			for col in range(4):
				front.append([
					Vector3(0.0092, 0.42, 0.011),
					Vector3(-0.065 + float(col) * 0.0431, -0.10, 0.0), 0.0, "legs",
				])
			for col in range(3):
				front.append([
					Vector3(0.0085, 0.18, 0.011),
					Vector3(-0.035 + float(col) * 0.035, -0.05, 0.0), 0.0, "sleeves",
				])
		"rhythm":
			## **Vertical, not horizontal.** The strokes used to run across the
			## chest at uneven heights, which is a rhythm read top to bottom; the
			## design sheet draws it as irregular vertical striping, a rhythm read
			## left to right, and that is the one the serve-toss idea belongs to.
			##
			## Listed as intervals rather than positions so the unevenness is the
			## thing being stated, and the widths vary with them: a beat is not
			## only when a mark falls but how heavy it is.
			var beat := [0.10, 0.055, 0.085, 0.035, 0.075, 0.05]
			## 1% to 4% of chest width, which is the range the design states.
			var weight := [0.0246, 0.0080, 0.0180, 0.0062, 0.0215, 0.0105]
			var x := -0.235
			for i in range(beat.size()):
				front.append([
					Vector3(float(weight[i]), 0.54, 0.011),
					Vector3(x, 0.0, 0.112), 0.0, "torso",
					## Tapered ends rather than cut square, which is what gives a
					## stroke the struck, brushed quality the region is named for.
					## A single box cannot do it; a stack narrowing at both ends
					## can.
					{"segments": 14, "taper": 0.30},
				])
				x += float(beat[i])
			front.append([
				Vector3(0.024, 0.40, 0.011),
				Vector3(-0.02, -0.10, 0.0), 0.0, "legs",
			])
			front.append([
				Vector3(0.018, 0.18, 0.011),
				Vector3(0.018, -0.05, 0.0), 0.0, "sleeves",
				{"segments": 8, "taper": 0.30},
			])
		_:
			front = Array(MARKS.get(pattern, MARKS[FALLBACK_PATTERN]))
	front = _attempt_marks(front, chosen_attempt)
	## A borrower takes **one or two motifs, not the whole shirt**.
	##
	## Wearing every mark of the champion's build would not read as borrowing, it
	## would read as being them -- and on a court where both sides can be on it,
	## as the same team twice. Two front marks is enough to quote a construction
	## and not enough to reproduce it.
	if str(Dictionary(BUILD.get(region, {})).get("pattern", "")) == BORROWED_PATTERN:
		## The three Zaitgaist attempts are the borrowing argument itself: a full
		## copy, one quotation, then the selected two-motif remix.
		if chosen_attempt == 1:
			front = front.slice(0, mini(1, front.size()))
		elif chosen_attempt == 2:
			var remixed: Array = front.slice(0, mini(1, front.size()))
			for mark in front:
				var place := str(mark[3]) if mark.size() > 3 else "torso"
				if place not in ["torso", "band"]:
					remixed.append(mark)
					break
			front = remixed
	var both: Array = []
	for mark in front:
		var size: Vector3 = mark[0]
		var at: Vector3 = mark[1]
		## Optional, so every mark authored before angles existed still reads.
		var roll := float(mark[2]) if mark.size() > 2 else 0.0
		var place := str(mark[3]) if mark.size() > 3 else "torso"
		var profile: Dictionary = mark[4] if mark.size() > 4 else {}
		for face in [1.0, -1.0]:
			## **The roll mirrors with the mark.** Negating x without negating
			## the angle would leave a seam leaning the same way on both sides of
			## the body, which on the back reads as the mirror of a *different*
			## garment. One sign, applied to both, keeps the two faces the same
			## shirt seen from two directions -- and it keeps an asymmetric
			## pattern like `early` on the shoulder it was drawn on.
			both.append([
				size, Vector3(at.x * face, at.y, at.z * face), roll * face, place,
				## The bow mirrors with the mark for the same reason the roll
				## does: a panel that bows inward on the front has to bow inward
				## on the back, and inward is a different sign on each side.
				_mirror_profile(profile, face),
			])
	return both


## Turn the selected full-volume drawing back into its two earlier passes.
##
## Pass 0 is the old torso-only idea at restrained scale. Pass 1 proves the
## construction on the separated garment pieces but keeps it quieter. Pass 2
## is the selected match-distance version exactly as authored above. Deriving
## the earlier passes from the selected geometry keeps all three compatible
## with later fixes to curved patches, bands, sleeves and shorts.
static func _attempt_marks(source: Array, attempt: int) -> Array:
	if attempt >= 2:
		return source
	var result: Array = []
	var scale := 0.72 if attempt == 0 else 0.88
	for raw in source:
		var mark: Array = raw
		var place := str(mark[3]) if mark.size() > 3 else "torso"
		if attempt == 0 and place not in ["torso", "band"]:
			continue
		var size: Vector3 = mark[0]
		var at: Vector3 = mark[1]
		var roll := float(mark[2]) if mark.size() > 2 else 0.0
		var profile: Dictionary = mark[4].duplicate() if mark.size() > 4 else {}
		if profile.has("bow"):
			profile["bow"] = float(profile.bow) * scale
		result.append([
			Vector3(size.x * scale, size.y * scale, size.z),
			Vector3(at.x * scale, at.y * scale, at.z),
			roll * scale,
			place,
			profile,
		])
	return result


static func _mirror_profile(profile: Dictionary, face: float) -> Dictionary:
	if profile.is_empty() or not profile.has("bow"):
		return profile
	var mirrored := profile.duplicate()
	mirrored["bow"] = float(profile.bow) * face
	return mirrored


## One region for a whole side, from the players standing in it.
##
## **A kit belongs to a club, not to a body.** Reading `club_region` per player
## and painting each one from it would dress a roster whose data has drifted --
## a transfer half-applied, a generated squad with one unassigned voli -- in
## twelve different shirts, which is worse than the single wrong colour it
## replaced. The mode is immune to that: one outlier cannot split a team.
static func side_region(players: Array) -> String:
	var counts := {}
	var best := ""
	var best_count := 0
	for entry in players:
		if entry == null:
			continue
		var region := str(entry.club_region)
		if region.is_empty():
			continue
		counts[region] = int(counts.get(region, 0)) + 1
		if int(counts[region]) > best_count:
			best_count = int(counts[region])
			best = region
	return best
