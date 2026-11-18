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

func run() -> void:
	var lab_source := FileAccess.get_file_as_string("res://scripts/contact_lab.gd")
	check_order(body_of(lab_source, "func _physics_process(dt: float)"), TICK, "_physics_process")
	check_order(body_of(lab_source, "func _tick_ball(dt: float)"), BALL, "_tick_ball")
	# The ordinary player attempt is after _tick_ball; the swept Block is inside it, before net response and bots (FC-02).
	var tick := body_of(lab_source, "func _physics_process(dt: float)")
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
