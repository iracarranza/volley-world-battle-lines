extends SceneTree
## CPU microbenchmark; run through tools/test.py. Not a frame/GPU benchmark.
const Book = preload("res://scripts/trait_book.gd")

func _initialize() -> void:
	var book = Book.new()
	book.load_book()
	var cases := [
		[],
		["acc_broad_range", "acc_anticipation", "acc_trickster"],
		["new_trait", "new_trait_3", "pow_heavy_arm", "pow_sledgehammer", "pow_terminal_hitter"],
	]
	# Include an editor-sized selection to expose repeated traversal costs.
	var all_ids := []
	for node in book.nodes:
		all_ids.append(String(node.id))
	cases.append(all_ids)
	var results := []
	for picks in cases:
		var samples := []
		for repeat in range(5):
			var start := Time.get_ticks_usec()
			for iteration in range(100):
				book.frontier(picks)
			samples.append((Time.get_ticks_usec() - start) / 100.0)
		results.append({"picks": picks.size(), "microseconds_per_call": samples, "frontier": book.frontier(picks)})
	var file := FileAccess.open("res://artifacts/trait-frontier-profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print(JSON.stringify(results))
	quit()
