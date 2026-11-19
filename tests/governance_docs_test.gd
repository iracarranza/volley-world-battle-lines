extends "res://tests/support/test_case.gd"
## Document lint for the architecture-migration governance documents (MS-01).
## Every FC id cited by a divergence entry is defined; every entry has a citation, a pin placeholder and a gate or "none".
const DOCS := "res://docs/architecture-migration/"

func _initialize() -> void:
	call_deferred("run")

func _read(name: String) -> String:
	var file := FileAccess.open(DOCS + name, FileAccess.READ)
	return file.get_as_text() if file else ""

func _cells(line: String) -> PackedStringArray:
	var cells := PackedStringArray()
	for cell in line.split("|"):
		cells.append(cell.strip_edges())
	return cells

func run() -> void:
	var text := _read("behavioural-divergence-register.md")
	check(text != "", "The divergence register exists")
	var defined := {}
	var entries: Array = []
	for line in text.split("\n"):
		if line.begins_with("| FC-"):
			defined[_cells(line)[1]] = true
		elif line.begins_with("| BDR-"):
			entries.append(_cells(line))
	check(not defined.is_empty(), "The register defines its FC facts")
	check(entries.size() >= 20, "Every verified divergence has an entry")
	var seen := {}
	var fc_pattern := RegEx.create_from_string("FC-\\d+")
	for cells in entries:
		var id: String = cells[1]
		check(not seen.has(id), "%s is unique" % id)
		seen[id] = true
		check(cells.size() >= 10, "%s has every column" % id)
		if cells.size() < 10:
			continue
		for match in fc_pattern.search_all(cells[2]):
			check(defined.has(match.get_string()), "%s cites a defined FC id (%s)" % [id, match.get_string()])
		check(cells[4] != "", "%s has a citation" % id)
		check(cells[6] in ["CURRENT-reproduced", "CHANGED", "GATED", "DESIGNER-APPROVED-AS-IS"], "%s has a valid status" % id)
		check(cells[7] != "", "%s names a pin test or its placeholder" % id)
		check(cells[8].begins_with("G-") or cells[8] == "none", "%s names a gate or 'none'" % id)
	var registry := _read("event-field-registry.md")
	check(registry.contains("input_charge") and registry.contains("delivered_pressure"), "The registry documents both senses of event.charge")
	var unenforced := _read("unenforced-state-register.md")
	for name in ["action_endlag", "preview_velocity", "team_empty", "Winded-bar"]:
		check(unenforced.contains(name), "The unenforced-state register lists %s" % name)
	var vocabulary := _read("vocabulary.md")
	check(vocabulary.contains("LiveBall") and vocabulary.contains("shot metadata"), "The vocabulary separates BallState from LiveBall")
	print("GOVERNANCE DOCS: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
