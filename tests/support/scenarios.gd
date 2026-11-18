extends RefCounted
## MS-05 scenario catalogue (blueprint 3.1). Each scenario builds a fresh session, drives it with scripted calls (no wall-clock, seeded
## where random), and returns {"trace": [...], "facts": {...}}. `trace` is the consequence ledger (golden-comparable); `facts` is a small
## dictionary of named observations that the BDR pin tests assert on directly. Scenarios CURRENT behaviour, quirks included.
const C := preload("res://tests/support/characterization.gd")
const Recorder := preload("res://tests/support/recorder.gd")
const Charge := preload("res://scripts/receive_charge.gd")
const SEED := 1234
const INCOMING := Vector3(0, -3, 20)

## name -> method. Every scenario takes (tree) and is awaited.
const CATALOGUE := {
	"s01_depleted_player": "s01_player", "s01_depleted_bot": "s01_bot", "s01_depleted_pepper": "s01_pepper", "s01_depleted_serve": "s01_serve",
	"s02_receive_both": "s02_receive_both", "s02_receive_bot_only": "s02_receive_bot_only", "s02_receive_player_only": "s02_receive_player_only",
	"s02_block_both": "s02_block_both", "s02_repeat_gate_player": "s02_repeat_gate_player", "s02_repeat_gate_bot": "s02_repeat_gate_bot",
	"s03_ledger_table": "s03_ledger_table", "s04_slowdown": "s04_slowdown", "s05_di_by_mode": "s05_di_by_mode",
	"s06_delivery_by_actor": "s06_delivery_by_actor", "s07_plant_timeline": "s07_plant_timeline", "s08_grounded_attack": "s08_grounded_attack",
	"s09_match_scope": "s09_match_scope", "s10_attack_volume": "s10_attack_volume", "s11_endlag": "s11_endlag",
	"s12_charge_senses": "s12_charge_senses", "s13_recovery": "s13_recovery", "s14_exhausted_expiry": "s14_exhausted_expiry",
	"s15_custody": "s15_custody", "s16_auto_clock": "s16_auto_clock", "s17_preview": "s17_preview", "s18_bench_window": "s18_bench_window",
	"s19_left_handed_bot": "s19_left_handed_bot", "s20_seeded_rally": "s20_seeded_rally",
}

static func run(tree: SceneTree, name: String) -> Dictionary:
	return await Callable(load("res://tests/support/scenarios.gd"), CATALOGUE[name]).call(tree)

static func listener_state(lab: Node, actor: String) -> Dictionary:
	var athlete = lab.athlete
	var flow: float = lab.contact_flow.amount("player") if actor == "player" else float(lab.contact_flow.values.get(actor, 0.0))
	if actor != "player" and actor.begins_with("training_bot_"):
		athlete = lab.training_bots.athlete_for(int(actor.trim_prefix("training_bot_")))
	elif actor.begins_with("pepper_"):
		athlete = lab.pepper.athlete_for(int(actor.trim_prefix("pepper_")))
	return {"stamina": athlete.stamina, "winded": athlete.winded, "exhausted": athlete.exhausted, "epoch": athlete.fatigue_epoch, "flow": flow}

## Depleting contact for one caller. `depleting` true leaves 0.01 Stamina so the contact's cost crosses zero.
static func depleted(tree: SceneTree, caller: String, depleting: bool) -> Dictionary:
	var scene := "res://map_graybox.tscn" if caller == "serve" else "res://main.tscn"
	var lab: Node = await C.new_lab(tree, scene)
	var rec := Recorder.new(lab)
	var listener := {}
	var actor_id: String = {"player": "player", "bot": "training_bot_0", "pepper": "pepper_1", "serve": "player_serve"}[caller]
	lab.moc.impact_started.connect(func(event):
		if listener.is_empty() and event.actor == actor_id:
			listener.merge({"at_moc": listener_state(lab, actor_id), "flow_recorded": lab.contact_flow.recent.has(event.id)}))
	lab.receive_resolved.connect(func(event):
		if not listener.has("at_receive_resolved") and event.actor == actor_id:
			listener["at_receive_resolved"] = listener_state(lab, actor_id))
	lab._reset()
	var stamina := 0.01 if depleting else 100.0
	match caller:
		"player":
			lab.athlete.stamina = stamina
			lab.contact_flow.set_amount("player", 0.0)
			lab.moc.enabled = false
			lab.selected = 0
			lab.locked_action = 0
			lab.locked_charge = 0.675
			lab.armed = true
			lab.ball_active = true
			lab.ball_shot = Charge.shot("attack", 0.6, "test")
			lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(0).center
			lab.ball_velocity = INCOMING
			lab._confirm_action()
			lab.confirm_window = lab.confirm_duration - 0.22
			rec.step("before")
			lab._contact()
		"bot":
			var bots = lab.training_bots
			bots.reseed(SEED)
			bots.settings[0].enabled = true
			lab.ball_active = true
			lab.ball_shot = Charge.shot("attack", 0.6, "test")
			lab.ball.position = Vector3(0, 1.0, 5)
			lab.ball_velocity = INCOMING
			bots._plan(0, lab.ball.position, 0.2)
			bots.preparation.state_for(0).charge = 0.675
			bots.athlete_for(0).stamina = stamina
			lab.contact_flow.values["training_bot_0"] = 50.0
			rec.step("before")
			bots.tick(0.2)
		"pepper":
			var pepper = lab.pepper
			pepper.reseed(SEED)
			var spot: Vector3 = pepper.SPOTS[1]
			lab.player.position = spot + Vector3(0, 0, 6)
			lab.ball_active = true
			pepper.partner = 1
			pepper.npc_turn = true
			pepper.stage = 0
			lab.ball.position = spot + Vector3(0, 3.0, 0.5)
			lab.ball_velocity = Vector3(0, -1, 0)
			pepper.tick(1.0)
			pepper.plan()
			# Stand the partner on its contact point so walking costs nothing: the contact alone depletes.
			pepper.actors[1].position = pepper.move_target
			pepper.athlete_for(1).stamina = stamina
			lab.contact_flow.values["pepper_1"] = 50.0
			rec.step("before")
			for frame in range(240):
				if pepper.exchanges > 0 or not lab.ball_active: break
				lab._tick_ball(1.0 / 120)
		"serve":
			lab.select_net(0)
			lab.player.position = lab.court_center + Vector3(0, 0.03, lab.court_half_depth + 0.4)
			lab.camera_rig.view_yaw = 0
			lab.camera_rig.facing_yaw = 0
			lab.camera_rig.update_aim()
			lab.animation.update()
			lab.athlete.stamina = stamina
			lab.contact_flow.set_amount("player", 0.0)
			rec.step("before")
			lab.serve.press()
			lab.serve.basic_strike()
	rec.step("after")
	var facts := {"listener": listener, "events": rec.event_log(), "post": listener_state(lab, actor_id)}
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-01 scenarios run the contact twice: `depleting` (0.01 Stamina left, the contact crosses zero) and `control` (full Stamina).
static func s01_both(tree: SceneTree, caller: String) -> Dictionary:
	var depleting: Dictionary = await depleted(tree, caller, true)
	var control: Dictionary = await depleted(tree, caller, false)
	var trace: Array = depleting.trace.duplicate()
	trace.append_array(control.trace)
	return {"trace": trace, "facts": {"depleting": depleting.facts, "control": control.facts}}

