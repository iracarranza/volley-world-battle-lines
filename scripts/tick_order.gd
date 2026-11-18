extends RefCounted
## MS-11 scheduler as a numbered order (SADR-05, SADR-12). The one place the order of the session's physics step is written. The list is EXTRACTED
## from the current code, not designed (G-02: the order is kept; any reorder needs a new decision). `tests/scheduler_order_test.gd` pins that the
## orchestrator calls the stages in this order and that the statements inside the stages keep the documented first-token order.
## Each stage: n (number), name, call (the stage function of LabSession, or "inline" for the clock lines), tokens (first tokens of its statements, in order).
const PHYSICS := [
	{"n": 1, "name": "pause_gate", "call": "_tick_pause", "tokens": ["directional_input.clear()", "hud.update()"]},
	{"n": 2, "name": "clock", "call": "inline", "tokens": ["moc.clock_record().actor(\"player\")", "elapsed += world_dt"]},
	{"n": 3, "name": "pre_motion", "call": "_tick_pre_motion", "tokens": ["auto_preparation.tick(world_dt", "contact_flow.tick(world_dt)", "ground_balls.tick(self,world_dt)", "serve.tick_toss_charge(world_dt)"]},
	{"n": 4, "name": "bench_gate", "call": "_tick_bench_gate", "tokens": ["_check_bench()", "_tick_benched(world_dt)"]},
	{"n": 5, "name": "player", "call": "_tick_player", "tokens": ["block_state.tick(dt)", "motion.tick(dt, motion_scale)", "athlete_touches_net(previous_player_position,player.position)", "camera_rig.update_aim()", "animation.update()"]},
	{"n": 6, "name": "activities", "call": "_tick_activities", "tokens": ["station.tick(world_dt)", "drills.tick(world_dt)", "_remember_contacts(dt)"]},
	{"n": 7, "name": "ball_or_feed", "call": "_tick_ball_or_feed", "tokens": ["_tick_ball(world_dt)"]},
	{"n": 8, "name": "idle_actors", "call": "_tick_idle_actors", "tokens": ["training_bots.tick_motion(world_dt)"]},
	{"n": 9, "name": "confirm_window", "call": "_tick_confirm_window", "tokens": ["PlayerLifecycle.set_window(self, maxf(0, confirm_window - dt))", "and _can_contact():\n\t\t\t_contact()"]},
	{"n": 10, "name": "present", "call": "_tick_present", "tokens": ["_check_bench()", "_update_preview(false)", "hud.update()"]},
]
## Line budgets (SADR-05 consequence: the lab was cut from 2,572 to 1,513 lines and regrew before). Growth past a budget is a decision, not a fix.
const LINE_BUDGETS := {"res://scripts/contact_lab.gd": 1600, "res://scripts/map_lab.gd": 260, "res://scripts/drill_lab.gd": 60}
## The orchestrator itself stays a list of calls.
const ORCHESTRATOR_BUDGET_LINES := 30

static func calls() -> Array:
	var out := []
	for stage in PHYSICS:
		if stage.call != "inline": out.append(stage.call)
	return out
