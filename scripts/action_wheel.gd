extends Control

const NAMES := ["RECEIVE", "SET", "ATTACK", "BLOCK"]
const ACCENT := Color("54ead0")
var selected := 0
var locked := false
var charge_level := 0.0

func set_charge(value: float) -> void:
	value = clampf(value, 0, 1)
	if not is_equal_approx(charge_level, value):
		charge_level = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_action(action: int, committed: bool) -> void:
	if selected != action or locked != committed:
		selected = action
		locked = committed
		queue_redraw()

func action_at_slot(slot: int) -> int:
	if slot == 0:
		return selected
	var other: Array[int] = []
	for action in range(4):
		if action != selected:
			other.append(action)
	return other[slot - 1]

func slot_position(slot: int) -> Vector2:
	var corner := Vector2(280, 280)
	if slot == 0:
		return corner
	return corner + Vector2.from_angle(PI + (slot - 1) * PI / 4.0) * 184.0

func centered_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var corner := slot_position(0)
	var sector_radius := 240.0
	var sector := PackedVector2Array([corner])
	for i in range(65):
		sector.append(corner + Vector2.from_angle(PI + PI * 0.5 * i / 64.0) * sector_radius)
	draw_colored_polygon(sector, Color(0.04, 0.09, 0.13, 0.48))
	# Horizontal slices fill the quarter disk upward, green through gold to red.
	var fill_top := corner.y - sector_radius * charge_level
	var y := corner.y
	while y > fill_top + 0.01:
		var next_y := maxf(fill_top, y - 2.0)
		var x0 := corner.x - sqrt(maxf(0, sector_radius * sector_radius - pow(corner.y - y, 2)))
		var x1 := corner.x - sqrt(maxf(0, sector_radius * sector_radius - pow(corner.y - next_y, 2)))
		var fraction := clampf((corner.y - (y + next_y) * 0.5) / sector_radius, 0, 1)
		var color := Color("54d994").lerp(Color("f0ce5a"), fraction * 2) if fraction < 0.5 else Color("f0ce5a").lerp(Color("ee6170"), (fraction - 0.5) * 2)
		color.a = 0.38
		draw_colored_polygon(PackedVector2Array([Vector2(x0, y), Vector2(corner.x, y), Vector2(corner.x, next_y), Vector2(x1, next_y)]), color)
		y = next_y
	draw_arc(corner, sector_radius, PI, PI * 1.5, 64, Color(0.6, 0.78, 0.85, 0.25), 1, true)
	draw_arc(corner, 184, PI, PI * 1.5, 48, Color("42616e"), 2.0, true)
	draw_arc(corner, 202, PI, PI * 1.5, 48, Color(0.33, 0.92, 0.82, 0.15), 1.0, true)
	for slot in range(4):
		var action := action_at_slot(slot)
		var point := slot_position(slot)
		var active := slot == 0
		var radius := 46.0 if active else 35.0
		var color := ACCENT if active else Color("b1c8d2")
		draw_circle(point + Vector2(0, 3), radius + 3, Color(0, 0, 0, 0.22))
		draw_circle(point, radius, Color("1c4249") if active else Color("142536"))
		draw_arc(point, radius, 0, TAU, 64, color if active else Color("486170"), 2.0, true)
		centered_text(font, str(action + 1), point + Vector2(0, -1), 25 if active else 21, color)
		centered_text(font, NAMES[action], point + Vector2(0, 18), 12 if active else 10, color)
	if charge_level > 0:
		centered_text(font, "%d%%" % roundi(charge_level * 100), corner + Vector2(-80, -72), 16, Color("eff7fb"))
	centered_text(font, "ACTION WHEEL", Vector2(155, 28), 13, Color("91acbb"))
	centered_text(font, "COMMITTED" if locked else "1–4 SELECT", Vector2(155, 48), 12, Color("ffce73") if locked else Color("91acbb"))
