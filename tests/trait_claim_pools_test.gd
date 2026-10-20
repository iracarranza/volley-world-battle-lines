extends SceneTree
# Double-click to claim, and the opening AP kept apart from earned AP.
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func dbl(button: Button) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.double_click = true
	button.gui_input.emit(e)
func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	Store.roster = []
	Store.selected = -1
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	await process_frame
	menu.draft.power = 70.0
	menu.tree_view.show_page("power")
	menu._refresh_traits()
	await process_frame
	(menu.tree_view.nodes["power_power_serve"] as Button).pressed.emit()
	await process_frame
	dbl(menu.tree_view.nodes["power_power_serve"])
	await process_frame
	check((menu.draft.picks as Array).has("power_power_serve"), "Double-click claims a valid node")
	dbl(menu.tree_view.nodes["power_power_serve"])
	await process_frame
	check((menu.draft.picks as Array).has("power_power_serve"), "...and never drops a claimed one")
	(menu.tree_view.nodes["pow_tooler"] as Button).pressed.emit()
	await process_frame
	dbl(menu.tree_view.nodes["pow_tooler"])
	await process_frame
	check(not (menu.draft.picks as Array).has("pow_tooler"), "Double-click does nothing on a node that is not valid")
	var other: Dictionary = Store.blank()
	# Pools
	menu.draft.role = "OH"
	menu.draft.innates = []
	menu.draft.power = 65.0
	menu.draft.picks = []
	menu._toggle_innate("Open Mind")
	var pools: Dictionary = Store.ap_pools(menu.draft)
	check(menu.draft.innates.has("Open Mind") and pools.opening_only == 6 and pools.opening_free == 6, "An innate is paid from the opening AP")
	menu._debug_ap(20)
	check(Store.innates_locked(menu.draft), "Innates lock once AP has been added")
	menu._toggle_innate("Deep Bag")
	check(not menu.draft.innates.has("Deep Bag"), "Debug AP cannot claim an innate")
	menu._debug_reset()
	check(not Store.innates_locked(menu.draft) and menu.draft.innates.has("Open Mind"), "Reset unlocks innates and keeps the chosen ones")
	menu._toggle_innate("Deep Bag")
	check(menu.draft.innates.has("Deep Bag") and Store.opening_only_cost(menu.draft) == 12, "Innates may use the whole 12 opening AP")
	menu._toggle_innate("Workhorse")
	check(not menu.draft.innates.has("Workhorse"), "...but not more")
	menu.draft.innates = ["Giant"]
	menu.draft.height = 2.18
	check(Store.opening_only_cost(menu.draft) >= 10, "Giant counts as opening-only AP")
	menu.draft.innates = []
	menu.draft.height = 1.86
	menu.draft.power = 77.0
	menu.draft.speed = 70.0
	menu.draft.accuracy = 77.0
	pools = Store.ap_pools(menu.draft)
	check(pools.opening_attributes == 12 and pools.earned_spent == 17 and pools.opening_free == 0, "Attributes use the opening pool first, then earned AP")
	# Fork exclusivity follows the route a node was taken through
	var book = Store.trait_book()
	var rich := {"power": 99.0, "speed": 99.0, "accuracy": 99.0, "endurance": 99.0, "picks": []}
	Store.pick_trait(rich, "new_trait")
	check(Store.pick_blocker(rich, "pow_tough_arms") == "", "Big Hitter does not lock Tough Arms: they share no fork")
	Store.pick_trait(rich, "new_trait_3")
	check(Store.pick_blocker(rich, "pow_tough_arms") == "", "Nor does Rhythm Hitter taken through Big Hitter")
	check(Store.pick_trait(rich, "pow_tough_arms") and Store.pick_blocker(rich, "pow_scramble") == "", "Rhythm Hitter taken through Big Hitter leaves Tough Arms' other branch open")
	var via_tough := {"power": 99.0, "speed": 99.0, "accuracy": 99.0, "endurance": 99.0, "picks": []}
	Store.pick_trait(via_tough, "pow_tough_arms")
	Store.pick_trait(via_tough, "new_trait_3", "pow_tough_arms")
	check(Store.pick_blocker(via_tough, "pow_scramble") == "locked", "Rhythm Hitter taken through Tough Arms does use that fork")
	print("trait_claim_pools: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
