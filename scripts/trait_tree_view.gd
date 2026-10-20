extends Control

# The trait tree as an athlete sees it: one page per Attribute, laid out as authored in the trait tree editor
# (data/trait_tree.json). Nodes are picked, available, locked behind a rating, locked out by an exclusive branch, or planned.
signal node_selected(info: Dictionary)

const Store := preload("res://scripts/athlete_store.gd")
const TEAL := Color("54ead0")
const GOLD := Color("ffce73")
const NODE := Vector2(132, 62)
const MARGIN := Vector2(16, 16)
const HEADER := 30.0   # cancels the -30 in the position formulas below; the tabs live outside the scrolling region
const DRAG_START := 6.0
var edges: Array = []
var nodes: Dictionary = {}
var selected_id := ""
var page := "power"
var tab_buttons := {}
var tab_row: HBoxContainer
var last_draft: Dictionary = {}
var dragging := false
var hover_node := ""          # a node with several parents shows its parents as sections: the one under the mouse is highlighted
var hover_side := 0
var chosen_side := {}           # node id -> which section the player last chose (the parent that taking it consumes)
var drag_distance := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(900, 620)

# The four attribute tabs, kept outside the scrolling region so they are always visible. The menu places them above the scroll.
func build_tabs() -> HBoxContainer:
	if tab_row != null:
		return tab_row
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	for key in Store.ATTRIBUTES:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.button_pressed = key == page
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(112, 28)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.text = Store.ATTRIBUTE_NAMES[key].to_upper()
		tab.pressed.connect(show_page.bind(key))
		tab_row.add_child(tab)
		tab_buttons[key] = tab
	return tab_row

# Drag anywhere on the tree, nodes included, to scroll it. A press that moved is a drag, not a click on a node.
func _gui_input(event: InputEvent) -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if event.pressed:
			drag_distance = 0.0
	elif event is InputEventMouseMotion and dragging:
		var step: Vector2 = -event.relative
		drag_distance += step.length()
		scroll.scroll_horizontal += int(step.x)
		scroll.scroll_vertical += int(step.y)

func show_page(key: String) -> void:
	page = key
	selected_id = ""
	if not last_draft.is_empty():
		rebuild(last_draft)

# What a node is for this athlete, as a state name.
static func state_of(draft: Dictionary, node: Dictionary) -> String:
	var book = Store.trait_book()
	var picks: Array = draft.get("picks", [])
	if picks.has(node.id):
		return "picked"
	if node.kind == "planned":
		return "planned"
	match Store.pick_blocker(draft, node.id):
		"locked": return "blocked"
		"ratings": return "locked"
		"needs": return "locked_parent"
		"capacity": return "full"
	return "available"

