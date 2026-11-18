extends "res://tests/support/test_case.gd"
## The tuning index (docs/architecture-migration/tuning-index.md) equals the code, constant by constant.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var file := FileAccess.open("res://docs/architecture-migration/tuning-index.md", FileAccess.READ)
	check(file != null, "The tuning index exists")
	var rows := 0
	for line in file.get_as_text().split("\n"):
		if not line.begins_with("| ") or ".gd |" not in line:
			continue
		var cells := PackedStringArray()
		for cell in line.split("|"):
			cells.append(cell.strip_edges())
		var script: GDScript = load("res://scripts/" + cells[1])
		check(script != null, "%s loads" % cells[1])
		if script == null:
			continue
		var constants := script.get_script_constant_map()
		check(constants.has(cells[2]), "%s declares %s" % [cells[1], cells[2]])
		if constants.has(cells[2]):
			check(is_equal_approx(float(constants[cells[2]]), float(cells[3])), "%s.%s equals the documented %s" % [cells[1], cells[2], cells[3]])
		rows += 1
	check(rows >= 20, "The index covers the shared timing constants (%d rows)" % rows)
	var settings := preload("res://scripts/session_settings.gd")
	var execution := preload("res://scripts/contact_execution.gd")
	check(is_equal_approx(settings.shared.spike_windup_seconds, 0.25) and settings.shared.spike_windup_enabled, "The shared settings instance holds the documented windup defaults")
	execution.spike_windup_seconds = 0.5
	check(is_equal_approx(settings.shared.spike_windup_seconds, 0.5), "The Execution static writes through the one shared instance")
	settings.shared.spike_windup_seconds = 0.25
	check(is_equal_approx(execution.spike_windup_seconds, 0.25), "A write on the shared instance is seen by every Execution reader")
	print("TUNING INDEX: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
