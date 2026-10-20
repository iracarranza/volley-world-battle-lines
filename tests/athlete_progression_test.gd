extends SceneTree
# Debug progression: levels, position growth, Net-fall AP, and the builder's debug panel.
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
	var oh: Dictionary = Store.blank()
	oh.role = "OH"
	Store.level_up(oh, 9)
	check(int(oh.level) == 10 and int(oh.power) == 74 and int(oh.endurance) == 74, "All-Rounder: +1 to every attribute per level (level 10 = 74)")
	check(Store.ap_spent(oh) == 0 and Store.ap_budget(oh) == 12, "Growth is free: no AP spent, budget unchanged without a base AP per level")
	var mb: Dictionary = Store.blank()
	mb.role = "MB"
	Store.set_level(mb, 20)
	check(int(mb.level) == 20 and int(mb.endurance) == 99 and int(mb.power) == 65, "Wall reaches END 99 by the level cap, other attributes untouched")
	check(int(mb.growth.endurance) == 34, "Growth records only what was applied (34, capped at 99)")
	var op: Dictionary = Store.blank()
	op.role = "OP"
	Store.set_level(op, 20)
	check(Store.ap_budget(op) == 12 + 57, "Rising Star: +3 AP on each of 19 level-ups")
	check(Store.level_up(op).levels == 0, "No level past the cap")
	check(Store.rating_cap(op) == 99 and Store.rating_cap(Store.blank()) == Store.MAX_RATING, "Progressed athletes can allocate to 99; creation stays at 77")
	check(Store.net_award("primary").total == 2 and Store.net_award("tertiary").total == 4, "Global Net awards 2 / 3 / 4")
	check(Store.net_award("primary", 1, true).total == 2 + 6 and Store.net_award("secondary", 3).total == 3 + 2, "Local shares: double the value (+2 first Net) split evenly, rounded down")
	var team: Dictionary = Store.blank()
	check(Store.simulate_match(team) == 19 and Store.ap_budget(team) == 12 + 19, "A full winning match is 19 global AP")
	team.power = 77.0
	team.speed = 77.0
	team.accuracy = 74.0
	check(Store.ap_spent(team) == 12 + 12 + 9, "Spending the earned AP is counted against the larger budget")
	Store.reset_progression(team)
	check(Store.ap_budget(team) == 12 and int(team.level) == 1 and Store.ap_spent(team) <= 12, "Reset returns to a creation athlete, trimmed to 12 AP")
	var s_player: Dictionary = Store.blank()
	s_player.role = "S"
	Store.level_up(s_player, 5)
	check(Store.rating_floor(s_player, "accuracy") == 75 and int(s_player.accuracy) == 75, "Free growth cannot be lowered away")
	# The builder's panel
	Store.roster = []
	Store.selected = -1
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	await process_frame
	menu.draft.role = "OP"
	check(not menu.debug_box.visible, "Debug controls start hidden")
	menu.debug_check.button_pressed = true
	check(menu.debug_box.visible, "...and show when switched on")
	menu._debug_level(10)
	check(int(menu.draft.level) == 10 and menu._free_points() == 12 + 27, "Level 10 as an Opposite: 27 more free AP in the builder")
	menu.debug_net_kind.select(2)
	menu._debug_net()
	check(Store.ap_budget(menu.draft) == 12 + 27 + 4, "A Tertiary Net adds 4")
	menu._debug_match()
	check(menu.debug_readout.text.contains("Level 10"), "The readout reports the level")
	menu._debug_reset()
	check(int(menu.draft.level) == 1 and menu._free_points() <= 12, "Reset in the builder returns to level 1")
	print("athlete_progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
