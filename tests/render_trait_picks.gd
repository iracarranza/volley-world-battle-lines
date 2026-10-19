extends SceneTree
# The athlete menu's trait tree page with a few picks: godot --path . --script res://tests/render_trait_picks.gd
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
	menu.draft.power = 72.0
	menu.draft.accuracy = 70.0
	Store.pick_trait(menu.draft, "power_power_serve")
	Store.pick_trait(menu.draft, "new_trait_5")
	var attribute_tabs: TabContainer = menu.tree_scroll.get_parent().get_parent().get_parent()
	attribute_tabs.current_tab = 1
	(attribute_tabs.get_parent() as TabContainer).current_tab = 1
	menu.tree_view.show_page("power")
	menu._refresh_traits()
	await process_frame
	(menu.tree_view.nodes["new_trait_9"] as Button).pressed.emit()
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://artifacts/trait-picks.png")
	quit()
