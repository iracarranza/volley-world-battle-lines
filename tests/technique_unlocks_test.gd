extends "res://tests/support/test_case.gd"
## MS-14: the technique-unlock table matches the four ids the code gated by literal before, every trait id is in the tree, readers use the table, and the
## key lists are one list with a reader for every legal key.
const Unlocks := preload("res://scripts/technique_unlocks.gd")
const Registry := preload("res://scripts/contact/mechanic_registry.gd")
const Book := preload("res://scripts/trait_book.gd")

func _initialize() -> void: call_deferred("run")

func _source(path: String) -> String:
	return FileAccess.get_file_as_string("res://scripts/" + path)

func run() -> void:
	var expected := {"back_set": "accuracy_back_set", "float_serve": "acc_float_serve", "rolling_receive": "endurance_rolling_receive", "quick_step": "speed_quick_step"}
	check(Unlocks.TABLE.size() == 4, "Four id-gated techniques")
	var tree_text := FileAccess.get_file_as_string("res://data/trait_tree.json")
	for technique in expected:
		check(Unlocks.trait_for(technique) == expected[technique], "%s unlocks with %s (unchanged)" % [technique, expected[technique]])
		check(tree_text.contains("\"%s\"" % expected[technique]), "%s is a trait in the tree" % expected[technique])
		var owner_source := _source(String(Unlocks.TABLE[technique].owner))
		check(owner_source.contains("TechniqueUnlocks"), "%s reads the table" % Unlocks.TABLE[technique].owner)
		check(not owner_source.contains("\"%s\"" % expected[technique]), "%s has no literal for %s" % [Unlocks.TABLE[technique].owner, expected[technique]])
	# One key list, and each key has registered metadata and a reader outside the registry and the trait book.
	check(Book.GAMEPLAY_KEYS == Registry.EFFECT_KEYS, "TraitBook.GAMEPLAY_KEYS is the registry list")
	var seen := {}
	for key in Registry.EFFECT_KEYS:
		check(not seen.has(key), "%s is listed once" % key)
		seen[key] = true
		check(Registry.registered(key), "%s has registry metadata" % key)
	var corpus := ""
	var dir := DirAccess.open("res://scripts")
	var stack := ["res://scripts"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and not f.ends_with("mechanic_registry.gd") and not f.ends_with("trait_book.gd"):
				corpus += FileAccess.get_file_as_string(d + "/" + f)
		for sub in DirAccess.get_directories_at(d): stack.append(d + "/" + sub)
	var no_reader := []
	for key in Registry.EFFECT_KEYS:
		if not corpus.contains("\"%s\"" % key): no_reader.append(key)
	for key in no_reader:
		check(Registry.READER_SITES.has(key), "%s has a declared reader site" % key)
	for key in Registry.READER_SITES:
		check(no_reader.has(key), "READER_SITES entry %s is still needed (remove it once a reader names the key)" % key)
	print("TECHNIQUE UNLOCKS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
