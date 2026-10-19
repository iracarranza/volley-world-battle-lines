extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	Store.save_path = "user://test_athletes.json"
	Store.roster = []
	Store.selected = -1
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	check(title.menu == null and title.title_box.visible, "Title shows its main buttons first")
	title._open_menu()
	await process_frame
	var menu = title.menu
	check(menu != null and not title.title_box.visible, "Athlete menu opens over the title")
	check(menu.summary_row.get_child_count() > 0, "Summary row is built")
	var texts := ""
	for child in menu.summary_row.get_children():
		texts += child.text + " "
	check("Level 1" in texts and "12 Points" in texts and "Power D" in texts and "Trait Tree" in texts, "Summary matches handoff format: " + texts)
	menu._step_attribute("power", 1)
	check(int(menu.draft.power) == 66 and menu._free_points() == 11, "AP spends from the budget")
	for i in range(30):
		menu._step_attribute("speed", 1)
	check(Store.ap_spent(menu.draft) == Store.AP_BUDGET, "AP never exceeds budget")
	menu._step_stat("speed", 0, 1)
	check(int(menu._offsets("speed")[0]) == 0, "Cannot raise a stat without a free point")
	menu._step_stat("speed", 1, -1)
	menu._step_stat("speed", 0, 1)
	check(int(menu._offsets("speed")[0]) == 1 and int(menu._offsets("speed")[1]) == -1, "Stat points redistribute zero-sum")
	for i in range(20):
		menu._step_stat("speed", 1, -1)
	check(int(menu._offsets("speed")[1]) >= -Store.STAT_RANGE, "Stat offset capped at range")
	menu._toggle_innate("Workhorse")
	check(Store.ap_spent(menu.draft) <= Store.AP_BUDGET, "Innate respects AP budget")
	menu.draft.speed = 65.0
	menu.draft.power = 65.0
	menu.draft.innates = []
	menu._toggle_innate("Giant")
	check("Giant" in menu.draft.innates, "Giant is chosen")
	check(Store.height_zone(81) == "giant" and Store.height_allowed(81, menu.draft.innates) and not Store.height_allowed(60, menu.draft.innates), "Giant unlocks only the giant range")
	menu._apply_height(82)
	check(Store.height_inches(menu.draft.height) == 82, "Giant height is selectable")
	check(Store.ap_spent(menu.draft) == 10, "Giant height adds no extra cost")
	menu._toggle_innate("Tiny")
	check("Tiny" in menu.draft.innates and not ("Giant" in menu.draft.innates) and Store.ap_spent(menu.draft) <= Store.AP_BUDGET, "Tiny replaces Giant, within budget")
	check(Store.height_zone(Store.height_inches(menu.draft.height)) == "free", "Dropping Giant resets a giant height")
	menu._toggle_innate("Tiny")
	check(menu.draft.innates.is_empty(), "Innate toggles off")
	check(menu.tree_view.get_parent() is ScrollContainer, "Trait tree is scrollable")
	menu.tree_view.show_page("speed")
	check(menu.tree_view.nodes.has("speed_quick_step") and not menu.tree_view.nodes.has("power_jump"), "Attribute page shows its authored stable-ID trait nodes")
	check(Store.height_cost(73) == 0 and Store.height_cost(69) == 1 and Store.height_cost(68) == 2 and Store.height_cost(66) == 2 and Store.height_cost(77) == 1 and Store.height_cost(78) == 2 and Store.height_cost(80) == 2, "Height costs scale outside the free range")
	menu.draft.innates = []
	menu._apply_height(60)
	check(Store.height_inches(menu.draft.height) != 60, "Tiny height blocked without Tiny")
	menu._apply_height(73)
	check(menu.innate_box.get_child_count() > 4, "Innate tab lists position innate and innates")
	menu.draft.name = "Test Ace"
	menu.draft.role = "MB"
	menu._save_and_select()
	check(Store.roster.size() == 1 and Store.selected == 0, "Save & select adds to roster and selects")
	var config: Dictionary = Store.selected_config()
	check(config.name == "Test Ace" and config.role == "MB", "Selected config round-trips")
	menu.closed.emit()
	await process_frame
	check(title.title_box.visible and "Test Ace" in title.selected_label.text, "Returning to title shows selected athlete")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	check(lab.athlete_name == "Test Ace" and lab.position_role == "MB", "Lab applies selected athlete name/position")
	check(is_equal_approx(float(lab.athlete.build.power), 65.0), "Lab receives attribute ratings")
	Store.roster = []
	Store.selected = -1
	DirAccess.remove_absolute(Store.save_path)
	print("TITLE / ATHLETE MENU CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
