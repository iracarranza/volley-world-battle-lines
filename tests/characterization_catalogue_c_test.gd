extends "res://tests/support/test_case.gd"
## MS-05 catalogue shard C: S-13..S-20 (recovery, Exhausted expiry, custody, Auto clock, previews, Bench, left-handed bot, seeded rally).
const Runner := preload("res://tests/support/catalogue_runner.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	await Runner.shard(self, "C", ["s13", "s14", "s15", "s16", "s17", "s18", "s19", "s20"])
	quit(1 if failures else 0)
