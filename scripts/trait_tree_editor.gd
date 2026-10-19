extends Control

# Trait tree editor: one page per Attribute, nodes dragged into place, each connected to a parent or standalone.
# Traits live on their primary Attribute's page; other requirements show as an "Also Requires" tag.
signal closed

const Book := preload("res://scripts/trait_book.gd")
const Store := preload("res://scripts/athlete_store.gd")
const Style := preload("res://scripts/vwm_style.gd")
const NODE_SIZE := Vector2(132, 62)
const KIND_COLORS := {"trait": Color("54ead0"), "innate": Color("ffce73"), "planned": Color("7f93a8")}
const BAD := Color("ff6b6b")

var book := Book.new()
var page := "power"
var selected := ""
var canvas: Control
var tab_buttons := {}
var name_edit: LineEdit
var effects_box: VBoxContainer
var effect_pick: OptionButton
const Mechanics := preload("res://scripts/contact/mechanic_registry.gd")
const EFFECT_KEYS := Mechanics.EFFECT_KEYS
var text_edit: TextEdit
var kind_pick: OptionButton
var cost_spin: SpinBox
var cost_row: Control
var group_row: Control
var group_edit: LineEdit
var reach_label: Label
var parent_pick: OptionButton
var need_checks := {}
var need_spins := {}
var problem_label: Label
var status_label: Label
var tag_label: Label
var dragging := ""
var drag_offset := Vector2.ZERO
var refreshing := false
var dirty := false
var save_path := Book.PATH

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.load_book(save_path)
	var back := ColorRect.new()
	back.color = Style.SURFACE_INSET
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	top.add_child(Style.label("TRAIT TREE EDITOR", 22, Style.INK, true, true))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pad)
	for key in Store.ATTRIBUTES:
		var tab := Button.new()
		tab.text = "%s  %s" % [Book.SHORT[key], Store.ATTRIBUTE_NAMES[key]]
		tab.toggle_mode = true
		tab.pressed.connect(show_page.bind(key))
		top.add_child(tab)
		tab_buttons[key] = tab
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	canvas = Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	body.add_child(canvas)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel_style())
	panel.custom_minimum_size.x = 340
	body.add_child(panel)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	var form_scroll := ScrollContainer.new()
	form_scroll.custom_minimum_size.x = 340
	panel.add_child(form_scroll)
	form_scroll.add_child(form)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(Style.label("SELECTED NODE", 12, Style.ACCENT))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Name"
	name_edit.text_changed.connect(func(_t): _read_form())
	form.add_child(name_edit)
	text_edit = TextEdit.new()
	text_edit.placeholder_text = "Description (required)"
	text_edit.custom_minimum_size.y = 90
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(_read_form)
	form.add_child(text_edit)
	form.add_child(Style.label("GAMEPLAY EFFECTS",12,Style.ACCENT))
	effects_box = VBoxContainer.new()
	form.add_child(effects_box)
	var effect_row := HBoxContainer.new()
	form.add_child(effect_row)
	effect_pick = OptionButton.new()
	for key in EFFECT_KEYS:
		effect_pick.add_item(Mechanics.effect(key).label)
		effect_pick.set_item_tooltip(effect_pick.item_count - 1, Mechanics.effect(key).description)
	effect_row.add_child(effect_pick)
	effect_row.add_child(_button("+",func():
		var node := _selected_node()
		if node.is_empty(): return
		if not node.has("effects"): node["effects"] = {}
		node.effects[EFFECT_KEYS[effect_pick.selected]] = 0.0
		dirty = true
		_refresh_effects(node)
	))
	var kind_row := HBoxContainer.new()
	form.add_child(kind_row)
	kind_row.add_child(Style.label("Kind", 14, Style.INK_MUTED))
	kind_pick = OptionButton.new()
	for kind in Book.KINDS:
		kind_pick.add_item(kind)
	kind_pick.item_selected.connect(func(_i): _read_form())
	kind_row.add_child(kind_pick)
	cost_row = HBoxContainer.new()
	form.add_child(cost_row)
	cost_row.add_child(Style.label("AP cost (innates)", 14, Style.INK_MUTED))
	cost_spin = SpinBox.new()
	cost_spin.min_value = 0
	cost_spin.max_value = 40
	cost_spin.value_changed.connect(func(_v): _read_form())
	cost_row.add_child(cost_spin)
	var parent_row := HBoxContainer.new()
	form.add_child(parent_row)
	parent_row.add_child(Style.label("Connected to", 14, Style.INK_MUTED))
	parent_pick = OptionButton.new()
	parent_pick.item_selected.connect(func(_i): _read_form())
	parent_row.add_child(parent_pick)
	group_row = HBoxContainer.new()
	form.add_child(group_row)
	group_row.add_child(Style.label("Exclusive group", 14, Style.INK_MUTED))
	group_edit = LineEdit.new()
	group_edit.placeholder_text = "blank = standalone"
	group_edit.custom_minimum_size.x = 150
	group_edit.text_changed.connect(func(_t): _read_form())
	group_row.add_child(group_edit)
	form.add_child(Style.label("ATTRIBUTE RESTRICTIONS", 12, Style.ACCENT))
	for key in Store.ATTRIBUTES:
		var row := HBoxContainer.new()
		form.add_child(row)
		var check := CheckBox.new()
		check.text = "%s  minimum" % Book.SHORT[key]
		check.toggled.connect(func(_on): _read_form())
		row.add_child(check)
		var spin := SpinBox.new()
		spin.min_value = Store.BASE_RATING
		spin.max_value = Store.MAX_RATING + 20
		spin.value = Store.BASE_RATING + 3
		spin.value_changed.connect(func(_v): _read_form())
		row.add_child(spin)
		need_checks[key] = check
		need_spins[key] = spin
	reach_label = Style.label("", 13, Style.ACCENT, false)
	reach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(reach_label)
	tag_label = Style.label("", 13, Style.INK_MUTED, false)
	tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(tag_label)
	problem_label = Style.label("", 13, BAD, false)
	problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(problem_label)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	bottom.add_child(_button("+ STANDALONE", func(): add_node(false)))
	bottom.add_child(_button("+ CONNECTED TO SELECTED", func(): add_node(true)))
	bottom.add_child(_button("DELETE", func(): delete_selected()))
	status_label = Style.label("", 13, Style.INK_MUTED, false)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status_label)
	bottom.add_child(_button("SAVE", func(): save()))
	bottom.add_child(_button("BACK", func(): closed.emit()))
	show_page("power")

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	return b

