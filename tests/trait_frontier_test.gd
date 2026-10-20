extends "res://tests/support/test_case.gd"
const Book = preload("res://scripts/trait_book.gd")

func _initialize() -> void:
	var book = Book.new()
	for spec in [
		{"id": "a"}, {"id": "b"}, {"id": "next", "parent": "a"},
		{"id": "choice", "parent": "a", "alt_parents": ["b"]},
		{"id": "merge", "merges": ["a", "b"]},
		{"id": "needs", "requires": ["a"]},
		{"id": "self", "parent": "self"},
	]:
		book.nodes.append(Book._clean(spec))
	check(book.frontier([]) == [], "No picks have no current traits")
	check(book.frontier(["missing", "a"]) == ["a"], "Missing IDs are ignored")
	check(book.frontier(["next", "a", "b"]) == ["next", "b"], "Successor consumes its parent; output keeps pick order")
	check(book.frontier(["a", "a", "b"]) == ["a", "a", "b"], "Frontier preserves existing duplicate handling")
	check(book.frontier(["a", "needs"]) == ["a", "needs"], "Required traits are not consumed")
	check(book.frontier(["a", "b", "choice"], {"choice": "b"}) == ["a", "choice"], "Alternative consumes the chosen parent")
	check(book.frontier(["a", "b", "choice"]) == ["b", "choice"], "Alternative defaults to first owned parent")
	check(book.frontier(["a", "merge"]) == ["a", "merge"], "Incomplete merge consumes neither source")
	check(book.frontier(["b", "merge", "a"]) == ["merge"], "Complete merge consumes both sources regardless of order")
	check(book.frontier(["self"]) == ["self"], "Malformed self-parent does not consume itself")
	print("trait_frontier: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