static func s01_player(tree: SceneTree) -> Dictionary: return await s01_both(tree, "player")
static func s01_bot(tree: SceneTree) -> Dictionary: return await s01_both(tree, "bot")
static func s01_pepper(tree: SceneTree) -> Dictionary: return await s01_both(tree, "pepper")
static func s01_serve(tree: SceneTree) -> Dictionary: return await s01_both(tree, "serve")

## S-02: one physics step in which the player (ordinary Receive or swept Block) and a court bot both qualify for the same ball.
static func same_step(tree: SceneTree, action: int, player_armed: bool, bot_present: bool) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	var bots = lab.training_bots
	bots.reseed(SEED)
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.view_yaw = 0
	lab.camera_rig.update_aim()
	lab.selected = action
	lab.locked_action = action
	lab.locked_charge = 0.675
	lab.ball_active = true
	lab.ball_shot = Charge.shot("attack", 0.6, "test")
	var centre: Vector3 = lab._raw_hurtbox_definition(action).center
	lab.ball.position = lab.player.position + centre
	lab.ball_velocity = Vector3(0, -0.5, 0) if action == 0 else Vector3(0, -0.5, 6)
	if player_armed:
		lab.armed = true
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration - 0.22
	if bot_present:
		bots.settings[0].enabled = true
		bots._plan(0, lab.ball.position, 0.2)
		bots.tick_motion(0.2 - 1.0 / 120)
		bots.remaining = 1.0 / 120
	rec.step("before")
	lab._physics_process(1.0 / 120)
	rec.step("after")
	var order: Array = rec.events.map(func(e): return "%s/action%d" % [e.actor, e.action])
	var facts := {"order": order, "player_contacts": lab.contacts, "bot_total": bots.total_contacts, "side_contacts": lab.side_contacts,
		"final_actor": lab.ball_shot.get("actor", ""), "final_kind": lab.ball_shot.get("kind", ""), "events": rec.event_log()}
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

static func s02_receive_both(tree: SceneTree) -> Dictionary: return await same_step(tree, 0, true, true)
static func s02_receive_bot_only(tree: SceneTree) -> Dictionary: return await same_step(tree, 0, false, true)
static func s02_receive_player_only(tree: SceneTree) -> Dictionary: return await same_step(tree, 0, true, false)
static func s02_block_both(tree: SceneTree) -> Dictionary: return await same_step(tree, 3, true, true)

