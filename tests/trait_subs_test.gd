extends SceneTree
# Sub-attribute requirements (needs_subs): checked on the athlete's statistic, on top of Attribute thresholds.
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
	check(Store.sub_parent("ball_control") == "accuracy" and Store.sub_parent("resistance") == "endurance" and Store.sub_parent("core_strength") == "endurance" and Store.sub_parent("nope") == "", "Sub-attributes map to their Attribute")
	var cfg := {"accuracy": 90.0, "power": 90.0, "speed": 90.0, "endurance": 90.0, "picks": [], "offsets": {}}
	check(Store.sub_rating(cfg, "ball_control") == 90.0, "No offset: the sub-attribute equals its Attribute")
	cfg["offsets"] = {"accuracy": [-4, 0, 4]}
	check(Store.sub_rating(cfg, "ball_control") == 86.0 and Store.sub_rating(cfg, "stability") == 94.0, "Offsets move it")
	check(book.nodes[book.find("acc_bullet_set")].needs_subs == {"ball_control": 88.0}, "Bullet Set needs Ball Control 88")
	cfg["accuracy"] = 80.0
	cfg["offsets"] = {"accuracy": [-4, 0, 0]}
	for id in ["acc_steady_arms", "acc_safe_hands", "accuracy_back_set", "accuracy_shoot_set"]:
		Store.pick_trait(cfg, id)
	check(cfg.picks.has("accuracy_back_set") and not cfg.picks.has("accuracy_shoot_set"), "Shoot Set is refused at Ball Control 76 (needs 78)")
	cfg["offsets"] = {"accuracy": [0, 0, 0]}
	check(Store.pick_trait(cfg, "accuracy_shoot_set"), "...and taken at 80")
	cfg["offsets"] = {"accuracy": [-4, 0, 0]}
	Store.prune_picks(cfg)
	check(not cfg.picks.has("accuracy_shoot_set") and cfg.picks.has("accuracy_back_set"), "Dropping below the gate prunes it, and only it")
	check("ball control 88" in book.path_subs("acc_bullet_set").keys().map(func(k): return String(k).replace("_", " ") + " " + str(int(book.path_subs("acc_bullet_set")[k]))), "Display shows the requirement")
	print("trait_subs: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
