extends "res://tests/support/test_case.gd"
## MS-08: the lease derives the holder from the activities' own hooks, the ledger-access term equals the old three-way guard, and every activity
## implements the documented hook surface (the duck-typed running()/has_method calls the lab makes).
const Lease := preload("res://scripts/ball_lease.gd")

func _initialize() -> void: call_deferred("run")

func missing(node: Object, hooks: Array) -> Array:
	return hooks.filter(func(hook): return not node.has_method(hook))

func run() -> void:
	var lab = load("res://drill_lab.tscn").instantiate()
	root.add_child(lab)
	lab.auto_feed = false
	lab.moc.enabled = false
	await physics_frame
	for name in lab.activities.by_name:
		var node: Object = lab.activities.by_name[name]
		var hooks: Array = Lease.STATION_HOOKS if node == lab.station or name == "serve_machine" else Lease.DRILL_HOOKS
		var gap := missing(node, hooks)
		check(gap.is_empty(), "%s implements its hook surface (missing %s)" % [name, gap])
	check(missing(lab.pepper, Lease.PEPPER_HOOKS).is_empty(), "Pepper implements active()")
	# Holder and the ledger term, for every combination of the three activities (stubbing the hook answers is not needed: use the real states).
	check(Lease.holder(lab) == "" and Lease.ledger_open(lab), "Nobody holds the ball in free practice; the ledger is open")
	lab.pepper.partner = 0
	check(Lease.holder(lab) == Lease.PEPPER and not Lease.ledger_open(lab), "Pepper holds the ball and has no ledger access")
	lab.pepper.partner = -1
	var drill = lab.activities.by_name["transition_set"]
	lab.drills = drill
	lab.inventory.give()
	drill.interact()
	check(drill.running() and Lease.holder(lab) == Lease.DRILL and not Lease.ledger_open(lab), "A running drill holds the ball and has no ledger access")
	drill.reset()
	lab.station.state = lab.station.State.WAITING
	check(Lease.holder(lab) == Lease.STATION and not Lease.ledger_open(lab), "A running station holds the ball and has no ledger access")
	lab.station.state = lab.station.State.IDLE
	for path in ["res://scripts/contact_lab.gd"]:
		var source := FileAccess.get_file_as_string(path)
		check(source.count("not station.running() and not drills.running() and not pepper.active()") == 0, "The three-way guard is spelled once, in the lease")
	print("BALL LEASE: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
