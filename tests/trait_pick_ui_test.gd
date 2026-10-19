extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func id_of(book, name: String) -> String:
	for n in book.nodes:
		if n.name == name:
			return n.id
	return ""
func click(menu, id: String) -> void:
	(menu.tree_view.nodes[id] as Button).pressed.emit()
	await process_frame
func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	Store.roster = []
	Store.selected = -1
	Store.save_path = "user://pick_ui_test.json"
	Store.forget_trait_book()
	var book = Store.trait_book()
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	await process_frame
	check(menu.draft.picks.is_empty(), "A new athlete starts with no picks")
	var serve := id_of(book, "Power Serve")
	var big := id_of(book, "Big Hitter")
	menu.tree_view.show_page("power")
	await process_frame
	await click(menu, serve)
	check(menu.shown_node.state == "locked" and not menu.pick_button.visible, "Power Serve is locked at POW 65 and cannot be picked")
	menu._step_attribute("power", 1)
	menu._step_attribute("power", 1)
	menu._step_attribute("power", 1)
	await click(menu, serve)
	check(menu.shown_node.state == "available" and menu.pick_button.visible and menu.pick_button.text == "PICK TRAIT", "POW 68 makes Power Serve available")
	menu.pick_button.pressed.emit()
	await process_frame
	check(menu.draft.picks == [serve], "Pressing PICK TRAIT picks it")
	await click(menu, big)
	check(menu.shown_node.state == "blocked" and not menu.pick_button.visible, "Big Hitter is locked out by the other branch")
	await click(menu, serve)
	check(menu.shown_node.state == "picked" and menu.pick_button.text == "DROP TRAIT", "A picked node offers DROP TRAIT")
	menu._step_attribute("power", -1)
	check(menu.draft.picks.is_empty(), "Lowering POW below 68 drops the pick")
	menu._step_attribute("power", 1)
	await click(menu, serve)
	menu.pick_button.pressed.emit()
	await process_frame
	menu.pick_button.pressed.emit()
	await process_frame
	check(menu.draft.picks.is_empty(), "DROP TRAIT removes it again")
	menu._step_attribute("power", 1)
	menu._step_attribute("power", 1)
	menu._step_attribute("power", 1)
	menu._step_attribute("power", 1)
	await click(menu, serve)
	menu.pick_button.pressed.emit()
	await process_frame
	menu._save()
	var saved: Dictionary = Store.roster[0]
	check(saved.picks == [serve] and Store.owned_traits(saved) == ["Power Serve"], "Picks are saved and decide the athlete's traits")
	# Legacy athlete without picks
	var legacy: Dictionary = Store.blank()
	legacy.speed = 66.0
	legacy.power = 70.0
	var carried: Array = Store.legacy_picks(legacy)
	check(carried.size() == 1 and carried.has(serve) or carried.size() == 2, "A legacy athlete keeps the traits they owned, without breaking branch locks (%s)" % str(carried))
	check(not (carried.has(serve) and carried.has(big)), "Legacy conversion never picks both starting branches")
	print("trait_pick_ui: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
