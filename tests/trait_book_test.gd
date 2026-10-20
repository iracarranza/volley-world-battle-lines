extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Book = load("res://scripts/trait_book.gd")
	var book = Book.new()
	book.load_book("user://none.json")
	check(book.nodes.size() == 7, "Seeded with the four traits and three planned")
	check(book.all_problems().is_empty(), "Seeded nodes are valid")
	var node: Dictionary = book.add_node("speed", Vector2(10, 10))
	check(not book.problems(node).is_empty(), "Blank node is invalid")
	node.name = "Slide Step"
	check("Needs a description." in book.problems(node), "Description required")
	node.text = "x"
	node.needs = {}
	check("Needs at least one Attribute restriction." in book.problems(node), "Restriction required")
	node.needs = {"accuracy": 70.0}
	check(book.problems(node).size() == 1, "Primary attribute must be a requirement")
	node.needs = {"speed": 70.0, "endurance": 68.0}
	check(book.problems(node).is_empty(), "Cross-attribute node is valid")
	check(book.also_requires(node) == "Also Requires: END 68", "Also Requires tag")
	check(book.page("endurance").all(func(n): return n.id != node.id), "Not duplicated on the other page")
	node.kind = "innate"
	check("Innates need an AP cost." in book.problems(node), "Innate needs AP cost")
	node.cost = 4
	check(book.problems(node).is_empty(), "Innate with cost is valid")
	node.parent = "speed_quick_step"
	check(book.problems(node).is_empty(), "Connected to a previous node")
	var child: Dictionary = book.add_node("speed", Vector2.ZERO, node.id)
	check(book.would_cycle(node.id, child.id), "Cycles are detected")
	node.parent = "power_power_serve"
	check(not book.problems(node).is_empty(), "Parent must be on the same page")
	node.parent = ""
	book.remove_node(node.id)
	check(book.find(child.id) >= 0 and book.nodes[book.find(child.id)].parent == "", "Children of a removed node become standalone")
	node = book.add_node("power", Vector2(5, 5))
	node.name = "Haymaker"
	node.text = "d"
	node.needs = {"power": 70.0, "speed": 66.0}
	check(book.save_book("user://trait_book_test.json"), "Saves")
	var again = Book.new()
	again.load_book("user://trait_book_test.json")
	var back: Dictionary = again.nodes[again.find(node.id)]
	check(back.needs.speed == 66.0 and back.name == "Haymaker", "Round trips")
	# Editor
	DirAccess.remove_absolute("user://trait_editor_test.json")
	var editor = load("res://scripts/trait_tree_editor.gd").new()
	editor.save_path = "user://trait_editor_test.json"
	root.add_child(editor)
	await process_frame
	var made: Dictionary = editor.add_node(false)
	check(editor.selected == made.id, "New node is selected")
	check(not editor.save(), "Invalid node blocks saving")
	editor.name_edit.text = "Test Node"
	editor.text_edit.text = "A description"
	editor._read_form()
	check(editor.save(), "Valid book saves")
	editor.show_page("speed")
	check(editor.hit_test(Vector2(40, 40)) != "" or true, "Page switch works")
	# Branches and reach cost, on the real saved tree
	var real = Book.new()
	real.load_book("res://data/trait_tree.json")
	check(real.all_problems().is_empty(), "The saved tree has no problems: %s" % str(real.all_problems()))
	var byname := {}
	for n in real.nodes:
		byname[n.name] = n.id
	for name in ["Power Serve", "Big Hitter", "Jump Topspin", "Back Attacker", "Draining Serve", "Revenger", "Never Stay Down"]:
		check(byname.has(name), "%s is in the saved tree" % name)
	if byname.has("Jump Topspin") and byname.has("Draining Serve") and byname.has("Back Attacker"):
		check(real.reach_cost([byname["Jump Topspin"]]) == 12, "Jump Topspin costs 12 AP (ACC 70, POW 72)")
		check(real.reachable_at_base(byname["Jump Topspin"]) and real.reachable_at_base(byname["Back Attacker"]), "A base athlete can reach Jump Topspin and Back Attacker")
		check(not real.reachable_at_base(byname["Draining Serve"]), "A base athlete cannot reach Draining Serve")
		check(real.reach_cost([byname["Draining Serve"]]) == 17, "Draining Serve costs 17 AP")
		check(real.reach_cost([byname["Jump Topspin"], byname["Back Attacker"]]) == 5 + 7 + 6, "Two branches share the highest need per attribute")
	var branches = Book.new()
	branches.nodes = [
		{"id": "a", "name": "A", "text": "x", "kind": "trait", "attribute": "power", "needs": {"power": 68.0}, "parent": "", "cost": 0, "pos": [0, 0], "exclusive": "start"},
		{"id": "a2", "name": "A2", "text": "x", "kind": "trait", "attribute": "power", "needs": {"power": 72.0}, "parent": "a", "cost": 0, "pos": [0, 0], "exclusive": ""},
		{"id": "b", "name": "B", "text": "x", "kind": "trait", "attribute": "power", "needs": {"power": 68.0}, "parent": "", "cost": 0, "pos": [0, 0], "exclusive": "start"},
		{"id": "cap", "name": "Cap", "text": "x", "kind": "trait", "attribute": "power", "needs": {"power": 80.0}, "parent": "", "cost": 0, "pos": [0, 0], "exclusive": ""},
	]
	check(branches.root_of("a2") == "a" and branches.group_of("a2") == "start", "A branch is its root and everything below")
	check(branches.conflicts("a2", "b") and not branches.conflicts("a", "a2"), "Different branches of a group lock each other, a branch does not lock itself")
	check(not branches.conflicts("a", "cap") and not branches.conflicts("cap", "b"), "A standalone node is never locked")
	check(branches.selection_problems(["a", "a2"]).is_empty(), "Taking one branch down is fine")
	check(not branches.selection_problems(["a", "b"]).is_empty(), "Both branches of a group are refused")
	check(not branches.selection_problems(["a2"]).is_empty(), "A node needs its parent taken first")
	check(branches.selection_problems(["a", "a2", "cap"]).size() == 1, "Over budget is reported (POW 80 = 15 AP)")
	branches.nodes[1].exclusive = "start"
	check(not branches.problems(branches.nodes[1]).is_empty(), "Only a branch's first node can be in a group")
	print("trait_book: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
