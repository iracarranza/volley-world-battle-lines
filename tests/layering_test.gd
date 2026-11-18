extends "res://tests/support/test_case.gd"
## MS-11 layering lint (SADR-05; file 09 section 2.1): data, pure rules, state, orchestration, presentation, tools. Calls go downward only: a file
## may not name (preload or load by path) a file of a higher layer. Only statically visible references are checked (a duck-typed `lab` argument is
## not a reference); the existing upward references are registered exceptions below and may only shrink. A new upward reference fails.
const L1 := 1  # pure rules
const L2 := 2  # state
const L3 := 3  # orchestration
const L4 := 4  # presentation
const LAYERS := {
	"contact_execution": L1, "contact_geometry": L1, "contact/contact_resolver": L1, "receive_charge": L1, "directional_influence": L1, "approach_run": L1,
	"dive_recovery": L1, "floor_recovery": L1, "net_response": L1, "rally_rules": L1, "contact/ball_state": L1, "gameplay_rules": L1, "contact_intent": L1, "auto_charge": L1,
	"athlete": L2, "live_ball": L2, "rally_ledger": L2, "ball_lease": L2, "ball_custody": L2, "player_lifecycle": L2, "player_locks": L2, "block_state": L2,
	"receive_plant": L2, "gameplay_modifiers": L2, "action_timeline": L2,
	"contact_lab": L3, "map_lab": L3, "drill_lab": L3, "contact_commit": L3, "training_bots": L3, "pepper_partners": L3, "interactive_serve": L3, "map_activities": L3,
	"map_drills": L3, "bench_status": L3, "moment_of_contact": L3, "serve_receive_station": L3, "contact_flow": L3, "tick_order": L3,
	"lab/athlete_animation": L4, "athlete_hud": L4, "lab/lab_hud": L4, "impact_visual": L4, "athlete_pose": L4, "pose_smoother": L4, "bot_animation": L4,
}
## Registered upward references at the baseline measurement (file -> referenced files): the orchestrators name presentation types they construct or
## read (impact visual, pose library, bot animation). `contact/ball_state` is a value type read by the resolver, classed with the pure rules.
## The list may shrink and never grow; an entry removed from the code must be removed here.
const EXCEPTIONS := {
	"contact_lab": ["athlete_pose", "impact_visual"],
	"training_bots": ["bot_animation"],
	"pepper_partners": ["bot_animation", "athlete_pose"],
	"bench_status": ["athlete_pose"],
}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var reference := RegEx.new()
	reference.compile("res://scripts/([\\w/]+)\\.gd")
	var found := {}
	for name in LAYERS:
		var path: String = "res://scripts/%s.gd" % name
		check(FileAccess.file_exists(path), "%s exists (the layer table names real files)" % name)
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges().begins_with("#"): continue
			for match in reference.search_all(line):
				var target: String = match.get_string(1)
				if LAYERS.has(target) and LAYERS[target] > LAYERS[name]:
					found[name] = found.get(name, []) + [target]
	for name in found:
		for target in found[name]:
			check(EXCEPTIONS.get(name, []).has(target), "Upward reference: %s (layer %d) names %s (layer %d)" % [name, LAYERS[name], target, LAYERS[target]])
	for name in EXCEPTIONS:
		for target in EXCEPTIONS[name]:
			check(found.get(name, []).has(target), "Registered exception %s -> %s is still present (remove it when it is gone)" % [name, target])
	# Self-test: the matcher sees a reference and the layer order is strict.
	check(reference.search("const X := preload(\"res://scripts/contact_lab.gd\")") != null and L1 < L2 and L2 < L3 and L3 < L4, "Self-test: references match and the layers are ordered")
	print("LAYERING: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
