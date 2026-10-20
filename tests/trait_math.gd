extends SceneTree
# What the fork, start and capacity rules leave open, counted on the saved tree, for a given AP budget:
#   godot --headless --path . --script res://tests/trait_math.gd -- 12 24
var book
var order: Array = []
var budget := 12
var total := 0
var within := 0
var best_picks := 0
var best_frontier := 0
var by_page := {}
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
	if book.reach_cost(with) > budget:
		return
	walk(index + 1, with)
func record(picks: Array) -> void:
	total += 1
	var used: int = book.capacity_used(picks)
	if used <= 6:
		within += 1
	best_picks = maxi(best_picks, picks.size())
	best_frontier = maxi(best_frontier, book.frontier(picks).size())
func run() -> void:
	var Book = load("res://scripts/trait_book.gd")
	var budgets := []
	for a in OS.get_cmdline_user_args():
		budgets.append(int(a))
	if budgets.is_empty():
		budgets = [12]
	for b in budgets:
		budget = b
		book = Book.new()
		book.load_book()
		order = []
		for n in book.nodes:
			if n.kind != "planned":
				order.append(String(n.id))
		order.sort_custom(func(x, y): return depth(x) < depth(y))
		total = 0
		within = 0
		best_picks = 0
		best_frontier = 0
		walk(0, [])
		print("BUDGET ", budget, " AP: ", order.size(), " nodes / valid builds ", total, " / within capacity 6: ", within, " / most Traits owned ", best_picks, " / most current Traits ", best_frontier)
	quit()
