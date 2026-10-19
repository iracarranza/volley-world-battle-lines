class_name UIPalette
extends RefCounted

## Presentation tokens shared by Control themes, custom drawing, and 3D playback.
## Static resources duplicate a small subset of these values; the test suite
## verifies that those copies remain synchronized.
const DARK := {
	"canvas": Color("08131f"),
	"canvas_alt": Color("0d2130"),
	"surface": Color("10283a"),
	"surface_raised": Color("17384b"),
	"surface_inset": Color("07101a"),
	"surface_hover": Color("214d5d"),
	"ink": Color("f5f0dc"),
	"ink_muted": Color("a9bdc6"),
	"ink_faint": Color("6f8995"),
	"stroke": Color("34596a"),
	"stroke_strong": Color("5e8590"),
	"accent": Color("f2c84b"),
	"accent_ink": Color("17202a"),
	"accent_alt": Color("55c9c1"),
	"danger": Color("ff6b5f"),
	"positive": Color("75d99b"),
	"scrim": Color(0.01, 0.025, 0.04, 0.88),
	## The court, softened.
	##
	## `d97a45` is a saturated terracotta, and a volleyball court is the single
	## largest field of colour on the screen -- roughly a third of the frame. A
	## hue that reads as warm on a swatch reads as loud across that much area,
	## which is the ordinary trap of picking a colour in isolation and then
	## applying it to a wall.
	##
	## So the same hue, taken down in saturation and up a little in value: it is
	## still unmistakably a warm indoor court and it no longer competes with the
	## bodies standing on it, which are the thing a viewer is supposed to be
	## reading. The lines stay near-white and gain contrast for free.
	##
	## `court_floor` comes up off near-black for the matching reason. At `101b27`
	## the surround was a void the court floated in; a room has a floor, and it
	## being visible is most of what stops a lit court reading as a product on a
	## turntable.
	"court_floor": Color("1d2a36"),
	"court_surface": Color("cf8659"),
	"court_line": Color("fff2c7"),
	"court_net": Color(0.90, 0.96, 0.95, 0.64),
	"court_post": Color("267b84"),
}

const LIGHT := {
	"canvas": Color("efe7d3"),
	"canvas_alt": Color("d9e2d2"),
	"surface": Color("fffaf0"),
	"surface_raised": Color("f4eedf"),
	"surface_inset": Color("e4dfd2"),
	"surface_hover": Color("d7ead9"),
	"ink": Color("173d35"),
	"ink_muted": Color("4e6b64"),
	"ink_faint": Color("768b83"),
	"stroke": Color("9db6a9"),
	"stroke_strong": Color("537b6c"),
	"accent": Color("d94b3d"),
	"accent_ink": Color("fff9e9"),
	"accent_alt": Color("167f79"),
	"danger": Color("bd302d"),
	"positive": Color("247a50"),
	"scrim": Color(0.08, 0.11, 0.10, 0.72),
	## Molten gets the same treatment, from a lighter start -- see the note on
	## the Mikasa pair above. The floor stays the warm stock it already was.
	"court_floor": Color("ded7c8"),
	"court_surface": Color("d9906a"),
	"court_line": Color("fff8df"),
	"court_net": Color(0.13, 0.29, 0.28, 0.58),
	"court_post": Color("176f72"),
}

## What a grade is written in.
##
## Two tables, and it has to be two. These are the only colours in the interface
## that are *data* rather than decoration -- the number says what it is by what
## it is written in -- so they cannot be theme tokens, and for a long time they
## were one table used in both themes on the reasoning that a grade means the
## same thing on either page.
##
## Which is true of the meaning and false of the pigment. The dark table is five
## bright inks for a dark page, and C is `f2f4f7` -- as near white as makes no
## difference. Put that on cream paper and the most common grade on the roster,
## the one every average attribute carries, is invisible. Not hard to read:
## absent. A player's whole middle band read as a column of blank space.
##
## So the light table is the same five *hues* taken down to values that survive
## being written on paper, and C stops being "no colour" and becomes the page's
## own muted ink -- which is what average should look like anyway.
const GRADE_COLORS := {
	"S": Color("ffd84d"),
	"A": Color("58d68d"),
	"B": Color("5dade2"),
	"C": Color("f2f4f7"),
	"D": Color("ff6b6b"),
}

