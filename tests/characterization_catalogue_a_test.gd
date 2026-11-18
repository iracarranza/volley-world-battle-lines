extends "res://tests/support/test_case.gd"
## MS-05 catalogue shard A: S-01..S-04 (spend order, same-step order, ledger table, slowdown). See catalogue_runner.gd.
const Runner := preload("res://tests/support/catalogue_runner.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	await Runner.shard(self, "A", ["s01", "s02", "s03", "s04"])
	quit(1 if failures else 0)
