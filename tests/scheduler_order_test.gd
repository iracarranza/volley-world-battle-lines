extends "res://tests/support/test_case.gd"
## MS-05 step 6 / SADR-05: the one-tick trace of the session scheduler. Each statement of the physics step, in its CURRENT order, is pinned by its
## first token (the same technique as event_contract_test's publish order), plus the two subclass re-entries (map_lab and drill_lab call
## super._physics_process after their own activity ticks). Reordering any pair is a gameplay change (G-02: order is kept) and fails here.
## Runtime order evidence for the same-step pairs is in the catalogue's S-02 scenarios (bot before ordinary player; swept Block first).
const TICK := ["auto_preparation.tick(world_dt", "contact_flow.tick(world_dt)", "ground_balls.tick(self,world_dt)", "serve.tick_toss_charge(world_dt)", "_check_bench()",
	"block_state.tick(dt)", "motion.tick(dt, motion_scale)", "athlete_touches_net(previous_player_position,player.position)", "camera_rig.update_aim()", "animation.update()",
	"station.tick(world_dt)", "drills.tick(world_dt)", "_remember_contacts(dt)", "_tick_ball(world_dt)", "training_bots.tick_motion(world_dt)",
	"PlayerLifecycle.set_window(self, maxf(0, confirm_window - dt))", "and _can_contact():\n\t\t\t_contact()", "_update_preview(false)", "hud.update()"]
## Ball integration step: statement order inside _tick_ball.
const BALL := ["dt *= moc.clock_record().ball()", "LiveBall.integrate(self, dt)", "serve.tick(dt, previous)", "pepper.try_start(previous)", "pepper.tick(world_dt)",
	"drills.sweep_ball(previous,dt)", "_try_swept_player_block(previous, dt)", "resolve_ball_net(previous,dt)", "OUTSIDE-ANTENNA FAULT", "UNDER-NET FAULT",
	"contact_flow.net_cross()", "training_bots.tick(world_dt)", "intersect_ray(query)", "if ball.position.y <= 0.105:"]

func _initialize() -> void: call_deferred("run")

func body_of(source: String, signature: String) -> String:
	var start := source.find(signature)
	var end := source.find("\nfunc ", start + 10)
	return source.substr(start, end - start if end > 0 else -1)

func check_order(body: String, tokens: Array, label: String) -> void:
	var previous := -1
	for token in tokens:
		var index := body.find(token, previous + 1)
		check(index > previous, "%s: '%s' keeps its documented place" % [label, String(token).replace("\n", " ")])
		if index > previous: previous = index

## The physics step region: the orchestrator and the numbered stage functions that follow it, up to the next unrelated function.
func tick_region(source: String) -> String:
	var start := source.find("func _physics_process(dt: float)")
	return source.substr(start, source.find("func is_benched()", start) - start)

func run() -> void:
	var lab_source := FileAccess.get_file_as_string("res://scripts/contact_lab.gd")
	var region := tick_region(lab_source)
	check_order(region, TICK, "_physics_process")
	# MS-11: the numbered list (scripts/tick_order.gd) equals the order the orchestrator calls its stages, and each stage's statements keep their order.
	var order = load("res://scripts/tick_order.gd")
	var orchestrator := body_of(lab_source, "func _physics_process(dt: float)")
	check_order(orchestrator, order.calls().map(func(c): return c + "("), "orchestrator calls")
	var numbers: Array = order.PHYSICS.map(func(stage): return stage.n)
	var expected := range(1, order.PHYSICS.size() + 1)
	check(numbers == expected, "The stages are numbered 1..%d without gaps" % order.PHYSICS.size())
	var stage_text := ""
	for stage in order.PHYSICS:
		if stage.call == "inline":
			var inline_ok := true
			for token in stage.tokens: inline_ok = inline_ok and orchestrator.contains(token)
			check(inline_ok, "Stage %d %s: the inline statements are in the orchestrator" % [stage.n, stage.name])
			continue
		var body := body_of(lab_source, "func %s(" % stage.call)
		check(body != "", "Stage %d %s: %s exists" % [stage.n, stage.name, stage.call])
		check_order(body, stage.tokens, "stage %d %s" % [stage.n, stage.name])
		check(lab_source.find("func %s(" % stage.call) > lab_source.find("func _physics_process(dt: float)"), "Stage %d is laid out after the orchestrator" % stage.n)
	var last := -1
	for stage in order.PHYSICS:
		if stage.call == "inline": continue
		var at := lab_source.find("func %s(" % stage.call)
		check(at > last, "Stage %d %s is laid out in numbered order" % [stage.n, stage.name])
		last = at
	check(orchestrator.count("\n") <= order.ORCHESTRATOR_BUDGET_LINES, "The orchestrator stays a list of calls (%d lines)" % orchestrator.count("\n"))
	for path in order.LINE_BUDGETS:
		var lines := FileAccess.get_file_as_string(path).count("\n")
		check(lines <= order.LINE_BUDGETS[path], "%s stays within its line budget (%d of %d)" % [path.get_file(), lines, order.LINE_BUDGETS[path]])
	check_order(body_of(lab_source, "func _tick_ball(dt: float)"), BALL, "_tick_ball")
	# The ordinary player attempt is after _tick_ball; the swept Block is inside it, before net response and bots (FC-02).
	var tick := region
	check(tick.find("_tick_ball(world_dt)") < tick.find("and _can_contact():"), "The ordinary player contact attempt follows the ball step")
	var ball := body_of(lab_source, "func _tick_ball(dt: float)")
	check(ball.find("_try_swept_player_block") < ball.find("resolve_ball_net") and ball.find("pepper.tick(world_dt)") < ball.find("_try_swept_player_block"), "Pepper runs before the swept Block, which runs before net response")
	check(ball.find("resolve_ball_net") < ball.find("training_bots.tick(world_dt)"), "Net response precedes court bots")
	# Subclass re-entry: both lab variants run their own ticks and then re-enter the base step.
	for path in ["res://scripts/map_lab.gd", "res://scripts/drill_lab.gd"]:
		var body := body_of(FileAccess.get_file_as_string(path), "func _physics_process(dt: float)")
		check(body.contains("activities.tick(dt)") and body.contains("ball_carts.tick(dt)") and body.find("ball_carts.tick(dt)") < body.find("super._physics_process(dt)"), "%s ticks activities and carts, then re-enters super._physics_process" % path.get_file())
	check(FileAccess.get_file_as_string("res://scripts/map_lab.gd").contains("select_net(nearest_primary_net())"), "map_lab selects the nearest net before the base step")
	print("SCHEDULER ORDER: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