func show_page(key: String) -> void:
	page = key
	selected = ""
	for k in tab_buttons:
		tab_buttons[k].set_pressed_no_signal(k == key)
	_refresh_form()
	canvas.queue_redraw()

func node_rect(node: Dictionary) -> Rect2:
	return Rect2(Vector2(node.pos[0], node.pos[1]) + Vector2(24, 24), NODE_SIZE)

func add_node(connected: bool) -> Dictionary:
	var parent := selected if connected and selected != "" else ""
	var pos := Vector2(20, 20)
	if parent != "":
		var p: Dictionary = book.nodes[book.find(parent)]
		pos = Vector2(p.pos[0], p.pos[1]) + Vector2(0, Book.ROW_GAP)
	else:
		pos = Vector2(Book.COLUMN_GAP * float(book.page(page).size() % 4) + 160.0, 20)
	var node := book.add_node(page, pos, parent)
	node.needs = {page: Store.BASE_RATING + 3}
	selected = node.id
	dirty = true
	_refresh_form()
	canvas.queue_redraw()
	return node

func delete_selected() -> void:
	if selected == "":
		return
	book.remove_node(selected)
	selected = ""
	dirty = true
	_refresh_form()
	canvas.queue_redraw()

func select(id: String) -> void:
	selected = id
	_refresh_form()
	canvas.queue_redraw()