## S-02 repeat gate: the player's ordinary contact needs 0.22 s since the last one; a court bot has no such gate.
static func s02_repeat_gate_player(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
	var facts := {}
	for attempt in range(3):
		lab.selected = 0
		lab.locked_action = 0
		lab.locked_charge = 0.675
		lab.ball_active = true
		lab.ball_shot = Charge.shot("attack", 0.6, "test")
		lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(0).center
		lab.ball_velocity = Vector3(0, -0.5, 0)
		lab.armed = true
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration - 0.22
		if attempt == 2: lab.elapsed += 0.3
		lab.contacts = 0
		lab.side_contacts.assign([0, 0])
		lab._physics_process(1.0 / 120)
		facts["events_after_attempt_%d" % attempt] = rec.events.size()
		rec.step("attempt %d" % attempt)
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

static func s02_repeat_gate_bot(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	var bots = lab.training_bots
	bots.reseed(SEED)
	bots.settings[0].enabled = true
	var facts := {}
	for attempt in range(2):
		lab.ball_active = true
		lab.ball_shot = Charge.shot("attack", 0.6, "test")
		lab.ball.position = Vector3(0, 1.0, 5)
		lab.ball_velocity = Vector3(0, -0.5, 0)
		lab.side_contacts.assign([0, 0])
		bots._plan(0, lab.ball.position, 0.2)
		bots.tick_motion(0.2 - 1.0 / 120)
		bots.remaining = 1.0 / 120
		lab._physics_process(1.0 / 120)
		facts["after_%d_total" % attempt] = bots.total_contacts
		rec.step("bot attempt %d" % attempt)
	facts["elapsed"] = lab.elapsed
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## --- shared fixtures ---------------------------------------------------------------------------------------------------------------
## Player armed for `action` with the ball inside that action's hurtbox and the confirmation `age` seconds old.
static func arm_player(lab: Node, action: int, charge: float = 0.675, age: float = 0.22, velocity: Vector3 = Vector3.INF) -> void:
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
	lab.selected = action
	lab.locked_action = action
	lab.locked_charge = charge
	lab.ball_active = true
	lab.ball_shot = Charge.shot("attack", 0.6, "test")
	var shape: Dictionary = lab._raw_hurtbox_definition(action)
	var centre: Vector3 = shape.center
	if action == 1: centre += Vector3.UP * float(shape.radius) * 0.55
	lab.ball.position = lab.player.position + centre
	lab.ball_velocity = INCOMING if velocity == Vector3.INF and action != 3 else (Vector3(0, -0.5, 6) if velocity == Vector3.INF else velocity)
	lab.armed = true
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration - age

static func arm_bot(lab: Node, charge: float = 0.675) -> void:
	var bots = lab.training_bots
	bots.reseed(SEED)
	bots.settings[0].enabled = true
	lab.ball_active = true
	lab.ball_shot = Charge.shot("attack", 0.6, "test")
	lab.ball.position = Vector3(0, 1.0, 5)
	lab.ball_velocity = INCOMING
	bots._plan(0, lab.ball.position, 0.2)
	bots.preparation.state_for(0).charge = charge

static func arm_pepper(lab: Node, stamina: float = 100.0) -> void:
	var pepper = lab.pepper
	pepper.reseed(SEED)
	var spot: Vector3 = pepper.SPOTS[1]
	lab.player.position = spot + Vector3(0, 0, 6)
	lab.ball_active = true
	pepper.partner = 1
	pepper.npc_turn = true
	pepper.stage = 0
	lab.ball.position = spot + Vector3(0, 3.0, 0.5)
	lab.ball_velocity = Vector3(0, -1, 0)
	pepper.tick(1.0)
	pepper.plan()
	pepper.actors[1].position = pepper.move_target
	pepper.athlete_for(1).stamina = stamina

static func run_pepper(lab: Node) -> void:
	for frame in range(240):
		if lab.pepper.exchanges > 0 or not lab.ball_active: break
		lab._tick_ball(1.0 / 120)

static func ledger_state(lab: Node) -> Dictionary:
	return {"contacts": lab.contacts, "side_contacts": lab.side_contacts.duplicate(), "last_touch_side": lab.rally_rules.last_touch_side,
		"bot_total": lab.training_bots.total_contacts, "pepper_player_contacts": lab.pepper.player_contacts, "ball_active": lab.ball_active}

## S-03: how each caller counts, faults and renews. Cases are independent sessions.
static func ledger_case(tree: SceneTree, name: String) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	var pre := {}
	match name:
		"player_receive":
			lab.side_contacts.assign([0, 2])
			lab.contacts = 0
			arm_player(lab, 0)
			pre = ledger_state(lab)
			lab._contact()
		"player_block":
			lab.side_contacts.assign([2, 2])
			lab.contacts = 1
			arm_player(lab, 3)
			pre = ledger_state(lab)
			lab._contact()
		"player_receive_fourth":
			lab.side_contacts.assign([3, 0])
			lab.contacts = 3
			arm_player(lab, 0)
			pre = ledger_state(lab)
			lab._contact()
		"player_block_after_three":
			lab.side_contacts.assign([3, 2])
			lab.contacts = 3
			arm_player(lab, 3)
			pre = ledger_state(lab)
			lab._contact()
		"bot_receive":
			lab.side_contacts.assign([0, 2])
			lab.contacts = 2
			arm_bot(lab)
			pre = ledger_state(lab)
			lab.training_bots.tick(0.2)
		"bot_fourth":
			lab.side_contacts.assign([3, 0])
			lab.contacts = 3
			arm_bot(lab)
			pre = ledger_state(lab)
			lab.training_bots.tick(0.2)
		"pepper_receive":
			arm_pepper(lab)
			lab.side_contacts.assign([2, 1])
			lab.contacts = 2
			pre = ledger_state(lab)
			run_pepper(lab)
	rec.step(name)
	var facts := {"pre": pre, "post": ledger_state(lab), "events": rec.events.size(), "event_actors": rec.events.map(func(e): return e.actor)}
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

const LEDGER_CASES := ["player_receive", "player_block", "player_receive_fourth", "player_block_after_three", "bot_receive", "bot_fourth", "pepper_receive"]

static func s03_ledger_table(tree: SceneTree) -> Dictionary:
	var trace := []
	var facts := {}
	for name in LEDGER_CASES:
		var result: Dictionary = await ledger_case(tree, name)
		trace.append_array(result.trace)
		facts[name] = result.facts
	return {"trace": trace, "facts": facts}

## S-04: a physical hit starts the MoC effect for its actor; the ball-wide scale slows while only the player can steer.
static func slowdown_case(tree: SceneTree, caller: String) -> Dictionary:
	var scene := "res://map_graybox.tscn" if caller == "serve" else "res://main.tscn"
	var lab: Node = await C.new_lab(tree, scene)
	var rec := Recorder.new(lab)
	var facts := {"mode": lab.moc.mode, "enabled": lab.moc.enabled, "steering_speed": lab.moc.steering_speed}
	lab._reset()
	match caller:
		"player":
			arm_player(lab, 0)
			lab._contact()
		"bot":
			arm_bot(lab)
			lab.training_bots.tick(0.2)
		"pepper":
			arm_pepper(lab)
			run_pepper(lab)
		"serve":
			lab.select_net(0)
			lab.player.position = lab.court_center + Vector3(0, 0.03, lab.court_half_depth + 0.4)
			lab.camera_rig.view_yaw = 0
			lab.camera_rig.facing_yaw = 0
			lab.camera_rig.update_aim()
			lab.animation.update()
			lab.serve.press()
			lab.serve.basic_strike()
	rec.step("hit")
	facts["acting_actor"] = lab.moc.acting_actor
	facts["active"] = lab.moc.active
	C.advance_clock(lab, 50000)
	facts["ball_scale"] = lab.moc.simulation_scale()
	facts["player_scale"] = lab.moc.actor_scale("player")
	facts["steering_active"] = lab.moc.steering_active()
	var before: Vector3 = lab.ball_velocity
	lab.moc.steer(0.05, Vector3.RIGHT)
	facts["steer_changed_velocity"] = lab.ball_velocity != before
	rec.step("50ms later")
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

static func s04_slowdown(tree: SceneTree) -> Dictionary:
	var trace := []
	var facts := {}
	for caller in ["player", "bot", "pepper", "serve"]:
		var result: Dictionary = await slowdown_case(tree, caller)
		trace.append_array(result.trace)
		facts[caller] = result.facts
	return {"trace": trace, "facts": facts}

## S-05: contact-time directional influence by action and MoC mode. `request` is what the resolver is handed; `yaw` is the Set contact's result.
static func s05_di_by_mode(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	var facts := {}
	var modes := {"steering_default": [true, lab.moc.Mode.TRAJECTORY_STEERING], "slowdown_mode": [true, lab.moc.Mode.CURRENT_SLOWDOWN],
		"tuned_slowdown_mode": [true, lab.moc.Mode.TUNED_SLOWDOWN], "moc_off": [false, lab.moc.Mode.TRAJECTORY_STEERING], "mode_none": [true, lab.moc.Mode.NONE]}
	for label in modes:
		lab._reset()
		lab.moc.enabled = modes[label][0]
		lab.moc.set_mode(modes[label][1])
		lab.directional_input.clear()
		lab.directional_input.sample(Vector3.RIGHT, 0.2)
		var request := {}
		for action in range(4):
			request[action] = C.norm(lab.contact_request(action).directional_input)
		var result := {"request": request}
		lab._reset()
		lab.moc.enabled = modes[label][0]
		lab.moc.set_mode(modes[label][1])
		lab.directional_input.sample(Vector3.RIGHT, 0.2)
		arm_player(lab, 1)
		lab._contact()
		result["set_yaw_degrees"] = lab.last_directional_influence.get("yaw_degrees", -999.0)
		facts[label] = result
		rec.step(label, {"set_yaw": result.set_yaw_degrees})
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-06: base delivery of a clean Receive by actor kind (player net law, bot solves toward a setter, Pepper aims at the player).
static func s06_delivery_by_actor(tree: SceneTree) -> Dictionary:
	var trace := []
	var facts := {}
	for caller in ["player", "bot", "pepper"]:
		var result: Dictionary = await depleted(tree, caller, false)
		trace.append_array(result.trace)
		var event: Dictionary = result.facts.events[0]
		facts[caller] = {"outgoing": event.outgoing, "quality": event.quality, "zone": event.zone}
	var lab: Node = await C.new_lab(tree)
	var origin := Vector3(0, 1, 5)
	facts["charge_does_not_set_receive_range"] = lab._shot_velocity(origin, 0, 0.1).is_equal_approx(lab._shot_velocity(origin, 0, 1.0))
	facts["receive_net_distance"] = lab.receive_net_distance()
	await C.free_lab(tree, lab)
	return {"trace": trace, "facts": C.norm(facts)}

## S-07: the 0.85 s plant is a pose, hurtbox offset and aim lock; the movement lock lasts only while the confirm window lives.
static func s07_plant_timeline(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
	for settle in range(12):
		lab._physics_process(1.0 / 60)
		await tree.physics_frame
	lab.selected = 0
	lab.locked_action = 0
	lab.armed = true
	lab._confirm_action()
	lab.camera_rig.facing_yaw = 0.7
	var timeline := []
	var lock_end: float = -1.0
	var plant_end: float = -1.0
	var yaw_during: float = lab._contact_yaw()
	for step in range(70):
		var age: float = lab.receive_plant.age
		var planted: bool = lab.receive_plant.active()
		var locked: bool = lab.receive_planted()
		if lock_end < 0 and planted and not locked: lock_end = age
		if plant_end < 0 and not planted: plant_end = age
		if step % 6 == 0: timeline.append([snappedf(age, 0.0001), planted, locked, snappedf(lab.confirm_window, 0.0001)])
		lab._physics_process(1.0 / 60)
		await tree.physics_frame
	var plain: Dictionary = lab._raw_hurtbox_definition(0)
	lab._confirm_action()
	var plain_centre: Vector3 = lab.hurtbox_center_local(plain.center)
	lab.receive_plant.lean = Vector2(1, 1)
	var leaned: Dictionary = lab._raw_hurtbox_definition(0)
	var facts := {"duration": lab.receive_plant.DURATION, "movement_lock_ends_at_plant_age": lock_end, "plant_ends_at_age": plant_end,
		"contact_window": lab.Execution.contact_seconds(0), "yaw_during_plant": yaw_during, "plant_yaw": lab.receive_plant.yaw, "timeline": timeline,
		"shape_center": plain.center, "center_with_lean_zero": plain_centre, "lean_offset": lab.receive_plant.offset(),
		"center_with_lean": lab.hurtbox_center_local(leaned.center), "size_with_lean": leaned.size, "size_plain": plain.size}
	rec.step("end")
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-08 / probe F: a grounded Attack is a legal contact once the slice reaches the ball.
static func s08_grounded_attack(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	var sector: Dictionary = lab._hurtbox_definition(2)
	lab.athlete.build.accuracy = 99
	lab.armed = true
	lab.locked_action = 2
	lab.locked_charge = 0.6
	lab.ball_active = true
	lab.aim = Vector3(0, 0, -6)
	lab.camera_rig.facing_yaw = 0
	var point: Vector3 = sector.center + lab.Geometry.sector_point(sector, 0.74, 67.5, 0)
	lab.ball.position = lab.player.position + point
	lab._confirm_action()
	var struck_at := -1.0
	for step in range(201):
		var age: float = step * 0.005
		if lab.Geometry.spike_active(sector, point, age):
			struck_at = age
			break
	var facts := {"jumped": lab.motion.jumped, "windup": lab.Execution.SPIKE_WINDUP, "end": lab.Execution.SPIKE_END, "first_active_age": struck_at}
	lab.confirm_window = lab.confirm_duration - struck_at
	facts["can_contact_grounded"] = lab._can_contact()
	rec.step("before")
	lab._contact()
	rec.step("after")
	facts["contacts"] = lab.contacts
	facts["quality"] = lab.last_quality
	facts["shot_kind"] = lab.ball_shot.get("kind", "")
	facts["still_grounded"] = not lab.motion.jumped
	lab.confirm_window = lab.confirm_duration - 0.5
	facts["expired_age_can_contact"] = lab._can_contact()
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-09: Auto receives must match every charged incoming shot; manual only serve and attack.
static func s09_match_scope(tree: SceneTree) -> Dictionary:
	var facts := {}
	for kind in ["serve", "attack", "set", "receive", "block"]:
		var shot := Charge.shot(kind, 0.6, "test")
		facts[kind] = {"manual_required": Charge.match_charge(shot, 0.2).required, "all_contacts_required": Charge.match_charge(shot, 0.2, 0.0, 0.0, true).required,
			"manual_status": Charge.match_charge(shot, 0.2).status, "all_contacts_status": Charge.match_charge(shot, 0.2, 0.0, 0.0, true).status}
	# Through the resolver: Auto player Receive of a charged "set" shot is judged, a manual one is not.
	for mode in ["manual", "auto"]:
		var lab: Node = await C.new_lab(tree)
		lab._reset()
		lab.moc.enabled = false
		arm_player(lab, 0, 0.2)
		lab.ball_shot = Charge.shot("set", 0.6, "test")
		if mode == "auto":
			lab.begin_auto_preparation(0)
		lab._contact()
		facts["resolver_" + mode] = {"required": lab.last_contact_result.charge_match.required, "status": lab.last_contact_result.charge_match.status}
		await C.free_lab(tree, lab)
	return {"trace": [], "facts": C.norm(facts)}

## S-10 / probe D: the Attack hurtbox follows the live rig pose for the player; Receive, Set and Block do not. Court bots measure once.
static func s10_attack_volume(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	var facts := {}
	var idle := {}
	for action in range(4): idle[action] = C.norm(lab._raw_hurtbox_definition(action).center)
	facts["idle_centres"] = idle
	lab.locked_action = 0
	lab.receive_plant.begin(0.0, 0.0)
	lab.receive_plant.lean = Vector2(1, 1)
	lab.animation.update()
	var posed := {}
	for action in range(4): posed[action] = C.norm(lab._raw_hurtbox_definition(action).center)
	facts["leaned_centres"] = posed
	lab.receive_plant.clear()
	lab.locked_action = 2
	lab.animation.update()
	facts["released_attack_centre"] = C.norm(lab._raw_hurtbox_definition(2).center)
	facts["radius"] = lab._raw_hurtbox_definition(2).radius
	# Court bots: the shape is cached after the first measurement.
	var bots = lab.training_bots
	bots.settings[2].enabled = true
	var slot := 2
	if slot >= 0:
		var first: Dictionary = bots.contact_shape(slot)
		lab.receive_plant.begin(0.0, 0.0)
		lab.receive_plant.lean = Vector2(1, 1)
		lab.locked_action = 0
		lab.animation.update()
		var second: Dictionary = bots.contact_shape(slot)
		facts["bot_attack_slot"] = slot
		facts["bot_attack_centre"] = C.norm(first.center)
		facts["bot_centre_unchanged_by_player_pose"] = first.center == second.center
	rec.step("end")
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-11: `action_endlag` is written on contact, decays with Transition Speed, and gates nothing.
static func s11_endlag(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	arm_player(lab, 0)
	var facts := {"before": lab.action_endlag}
	lab._contact()
	facts["after_contact"] = lab.action_endlag
	rec.step("contact")
	# While endlag is live the next attempt is legal (the only gate is the repeat gate in the physics step).
	arm_player(lab, 0)
	facts["can_contact_with_endlag_live"] = lab._can_contact() and lab.action_endlag > 0.0
	lab.motion.tick(0.05, 1.0)
	facts["after_decay_0_05"] = lab.action_endlag
	for step in range(20): lab.motion.tick(0.05, 1.0)
	facts["after_decay_1_0"] = lab.action_endlag
	rec.step("decayed")
	# Static: no gameplay script reads it (every textual use outside its declaration is an assignment or the decay).
	var readers := []
	for path in all_scripts("res://scripts"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for index in range(lines.size()):
			var line: String = lines[index]
			if line.contains("action_endlag") and not line.strip_edges().begins_with("#"):
				readers.append("%s:%s" % [path.get_file(), line.strip_edges()])
	facts["uses"] = readers
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

static func all_scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"): out.append(dir + "/" + file)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(all_scripts(dir + "/" + sub))
	out.sort()
	return out

## S-12: `event.charge` is the input charge for the player and the delivered shot pressure for bots, Pepper and Serve.
static func s12_charge_senses(tree: SceneTree) -> Dictionary:
	var trace := []
	var facts := {}
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	arm_player(lab, 2, 0.8)
	lab.armed = true
	lab._contact()
	var player_event: Dictionary = lab.last_contact_result
	facts["player_attack"] = {"event_charge": player_event.charge, "locked_charge": 0.8, "ball_shot_charge": lab.ball_shot.get("charge", -1.0), "action_charge": lab.ball_shot.get("action_charge", -1.0)}
	rec.step("player attack")
	lab._reset()
	lab.moc.enabled = false
	arm_player(lab, 0, 0.4)
	lab._contact()
	facts["player_receive_undercharged"] = {"event_charge": lab.last_contact_result.charge, "locked_charge": 0.4, "ball_shot_charge": lab.ball_shot.get("charge", -1.0)}
	rec.step("player receive")
	await C.free_lab(tree, lab)
	trace.append_array(rec.trace)
	for caller in ["bot", "pepper", "serve"]:
		var scene := "res://map_graybox.tscn" if caller == "serve" else "res://main.tscn"
		var other: Node = await C.new_lab(tree, scene)
		var capture := []
		other.moc.impact_started.connect(func(event): capture.append(event))
		other._reset()
		other.moc.enabled = false
		match caller:
			"bot":
				arm_bot(other)
				other.training_bots.tick(0.2)
			"pepper":
				arm_pepper(other)
				run_pepper(other)
			"serve":
				other.select_net(0)
				other.player.position = other.court_center + Vector3(0, 0.03, other.court_half_depth + 0.4)
				other.camera_rig.view_yaw = 0
				other.camera_rig.facing_yaw = 0
				other.camera_rig.update_aim()
				other.animation.update()
				other.serve.press()
				other.serve.basic_strike()
		var event: Dictionary = capture[0] if not capture.is_empty() else {}
		facts[caller] = {"event_charge": event.get("charge", -1.0), "ball_shot_charge": other.ball_shot.get("charge", -1.0), "events": capture.size()}
		await C.free_lab(tree, other)
	return {"trace": trace, "facts": C.norm(facts)}

## S-13: recovery and shrug. Locks and recovery velocity are written by animation code, for the player only.
static func recovery_case(tree: SceneTree, label: String, charge: float, input: Vector3, actor: String) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	if actor == "player":
		lab.directional_input.sample(input, 0.2)
		arm_player(lab, 0, charge)
		lab.player.velocity = Vector3.ZERO
		lab._contact()
	else:
		arm_bot(lab, charge)
		lab.training_bots.tick(0.2)
	var an = lab.animation
	var outcome: Dictionary = lab.last_contact_result.get("receive_outcome", {}) if actor == "player" else {}
	rec.step(label)
	var facts := {"recovery": String(lab.last_contact_result.get("recovery", "")) if actor == "player" else "", "floor_recovery_name": an.floor_recovery_name,
		"floor_recovery_time": an.floor_recovery_time, "floor_recovery_lock": an.floor_recovery_lock, "floor_input_locked": an.floor_input_locked(),
		"floor_recovery_total": an.floor_recovery_total() if an.floor_recovery_time >= 0.0 else 0.0, "roll_lock": an.roll_lock,
		"player_velocity": lab.player.velocity, "recovery_seconds": outcome.get("recovery_seconds", 0.0), "recovery_penalty_seconds": outcome.get("recovery_penalty_seconds", 0.0),
		"outcome": outcome.get("outcome", "")}
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

static func s13_recovery(tree: SceneTree) -> Dictionary:
	var trace := []
	var facts := {}
	for spec in [["blown_away", 0.4, Vector3.ZERO, "player"], ["shrug_input_back_in_lab", 0.55, Vector3.BACK, "player"], ["clean", 0.675, Vector3.ZERO, "player"], ["bot_undercharged", 0.4, Vector3.ZERO, "bot"]]:
		var result: Dictionary = await recovery_case(tree, spec[0], spec[1], spec[2], spec[3])
		trace.append_array(result.trace)
		facts[spec[0]] = result.facts
	# The shrug the lab never produces (Receive DI input is zero), fed to the animation as an event: lock = penalty budget, animation = authored length.
	var lab: Node = await C.new_lab(tree)
	lab._reset()
	lab.animation.on_receive_resolved({"actor": "player", "recovery": "shrug", "recovery_penalty_seconds": 0.25, "receive_outcome": {"platform_coord": Vector3(0.1, 0, 0), "penalty_factor": 1.0}})
	var an = lab.animation
	facts["shrug_event"] = C.norm({"floor_recovery_name": an.floor_recovery_name, "lock": an.floor_recovery_lock, "total": an.floor_recovery_total(), "locked": an.floor_input_locked()})
	await C.free_lab(tree, lab)
	return {"trace": trace, "facts": facts}

## S-14: Exhausted expiry returns to Winded, which clears Flow and bumps the fatigue epoch; Flow decays through the lab's own poll.
static func s14_exhausted_expiry(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	var athlete = lab.athlete
	athlete.exhausted = true
	athlete.winded = false
	athlete.exhaustion_remaining = 0.05
	athlete.stamina = 0.0
	lab.contact_flow.set_amount("player", 40.0)
	var epoch_before: int = athlete.fatigue_epoch
	rec.step("exhausted, flow 40")
	athlete.recover(0.1, false)
	rec.step("expiry")
	var facts := {"epoch_delta": athlete.fatigue_epoch - epoch_before, "winded": athlete.winded, "exhausted": athlete.exhausted, "flow_field": athlete.flow,
		"stamina_after_expiry": athlete.stamina, "max_stamina": athlete.max_stamina(), "flow_amount": lab.contact_flow.amount("player")}
	lab.contact_flow.tick(0.0)
	rec.step("flow poll")
	facts["flow_values_after_poll"] = lab.contact_flow.values.get("player", -1.0)
	# Depletion from Winded enters Exhausted, and clears Flow too.
	athlete.winded = true
	athlete.exhausted = false
	athlete.stamina = 0.5
	athlete.flow = 30.0
	var epoch2: int = athlete.fatigue_epoch
	athlete.spend_resolved(5.0)
	facts["winded_depletion"] = {"exhausted": athlete.exhausted, "flow": athlete.flow, "epoch_delta": athlete.fatigue_epoch - epoch2}
	# Bot athletes share the rule (BotVitals.spend also zeroes the flow store directly).
	var bots = lab.training_bots
	var bot = bots.athlete_for(0)
	lab.contact_flow.values["training_bot_0"] = 50.0
	bot.stamina = 0.2
	bots.spend_stamina(0, 5.0, true)
	facts["bot_depletion"] = {"winded": bot.winded, "flow": lab.contact_flow.values.get("training_bot_0", -1.0), "epoch": bot.fatigue_epoch}
	# Second Wind is +10 in the trait data.
	var tree_json: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/trait_tree.json"))
	facts["second_wind_in_data"] = JSON.stringify(tree_json).contains("\"second_wind\":10")
	rec.step("end")
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-15: custody leaks. Ground balls evict the oldest of three without a cart return; `team_empty` has no reader; the Bench keeps the held
## ball; the Serve Receive reward caps Stamina at a literal 100 rather than the athlete's maximum.
static func s15_custody(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree, "res://map_graybox.tscn")
	var rec := Recorder.new(lab)
	var facts := {}
	var carts_before: int = lab.ball_carts.total_balls()
	for index in range(4):
		lab.ground_balls.land(lab, Vector3(index, 0, 3), Vector3(0, -3, 2), Charge.shot("receive", 0.5, "test"))
	facts["ground_balls_after_four_landings"] = lab.ground_balls.balls.size()
	facts["max_balls"] = lab.ground_balls.MAX_BALLS
	facts["cart_balls_before"] = carts_before
	facts["cart_balls_after"] = lab.ball_carts.total_balls()
	rec.step("landings")
	var callers := []
	for path in all_scripts("res://scripts"):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.contains("team_empty(") and not line.strip_edges().begins_with("#") and not line.strip_edges().begins_with("func "):
				callers.append("%s:%s" % [path.get_file(), line.strip_edges()])
	facts["team_empty_callers"] = callers
	lab.inventory.held = true
	lab.athlete.exhausted = true
	lab.ball_active = true
	lab.player.position = lab.court_center + Vector3(0, 0.03, 5)
	lab._check_bench()
	facts["benched"] = lab.is_benched()
	facts["inventory_held_while_benched"] = lab.inventory.held
	lab.bench.clear()
	lab.athlete.exhausted = false
	# Serve Receive reward: stamina above 100 is cut to the literal.
	lab.athlete.build["endurance"] = 99
	facts["max_stamina"] = lab.athlete.max_stamina()
	lab.athlete.stamina = 105.0
	lab.station.points = lab.station.GOAL
	lab.station.advance()
	facts["stamina_after_station_complete"] = lab.athlete.stamina
	rec.step("station complete")
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-16 / probe E: manual charge accrues on the actor clock; Auto preparation ticks on world time. Differs only under a MoC slowdown.
static func s16_auto_clock(tree: SceneTree) -> Dictionary:
	var rec: Recorder
	var facts := {}
	var trace := []
	for moc_on in [false, true]:
		for kind in ["manual", "auto"]:
			var lab: Node = await C.new_lab(tree)
			lab._reset()
			lab.auto_feed = false
			lab.ball_active = false
			lab.moc.enabled = true
			lab.locked_action = 0
			if moc_on:
				lab.moc.begin({"id": "p", "actor": "player", "action": 2, "physical_hit": true, "outgoing_velocity": Vector3(0, 10, -20), "incoming_velocity": Vector3(0, -3, 20)})
				C.advance_clock(lab, 50000)
			if kind == "manual":
				lab.charging = true
				lab.charge = 0.0
			else:
				lab.armed = true
				lab.begin_auto_preparation(0)
			for frame in range(30):
				lab._physics_process(1.0 / 60)
			var key := "%s_moc_%s" % [kind, "on" if moc_on else "off"]
			facts[key] = {"actor_scale": lab.moc.actor_scale("player"), "charge": lab.charge if kind == "manual" else -1.0,
				"auto_age": lab.auto_preparation.age if kind == "auto" else -1.0, "auto_prepared": lab.auto_preparation.prepared if kind == "auto" else -1.0,
				"armed": lab.armed}
			await C.free_lab(tree, lab)
	return {"trace": trace, "facts": C.norm(facts)}

## S-17 / INV-02: previews neither spend, publish nor draw random numbers.
static func s17_preview(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	var bots = lab.training_bots
	bots.reseed(SEED)
	lab.pepper.reseed(SEED)
	arm_player(lab, 0)
	var capture := func() -> Dictionary:
		return C.norm({"stamina": lab.athlete.stamina, "hp": lab.athlete.hp, "flow": lab.athlete.flow, "events": rec.events.size(), "moc_events": lab.moc.event_count,
			"serial": lab._contact_event_serial, "contacts": lab.contacts, "side_contacts": lab.side_contacts, "ball": lab.ball.position, "velocity": lab.ball_velocity,
			"rng": [bots.random.state, bots.aim_random.state, bots.charge_random.state, lab.pepper.aim_random.state, lab.pepper.charge_random.state],
			"confirm_window": lab.confirm_window, "flow_values": lab.contact_flow.values, "pending": lab.contact_flow.pending_attacks.keys()})
	var before: Dictionary = capture.call()
	rec.step("before preview")
	for index in range(3):
		lab._update_preview(true)
		lab._update_contact_preview()
	var after: Dictionary = capture.call()
	rec.step("after preview")
	var facts := {"unchanged": C.diff(before, after).is_empty(), "differences": C.diff(before, after), "preview_has_content": not lab.last_trajectory_preview.is_empty()}
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-18 / INV-15: Exhaustion during a live rally benches the player before the receive resolves.
static func s18_bench_window(tree: SceneTree) -> Dictionary:
	var lab: Node = await C.new_lab(tree)
	var rec := Recorder.new(lab)
	lab._reset()
	lab.moc.enabled = false
	arm_player(lab, 0)
	lab.athlete.exhausted = true
	lab.athlete.stamina = 0.0
	rec.step("exhausted, armed, in window")
	var contacts_before: int = lab.contacts
	lab._contact()
	rec.step("contact attempt")
	var facts := {"benched": lab.is_benched(), "events": rec.events.size(), "contacts_unchanged": lab.contacts == contacts_before, "armed_after": lab.armed,
		"confirm_window_after": lab.confirm_window, "can_contact": lab._can_contact()}
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}

## S-19: left-handed athletes mirror the player's geometry; bots and Pepper use dominant_sign 1.
static func s19_left_handed_bot(tree: SceneTree) -> Dictionary:
	var facts := {}
	for hand in ["Right", "Left"]:
		var lab: Node = await C.new_lab(tree)
		lab._reset()
		lab.dominant_hand = hand
		var bots = lab.training_bots
		bots.settings[2].enabled = true
		var slot := 2
		var entry := {"player_attack_x": lab._raw_hurtbox_definition(2).center.x, "bot_slot": slot}
		if slot >= 0: entry["bot_attack_x"] = bots.contact_shape(slot).center.x
		lab.pepper.partner = 1
		lab.pepper.stage = 2
		entry["pepper_attack_x"] = lab.pepper.shape().center.x
		facts[hand] = entry
		await C.free_lab(tree, lab)
	return {"trace": [], "facts": C.norm(facts)}

## S-20 / MS-02: a seeded three-contact bot rally (receive, set, attack) reproduces its ledger.
static func s20_seeded_rally(tree: SceneTree, seed_value: int = 7) -> Dictionary:
	var lab: Node = await C.new_lab(tree, "res://map_graybox.tscn")
	var rec := Recorder.new(lab)
	lab.moc.enabled = false
	var bots = lab.training_bots
	bots.reseed(seed_value)
	lab.select_net(0)
	var receiver: int = bots.summon_generic(true, 0, {1: 0}, false)
	var setter: int = bots.summon_generic(true, 0, {2: 1}, false)
	var attacker: int = bots.summon_generic(true, 0, {3: 2}, false)
	for slot in [receiver, setter, attacker]:
		bots.set_aiming_accuracy(slot, 20.0)
	bots._place(receiver, lab.court_center + Vector3(0, 0, -5))
	bots._place(setter, lab.court_center + Vector3(-1, 0, -2))
	bots._place(attacker, lab.court_center + Vector3(-3, 0, -3))
	lab.player.position = lab.court_center + Vector3(0, 0.03, lab.court_half_depth + 0.4)
	lab.camera_rig.view_yaw = 0
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab.serve.press()
	lab.serve.basic_strike()
	rec.step("serve")
	var ledger := []
	var previous := 0
	for frame in range(1800):
		if not lab.ball_active: break
		lab._tick_ball(1.0 / 120)
		if bots.total_contacts > previous:
			previous = bots.total_contacts
			ledger.append([bots.last_action, lab.ball_velocity, lab.ball.position])
			rec.step("bot contact %d" % previous)
			if ledger.size() == 3: break
	var facts := {"ledger": ledger, "contacts": ledger.size()}
	await C.free_lab(tree, lab)
	return {"trace": rec.trace, "facts": C.norm(facts)}
