extends "res://tests/support/test_case.gd"
## MS-05 catalogue shard B: S-05..S-12 (DI, delivery, plant, grounded Attack, match scope, Attack volume, endlag, event.charge).
const Runner := preload("res://tests/support/catalogue_runner.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	await Runner.shard(self, "B", ["s05", "s06", "s07", "s08", "s09", "s10", "s11", "s12"])
	quit(1 if failures else 0)
