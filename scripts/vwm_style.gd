extends RefCounted

# Font and colour conventions taken from Volley World Manager's title screen.
const HEADING_PATH := "res://fonts/CherryBombOne-Regular.ttf"
const BODY_PATH := "res://fonts/ShortStack-Regular.ttf"
const INK := Color("f5f0dc")
const INK_MUTED := Color("a9bdc6")
const INK_FAINT := Color("6f8995")
const ACCENT := Color("f2c84b")
const SURFACE_INSET := Color("07101a")
const STROKE := Color("5e8590")
const SHADOW := Color(0.01, 0.025, 0.04, 0.82)

static var _heading: Font
static var _body: Font

static func heading() -> Font:
	if _heading == null:
		_heading = load(HEADING_PATH)
	return _heading

static func body() -> Font:
	if _body == null:
		var variation := FontVariation.new()
		variation.base_font = load(BODY_PATH)
		variation.fallbacks = [heading()]
		_body = variation
	return _body

static func label(text: String, size: int, color: Color, use_heading: bool = true, shadow: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", heading() if use_heading else body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 3)
		l.add_theme_constant_override("shadow_offset_y", 4)
	return l

static func _nav_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 28.0 if hover else 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.bg_color = Color(0.06, 0.19, 0.29, 1) if hover else Color(0.03, 0.09, 0.16, 0.96)
	style.border_width_left = 6 if hover else 3
	style.border_color = Color(0.98, 0.79, 0.22, 1) if hover else Color(0.83, 0.66, 0.16, 0.65)
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	return style

static func nav_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", heading())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_stylebox_override("normal", _nav_style(false))
	for state in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, _nav_style(true))
	b.pressed.connect(callback)
	return b

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.157, 0.227, 0.97)
	style.border_color = Color(0.37, 0.52, 0.56, 1)
	style.set_border_width_all(4)
	style.set_corner_radius_all(26)
	style.set_content_margin_all(36)
	return style
