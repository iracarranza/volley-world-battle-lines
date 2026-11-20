extends "res://tests/support/test_case.gd"
## MS-21 (G-15 bug fix): the Serve Receive completion reward restores Stamina up to max_stamina(), not a literal 100.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var lab: Node = load("res://main.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var station = lab.station
	var athlete = lab.athlete
	for rating in [99.0, 50.0]:
		athlete.build.statistics = {"core_strength": rating}
		var cap: float = athlete.max_stamina()
		check((cap > 100.0) if rating > 90.0 else (cap < 100.0), "The test build has max_stamina() %s 100 (%.0f)" % [">" if rating > 90.0 else "<", cap])
		athlete.stamina = cap - 10.0
		station.points = station.GOAL
		station.advance()
		check(is_equal_approx(athlete.stamina, minf(cap, cap - 10.0 + 15.0)), "Completion restores 15 up to max_stamina() (%.0f)" % cap)
		check(athlete.stamina <= cap + 0.0001, "Stamina never exceeds the athlete's own maximum")
	lab.queue_free()
	await process_frame
	print("SERVE RECEIVE CAP: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
