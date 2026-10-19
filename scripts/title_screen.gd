extends Control

const Store := preload("res://scripts/athlete_store.gd")
const Style := preload("res://scripts/vwm_style.gd")
var menu: Control
var selected_label: Label
var selected_detail: Label
var title_box: Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Store.load_roster()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Style.SURFACE_INSET
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var court := Control.new()
	court.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	court.mouse_filter = Control.MOUSE_FILTER_IGNORE
	court.draw.connect(func():
		var line := Color(0.33, 0.92, 0.82, 0.07)
		var size := court.size
		for lane in range(3):
			var y := size.y * (0.70 + lane * 0.08)
			court.draw_line(Vector2(0, y), Vector2(size.x * 0.58, y), line, 2.0)
		court.draw_line(Vector2(size.x * 0.29, size.y * 0.66), Vector2(size.x * 0.29, size.y), line, 2.0)
	)
	add_child(court)
	var bar := ColorRect.new()
	bar.color = Style.ACCENT
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 8
	add_child(bar)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 68)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 52)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	title_box = margin
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	margin.add_child(columns)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 12)
	columns.add_child(brand)
	brand.add_child(Style.label("PROVISIONAL TITLE  /  2026", 14, Style.ACCENT))
	var title := Style.label("VOLLEY WORLD\\nBATTLE LINES".replace("\\n", "\n"), 64, Style.INK, true, true)
	title.add_theme_constant_override("line_spacing", 14)
	brand.add_child(title)
	brand.add_child(Style.label("three lanes. five positions.\nthe rally is the teamfight.", 17, Style.INK_MUTED, false))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brand.add_child(spacer)
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.157, 0.227, 0.96)
	card_style.border_color = Color(0.37, 0.52, 0.56, 1)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size.x = 430
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	brand.add_child(card)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	card.add_child(lines)
	lines.add_child(Style.label("SELECTED ATHLETE", 12, Style.ACCENT))
	selected_label = Style.label("", 23, Style.INK)
	lines.add_child(selected_label)
	selected_detail = Style.label("", 14, Style.INK_MUTED, false)
	lines.add_child(selected_detail)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel_style())
	panel.custom_minimum_size = Vector2(480, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(panel)
	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 14)
	panel.add_child(menu_box)
	menu_box.add_child(Style.label("CONTACT LAB", 12, Style.ACCENT))
	menu_box.add_child(Style.label("Where to next?", 25, Style.INK, true, true))
	menu_box.add_child(HSeparator.new())
	menu_box.add_child(Style.nav_button("01   ENTER CONTACT LAB", _enter_lab))
	menu_box.add_child(Style.nav_button("02   ATHLETES", _open_menu))
	menu_box.add_child(Style.nav_button("03   TRAIT TREE EDITOR", _open_trait_editor))
	menu_box.add_child(Style.nav_button("04   QUIT", func(): get_tree().quit()))
	_refresh_selected()

func _refresh_selected() -> void:
	var config := Store.selected_config()
	if config.is_empty():
		selected_label.text = "None selected"
		selected_detail.text = "The lab will use the default Rookie."
	else:
		selected_label.text = str(config.name)
		selected_detail.text = "%s  /  Level %d  /  %s" % [config.role, int(config.get("level", 1)), Store.height_label(Store.height_inches(float(config.height)))]

func _enter_lab() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _open_menu() -> void:
	title_box.hide()
	menu = preload("res://scripts/athlete_menu.gd").new()
	menu.closed.connect(func():
		menu.queue_free()
		menu = null
		title_box.show()
		_refresh_selected()
	)
	add_child(menu)

func _open_trait_editor() -> void:
	title_box.hide()
	var editor := preload("res://scripts/trait_tree_editor.gd").new()
	editor.closed.connect(func():
		editor.queue_free()
		title_box.show()
	)
	add_child(editor)
