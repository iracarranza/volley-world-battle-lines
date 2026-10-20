extends SceneTree
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	Store.roster = []
	Store.selected = -1
	Store.forget_trait_book()
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	await process_frame
	menu.draft.power = 80.0
	menu.draft.speed = 70.0
	menu.draft.picks = []
	Store.pick_trait(menu.draft, "new_trait")
	menu.tree_view.show_page("power")
	menu._refresh_traits()
	await process_frame
	var flow_button: Button = menu.tree_view.nodes["new_trait_3"]
	check(flow_button.get_child_count() > 0, "A node with two parents is drawn in two sections")
	check((menu.tree_view.nodes["new_trait"] as Button).get_child_count() == 0, "A single-parent node is not")
	# Only Big Hitter is taken: either section means Big Hitter
	menu.tree_view.hover_node = "new_trait_3"
	menu.tree_view.hover_side = 1
	flow_button.pressed.emit()
	await process_frame
	check(menu.shown_node.via == "new_trait", "With one parent taken, the other section is not a choice")
	# Take Tough Arms too, then choose the second section
	Store.pick_trait(menu.draft, "pow_tough_arms")
	menu._refresh_traits()
	await process_frame
	flow_button = menu.tree_view.nodes["new_trait_3"]
	menu.tree_view.hover_node = "new_trait_3"
	menu.tree_view.hover_side = 1
	flow_button.pressed.emit()
	await process_frame
	check(menu.shown_node.via == "pow_tough_arms", "The hovered section is the parent consumed")
	check(String(menu.shown_node.kept).contains("Platform Quality"), "The panel says what it keeps from that parent (%s)" % String(menu.shown_node.kept))
	check(menu.tree_detail.text.contains("consumes: Tough Arms"), "And names the parent it consumes")
	menu.pick_button.pressed.emit()
	await process_frame
	check(menu.draft.picks.has("new_trait_3") and String(menu.draft.get("via", {}).get("new_trait_3", "")) == "pow_tough_arms", "Claiming it records the chosen side")
	var book = Store.trait_book()
	var current: Array = book.frontier(menu.draft.picks, menu.draft.via)
	check(current.has("new_trait") and not current.has("pow_tough_arms") and current.has("new_trait_3"), "Tough Arms is consumed; Big Hitter keeps its own slot")
	check(Store.capacity_used(menu.draft) == 2, "Two current Traits: Big Hitter and Rhythm Hitter")
	print("trait_split_node: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
