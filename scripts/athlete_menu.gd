extends Control

# Athlete creation + selection. Layout follows the handoff progression UI:
#   (Position) | Level N | N Points | Power D+ | Speed D+ | Accuracy D+ | Endurance D+ | Trait Tree
# with each Attribute's governed statistics listed tree-style beneath it.
signal closed

const Store := preload("res://scripts/athlete_store.gd")
const Bodies := preload("res://vendor/vwm/body_type_models.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const TEAL := Color("54ead0")
const GOLD := Color("ffce73")
const DIM := Color("8faabb")

var draft: Dictionary
var editing := -1
var summary_row: HBoxContainer
var roster_box: VBoxContainer
var attribute_box: GridContainer
var attribute_intro: Label
var innate_box: VBoxContainer
var shape_picker: OptionButton
var shape_row: HBoxContainer
var palette_picker: OptionButton
var marking_picker: OptionButton
var span_control: SpinBox
var height_picker: OptionButton
var tree_view: Control
var tree_detail: Label
var pick_button: Button
var capacity_label: Label
var editor_tabs: TabContainer
var preview_panel: Control
var shown_node := {}
var tree_scroll: ScrollContainer
var name_edit: LineEdit
var status: Label
var preview_world: Node3D
var preview_actor: Node3D
var preview_stub: Node3D
var expanded := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draft = Store.blank()
	draft["picks"] = []
	if Store.selected >= 0 and Store.selected < Store.roster.size():
		editing = Store.selected
		draft = Store.migrate(Store.roster[editing])
	# Athletes saved before trait picks keep the traits they owned, as picks.
	if not draft.has("picks"):
		draft["picks"] = Store.legacy_picks(draft)
	_build()
	_refresh_all()

func label(text: String, size: int = 16, color: Color = Color("d8e8ed")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func button(text: String, callback: Callable, width: float = 130) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 34)
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_NONE
	return b

func panel(parent: Node, min_size: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142536")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	return box

func row(parent: Node, caption: String, control: Control) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var text := label(caption, 13)
	text.custom_minimum_size.x = 110
	line.add_child(text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = 32
	line.add_child(control)
	parent.add_child(line)
	return line

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color("0a1520")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var title := label("ATHLETES", 28, TEAL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(button("BACK TO TITLE", func(): closed.emit()))
	var bar_panel := panel(page, Vector2(0, 0))
	summary_row = HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 14)
	bar_panel.add_child(summary_row)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_build_roster(body)
	_build_editor(body)
	_build_preview(body)
	# The live preview belongs to the Build tab only.
	editor_tabs.tab_changed.connect(func(index: int): preview_panel.visible = index == 0)
	preview_panel.visible = editor_tabs.current_tab == 0
	status = label("", 14, GOLD)
	page.add_child(status)

func _build_roster(parent: Node) -> void:
	var box := panel(parent, Vector2(220, 0))
	box.add_child(label("ROSTER", 16, TEAL))
	roster_box = VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 6)
	box.add_child(roster_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(button("+ NEW ATHLETE", _new_athlete, 188))
	box.add_child(button("DELETE", _delete_athlete, 188))

func _build_editor(parent: Node) -> void:
	var box := panel(parent, Vector2(780, 0))
	# The panel itself (not just its inner box) takes the free width, so Allocation, Trait Tree and Innates use the space the live preview
	# occupies on the Build tab.
	(box.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tabs := TabContainer.new()
	editor_tabs = tabs
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	var build := VBoxContainer.new()
	build.name = "BUILD"
	build.add_theme_constant_override("separation", 10)
	tabs.add_child(build)
	var attribute_tabs := TabContainer.new()
	attribute_tabs.name = "ATTRIBUTES"
	tabs.add_child(attribute_tabs)
	var attributes_page := VBoxContainer.new()
	attributes_page.name = "ALLOCATION"
	attributes_page.add_theme_constant_override("separation", 8)
	attribute_tabs.add_child(attributes_page)
	attribute_intro = label("", 13, DIM)
	attributes_page.add_child(attribute_intro)
	attribute_box = GridContainer.new()
	attribute_box.columns = 2
	attribute_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attribute_box.add_theme_constant_override("h_separation", 24)
	attribute_box.add_theme_constant_override("v_separation", 14)
	attributes_page.add_child(attribute_box)
	_build_debug(attributes_page)
	var trait_page := HBoxContainer.new()
	trait_page.name = "TRAIT TREE"
	trait_page.add_theme_constant_override("separation", 12)
	attribute_tabs.add_child(trait_page)
	# The four attribute tabs stay put above the tree; only the tree region scrolls, by dragging it.
	var tree_column := VBoxContainer.new()
	tree_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_column.add_theme_constant_override("separation", 6)
	trait_page.add_child(tree_column)
	tree_view = preload("res://scripts/trait_tree_view.gd").new()
	tree_column.add_child(tree_view.build_tabs())
	tree_scroll = ScrollContainer.new()
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_column.add_child(tree_scroll)
	tree_scroll.add_child(tree_view)
	tree_view.node_selected.connect(_show_node)
	tree_view.node_activated.connect(_claim_node)
	var detail := panel(trait_page, Vector2(230, 0))
	capacity_label = label("", 14, GOLD)
	detail.add_child(capacity_label)
	tree_detail = label("", 14)
	tree_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tree_detail.custom_minimum_size.x = 200
	detail.add_child(tree_detail)
	pick_button = Button.new()
	pick_button.visible = false
	pick_button.pressed.connect(_toggle_pick)
	detail.add_child(pick_button)
	var innate_scroll := ScrollContainer.new()
	innate_scroll.name = "INNATES"
	innate_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	attribute_tabs.add_child(innate_scroll)
	innate_box = VBoxContainer.new()
	innate_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	innate_box.add_theme_constant_override("separation", 8)
	innate_scroll.add_child(innate_box)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Athlete name"
	name_edit.text_changed.connect(func(value: String):
		draft.name = value.left(24)
		_refresh_summary()
	)
	row(build, "NAME", name_edit)
	var body_picker := OptionButton.new()
	for type in Bodies.MODELLED:
		body_picker.add_item(type)
	body_picker.item_selected.connect(func(index: int):
		draft.body_type = Bodies.MODELLED[index]
		draft.appearance = {"palette_index": 0, "marking": "none"}
		_refresh_choices()
		_refresh_preview()
	)
	body_picker.name = "BodyPicker"
	row(build, "BODY", body_picker)
	shape_picker = OptionButton.new()
	for index in range(Bodies.PRODUCE.size()):
		shape_picker.add_item("Shape %d" % (index + 1))
	shape_picker.item_selected.connect(func(index: int):
		draft.appearance.produce = Bodies.PRODUCE[index]
		draft.appearance.palette_index = 0
		draft.appearance.marking = "none"
		_refresh_choices()
		_refresh_preview()
	)
	shape_row = row(build, "VARIETY", shape_picker)
	palette_picker = OptionButton.new()
	palette_picker.item_selected.connect(func(index: int):
		draft.appearance.palette_index = index
		_refresh_preview()
	)
	row(build, "PALETTE", palette_picker)
	marking_picker = OptionButton.new()
	marking_picker.item_selected.connect(func(index: int):
		draft.appearance.marking = marking_picker.get_item_text(index)
		_refresh_preview()
	)
	row(build, "MARKINGS", marking_picker)
	var role_picker := OptionButton.new()
	for role in Store.ROLES:
		role_picker.add_item(role)
	role_picker.item_selected.connect(func(index: int):
		draft.role = Store.ROLES[index]
		_refresh_summary()
		_refresh_innates()
	)
	role_picker.name = "RolePicker"
	row(build, "POSITION", role_picker)
	var hand_picker := OptionButton.new()
	hand_picker.add_item("Right")
	hand_picker.add_item("Left")
	hand_picker.item_selected.connect(func(index: int): draft.dominant_hand = "Left" if index == 1 else "Right")
	hand_picker.name = "HandPicker"
	row(build, "DOMINANT ARM", hand_picker)
	height_picker = OptionButton.new()
	height_picker.name = "HeightPicker"
	for inches in range(Store.MIN_INCHES, Store.MAX_INCHES + 1):
		height_picker.add_item(Store.height_label(inches))
	height_picker.item_selected.connect(func(index: int): _apply_height(Store.MIN_INCHES + index))
	row(build, "HEIGHT", height_picker)
	span_control = SpinBox.new()
	span_control.step = 1
	span_control.suffix = "cm"
	span_control.value_changed.connect(func(value: float):
		draft.span = value / 100.0
		_refresh_preview()
	)
	row(build, "WINGSPAN", span_control)
	build.add_child(label("6'0 to 6'2 is free. Nearby heights cost AP; Tiny and Giant heights unlock with those Innates.\nHeight and wingspan change reach and physical profile, not your Attribute ratings.", 12, DIM))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	actions.add_child(button("SAVE ATHLETE", _save, 160))
	actions.add_child(button("SAVE & SELECT", _save_and_select, 160))

func _build_preview(parent: Node) -> void:
	var box := panel(parent, Vector2(300, 0))
	preview_panel = box.get_parent()
	box.add_child(label("VOLI / LIVE PREVIEW", 16, TEAL))
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(268, 460)
	container.stretch = true
	box.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(353, 520)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	preview_world = Node3D.new()
	viewport.add_child(preview_world)
	preview_stub = Node3D.new()
	preview_stub.set_script(preload("res://scripts/preview_stub.gd"))
	preview_world.add_child(preview_stub)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b3044")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4dce9")
	environment.ambient_light_energy = 0.8
	env.environment = environment
	preview_world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	preview_world.add_child(light)
	var camera := Camera3D.new()
	preview_world.add_child(camera)
	camera.position = Vector3(0, 1.2, 3.8)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.fov = 42

# ---------- state -> UI ----------

func _refresh_all() -> void:
	_sync_controls()
	_refresh_roster()
	_refresh_summary()
	_refresh_attributes()
	_refresh_traits()
	_refresh_innates()
	_refresh_choices()
	_refresh_preview()

func _sync_controls() -> void:
	name_edit.text = str(draft.name)
	(find_child("BodyPicker", true, false) as OptionButton).select(maxi(0, Bodies.MODELLED.find(draft.body_type)))
	(find_child("RolePicker", true, false) as OptionButton).select(maxi(0, Store.ROLES.find(draft.role)))
	(find_child("HandPicker", true, false) as OptionButton).select(1 if draft.dominant_hand == "Left" else 0)
	height_picker.select(Store.height_inches(float(draft.height)) - Store.MIN_INCHES)
	span_control.min_value = float(draft.height) * 100.0 - 8
	span_control.max_value = float(draft.height) * 100.0 + 15
	span_control.set_value_no_signal(float(draft.span) * 100.0)

func _refresh_roster() -> void:
	for child in roster_box.get_children():
		roster_box.remove_child(child)
		child.queue_free()
	if Store.roster.is_empty():
		roster_box.add_child(label("No saved athletes yet.\nBuild one and save it.", 13, DIM))
	for index in range(Store.roster.size()):
		var entry: Dictionary = Store.roster[index]
		var mark := "★ " if index == Store.selected else ""
		var b := button("%s%s / %s" % [mark, entry.name, entry.role], func():
			editing = index
			draft = Store.migrate(Store.roster[index])
			_refresh_all()
		, 188)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if index == editing:
			b.add_theme_color_override("font_color", TEAL)
		roster_box.add_child(b)
	if editing < 0:
		roster_box.add_child(label("Editing a new athlete", 12, GOLD))

# Debug mode: simulate the progression a match would give (levels, Net-fall AP) so builds can be tried without playing one.
var debug_check: CheckBox
var debug_box: VBoxContainer
var debug_readout: Label
var debug_net_kind: OptionButton
var debug_nearby: OptionButton
var debug_first: CheckBox

func _build_debug(parent: Node) -> void:
	debug_check = CheckBox.new()
	debug_check.text = "Debug: simulate match progression"
	debug_check.toggled.connect(func(on: bool):
		debug_box.visible = on
		_refresh_debug())
	parent.add_child(debug_check)
	debug_box = VBoxContainer.new()
	debug_box.add_theme_constant_override("separation", 6)
	debug_box.visible = false
	parent.add_child(debug_box)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	level_row.add_child(label("LEVEL", 14))
	for step in [-1, 1, 5]:
		level_row.add_child(button("%+d" % step, func(): _debug_level(int(draft.get("level", 1)) + step), 44))
	level_row.add_child(button("MAX", func(): _debug_level(Store.LEVEL_CAP), 56))
	level_row.add_child(button("RESET", func(): _debug_reset(), 70))
	debug_box.add_child(level_row)
	var net_row := HBoxContainer.new()
	net_row.add_theme_constant_override("separation", 6)
	net_row.add_child(label("NET FALL", 14))
	debug_net_kind = OptionButton.new()
	for kind in ["Primary", "Secondary", "Tertiary"]:
		debug_net_kind.add_item(kind)
	net_row.add_child(debug_net_kind)
	debug_nearby = OptionButton.new()
	debug_nearby.add_item("global only")
	for count in range(1, 6):
		debug_nearby.add_item("%d near" % count)
	net_row.add_child(debug_nearby)
	debug_first = CheckBox.new()
	debug_first.text = "first Net of match"
	net_row.add_child(debug_first)
	net_row.add_child(button("AWARD", func(): _debug_net(), 80))
	net_row.add_child(button("FULL MATCH", func(): _debug_match(), 110))
	debug_box.add_child(net_row)
	var ap_row := HBoxContainer.new()
	ap_row.add_theme_constant_override("separation", 6)
	ap_row.add_child(label("GRANT AP", 14))
	for amount in [1, 5, 10]:
		ap_row.add_child(button("+%d" % amount, func(): _debug_ap(amount), 52))
	ap_row.add_child(button("-1", func(): _debug_ap(-1), 44))
	debug_box.add_child(ap_row)
	debug_readout = label("", 13, DIM)
	debug_box.add_child(debug_readout)

func _debug_changed() -> void:
	Store.prune_picks(draft)
	_refresh_summary()
	_refresh_attributes()
	_refresh_traits()
	_refresh_innates()
	_refresh_debug()

func _debug_level(target: int) -> void:
	Store.set_level(draft, target)
	_debug_changed()

func _debug_reset() -> void:
	Store.reset_progression(draft)
	_debug_changed()

func _debug_net() -> void:
	var kind: String = String(debug_net_kind.get_item_text(debug_net_kind.selected)).to_lower()
	var award: Dictionary = Store.award_net(draft, kind, debug_nearby.selected, debug_first.button_pressed)
	status.text = "%s Net: +%d AP (%d global, %d local)." % [kind.capitalize(), award.total, award.global, award.local]
	_debug_changed()

func _debug_match() -> void:
	var total: int = Store.simulate_match(draft, debug_nearby.selected)
	status.text = "Winning match: +%d AP from Nets." % total
	_debug_changed()

func _debug_ap(amount: int) -> void:
	Store.grant_ap(draft, amount)
	_debug_changed()

func _refresh_debug() -> void:
	if debug_readout == null:
		return
	var growth: Dictionary = draft.get("growth", {})
	var parts: Array[String] = []
	for key in Store.ATTRIBUTES:
		if int(growth.get(key, 0)) > 0:
			parts.append("%s +%d" % [Store.ATTRIBUTE_NAMES[key], int(growth[key])])
	var pools: Dictionary = Store.ap_pools(draft)
	debug_readout.text = "Level %d of %d. Opening AP %d of %d used (%d on innates and height, %d on attributes). Earned AP %d (%d from Nets, attributes only), %d spent, %d free in total. Free growth: %s." % [int(draft.get("level", 1)), Store.LEVEL_CAP, pools.opening_only + pools.opening_attributes, Store.AP_BUDGET, pools.opening_only, pools.opening_attributes, pools.earned_total, int(draft.get("net_ap", 0)), pools.earned_spent, _free_points(), ", ".join(parts) if not parts.is_empty() else "none"]

func _free_points() -> int:
	return Store.ap_budget(draft) - Store.ap_spent(draft)

func _refresh_summary() -> void:
	_refresh_heights()
	for child in summary_row.get_children():
		summary_row.remove_child(child)
		child.queue_free()
	var parts: Array[String] = [str(draft.role), "Level %d" % int(draft.get("level", 1)), "%d Points" % _free_points()]
	for key in Store.ATTRIBUTES:
		parts.append("%s %s" % [Store.ATTRIBUTE_NAMES[key], Store.grade(float(draft[key]))])
	parts.append("Trait Tree")
	for index in range(parts.size()):
		if index > 0:
			summary_row.add_child(label("|", 18, Color("3c5568")))
		var color := TEAL if index == 0 else (GOLD if index == 2 else Color("d8e8ed"))
		summary_row.add_child(label(parts[index], 18, color))
	_refresh_debug()

func _offsets(key: String) -> Array:
	return draft.offsets[key]

func _free_stat_points(key: String) -> int:
	var total := 0
	for value in _offsets(key):
		total += int(value)
	return -total

func _refresh_attributes() -> void:
	Store.sync_statistics(draft)
	for child in attribute_box.get_children():
		attribute_box.remove_child(child)
		child.queue_free()
	attribute_intro.text = "Spend %d AP on Attributes and Innates. +1 Attribute costs 1 AP (65 to %d)." % [Store.ap_budget(draft), Store.rating_cap(draft)]
	for key in Store.ATTRIBUTES:
		var rating := int(draft[key])
		var group := VBoxContainer.new()
		group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		group.add_theme_constant_override("separation", 4)
		attribute_box.add_child(group)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var caption := label(Store.ATTRIBUTE_NAMES[key].to_upper(), 15)
		caption.custom_minimum_size.x = 100
		line.add_child(caption)
		line.add_child(button("-", func(): _step_attribute(key, -1), 36))
		var value := label("%d  %s" % [rating, Store.grade(rating)], 16, TEAL)
		value.custom_minimum_size.x = 70
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(value)
		line.add_child(button("+", func(): _step_attribute(key, 1), 36))
		line.add_child(button("▴" if expanded.get(key, true) else "▾", func():
			expanded[key] = not expanded.get(key, true)
			_refresh_attributes()
		, 36))
		group.add_child(line)
		if not expanded.get(key, true):
			continue
		var free := _free_stat_points(key)
		var names: Array = Store.STATS[key]
		for index in range(names.size()):
			var offset := int(_offsets(key)[index])
			var stat_line := HBoxContainer.new()
			stat_line.add_theme_constant_override("separation", 8)
			stat_line.add_child(label("├─" if index < names.size() - 1 else "└─", 14, Color("3c5568")))
			var stat_name := label(names[index], 14)
			stat_name.custom_minimum_size.x = 150
			stat_line.add_child(stat_name)
			stat_line.add_child(button("-", func(): _step_stat(key, index, -1), 30))
			var stat_value := label(str(rating + offset), 14, GOLD if offset != 0 else Color("d8e8ed"))
			stat_value.tooltip_text = preload("res://scripts/stat_tuning.gd").band_name(rating+offset)+" — effects change at tier boundaries."
			stat_value.custom_minimum_size.x = 32
			stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stat_line.add_child(stat_value)
			stat_line.add_child(button("+", func(): _step_stat(key, index, 1), 30))
			group.add_child(stat_line)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 8)
		foot.add_child(label("%d free (±%d max)" % [free, Store.STAT_RANGE], 12, DIM))
		foot.add_child(button("BALANCED", func():
			_offsets(key).fill(0)
			_refresh_attributes()
		, 90))
		group.add_child(foot)

func _step_attribute(key: String, direction: int) -> void:
	var value := int(draft[key]) + direction
	if value < Store.rating_floor(draft, key) or value > Store.rating_cap(draft):
		return
	if direction > 0 and _free_points() <= 0:
		status.text = "No AP remaining."
		return
	draft[key] = float(value)
	Store.prune_picks(draft)
	_offsets(key).fill(0)
	status.text = ""
	_refresh_summary()
	_refresh_attributes()
	_refresh_traits()
	_refresh_innates()

func _step_stat(key: String, index: int, direction: int) -> void:
	var offsets := _offsets(key)
	var next := int(offsets[index]) + direction
	if absi(next) > Store.STAT_RANGE or float(draft[key])+next < 50 or float(draft[key])+next > 99:
		return
	if direction > 0 and _free_stat_points(key) <= 0:
		status.text = "Lower another %s statistic first." % Store.ATTRIBUTE_NAMES[key]
		return
	offsets[index] = next
	status.text = ""
	_refresh_attributes()

func _apply_height(inches: int) -> void:
	var trial := draft.duplicate()
	trial.height = inches * 0.0254
	if not Store.height_allowed(inches, draft.get("innates", [])) or Store.ap_spent(trial) > Store.ap_budget(draft) or Store.opening_only_cost(trial) > Store.AP_BUDGET:
		height_picker.select(Store.height_inches(float(draft.height)) - Store.MIN_INCHES)
		status.text = "That height is not available."
		return
	draft.height = inches * 0.0254
	height_picker.select(inches - Store.MIN_INCHES)
	span_control.min_value = float(draft.height) * 100.0 - 8
	span_control.max_value = float(draft.height) * 100.0 + 15
	span_control.set_value_no_signal(clampf(float(draft.span) * 100.0, span_control.min_value, span_control.max_value))
	draft.span = span_control.value / 100.0
	status.text = ""
	_refresh_summary()
	_refresh_attributes()
	_refresh_innates()
	_refresh_preview()

func _refresh_heights() -> void:
	if height_picker == null:
		return
	var current := Store.height_inches(float(draft.height))
	for index in range(height_picker.item_count):
		var inches := Store.MIN_INCHES + index
		var zone := Store.height_zone(inches)
		var text := Store.height_label(inches)
		match zone:
			"extended": text += "   +%d AP" % Store.height_cost(inches)
			"tiny": text += "   TINY"
			"giant": text += "   GIANT"
		var trial := draft.duplicate()
		trial.height = inches * 0.0254
		var blocked := not Store.height_allowed(inches, draft.get("innates", [])) or Store.ap_spent(trial) > Store.ap_budget(draft)
		height_picker.set_item_text(index, text)
		height_picker.set_item_disabled(index, blocked and inches != current)
	height_picker.select(current - Store.MIN_INCHES)

func _refresh_traits() -> void:
	tree_view.rebuild(draft)
	capacity_label.text = "BUILD CAPACITY  %d / %d" % [Store.capacity_used(draft), Store.trait_capacity(draft)]
	if tree_detail.text.is_empty():
		tree_detail.text = "Select a node."

func _show_node(info: Dictionary) -> void:
	shown_node = info
	var text := "%s\n\n%s" % [info.title, info.status]
	if str(info.get("needs", "")) != "":
		text += "\nRequires: " + str(info.needs)
		text += "\nReach cost: %d AP of %d" % [int(info.get("cost", 0)), Store.ap_budget(draft)]
	if str(info.get("exclusive", "")) != "":
		text += "\nChoosing a trait in this branch locks the other starting branch."
	var parents: Array = info.get("parents", [])
	if parents.size() > 1:
		text += "\n\nBuilds on one of: " + " or ".join(parents.map(func(p): return String(p.name) + (" (taken)" if p.picked else "")))
		var consumed_name := String(info.get("via", ""))
		for parent in parents:
			if String(parent.id) == consumed_name:
				consumed_name = String(parent.name)
		text += "\nTaking it consumes: %s. Click the other section to change." % consumed_name
		if String(info.get("kept", "")) != "":
			text += "\nKeeps from it: " + String(info.kept)
	elif parents.size() == 1:
		text += "\n\nBuilds on: " + String(parents[0].name)
	text += "\n\n" + str(info.text)
	tree_detail.text = text
	var state := String(info.get("state", ""))
	pick_button.visible = state in ["available", "picked"]
	pick_button.text = "DROP TRAIT" if state == "picked" else "PICK TRAIT"

# Double-clicking a node claims it when that is valid (it is selected by the first click); it never drops a pick.
func _claim_node(id: String) -> void:
	if String(shown_node.get("node_id", "")) != id or (draft.get("picks", []) as Array).has(id):
		return
	if Store.pick_blocker(draft, id, String(shown_node.get("via", ""))) != "":
		return
	_toggle_pick()

func _toggle_pick() -> void:
	var id := String(shown_node.get("node_id", ""))
	if id.is_empty():
		return
	if (draft.get("picks", []) as Array).has(id):
		Store.unpick_trait(draft, id)
		status.text = "Dropped %s." % shown_node.title
	elif Store.pick_trait(draft, id, String(shown_node.get("via", ""))):
		status.text = "Picked %s." % shown_node.title
	else:
		status.text = "%s cannot be picked." % shown_node.title
	_refresh_traits()
	if tree_view.nodes.has(id):
		(tree_view.nodes[id] as Button).pressed.emit()

func _toggle_innate(innate: String) -> void:
	if Store.innates_locked(draft):
		status.text = "Innates are chosen before a match. Reset progression to change them."
		return
	var chosen: Array = draft.get("innates", [])
	if innate in chosen:
		chosen.erase(innate)
	else:
		var candidate := chosen.duplicate()
		candidate.append(innate)
		if innate == "Giant":
			candidate.erase("Tiny")
		elif innate == "Tiny":
			candidate.erase("Giant")
		var trial := draft.duplicate()
		trial.innates = candidate
		if Store.ap_spent(trial) > Store.ap_budget(draft):
			status.text = "Not enough AP for %s." % innate
			return
		if Store.opening_only_cost(trial) > Store.AP_BUDGET:
			status.text = "%s is paid from the %d opening AP; earned AP cannot buy innates." % [innate, Store.AP_BUDGET]
			return
		chosen = candidate
	draft.innates = chosen
	status.text = ""
	if not Store.height_allowed(Store.height_inches(float(draft.height)), chosen):
		_apply_height(Store.DEFAULT_INCHES)
	# Losing Deep Bag can leave the build over capacity: the newest picks go first.
	Store.prune_picks(draft)
	_refresh_summary()
	_refresh_attributes()
	_refresh_traits()
	_refresh_innates()

func _refresh_innates() -> void:
	for child in innate_box.get_children():
		innate_box.remove_child(child)
		child.queue_free()
	var position_innate: Dictionary = Store.POSITION_INNATES[draft.role]
	innate_box.add_child(label("POSITION INNATE  (free)", 15, TEAL))
	innate_box.add_child(label("%s  /  %s\n%s" % [draft.role, position_innate.name, position_innate.text], 15, GOLD))
	var pools: Dictionary = Store.ap_pools(draft)
	innate_box.add_child(label("MATCH-START INNATES   %d of %d opening AP free" % [pools.opening_free, Store.AP_BUDGET], 15, TEAL))
	innate_box.add_child(label("Only chosen at build time, paid from the opening AP (never earned AP), and they cost much more than ordinary Traits. Giant and Tiny are exclusive.", 12, DIM))
	if Store.innates_locked(draft):
		innate_box.add_child(label("Locked: this athlete has progressed. Reset progression to change innates.", 13, GOLD))
	var chosen: Array = draft.get("innates", [])
	for innate in Store.INNATES:
		var info: Dictionary = Store.INNATES[innate]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var on: bool = innate in chosen
		var toggle := button("%s  %s" % ["●" if on else "○", innate], func(): _toggle_innate(innate), 160)
		toggle.disabled = Store.innates_locked(draft)
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.add_child(toggle)
		line.add_child(label("%d AP" % int(info.cost), 15, GOLD))
		innate_box.add_child(line)
		innate_box.add_child(label("      " + str(info.text), 12, Color("d8e8ed") if on else DIM))

func _refresh_choices() -> void:
	var produce := Bodies.chosen_produce(42, draft.appearance)
	shape_row.visible = draft.body_type == "Vegi"
	shape_picker.select(maxi(0, Bodies.PRODUCE.find(produce)))
	var key := Bodies.palette_key(draft.body_type, produce)
	palette_picker.clear()
	for index in range(Bodies.palette_count(key)):
		palette_picker.add_item("Colorway %d" % (index + 1))
	palette_picker.select(clampi(int(draft.appearance.get("palette_index", 0)), 0, maxi(0, palette_picker.item_count - 1)))
	marking_picker.clear()
	var options := Bodies.marking_options(key)
	for marking in options:
		marking_picker.add_item(marking)
	marking_picker.select(maxi(0, options.find(str(draft.appearance.get("marking", "none")))))

func _refresh_preview() -> void:
	if not is_instance_valid(preview_world):
		return
	if is_instance_valid(preview_actor):
		preview_actor.get_parent().remove_child(preview_actor)
		preview_actor.queue_free()
	preview_actor = Visual.build(preview_stub, preview_world, draft.body_type, draft.appearance, draft).body
	preview_actor.rotation.y = PI + 0.3

func _process(_dt: float) -> void:
	if visible and is_instance_valid(preview_actor):
		preview_actor.rotation.y = PI + sin(Time.get_ticks_msec() / 1200.0) * 0.35

# ---------- actions ----------

func _new_athlete() -> void:
	editing = -1
	draft = Store.blank()
	draft["picks"] = []
	status.text = ""
	_refresh_all()

func _commit() -> bool:
	if Store.ap_spent(draft) > Store.ap_budget(draft):
		status.text = "Over the AP budget."
		return false
	if str(draft.name).strip_edges().is_empty():
		draft.name = "Rookie"
	if editing < 0:
		Store.roster.append(draft.duplicate(true))
		editing = Store.roster.size() - 1
	else:
		Store.roster[editing] = draft.duplicate(true)
	return true

func _save() -> void:
	if _commit():
		Store.save_roster()
		status.text = "Saved %s." % draft.name
		_refresh_roster()

func _save_and_select() -> void:
	if _commit():
		Store.selected = editing
		Store.save_roster()
		status.text = "%s selected for the lab." % draft.name
		_refresh_roster()

func _delete_athlete() -> void:
	if editing < 0:
		return
	Store.roster.remove_at(editing)
	if Store.selected == editing:
		Store.selected = -1
	elif Store.selected > editing:
		Store.selected -= 1
	Store.save_roster()
	status.text = "Deleted."
	editing = -1
	draft = Store.blank()
	draft["picks"] = []
	_refresh_all()
