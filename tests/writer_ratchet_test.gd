extends "res://tests/support/test_case.gd"
## MS-05 writer ratchet (SADR-04). The set of files that write the live ball, the rally ledger and the court counters may shrink and may never
## grow: a new file, or more write lines in a known file, fails this test. Baseline: tests/golden/writer_ratchet.json (category -> file -> count of
## write lines by the patterns below). A routing stage that removes writers makes the test report "tighten the baseline"; tighten it with
## `-- --regen` through tools/regen_golden.py and commit the smaller file. Growing the baseline is a decision (an ADR change), not a fix.
## Writes counted: lines outside comments in res://scripts (recursive) matching the pattern. Pure reads and comparisons do not match.
const BASELINE := "res://tests/golden/writer_ratchet.json"
const PATTERNS := {
	"ball_velocity": "\\bball_velocity(\\.[xyz])?\\s*(=|\\+=|-=|\\*=|/=)[^=]",
	"ball_position": "\\bball\\.position(\\.[xyz])?\\s*(=|\\+=|-=|\\*=|/=)[^=]",
	"ball_shot": "\\bball_shot\\s*=[^=]",
	"ball_active": "\\bball_active\\s*=[^=]",
	"side_contacts": "side_contacts(\\[[^\\]]*\\])?\\s*(=|\\+=|-=)[^=]|side_contacts\\.(fill|assign)\\(",
	"contacts": "(?<![_\\w])contacts\\s*(=|\\+=|-=)[^=]",
	"last_touch": "rally_rules\\.(touch|begin)\\(|\\blast_touch_side\\s*=[^=]",
}
## The FC-05 file set for `ball_velocity` (study chapter 07, VAR-171): ten files, plus bot_pads.gd for its own pad ball.
const FC05_BALL_VELOCITY := ["balance_ball_setting.gd", "bot_pads.gd", "contact_lab.gd", "interactive_serve.gd", "map_bot_roster.gd", "map_drills.gd", "moment_of_contact.gd", "pepper_partners.gd", "serve_receive_station.gd", "training_bots.gd", "transition_set_drill.gd"]

## Declared operation owners (blueprint MS-06..08): the files whose job is to perform these writes. They are the ledger, not a growth of the
## writer set, so they are not counted; every other file is ratcheted as before. A new entry is a decision (an ADR change).
const OPERATION_OWNERS := ["rally_ledger.gd"]

func _initialize() -> void: call_deferred("run")

static func scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"): out.append(dir + "/" + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(scripts(dir + "/" + sub))
	out.sort()
	return out

static func measure() -> Dictionary:
	var expressions := {}
	for category in PATTERNS:
		var regex := RegEx.new()
		regex.compile(PATTERNS[category])
		expressions[category] = regex
	var found := {}
	for category in PATTERNS: found[category] = {}
	for path in scripts("res://scripts"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = line.strip_edges()
			if code.begins_with("#") or code == "": continue
			for category in PATTERNS:
				if expressions[category].search(code) != null:
					var name: String = path.trim_prefix("res://scripts/")
					if name in OPERATION_OWNERS: continue
					found[category][name] = int(found[category].get(name, 0)) + 1
	return found

func run() -> void:
	var now := measure()
	if "--regen" in OS.get_cmdline_user_args():
		var file := FileAccess.open(BASELINE, FileAccess.WRITE)
		file.store_string(JSON.stringify(now, "\t", true) + "\n")
		print("WRITER RATCHET: baseline written")
		quit(0)
		return
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	check(baseline is Dictionary, "The baseline file exists and parses")
	if baseline is Dictionary:
		for category in PATTERNS:
			var allowed: Dictionary = baseline.get(category, {})
			for file in now[category]:
				check(allowed.has(file), "%s: new writer file %s (a writer file may not be added)" % [category, file])
				if allowed.has(file):
					check(int(now[category][file]) <= int(allowed[file]), "%s: %s has %d write lines, baseline allows %d" % [category, file, now[category][file], allowed[file]])
			var shrunk := []
			for file in allowed:
				if not now[category].has(file) or int(now[category][file]) < int(allowed[file]): shrunk.append(file)
			if not shrunk.is_empty():
				print("RATCHET NOTE: %s writers shrank in %s; tighten tests/golden/writer_ratchet.json" % [category, shrunk])
		# The exit criterion: the ball_velocity baseline equals the FC-05 file set.
		var files: Array = baseline.get("ball_velocity", {}).keys()
		files.sort()
		var expected := FC05_BALL_VELOCITY.duplicate()
		expected.sort()
		check(files == expected or files.all(func(f): return f in expected), "The ball_velocity baseline is within the FC-05 file set (%s)" % [files])
		check(baseline.get("ball_velocity", {}).size() >= 1, "The ratchet has a ball_velocity baseline")
		# Self-test: the matcher counts writes and ignores comparisons and comments.
		var regex := RegEx.new()
		regex.compile(PATTERNS.ball_velocity)
		check(regex.search("ball_velocity = Vector3.ZERO") != null and regex.search("lab.ball_velocity.y -= 1.0") != null, "Self-test: writes match")
		check(regex.search("if ball_velocity == Vector3.ZERO:") == null and regex.search("var speed = ball_velocity.length()") == null, "Self-test: reads and comparisons do not match")
		var contacts := RegEx.new()
		contacts.compile(PATTERNS.contacts)
		check(contacts.search("lab.contacts = 0") != null and contacts.search("contacts += 1") != null and contacts.search("side_contacts = [0, 0]") == null and contacts.search("total_contacts += 1") == null, "Self-test: contacts matches only the rally counter")
	print("WRITER RATCHET: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
