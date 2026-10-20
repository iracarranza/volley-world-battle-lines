extends SceneTree
# What the fork and capacity rules cost, counted on the saved tree: godot --headless --path . --script res://tests/trait_math.gd
var book
var order: Array = []
var total := 0
var by_capacity := {}
var best_picks := 0
var base_total := 0
var base_best := 0
var base_by_page := {}
var counts_over := {6: 0, 8: 0}
func _initialize() -> void:
	call_deferred("run")
func depth(id: String) -> int:
	return book.ancestry(id).size()
func walk(index: int, picks: Array) -> void:
	if index == order.size():
		record(picks)
		return
	var id: String = order[index]
	walk(index + 1, picks)
	for need in book.prereqs(id):
		if not picks.has(need):
			return
	for picked in picks:
		if book.conflicts(id, String(picked)):
			return
	var with := picks.duplicate()
	with.append(id)
	walk(index + 1, with)
func record(picks: Array) -> void:
	total += 1
	var used: int = book.capacity_used(picks)
	by_capacity[used] = int(by_capacity.get(used, 0)) + 1
	best_picks = maxi(best_picks, picks.size())
	for cap in [6, 8]:
		if used <= cap:
			counts_over[cap] += 1
	if book.reach_cost(picks) <= 12 and used <= 6:
		base_total += 1
		base_best = maxi(base_best, picks.size())
func run() -> void:
	var Book = load("res://scripts/trait_book.gd")
	for mode in ["exclusive", "open"]:
		book = Book.new()
		book.load_book()
		book.rules.forks = mode
		order = []
		for n in book.nodes:
			if n.kind != "planned":
				order.append(String(n.id))
		order.sort_custom(func(a, b): return depth(a) < depth(b))
		total = 0
		by_capacity = {}
		best_picks = 0
		base_total = 0
		base_best = 0
		counts_over = {6: 0, 8: 0}
		walk(0, [])
		print("MODE ", mode, ": nodes ", order.size(), " / structurally valid builds ", total, " / most Traits owned ", best_picks)
		print("   within capacity 6: ", counts_over[6], "   within 8: ", counts_over[8])
		print("   at creation (12 AP, capacity 6): builds ", base_total, "   most Traits owned ", base_best)
		var keys := by_capacity.keys()
		keys.sort()
		var line := "   by capacity used:"
		for k in keys:
			line += "  %d:%d" % [k, by_capacity[k]]
		print(line)
	# Per-page path counts under exclusive forks
	book = Book.new()
	book.load_book()
	for key in ["power", "speed", "accuracy", "endurance"]:
		var leaves := 0
		var nodes := 0
		for n in book.page(key):
			if n.kind == "planned":
				continue
			nodes += 1
			var has_child := false
			for m in book.nodes:
				if m.kind != "planned" and (m.parent == n.id or m.get("requires", []).has(n.id)):
					has_child = true
			if not has_child:
				leaves += 1
		print("PAGE ", key, ": ", nodes, " nodes, ", leaves, " ends of a line")
	quit()