func rebuild(draft: Dictionary) -> void:
	last_draft = draft
	for child in get_children():
		remove_child(child)
		child.queue_free()
	edges.clear()
	nodes.clear()
	var book = Store.trait_book()
	build_tabs()
	for key in Store.ATTRIBUTES:
		(tab_buttons[key] as Button).text = "%s  %d" % [Store.ATTRIBUTE_NAMES[key].to_upper(), int(draft[key])]
		(tab_buttons[key] as Button).set_pressed_no_signal(key == page)
	var extent := Vector2(900, 400)
	for node in book.page(page):
		var top_left := MARGIN + Vector2(float(node.pos[0]), float(node.pos[1]) + HEADER - 30.0)
		extent = extent.max(top_left + NODE + Vector2(24, 24))
		var state := state_of(draft, node)
		var path_needs: Dictionary = book.path_needs(node.id)
		var needs: Array[String] = []
		for key in Store.ATTRIBUTES:
			if path_needs.has(key):
				needs.append("%s %d" % [Store.ATTRIBUTE_NAMES[key], int(path_needs[key])])
		var path_subs: Dictionary = book.path_subs(node.id)
		for key in path_subs:
			needs.append("%s %d" % [String(key).capitalize().replace("_", " "), int(path_subs[key])])
		var info := {"id": node.id, "node_id": node.id, "title": node.name if node.name != "" else "(unnamed)", "text": node.text, "state": state, "kind": node.kind, "needs": ", ".join(needs), "cost": book.reach_cost([node.id]), "status": _status_text(state), "exclusive": book.group_of(node.id)}
		var parents: Array = book.choice_parents(node.id)
		var parent_info := []
		for parent_id in parents:
			parent_info.append({"id": parent_id, "name": String(book.nodes[book.find(parent_id)].name), "picked": (draft.get("picks", []) as Array).has(parent_id)})
		info["parents"] = parent_info
		if parents.size() > 1:
			var side := _usable_side(info)
			info["via"] = String(parents[side])
			info["kept"] = _kept_text(node, String(parents[side]))
		_node(info, top_left, state)
		for index in range(parents.size()):
			var parent: Dictionary = book.nodes[book.find(parents[index])]
			var parent_top := MARGIN + Vector2(float(parent.pos[0]), float(parent.pos[1]) + HEADER - 30.0)
			var share := 0.5 if parents.size() == 1 else (float(index) + 0.5) / float(parents.size())
			edges.append([parent_top + Vector2(NODE.x * 0.5, NODE.y), top_left + Vector2(NODE.x * share, 0), false])
		# Merged and required nodes are dotted lines: the node is not built on them one at a time.
		var dotted: Array = book.merges_of(node.id) + (node.get("requires", []) as Array)
		for other_id in dotted:
			var other_index: int = book.find(String(other_id))
			if other_index < 0 or book.nodes[other_index].attribute != page:
				continue
			var other_top := MARGIN + Vector2(float(book.nodes[other_index].pos[0]), float(book.nodes[other_index].pos[1]) + HEADER - 30.0)
			edges.append([other_top + Vector2(NODE.x * 0.5, NODE.y), top_left + Vector2(NODE.x * 0.5, 0), true])
	custom_minimum_size = extent
	queue_redraw()

# Which section of a multi-parent node a click on it means: the one under the mouse, else the last chosen, and always one whose parent is
# taken when only some are.
func _usable_side(info: Dictionary, wanted: int = -1) -> int:
	var parents: Array = info.parents
	var side: int = wanted if wanted >= 0 else int(chosen_side.get(info.id, 0))
	side = clampi(side, 0, parents.size() - 1)
	if not parents[side].picked:
		for index in range(parents.size()):
			if parents[index].picked:
				return index
	return side

# What taking the node through that parent keeps from it, as text: the carried effects.
func _kept_text(node: Dictionary, parent_id: String) -> String:
	var carried: Dictionary = node.get("carried", {}).get(parent_id, {})
	if carried.is_empty():
		return ""
	var parts: Array[String] = []
	for key in carried:
		parts.append("%s %s" % [String(key).capitalize().replace("_", " "), str(carried[key])])
	return ", ".join(parts)

static func _status_text(state: String) -> String:
	match state:
		"picked": return "PICKED"
		"available": return "AVAILABLE"
		"locked": return "LOCKED: RATINGS"
		"locked_parent": return "LOCKED: TAKE WHAT IT BUILDS ON FIRST"
		"full": return "NO ROOM: BUILD CAPACITY IS FULL"
		"blocked": return "LOCKED OUT BY YOUR OTHER BRANCH"
		_: return "PLANNED"

