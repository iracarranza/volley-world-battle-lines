extends SceneTree
# The athlete menu's trait tree with a two-parent node hovered: godot --path . --script res://tests/render_split_node.gd
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1500, 900)
	var Store = load("res://scripts/athlete_store.gd")
	Store.roster = []
	Store.selected = -1
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	await process_frame
	menu.draft.power = 80.0
	menu.draft.speed = 70.0
	menu.draft.picks = []
	Store.pick_trait(menu.draft, "new_trait")
	Store.pick_trait(menu.draft, "pow_tough_arms")
	var attribute_tabs: TabContainer = menu.tree_scroll.get_parent().get_parent().get_parent()
	attribute_tabs.current_tab = 1
	(attribute_tabs.get_parent() as TabContainer).current_tab = 1
	menu.tree_view.show_page("power")
	menu._refresh_traits()
	await process_frame
	menu.tree_scroll.scroll_horizontal = 300
	menu.tree_view.hover_node = "new_trait_3"
	menu.tree_view.hover_side = 1
	(menu.tree_view.nodes["new_trait_3"] as Button).pressed.emit()
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://artifacts/split-node.png")
	quit()
