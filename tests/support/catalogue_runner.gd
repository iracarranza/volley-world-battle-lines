extends RefCounted
## Runs a shard of the scenario catalogue: first run -> BDR pins and golden trace; second run -> dual-run comparison with the first.
const C := preload("res://tests/support/characterization.gd")
const S := preload("res://tests/support/scenarios.gd")
const Pins := preload("res://tests/support/bdr_pins.gd")

static func shard(suite: SceneTree, label: String, prefixes: Array) -> void:
	var regen := C.regen_requested()
	var count := 0
	for name in S.CATALOGUE:
		if not prefixes.any(func(p): return String(name).begins_with(p)): continue
		count += 1
		var first: Dictionary = await S.run(suite, name)
		var packed: Dictionary = C.norm({"trace": first.trace, "facts": first.facts})
		if not regen:
			suite.check(Pins.pin(suite, name, packed.facts) or not Pins.COVERAGE.values().any(func(list): return name in list), "%s: a BDR pin function exists" % name)
		var second: Dictionary = await S.run(suite, name)
		var repeat: Dictionary = C.norm({"trace": second.trace, "facts": second.facts})
		var self_diff := C.diff(packed, repeat)
		suite.check(self_diff.is_empty(), "%s: two fresh seeded runs agree (%d differences, first %s)" % [name, self_diff.size(), self_diff.slice(0, 3)])
		if regen:
			suite.check(C.save_golden(name, packed), "%s: golden written" % name)
			continue
		var golden: Variant = C.load_golden(name)
		suite.check(golden != null, "%s: golden trace exists (regenerate per tests/golden/README.md)" % name)
		if golden != null:
			var golden_diff := C.diff(golden, packed)
			suite.check(golden_diff.is_empty(), "%s: trace equals the recorded golden (%d differences, first %s)" % [name, golden_diff.size(), golden_diff.slice(0, 3)])
	print("CATALOGUE %s: %d / %d passed (%d scenarios%s)" % [label, suite.checks - suite.failures, suite.checks, count, ", GOLDEN REGENERATED" if regen else ""])