func save() -> bool:
	var bad := book.all_problems()
	if not bad.is_empty():
		status_label.text = "Not saved: %d node(s) still have problems." % bad.size()
		canvas.queue_redraw()
		return false
	var ok := book.save_book(save_path)
	if ok and save_path == Book.PATH:
		Store.forget_trait_book()
	dirty = not ok
	status_label.text = "Saved %d nodes." % book.nodes.size() if ok else "Could not write the file."
	return ok

func _selected_node() -> Dictionary:
	var i := book.find(selected)
	return book.nodes[i] if i >= 0 else {}

func _refresh_form() -> void:
	refreshing = true
	var node := _selected_node()
	var has := not node.is_empty()
	for control in [name_edit, text_edit, kind_pick, cost_spin, parent_pick]:
		if control is LineEdit or control is TextEdit:
			control.editable = has
	if has:
		name_edit.text = node.name
		text_edit.text = node.text
		kind_pick.select(Book.KINDS.find(node.kind))
		cost_spin.value = node.cost
		group_edit.text = String(node.get("exclusive", ""))
		parent_pick.clear()
		parent_pick.add_item("(standalone)")
		parent_pick.set_item_metadata(0, "")
		var chosen := 0
		for other in book.page(page):
			if other.id == node.id:
				continue
			if book.would_cycle(node.id, other.id):
				continue
			parent_pick.add_item(other.name if other.name != "" else other.id)
			var index := parent_pick.item_count - 1
			parent_pick.set_item_metadata(index, other.id)
			if other.id == node.parent:
				chosen = index
		parent_pick.select(chosen)
		for key in Store.ATTRIBUTES:
			need_checks[key].set_pressed_no_signal(node.needs.has(key))
			if node.needs.has(key):
				need_spins[key].value = node.needs[key]
	else:
		name_edit.text = ""
		text_edit.text = ""
	cost_row.visible = has and node.kind == "innate"
	group_row.visible = has and node.parent == ""
	_refresh_effects(node)
	refreshing = false
	_update_notes()

func _refresh_effects(node: Dictionary) -> void:
	for child in effects_box.get_children():
		effects_box.remove_child(child)
		child.queue_free()
	for key in node.get("effects",{}):
		var row := HBoxContainer.new()
		effects_box.add_child(row)
		var definition := Mechanics.effect(key)
		var caption := Style.label(definition.label,12,Style.INK_MUTED)
		caption.tooltip_text = definition.description + " / " + definition.stage
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var amount := SpinBox.new()
		amount.min_value = 0
		amount.max_value = 100
		amount.step = 1
		amount.suffix = definition.unit
		amount.value = float(node.effects[key])
		amount.value_changed.connect(func(value):
			node.effects[key] = value
			dirty = true
		)
		row.add_child(amount)
		row.add_child(_button("×",func():
			node.effects.erase(key)
			dirty = true
			_refresh_effects(node)
		))

func _read_form() -> void:
	if refreshing:
		return
	var node := _selected_node()
	if node.is_empty():
		return
	node.name = name_edit.text
	node.text = text_edit.text
	node.kind = Book.KINDS[kind_pick.selected]
	node.cost = int(cost_spin.value)
	node.exclusive = group_edit.text.strip_edges() if node.parent == "" or String(node.parent) == "" else ""
	node.parent = String(parent_pick.get_item_metadata(parent_pick.selected)) if parent_pick.selected >= 0 else ""
	var needs := {}
	for key in Store.ATTRIBUTES:
		if need_checks[key].button_pressed:
			needs[key] = float(need_spins[key].value)
	node.needs = needs
	cost_row.visible = node.kind == "innate"
	group_row.visible = node.parent == ""
	dirty = true
	_update_notes()
	canvas.queue_redraw()

