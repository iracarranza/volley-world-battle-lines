extends Control
## Presentation only: the tick reads the live contact clock; it never advances gameplay.
const Table := preload("res://scripts/action_table.gd")
const NAMES := ["RECEIVE", "SET", "SPIKE", "BLOCK"]
const GRAY := Color("647b8b")
const YELLOW := Color("e7c15a")
const GREEN := Color("6ee7a4")
const RED := Color("ed6975")
const HOLD := 0.65
const FADE := 0.25
var lab: Node3D
var action := -1
var segments: Array[Dictionary] = []
var duration := 0.0
var age := 0.0
var contact_age := -1.0
var running := false
var remaining := 0.0
var phase := ""
var caption: Label
var _region_action := -1
var _region_windup := -1.0
var _draw_age := -1.0
var _draw_contact := -2.0
var _draw_duration := -1.0
var _draw_phase := ""
var _regions_dirty := true

static func regions(which: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var row := Table.row(which)
	if which == 3:
		# Display bands of the existing cubic press pulse: >50%, >5%, then weak.
		var press: float = row.pulse_seconds
		var strong := press * (1.0 - pow(0.5, 1.0/3.0))
		var weak := press * (1.0 - pow(0.05, 1.0/3.0))
		result.assign([
			{"end":strong,"color":GREEN,"label":"STRONG PRESS"},
			{"end":weak,"color":YELLOW,"label":"WEAKENING PRESS"},
			{"end":press,"color":GRAY,"label":"FADING PRESS"}])
	else:
		if which == 2 and row.windup > 0:
			result.append({"end":row.windup,"color":GRAY,"label":"WINDUP"})
		if which == 2:
			result.append({"end":row.power_start,"color":YELLOW,"label":"EARLY ROLL"})
		result.append({"end":row.sweet_start,"color":YELLOW,"label":"EARLY POWER" if which == 2 else "PLATFORM READY" if which == 0 else "EARLY CONTACT"})
		result.append({"end":row.sweet_end,"color":GREEN,"label":"SWEET TIMING"})
		if which == 2:
			result.append({"end":row.rescue_start,"color":YELLOW,"label":"LATE POWER"})
		result.append({"end":row.live_end,"color":RED,"label":"RESCUE PUSH" if which == 2 else "LATE CONTACT"})
	return result

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("edf7fc"))
	caption.add_theme_color_override("font_outline_color", Color("10212e"))
	caption.add_theme_constant_override("outline_size", 3)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	hide()

func clear() -> void:
	action = -1
	running = false
	remaining = 0
	contact_age = -1
	hide()

func configure(which: int) -> void:
	action = which
	var windup: float = Table.row(which).windup
	if which != _region_action or windup != _region_windup:
		segments = regions(which)
		_region_action = which
		_region_windup = windup
		_regions_dirty = true
	duration = float(segments.back().end)
	age = 0
	contact_age = -1

func begin(which: int) -> void:
	configure(which)
	running = true
	modulate.a = 1.0
	remaining = 0
	show()

func contact(event: Dictionary) -> void:
	if event.get("actor", "") != "player": return
	var which := int(event.get("action", -1))
	if which < 0 or which > 3: return
	if action != which or not running: configure(which)
	contact_age = clampf(float(event.get("confirmation_age", 0)), 0, duration)
	age = contact_age
	finish("CONTACT · " + str(event.get("zone", "")))

func finish(result: String) -> void:
	running = false
	phase = result
	remaining = HOLD + FADE

func phase_at(time: float) -> String:
	for region in segments:
		if time < float(region.end): return str(region.label)
	return "PASSIVE BLOCK" if action == 3 else "EXPIRED"

func advance(dt: float) -> void:
	if not is_instance_valid(lab): return
	if lab.paused: return
	if lab.is_benched():
		clear()
		return
	if lab.charging and not running: remaining = 0
	if running:
		if action == 3 and lab.block_state.active:
			age = clampf(lab.block_state.confirmation_age, 0, duration)
			phase = phase_at(age)
		else:
			age = clampf(lab.confirm_duration - lab.confirm_window, 0, duration)
			phase = phase_at(age)
			if lab.confirm_window <= 0:
				age = duration
				finish("MISSED")
	elif remaining > 0:
		remaining = maxf(0, remaining - dt)
		if remaining == 0:
			hide()
			return
	elif lab.charging or lab.armed or lab.block_state.active:
		var which: int = lab.selected if lab.charging else lab.locked_action
		configure(which)
		phase = "CHARGING %d%%" % roundi(lab.charge * 100) if lab.charging else "PREPARED · CONFIRM TO START"
		if which == 3 and lab.block_state.active:
			phase = "PASSIVE BLOCK"
			age = duration
	else:
		hide()
		return
	show()
	modulate.a = clampf(remaining / FADE, 0, 1) if remaining > 0 else 1.0
	var text: String = NAMES[action] + "  /  " + phase
	if caption.text != text: caption.text = text
	if _regions_dirty or age != _draw_age or contact_age != _draw_contact or duration != _draw_duration or phase != _draw_phase:
		queue_redraw()
		_draw_age = age
		_draw_contact = contact_age
		_draw_duration = duration
		_draw_phase = phase
		_regions_dirty = false

func _process(dt: float) -> void:
	advance(dt)

func _draw() -> void:
	if action < 0 or duration <= 0: return
	var track := Rect2(0, 22, size.x, 12)
	draw_rect(track.grow(2), Color("10212e"))
	var start := 0.0
	for region in segments:
		var end := float(region.end) / duration * size.x
		draw_rect(Rect2(start, 22, end-start, 12), region.color)
		if start > 0: draw_line(Vector2(start,22),Vector2(start,34),Color("10212e"),1)
		start = end
	if phase == "PASSIVE BLOCK": draw_rect(track, GRAY)
	var x := clampf(age / duration, 0, 1) * size.x
	draw_line(Vector2(x,18),Vector2(x,38),Color("10212e"),5)
	draw_line(Vector2(x,18),Vector2(x,38),Color.WHITE,2)
	if contact_age >= 0:
		var mark := contact_age / duration * size.x
		draw_colored_polygon(PackedVector2Array([Vector2(mark,35),Vector2(mark-4,41),Vector2(mark+4,41)]),Color.WHITE)
