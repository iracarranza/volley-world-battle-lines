extends SceneTree
## Writes every catalogue scenario's trace as JSON into the directory given after `--` (`--out <dir>`). Used by tools/dual_run.py to
## compare two builds; not a suite (no _test suffix).
const C := preload("res://tests/support/characterization.gd")
const S := preload("res://tests/support/scenarios.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	for index in range(args.size() - 1):
		if args[index] == "--out": out = args[index + 1]
	if out == "":
		push_error("usage: --script res://tests/dump_scenarios.gd -- --out <dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	for name in S.CATALOGUE:
		var result: Dictionary = await S.run(self, name)
		var file := FileAccess.open("%s/%s.json" % [out, name], FileAccess.WRITE)
		file.store_string(JSON.stringify(C.norm({"trace": result.trace, "facts": result.facts}), "\t", true) + "\n")
	quit(0)
