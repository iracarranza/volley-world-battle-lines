extends "res://tests/support/test_case.gd"
## MS-05 catalogue coverage lint: every scenario has a golden file and a pin (where it covers a BDR), every BDR entry in the register has a pin
## function, every register scenario id S-01..S-20 is in the catalogue, and the register names the real pin tests. No Godot session needed.
const C := preload("res://tests/support/characterization.gd")
const S := preload("res://tests/support/scenarios.gd")
const Pins := preload("res://tests/support/bdr_pins.gd")
const REGISTER := "res://docs/architecture-migration/behavioural-divergence-register.md"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var names: Array = S.CATALOGUE.keys()
	var on_disk := []
	for file in DirAccess.get_files_at(C.GOLDEN_DIR):
		if file.ends_with(".json") and file != "writer_ratchet.json": on_disk.append(file.trim_suffix(".json"))
	on_disk.sort()
	var expected := names.duplicate()
	expected.sort()
	check(on_disk == expected, "Golden files and the catalogue agree (%s vs %s)" % [on_disk, expected])
	for index in range(1, 21):
		check(names.any(func(n): return String(n).begins_with("s%02d_" % index)), "The catalogue has a scenario for S-%02d" % index)
	var register := FileAccess.get_file_as_string(REGISTER)
	for entry in range(1, 21):
		var id := "BDR-%02d" % entry
		check(Pins.COVERAGE.has(id), "%s has pin coverage" % id)
		for scenario in Pins.COVERAGE.get(id, []):
			check(scenario in names, "%s: scenario %s is in the catalogue" % [id, scenario])
			check(Callable(Pins, "pin_" + scenario).is_valid(), "%s: pin function for %s exists" % [id, scenario])
		# The register row names the pin harness, not a placeholder.
		var row := ""
		for line in register.split("\n"):
			if line.begins_with("| %s |" % id): row = line
		check(row != "" and row.contains("bdr_pins.gd") and not row.contains("placeholder"), "%s: the register row names its pin (bdr_pins.gd)" % id)
	check(register.contains("tests/golden/README.md"), "The register documents the golden-trace procedure")
	print("CATALOGUE COVERAGE: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