const GRADE_COLORS_LIGHT := {
	"S": Color("9a6b06"),
	"A": Color("1f7a4d"),
	"B": Color("1f5f96"),
	"C": Color("4e6b64"),
	"D": Color("b1332f"),
}


static func color(token: StringName, light_mode: bool = false) -> Color:
	var palette: Dictionary = LIGHT if light_mode else DARK
	return Color(palette.get(token, Color.MAGENTA))


static func grade_color(tier: String, light_mode: bool = false) -> Color:
	var table: Dictionary = GRADE_COLORS_LIGHT if light_mode else GRADE_COLORS
	return Color(table.get(tier, table.C))


static func grade_color_hex(tier: String, light_mode: bool = false) -> String:
	return grade_color(tier, light_mode).to_html(false)


static func control_is_light(control: Control) -> bool:
	return control.get_theme_color("font_color", "Label").get_luminance() < 0.45


## ## The board's own four markers
##
## The match centre is not lit by the journal's palette. `docs/design/
## THE_TACTICAL_WHITEBOARD.md` gives it melamine and **four markers**, and the
## four are the whole of what the object can say in colour -- there is no fifth
## pen in the tray.
##
## Kept apart from `DARK`/`LIGHT` rather than folded into them, because those
## two tables are the desk's palette and the board is on the wall. A screen that
## wants a marker asks for one by name; nothing else on the desk can.
##
## | pen | what it is for |
## |---|---|
## | black | everything written, the default hand |
## | blue | *structure* -- the court, the slot numbers, rules |
## | green | a good reading: A and S, and Working |
## | red | a bad one: D, and Spent |
##
## Amber is the fifth colour and is deliberately not a pen: it marks the middle
## fatigue stage only, which is the one state that is neither and would
## otherwise have to borrow green or red and say the wrong thing.
const BOARD_LIGHT := {
	&"board": Color("e7edea"),
	&"board_deep": Color("dbe3df"),
	&"tray": Color("a6afb0"),
	&"tray_lip": Color("8b9496"),
	&"card": Color("f5f8f6"),
	&"ink": Color("242a2c"),
	&"ink_soft": Color("5c6669"),
	&"ghost": Color("b9c4c0"),
	&"magnet": Color("6e7a7c"),
	&"marker_red": Color("bf3a2b"),
	&"marker_blue": Color("2b6ba6"),
	&"marker_green": Color("378554"),
	&"amber": Color("b77a15"),
}

const BOARD_DARK := {
	&"board": Color("151b1d"),
	&"board_deep": Color("0f1416"),
	&"tray": Color("333c3e"),
	&"tray_lip": Color("454f51"),
	&"card": Color("1c2426"),
	&"ink": Color("dfe7e4"),
	&"ink_soft": Color("96a3a2"),
	&"ghost": Color("394446"),
	&"magnet": Color("7e8b8d"),
	&"marker_red": Color("e2705f"),
	&"marker_blue": Color("74aedd"),
	&"marker_green": Color("6fc28c"),
	&"amber": Color("dda83f"),
}


static func board_color(token: StringName, light_mode: bool = false) -> Color:
	var table: Dictionary = BOARD_LIGHT if light_mode else BOARD_DARK
	return Color(table.get(token, table[&"ink"]))


## Which marker a grade is written in.
##
## Only the ends are coloured. B and C are the ordinary two thirds of the
## distribution and they are written in the same black as everything else --
## which is what leaves green and red meaning something when they appear, and is
## the same argument the board's `!`/`✓` marks are made on.
static func board_grade_color(tier: String, light_mode: bool = false) -> Color:
	match tier:
		"S", "A":
			return board_color(&"marker_green", light_mode)
		"D":
			return board_color(&"marker_red", light_mode)
		"C":
			return board_color(&"ink_soft", light_mode)
	return board_color(&"ink", light_mode)


## And which one a fatigue stage is written in. Amber is the middle stage and
## only the middle stage -- see the note on `BOARD_LIGHT`.
static func board_stage_color(stage: String, light_mode: bool = false) -> Color:
	match stage.to_lower():
		"spent":
			return board_color(&"marker_red", light_mode)
		"laboured", "labored":
			return board_color(&"amber", light_mode)
	return board_color(&"marker_green", light_mode)
