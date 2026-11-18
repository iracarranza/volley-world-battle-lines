extends "res://tests/support/test_case.gd"
## MS-08: the custody record. Balls are conserved from cart to hand to live ball to ground, and the registered leaks are reproduced, not fixed.
const Custody := preload("res://scripts/ball_custody.gd")
const Charge := preload("res://scripts/receive_charge.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var start: int = Custody.total(lab)
	check(Custody.census(lab).carts == lab.ball_carts.total_balls() and Custody.census(lab).carts > 0 and Custody.census(lab).ground == 0, "At the start the carts hold balls and none is loose")
	# cart -> hand: taking a ball moves one, total unchanged.
	var index: int = lab.ball_carts.nearest_with_ball(lab.player.position)
	var taken: bool = lab.ball_carts.take_nearby(lab.ball_carts.carts[maxi(index, 0)].position) if index >= 0 else false
	if taken:
		lab.inventory.held = true
		check(Custody.total(lab) == start, "Taking a ball from a cart keeps the total (cart to hand)")
	# hand -> live -> ground: conserved while at most three are loose.
	lab.inventory.held = false
	lab.ball_active = false
	lab.ground_balls.land(lab, Vector3(0, 0, 3), Vector3(0, -3, 2), Charge.shot("receive", 0.5, "test"))
	check(Custody.census(lab).ground == 1, "A landed ball is a loose ground ball")
	for point in range(1, 3):
		lab.ground_balls.land(lab, Vector3(point, 0, 3), Vector3(0, -3, 2), Charge.shot("receive", 0.5, "test"))
	var three: int = Custody.census(lab).ground
	check(three == 3, "Three loose balls are kept")
	# Registered leak GROUND_EVICTION: the fourth landing evicts the oldest; no cart gets it back.
	var carts_before: int = Custody.census(lab).carts
	lab.ground_balls.land(lab, Vector3(5, 0, 3), Vector3(0, -3, 2), Charge.shot("receive", 0.5, "test"))
	check(Custody.census(lab).ground == 3 and Custody.census(lab).carts == carts_before, "%s: the fourth ball evicts the oldest with no cart return" % Custody.GROUND_EVICTION)
	# Registered leak BENCH_KEEPS_HAND.
	lab.inventory.held = true
	lab.ball_active = true
	lab.athlete.exhausted = true
	lab.player.position = lab.court_center + Vector3(0, 0.03, 5)
	lab._check_bench()
	check(lab.is_benched() and lab.inventory.held and Custody.census(lab).hand == 1, "%s: the Bench keeps the held ball" % Custody.BENCH_KEEPS_HAND)
	lab.bench.clear()
	lab.athlete.exhausted = false
	# Registered leak TEAM_EMPTY: no caller reads it.
	var readers := 0
	for path in preload("res://tests/support/scenarios.gd").all_scripts("res://scripts"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.strip_edges()
			if code.contains("team_empty(") and not code.begins_with("#") and not code.begins_with("func "):
				readers += 1
	check(readers == 0, "%s: no reader of team_empty (%d)" % [Custody.TEAM_EMPTY, readers])
	check(Custody.REGISTERED_LEAKS.size() == 3, "Three leaks are registered (G-15 keeps the economy unchanged)")
	print("BALL CUSTODY: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