func _update_notes() -> void:
	var node := _selected_node()
	if node.is_empty():
		tag_label.text = "Select a node, or add one."
		problem_label.text = ""
		reach_label.text = ""
		return
	tag_label.text = book.requirement_text(node) if not node.needs.is_empty() else ""
	problem_label.text = "\n".join(book.problems(node))
	var cost := book.reach_cost([node.id])
	var group := book.group_of(node.id)
	reach_label.text = "Reach cost %d AP (%s)%s" % [cost, "a base athlete can take it" if cost <= Store.AP_BUDGET else "out of reach at base, %d AP budget" % Store.AP_BUDGET, "  /  branch group: %s" % group if group != "" else ""]
	var warn := book.warnings(node)
	if not warn.is_empty():
		problem_label.text += ("\n" if problem_label.text != "" else "") + "\n".join(warn)

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := hit_test(event.position)
			select(hit)
			if hit != "":
				dragging = hit
				var node := _selected_node()
				drag_offset = event.position - node_rect(node).position
		else:
			dragging = ""
	elif event is InputEventMouseMotion and dragging != "":
		var node: Dictionary = book.nodes[book.find(dragging)]
		var top_left: Vector2 = event.position - drag_offset - Vector2(24, 24)
		node.pos = [maxf(0.0, snappedf(top_left.x, 10.0)), maxf(0.0, snappedf(top_left.y, 10.0))]
		dirty = true
		canvas.queue_redraw()

func hit_test(point: Vector2) -> String:
	var nodes := book.page(page)
	nodes.reverse()
	for node in nodes:
		if node_rect(node).has_point(point):
			return node.id
	return ""

func _draw_canvas() -> void:
	var font := ThemeDB.fallback_font
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color(0.04, 0.1, 0.15, 0.9))
	canvas.draw_string(font, Vector2(14, canvas.size.y - 10), "%s page: drag nodes to place them. Standalone nodes have no line." % Store.ATTRIBUTE_NAMES[page], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Style.INK_MUTED)
	var nodes := book.page(page)
	for node in nodes:
		if node.parent != "" and book.find(node.parent) >= 0:
			var parent: Dictionary = book.nodes[book.find(node.parent)]
			canvas.draw_line(node_rect(parent).get_center() + Vector2(0, NODE_SIZE.y * 0.5), node_rect(node).get_center() - Vector2(0, NODE_SIZE.y * 0.5), Color(0.37, 0.52, 0.56), 2.0)
	for node in nodes:
		var rect := node_rect(node)
		var invalid: bool = not book.problems(node).is_empty()
		var color: Color = KIND_COLORS.get(node.kind, Color.WHITE)
		var group: String = book.group_of(node.id)
		var tint := Color.from_hsv(fmod(float(hash(group)) * 0.0001, 1.0), 0.5, 0.9) if group != "" else Color(0, 0, 0, 0)
		canvas.draw_rect(rect, Color(color, 0.18))
		if group != "":
			canvas.draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), tint)
		canvas.draw_rect(rect, BAD if invalid else color, false, 3.0 if node.id == selected else 1.5)
		var title: String = node.name if node.name != "" else "(unnamed)"
		if node.kind == "innate":
			title += "  %d AP" % int(node.cost)
		canvas.draw_string(font, rect.position + Vector2(8, 18), title, HORIZONTAL_ALIGNMENT_LEFT, NODE_SIZE.x - 14, 13, Style.INK)
		canvas.draw_string(font, rect.position + Vector2(8, 36), _primary_text(node), HORIZONTAL_ALIGNMENT_LEFT, NODE_SIZE.x - 14, 12, color)
		canvas.draw_string(font, rect.position + Vector2(NODE_SIZE.x - 52, 36), "%d AP" % book.reach_cost([node.id]), HORIZONTAL_ALIGNMENT_RIGHT, 46, 11, Color("ffce73") if book.reachable_at_base(node.id) else Style.INK_MUTED)
		var also: String = book.also_requires(node)
		if also != "":
			canvas.draw_string(font, rect.position + Vector2(8, 52), also, HORIZONTAL_ALIGNMENT_LEFT, NODE_SIZE.x - 14, 10, Style.INK_MUTED)

func _primary_text(node: Dictionary) -> String:
	return "%s %d" % [Book.SHORT.get(node.attribute, "?"), int(node.needs.get(node.attribute, 0))] if node.needs.has(node.attribute) else "no restriction"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE and not name_edit.has_focus() and not text_edit.has_focus():
		delete_selected()
