extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func mouse(pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e
func motion(rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT # a drag moves with the button held
	return e
func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	Store.roster = []
	Store.selected = -1
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	root.size = Vector2i(1500, 900)
	await process_frame
	await process_frame
	check(menu.editor_tabs.current_tab == 0 and menu.preview_panel.visible, "The live preview shows on the Build tab")
	menu.editor_tabs.current_tab = 1
	await process_frame
	check(not menu.preview_panel.visible, "The live preview is hidden on the Attributes tab")
	menu.editor_tabs.current_tab = 0
	await process_frame
	check(menu.preview_panel.visible, "The live preview comes back on the Build tab")
	var view = menu.tree_view
	var scroll: ScrollContainer = menu.tree_scroll
	check(view.tab_row.get_parent() != null and not scroll.is_ancestor_of(view.tab_row), "The four attribute tabs are outside the scrolling region")
	check(view.tab_row.get_child_count() == 4, "All four attribute tabs are there")
	view.show_page("power")
	menu._refresh_traits()
	await process_frame
	for key in ["power", "speed", "accuracy", "endurance"]:
		check(view.tab_buttons[key].is_inside_tree(), "%s tab is present" % key)
	# Drag scrolls the tree
	scroll.size = Vector2(300, 200)
	await process_frame
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0
	view._gui_input(mouse(true))
	view._gui_input(motion(Vector2(-80, -40)))
	view._gui_input(mouse(false))
	check(scroll.scroll_horizontal > 40 or scroll.scroll_vertical > 20, "Dragging the tree region scrolls it (%d, %d)" % [scroll.scroll_horizontal, scroll.scroll_vertical])
	menu.editor_tabs.current_tab = 1
	(scroll.get_parent().get_parent().get_parent() as TabContainer).current_tab = 1
	await process_frame
	check(view.tab_row.is_visible_in_tree() and scroll.scroll_horizontal > 0, "The tabs are still visible while the tree is scrolled")
	# A drag that starts on a node does not select it
	view.selected_id = ""
	view._gui_input(mouse(true))
	view._gui_input(motion(Vector2(30, 0)))
	(view.nodes[view.nodes.keys()[0]] as Button).pressed.emit()
	check(view.selected_id == "", "A press that moved is a drag, not a click on a node")
	view._gui_input(mouse(false))
	view._gui_input(mouse(true))
	view._gui_input(mouse(false))
	(view.nodes[view.nodes.keys()[0]] as Button).pressed.emit()
	check(view.selected_id != "", "A plain click still selects")
	# A release lost to a rebuild must not leave the tree following the mouse: motion without the button held ends the drag.
	view.dragging = true
	var loose := InputEventMouseMotion.new()
	loose.relative = Vector2(0, 30)
	var before: int = menu.tree_scroll.scroll_vertical
	view._gui_input(loose)
	check(not view.dragging and menu.tree_scroll.scroll_vertical == before, "Motion with no button held stops a stuck drag")
	print("athlete_menu_layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
