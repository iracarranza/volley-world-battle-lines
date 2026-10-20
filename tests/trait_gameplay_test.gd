extends SceneTree
# The tree's side of docs/gameplay-runtime-contract.md: rules are stored, validated and aggregated for current Traits only.
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	Store.forget_trait_book()
	var book = Store.trait_book()
	check(book.all_problems().is_empty(), "Every node is valid, including its gameplay rules: %s" % str(book.all_problems()))
	var ids := {}
	for n in book.nodes:
		ids[n.name] = n.id
	var cfg := {"power": 99.0, "speed": 99.0, "accuracy": 99.0, "endurance": 99.0, "picks": []}
	Store.pick_trait(cfg, ids["Big Hitter"])
	check(book.active_gameplay_rules(cfg.picks, {}).is_empty(), "A Trait with no rules yields none")
	Store.pick_trait(cfg, ids["Rhythm Hitter"])
	var rules: Array = book.active_gameplay_rules(cfg.picks, cfg.get("via", {}))
	check(rules.size() == 1 and rules[0].id == "rhythm-release" and rules[0].threshold == 100 and rules[0].consume == "all", "Rhythm Hitter releases at Flow 100, consuming all")
	Store.pick_trait(cfg, ids["Heavy Arm"])
	rules = book.active_gameplay_rules(cfg.picks, cfg.get("via", {}))
	check(rules.size() == 1 and rules[0].id == "rhythm-release", "A successor restates the rule; the consumed one is not summed")
	var fx: Dictionary = book.active_effects(cfg.picks, cfg.get("via", {}))
	check(float(fx.get("swing_power_band", 0)) == 1.0 and float(fx.get("swing_power_band_cap", 0)) == 3.0, "Heavy Arm: Swing Power one band up, capped at T3")
	var bass: Dictionary = book.nodes[book.find(ids["Drop the Bass"])].gameplay[0]
	check(bass.consume == 80 and bass.pending.jump.jump_power == 5 and bass.pending.attack.spike_velocity == 12, "Drop the Bass matches the contract's receive spender")
	var merged := {"power": 99.0, "speed": 99.0, "accuracy": 99.0, "endurance": 99.0, "picks": []}
	for id in ["acc_broad_range", "acc_anticipation", "acc_trickster"]:
		Store.pick_trait(merged, id)
	rules = book.active_gameplay_rules(merged.picks, {})
	check(rules.size() == 1 and rules[0].id == "anticipation", "Trickster's merged Flow rule appears once")
	var bad: Dictionary = book.nodes[book.find("acc_anticipation")].duplicate(true)
	bad.gameplay = [{"id": "x", "trigger": "nonsense", "effects": {"not_a_key": 1}}]
	var problems: Array = book.problems(bad)
	check(problems.size() >= 2, "An unknown trigger and an unclaimed effect key are flagged")
	var used := {}
	for n in book.nodes:
		for k in n.effects:
			used[k] = true
		for src in n.get("carried", {}):
			for k in n.carried[src]:
				used[k] = true
	var unclaimed := []
	for k in used:
		if not book.GAMEPLAY_KEYS.has(k):
			unclaimed.append(k)
	check(unclaimed == ["spin"], "The only effect key the runtime does not claim is spin: %s" % str(unclaimed))
	print("trait_gameplay: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
