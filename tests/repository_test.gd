extends "res://tests/support/test_case.gd"
## MS-13 repository hardening: honest save result, atomic replace with last-good kept, corrupt and newer-schema files never destroyed.
const Store := preload("res://scripts/athlete_store.gd")

func _initialize() -> void: call_deferred("run")

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func run() -> void:
	var dir := "user://repo_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var original: String = Store.save_path
	Store.save_path = dir + "/athletes.json"
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(Store.save_path + suffix): DirAccess.remove_absolute(Store.save_path + suffix)
	# Good save, then a second save keeps the first as the last-good file.
	Store.roster = [Store.blank()]
	Store.selected = 0
	var r: Dictionary = Store.save_roster()
	check(r.ok and r.error == "", "A save reports success")
	check(not FileAccess.file_exists(Store.save_path + ".tmp"), "No temp file is left behind")
	var first := FileAccess.get_file_as_string(Store.save_path)
	check(JSON.parse_string(first).schema == Store.SCHEMA, "The file carries its schema number")
	Store.save_roster()
	check(FileAccess.file_exists(Store.save_path + ".bak") and FileAccess.get_file_as_string(Store.save_path + ".bak") == first, "The previous file is kept as .bak")
	Store.load_roster()
	check(Store.load_state == "ok" and Store.roster.size() == 1 and Store.selected == 0, "Round trip")
	# Unwritable location: the result says so.
	var good: String = Store.save_path
	Store.save_path = "user://no_such_dir_ms13/athletes.json"
	r = Store.save_roster()
	check(not r.ok and r.error != "", "An unwritable location reports failure (never 'Saved')")
	Store.save_path = good
	# Corrupt file: kept aside, then replaced by a save.
	_write(Store.save_path, "{not json")
	Store.load_roster()
	check(Store.load_state == "corrupt" and Store.roster.is_empty(), "A corrupt file loads as empty and is flagged")
	Store.roster = [Store.blank()]
	Store.save_roster()
	check(FileAccess.file_exists(Store.save_path + ".corrupt") and FileAccess.get_file_as_string(Store.save_path + ".corrupt") == "{not json", "The corrupt file is kept aside")
	# Newer schema: never overwritten.
	var newer := JSON.stringify({"schema": Store.SCHEMA + 1, "athletes": [], "selected": -1})
	_write(Store.save_path, newer)
	Store.load_roster()
	check(Store.load_state == "newer_schema", "A newer schema is detected")
	Store.roster = [Store.blank()]
	r = Store.save_roster()
	check(not r.ok and FileAccess.get_file_as_string(Store.save_path) == newer, "A newer-schema file is left untouched")
	# Legacy file without a schema number loads.
	_write(Store.save_path, JSON.stringify({"athletes": [], "selected": -1}))
	Store.load_roster()
	check(Store.load_state == "ok", "A legacy file (no schema key) loads")
	Store.save_path = original
	Store.roster = []
	Store.selected = -1
	print("REPOSITORY: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
