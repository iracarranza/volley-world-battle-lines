extends "res://tests/support/test_case.gd"
const Row := preload("res://scripts/drill_row.gd")
func _initialize() -> void: call_deferred("run")

func settle(lab: Node3D, at: Vector3, frames: int = 12) -> void:
	lab.player.velocity = Vector3.ZERO
	lab.player.position = at
	for i in range(frames): await physics_frame

func run() -> void:
	var lab = load("res://drill_lab.tscn").instantiate()
	root.add_child(lab)
	lab.auto_feed = false
	lab.moc.enabled = false
	await physics_frame
	var row = lab.activities
	check(row.by_name.size() == 8, "Eight drills are lined up")
	var xs: Array = []
	for index in range(Row.NAMES.size()):
		var node: Node3D = row.by_name[Row.NAMES[index]]
		var at: float = node.anchor.x if "anchor" in node and node.anchor != Vector3.ZERO else Row.slot_x(index)
		xs.append(at)
	var increasing := true
	for i in range(1, xs.size()): increasing = increasing and float(xs[i]) > float(xs[i - 1])
	check(increasing, "The drills run west to east in order")
	check(lab.inventory.enabled and is_instance_valid(lab.ball_carts), "The ball economy and bins are on")

	# Workouts: each needs no ball, and a completion rewards XP and counts toward its sub-attribute.
	for key in ["inclined_obstacles", "salmon_ladder", "weighted_balancing"]:
		var drill = row.by_name[key]
		lab._reset()
		lab.inventory.held = false
		await settle(lab, drill.anchor + Vector3(0, 0.03, 2.5))
		row.select_nearby()
		check(lab.drills == drill and drill.in_zone(), "%s selected from its start" % key)
		drill.interact()
		check(drill.running() and not drill.holding_ball(), "%s starts without a ball" % key)
		var before_xp: int = drill.earned_xp
		var before: float = float(lab.athlete.build.get("workout_counts", {}).get(drill.subattribute, 0))
		if key == "weighted_balancing":
			await settle(lab, Vector3(drill.anchor.x, drill.BEAM_TOP + 0.02, drill.anchor.z - 2.6))
			check(drill.on_beam, "Standing on the beam registers")
			await settle(lab, Vector3(drill.anchor.x, drill.BEAM_TOP + 0.02, drill.anchor.z - 2.0 - drill.BEAM_LENGTH + 0.4), 2)
		else:
			for i in range(drill.step_tops.size()):
				var top: Vector3 = drill.step_tops[i]
				await settle(lab, top + Vector3(0, 0.03, 0), 12)
				if i < drill.step_tops.size() - 1:
					check(drill.steps_done == i + 1, "%s landing %d counts" % [key, i + 1])
		check(drill.phase == drill.Phase.COOLDOWN and drill.earned_xp > before_xp, "%s completes and pays XP" % key)
		var after: float = float(lab.athlete.build.get("workout_counts", {}).get(drill.subattribute, 0))
		check(after != before or drill.last_progress.get("gained", false), "%s counts toward %s" % [key, drill.subattribute])
		drill.interact()
		check(not drill.running(), "%s rests for 30 s after completion" % key)
		drill.tick_setup(31.0)
		check(drill.phase == drill.Phase.READY, "%s reactivates after the rest" % key)

	# Leaving the area abandons a run; no reward.
	var ladder = row.by_name["salmon_ladder"]
	lab._reset()
	await settle(lab, ladder.anchor + Vector3(0, 0.03, 2.5))
	row.select_nearby()
	ladder.interact()
	var xp_before: int = ladder.earned_xp
	await settle(lab, ladder.anchor + Vector3(30, 0.03, 0))
	check(not ladder.running() and ladder.earned_xp == xp_before, "Leaving the area abandons the run")

	# Balance Ball Setting is a Setup: it wants a ball.
	var ball_drill = row.by_name["balance_ball_setting"]
	lab._reset()
	lab.inventory.held = false
	await settle(lab, ball_drill.anchor + Vector3(0.0, 0.03, 0.0))
	row.select_nearby()
	check(lab.drills == ball_drill, "Balance Ball Setting selected on its pad")
	ball_drill.interact()
	check(not ball_drill.running(), "Setup will not start without a ball")
	lab.inventory.give()
	ball_drill.interact()
	check(ball_drill.running() and lab.inventory.held == false, "Setup takes the ball to start")
	var start: Vector3 = lab.player.position
	for i in range(30):
		ball_drill.tick(1.0 / 60.0)
	check(lab.player.position.distance_to(start) > 0.001, "The balance ball wobbles the player")
	check(ball_drill.wobble_amplitude() > 0.0, "Wobble scales with Stability")
	var placement_before: float = lab.athlete.trait_effect("placement")
	for rep in range(ball_drill.distributor.min_reps):
		ball_drill._spike_used(true, "player", "")
	check(lab.athlete.trait_effect("placement") == placement_before + 1.0, "A completed Balance Ball Setting grants Placement access")
	check(float(lab.athlete.build.drill_auxiliaries.get("court_vision", 0.0)) == 0.0, "It grants nothing else")
	var transition = row.by_name["transition_set"]
	lab._reset()
	lab.inventory.give()
	await settle(lab, transition.anchor + Vector3(0, 0.03, 0))
	row.select_nearby()
	transition.interact()
	for rep in range(transition.distributor.min_reps):
		transition._spike_used(true, "player", "")
	check(lab.athlete.trait_effect("court_vision") == 1.0, "A completed Transition Set grants Court Vision access")

	# Sub-attribute growth gets harder with the band.
	var Progress = load("res://scripts/workout_progress.gd")
	check(Progress.needed(50.0) < Progress.needed(85.0) and Progress.needed(85.0) < Progress.needed(99.0), "Higher bands need more completions per point")
	var build: Dictionary = lab.athlete.build
	build["statistics"] = {"explosiveness": 60.0}
	build["workout_counts"] = {}
	var gained := false
	for i in range(Progress.needed(60.0)):
		gained = bool(Progress.record(lab.athlete, "explosiveness").gained)
	check(gained and float(build.statistics.explosiveness) == 61.0 and int(build.workout_counts.explosiveness) == 0, "Enough completions raise the sub-attribute by one and restart the count")
	lab.queue_free()
	await process_frame
	print("DRILL LAB: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
