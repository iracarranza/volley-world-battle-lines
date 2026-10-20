extends SceneTree
# Merged nodes (Trickster): both sources needed, claiming consumes both into one Trait.
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
	var cfg := {"accuracy": 99.0, "power": 99.0, "speed": 99.0, "endurance": 99.0, "picks": []}
	var tr := "acc_trickster"
	check(book.merges_of(tr) == ["acc_broad_range", "acc_anticipation"], "Trickster merges both")
	check(book.choice_parents(tr).is_empty(), "A merged node has no choice of parent")
	check(not Store.pick_trait(cfg, tr), "Trickster is refused with neither")
	Store.pick_trait(cfg, "acc_broad_range")
	check(Store.pick_blocker(cfg, tr) == "needs", "...and with only Broad Range")
	Store.pick_trait(cfg, "acc_anticipation")
	check(Store.pick_trait(cfg, tr), "Trickster is taken with both")
	check(book.frontier(cfg.picks, cfg.get("via", {})) == [tr], "Both are consumed into one current Trait")
	check(Store.capacity_used(cfg) == 1, "One slot")
	check(book.conflicts(tr, "acc_one_handed_set") and book.conflicts(tr, "acc_anticipation_2"), "Trickster rules out both standard lines")
	check(not book.conflicts("acc_broad_range", "acc_anticipation"), "The two sources do not conflict")
	check(book.unmet("acc_dump", cfg.picks).size() >= 1, "Dump needs Back Set")
	check(book.parents_of("acc_dump") == ["accuracy_back_set"] and book.nodes[book.find("acc_dump")].requires == ["acc_trickster"], "Dump branches off Back Set and needs Trickster")
	Store.unpick_trait(cfg, "acc_broad_range")
	check(not cfg.picks.has(tr), "Dropping a source drops Trickster")
	print("trait_merge: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