func _node(info: Dictionary, top_left: Vector2, state: String) -> Button:
	var b := Button.new()
	b.text = info.title
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = NODE
	b.size = NODE
	b.position = top_left
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	var colors := {"picked": [Color("17434a"), TEAL], "available": [Color("3a3320"), GOLD], "locked": [Color("1a2733"), Color("4a6173")], "locked_parent": [Color("1a2733"), Color("4a6173")], "blocked": [Color("2a1a22"), Color("7a4a58")], "full": [Color("2a2418"), Color("8a7a4a")], "planned": [Color("141d27"), Color("5d7385")]}
	var pair: Array = colors[state]
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = pair[0]
		style.border_color = Color.WHITE if info.id == selected_id else pair[1]
		style.set_border_width_all(3 if state == "picked" or info.id == selected_id else 2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(4)
		b.add_theme_stylebox_override(style_name, style)
	b.add_theme_color_override("font_color", pair[1] if state in ["locked", "locked_parent", "blocked", "planned", "full"] else Color("e8f5f7"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	# Let presses reach the view as well, so a drag that starts on a node still scrolls.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	if info.get("parents", []).size() > 1:
		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.draw.connect(func(): _draw_sections(overlay, info))
		b.add_child(overlay)
		b.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseMotion:
				var side := int(clampf(event.position.x / NODE.x * info.parents.size(), 0.0, info.parents.size() - 1.0))
				if hover_node != info.id or hover_side != side:
					hover_node = info.id
					hover_side = side
					overlay.queue_redraw()
		)
		b.mouse_exited.connect(func():
			if hover_node == info.id:
				hover_node = ""
				overlay.queue_redraw()
		)
	b.pressed.connect(func():
		if drag_distance > DRAG_START:
			return
		selected_id = info.id
		var shown := info
		if info.get("parents", []).size() > 1:
			var side := _usable_side(info, hover_side if hover_node == info.id else -1)
			chosen_side[info.id] = side
			shown = info.duplicate(true)
			shown["via"] = String(info.parents[side].id)
			shown["kept"] = _kept_text(last_book_node(info.id), String(shown.via))
		node_selected.emit(shown)
		rebuild(last_draft)
	)
	add_child(b)
	nodes[info.id] = b
	return b

func last_book_node(id: String) -> Dictionary:
	var book = Store.trait_book()
	return book.nodes[book.find(id)]

# The sections of a node with several parents: a divider, the parents' names, the hovered section lit, the chosen one outlined.
func _draw_sections(overlay: Control, info: Dictionary) -> void:
	var parents: Array = info.parents
	var width := NODE.x / float(parents.size())
	var font := ThemeDB.fallback_font
	var chosen := _usable_side(info)
	for index in range(parents.size()):
		var rect := Rect2(Vector2(width * index, 0), Vector2(width, NODE.y))
		var enabled: bool = parents[index].picked
		if hover_node == info.id and hover_side == index:
			overlay.draw_rect(rect, Color(GOLD, 0.28 if enabled else 0.08))
		if index == chosen and info.id == selected_id:
			overlay.draw_rect(rect.grow(-2.0), Color(GOLD, 0.9), false, 2.0)
		if index > 0:
			overlay.draw_line(Vector2(width * index, 3), Vector2(width * index, NODE.y - 3), Color(1, 1, 1, 0.55), 1.5)
		var label := String(parents[index].name)
		overlay.draw_string(font, rect.position + Vector2(4, NODE.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, width - 6, 9, Color(1, 1, 1, 0.85 if enabled else 0.35))

func _draw() -> void:
	for edge in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var mid := (a.y + b.y) * 0.5
		var color := Color("3c8f98")
		if edge.size() > 2 and edge[2]:
			color = Color("ffce73")
			draw_dashed_line(a, Vector2(a.x, mid), color, 1.5, 6.0)
			draw_dashed_line(Vector2(a.x, mid), Vector2(b.x, mid), color, 1.5, 6.0)
			draw_dashed_line(Vector2(b.x, mid), b, color, 1.5, 6.0)
			continue
		draw_line(a, Vector2(a.x, mid), color, 2.0)
		draw_line(Vector2(a.x, mid), Vector2(b.x, mid), color, 2.0)
		draw_line(Vector2(b.x, mid), b, color, 2.0)
