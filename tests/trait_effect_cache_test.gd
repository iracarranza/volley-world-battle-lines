extends "res://tests/support/test_case.gd"
const Athlete = preload("res://scripts/athlete.gd")
const Book = preload("res://scripts/trait_book.gd")
const Store = preload("res://scripts/athlete_store.gd")

func fixture() -> RefCounted:
	var book = Book.new()
	for spec in [
		{"id": "a", "effects": {"recovery": 10}},
		{"id": "b", "effects": {"recovery": 20}},
		{"id": "next", "parent": "a", "alt_parents": ["b"],
			"effects": {"recovery": 3}, "carried": {"a": {"recovery": 4}, "b": {"recovery": 8}}},
	]:
		book.nodes.append(Book._clean(spec))
	return book

func _initialize() -> void:
	var original = Store._book
	Store._book = fixture()
	var athlete = Athlete.new()
	check(athlete.trait_effect("recovery") == 0, "Empty picks have no effect")
	athlete.trait_ids.append("a")
	check(athlete.trait_effect("recovery") == 10, "In-place append invalidates cached effects")
	athlete.trait_ids.append("b")
	check(athlete.trait_effect("recovery") == 30, "Multiple current traits contribute")
	athlete.trait_ids.append("next")
	athlete.trait_via["next"] = "a"
	check(athlete.trait_effect("recovery") == 27, "Consumed a is replaced by carried total")
	athlete.trait_via["next"] = "b"
	check(athlete.trait_effect("recovery") == 21, "In-place via edit changes consumed source")
	athlete.trait_via.clear()
	check(athlete.trait_effect("recovery") == 27, "Removing via restores default source")
	athlete.trait_ids.assign(["a"])
	check(athlete.trait_effect("recovery") == 10, "In-place array replacement removes old effects")
	Store._book = fixture()
	Store._book.nodes[0].effects.recovery = 12
	check(athlete.trait_effect("recovery") == 12, "Book identity change invalidates the cache")
	check(athlete.trait_effect("unsupported_effect") == 0, "Unsupported effect remains inert")
	check(athlete.trait_effect("recovery") == 12, "Repeated reads preserve value")
	athlete.trait_ids.clear()
	check(athlete.trait_effect("recovery") == 0, "Clearing picks removes cached effects")
	Store._book = original
	print("trait_effect_cache: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
