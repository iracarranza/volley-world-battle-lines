extends SceneTree
# Wingspan and Stride Length as bounded, independent, AP-neutral ratios (build.wingspan_ratio / build.stride_ratio), with the absolute span kept.
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
	var h := 1.86
	check(is_equal_approx(Store.span_for_ratio(h, 1.0), h) and is_equal_approx(Store.span_for_ratio(h, 0.8), h * 0.8) and is_equal_approx(Store.span_for_ratio(h, 1.2), h * 1.2), "The wingspan ratio is literal: span = height x ratio, -20% to +20%")
	for r in [0.8, 0.9, 1.0, 1.1, 1.2]:
		check(absf(Store.ratio_for_span(h, Store.span_for_ratio(h, r)) - r) < 0.0001, "ratio_for_span inverts span_for_ratio at %.1f" % r)
	var a: Dictionary = Store.blank()
	check(is_equal_approx(float(a.span), float(a.height)), "A new athlete's span equals its height (ratio 1.0)")
	check(Store.wingspan_ratio(a) == 1.0 and Store.stride_ratio(a) == 1.0 and Store.ap_spent(a) == 0, "A new athlete is neutral and proportions cost no AP")
	Store.set_proportions(a, 1.2, 1.0)
	check(Store.wingspan_ratio(a) == 1.2 and Store.stride_ratio(a) == 1.0, "Raising wingspan leaves stride alone")
	Store.set_proportions(a, 1.2, 1.2)
	check(Store.stride_ratio(a) == 1.2 and Store.wingspan_ratio(a) == 1.2, "Both can be maxed together")
	Store.set_proportions(a, 0.9, 0.9)
	check(Store.wingspan_ratio(a) == 0.9 and Store.stride_ratio(a) == 0.9, "Lowering both is allowed (an economical build)")
	Store.set_proportions(a, 0.5, 2.0)
	check(Store.wingspan_ratio(a) >= 0.8 and Store.stride_ratio(a) <= 1.2, "Values are bounded to 0.8 - 1.2")
	check(is_equal_approx(float(a.span), Store.span_for_ratio(float(a.height), Store.wingspan_ratio(a))), "The absolute span follows the wingspan ratio")
	check(Store.ap_spent(a) == 0, "Still no AP")
	var tall: Dictionary = Store.blank()
	Store.set_proportions(tall, 1.1, 0.9)
	tall.height = 1.95
	Store.refresh_span(tall)
	check(Store.wingspan_ratio(tall) == 1.1 and is_equal_approx(float(tall.span), Store.span_for_ratio(1.95, 1.1)), "Changing height keeps the ratios and re-derives the span")
	# Migration: an old save keeps its absolute span and gets a derived ratio and a neutral stride
	var old := {"height": 1.86, "span": 1.95, "name": "Old", "role": "OH", "body_type": "Feli", "appearance": {}, "power": 65.0, "speed": 65.0, "accuracy": 65.0, "endurance": 65.0, "innates": []}
	var migrated: Dictionary = Store.migrate(old)
	check(float(migrated.span) == 1.95 and is_equal_approx(float(migrated.wingspan_ratio) * 1.86, 1.95) and migrated.stride_ratio == 1.0, "Migration keeps the absolute span, derives the ratio exactly (span = height x ratio), neutral stride")
	check(Store.migrate(migrated).wingspan_ratio == migrated.wingspan_ratio, "Migration is idempotent")
	check(is_equal_approx(Store.stride_metres({"height": 1.86, "stride_ratio": 1.2}), 0.43 * 1.86 * 1.2), "Stride length in metres is the old 0.43 x height scaled by the ratio")
	# Builder
	Store.roster = []
	Store.selected = -1
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	await process_frame
	check(menu.wingspan_slider != null and menu.stride_slider != null and menu.wingspan_slider.min_value == 0.8 and menu.stride_slider.max_value == 1.2, "The builder has both sliders, 0.8 to 1.2")
	menu.wingspan_slider.value = 1.2
	menu.stride_slider.value = 1.2
	check(is_equal_approx(menu.wingspan_slider.value, 1.2) and is_equal_approx(menu.stride_slider.value, 1.2) and menu.stride_label.text.begins_with("1.20"), "Wingspan and stride can both sit at 1.2")
	check(is_equal_approx(float(menu.draft.span), Store.span_for_ratio(float(menu.draft.height), 1.2)) and menu.wingspan_label.text.contains("cm"), "The span in cm is shown and kept in the draft")
	var spent_before: int = Store.ap_spent(menu.draft)
	menu._apply_height(Store.DEFAULT_INCHES + 1)
	check(Store.wingspan_ratio(menu.draft) == 1.2 and Store.ap_spent(menu.draft) >= spent_before, "A height change keeps the ratios")
	print("morphology_sliders: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
