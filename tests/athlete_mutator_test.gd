extends "res://tests/support/test_case.gd"
## MS-09: the athlete mutators and the single Flow store. Every row of the status machine goes through a mutator, and no file outside the
## athlete writes Stamina, HP or the player's Flow field except through them (the source scan is the lint half of the writer ratchet).
func _initialize() -> void: call_deferred("run")

static func scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"): out.append(dir + "/" + file)
	for sub in DirAccess.get_directories_at(dir): out.append_array(scripts(dir + "/" + sub))
	return out

func run() -> void:
	var a := LabAthlete.new()
	a.refill()
	check(a.stamina == a.max_stamina() and a.hp == 100.0, "refill fills Stamina and HP")
	# Winded entry: depletion while fresh, Flow cleared, epoch advanced, Stamina half.
	a.set_flow(60.0)
	var epoch := a.fatigue_epoch
	a.spend_resolved(a.max_stamina())
	check(a.winded and not a.exhausted and a.flow == 0.0 and a.fatigue_epoch == epoch + 1 and is_equal_approx(a.stamina, a.max_stamina() * 0.5), "Winded entry clears Flow, bumps the epoch, halves Stamina")
	# Repeated costs at zero are not a second depletion; exhausted entry from Winded.
	a.set_flow(40.0)
	a.spend_resolved(a.max_stamina())
	check(a.exhausted and not a.winded and a.flow == 0.0 and a.fatigue_epoch == epoch + 2 and is_equal_approx(a.exhaustion_remaining, 7.0), "Second depletion while Winded exhausts and clears Flow")
	var e2 := a.fatigue_epoch
	a.spend_resolved(10.0)
	check(a.fatigue_epoch == e2, "A cost at zero is not another depletion")
	# Exhausted expiry re-enters Winded and clears Flow.
	a.set_flow(30.0)
	a.recover(7.1, true)
	check(not a.exhausted and a.winded and a.flow == 0.0 and a.fatigue_epoch == e2 + 1, "Exhausted expiry re-enters Winded and clears Flow")
	# restore and heal: capped adds; explicit cap argument.
	a.refill()
	a.stamina = 10.0
	a.restore(15.0)
	check(is_equal_approx(a.stamina, 25.0), "restore adds Stamina")
	a.restore(1000.0)
	check(a.stamina == a.max_stamina(), "restore caps at max_stamina()")
	a.stamina = 95.0
	a.restore(15.0, 100.0)
	check(a.stamina == minf(100.0, 110.0), "restore honours an explicit cap (the Serve Receive literal 100, G-15)")
	a.hp = 90.0
	a.heal(20.0)
	check(a.hp == 100.0, "heal caps at 100")
	a.add_stamina(0.0)
	# Flow mutators.
	a.set_flow(70.0)
	a.award_flow(50.0, 100.0)
	check(a.flow == 100.0, "award_flow caps")
	a.lose_flow()
	check(a.flow == 0.0, "lose_flow clears")
	# Second Wind: cooldown path through the mutator for modifiers.
	a.add_modifier("probe", {"stats": {"speed": 3.0}, "duration": 1.0})
	check(a.modifiers.entries.has("probe"), "add_modifier registers the modifier")
	# Lint: outside the athlete, Stamina and HP are written only inside the athlete's mutators.
	var pattern := RegEx.new()
	pattern.compile("\\.(stamina|hp)\\s*(=|\\+=|-=|\\*=)[^=]")
	var offenders := []
	for path in scripts("res://scripts"):
		if path.ends_with("/athlete.gd"): continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].strip_edges()
			if code.begins_with("#"): continue
			if pattern.search(code) != null: offenders.append("%s:%d" % [path, i + 1])
	check(offenders.is_empty(), "No outside writer of .stamina or .hp (%s)" % [offenders])
	# One Flow store, direction resolved (PRB-13): the player's amount is the athlete field; values["player"] is a write-only shadow kept for trace parity.
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.athlete.set_flow(33.0)
	lab.contact_flow.values["player"] = 5.0
	check(lab.contact_flow.amount("player") == 33.0, "amount(player) reads the athlete field, not the store shadow")
	lab.contact_flow.set_amount("player", 20.0)
	check(lab.athlete.flow == 20.0 and lab.contact_flow.values["player"] == 20.0, "set_amount writes the field through the mutator and the shadow")
	lab.queue_free()
	await process_frame
	print("ATHLETE MUTATORS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
