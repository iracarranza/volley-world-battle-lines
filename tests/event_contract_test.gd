extends "res://tests/support/test_case.gd"
## Event/evidence contract (MS-04): documented fields exist for player, bot, Pepper and Serve events; consumers run in the documented
## order; a duplicate event is idempotent by id. Documented in docs/architecture-migration/event-schema.md.
const FIELDS := ["id", "actor", "team", "action", "charge", "point", "incoming_velocity", "outgoing_velocity", "incoming_shot", "outgoing_shot",
	"physical_hit", "zone", "quality", "mechanics", "gameplay", "steering", "block_response", "receive_response", "sweet", "rescue",
	"confirmation_age", "charge_match", "posture", "receive_outcome", "recovery", "recovery_seconds", "recovery_penalty_seconds",
	"platform_band", "platform_coord", "simulation_time", "intent", "directional_influence"]
## Added by MomentOfContact to the copy that impact_started carries.
const MOC_FIELDS := ["moc_mode", "velocity_duration_seconds", "sweet_duration_seconds", "duration_extension_seconds", "contact_duration_seconds", "duration_seconds", "incoming_speed", "outgoing_speed", "velocity_change"]
## _publish_impact order, by the first token each step is written with.
const PUBLISH_ORDER := ["hud.athlete_hud.timeline.contact(event)", "RallyLedger.renew_opponent(self, int(event.team))", "clear_net_responses()", "receive_resolved.emit(event)", "animation.on_contact(event)", "contact_flow.record(event)", "moc.begin(event)"]
var seen: Array = []

func _initialize() -> void: call_deferred("run")

func capture(event: Dictionary) -> void:
	seen.append(event)

func check_fields(event: Dictionary, label: String) -> void:
	var missing: Array = FIELDS.filter(func(key): return not event.has(key))
	var extra: Array = event.keys().filter(func(key): return key not in FIELDS and key not in MOC_FIELDS)
	check(missing.is_empty(), "%s event has every documented field (missing %s)" % [label, missing])
	check(extra.is_empty(), "%s event has no undocumented field (extra %s)" % [label, extra])
	check(event.is_read_only(), "%s event is read-only" % label)

func run() -> void:
	# Player and Pepper events on the main scene.
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.moc.impact_started.connect(capture)
	var pepper = lab.pepper
	lab._reset()
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
	for frame in range(240):
		if pepper.exchanges > 0 or not lab.ball_active: break
		lab._tick_ball(1.0 / 120)
	var pepper_events := seen.filter(func(e): return str(e.actor).begins_with("pepper_"))
	check(pepper_events.size() >= 1, "A Pepper contact publishes an event")
	if not pepper_events.is_empty():
		check_fields(pepper_events[0], "Pepper")
	lab.camera_rig.facing_yaw = 0
	lab.locked_action = 1
	lab.locked_charge = 0.55
	lab.camera_rig.view_pitch = 0.27
	lab.armed = true
	var shape: Dictionary = lab._hurtbox_definition(1)
	lab.ball.position = lab.player.position + Vector3(shape.center) + Vector3.UP * shape.radius * 0.55
	lab.aim = spot
	lab._contact()
	var player_events := seen.filter(func(e): return e.actor == "player")
	check(player_events.size() == 1, "A player contact publishes one event")
	if not player_events.is_empty():
		check_fields(player_events[0], "Player")
		check(is_equal_approx(float(player_events[0].charge), 0.55), "Player event.charge is the input charge (BDR-15)")
		# Idempotence by id: publishing the same event again changes nothing.
		var published: Dictionary = lab.last_contact_result
		var recorded: int = lab.contact_flow.recent.count(published.id)
		var count: int = lab.moc.event_count
		var flow_before: float = lab.contact_flow.amount("player")
		lab._publish_impact(published)
		check(recorded == 1 and lab.contact_flow.recent.count(published.id) == 1, "Flow records an event id once")
		check(lab.moc.event_count == count and is_equal_approx(lab.contact_flow.amount("player"), flow_before), "A duplicate event neither restarts MoC nor changes Flow")
	lab.queue_free()
	await process_frame
	# Serve and bot events, and the consumer order, on the map scene.
	seen.clear()
	var map = load("res://map_graybox.tscn").instantiate()
	root.add_child(map)
	map.set_process(false)
	map.set_physics_process(false)
	await physics_frame
	map.moc.impact_started.connect(capture)
	var bots = map.training_bots
	map.select_net(0)
	var receiver: int = bots.summon_generic(true, 0, {1: 0}, false)
	bots._place(receiver, map.court_center + Vector3(0, 0, -5))
	map.player.position = map.court_center + Vector3(0, 0.03, map.court_half_depth + 0.4)
	map.camera_rig.view_yaw = 0
	map.camera_rig.facing_yaw = 0
	map.camera_rig.update_aim()
	map.animation.update()
	# What each consumer has done by the time receive_resolved and impact_started fire.
	var at_receive := {}
	var at_moc := {}
	map.receive_resolved.connect(func(event):
		if at_receive.is_empty() and event.actor.begins_with("training_bot"):
			at_receive.merge({"flow": map.contact_flow.recent.has(event.id), "moc": map.moc.event_count}))
	map.moc.impact_started.connect(func(event):
		if at_moc.is_empty() and event.actor.begins_with("training_bot"):
			at_moc.merge({"flow": map.contact_flow.recent.has(event.id)}))
	var moc_before: int = map.moc.event_count
	map.serve.press()
	map.serve.basic_strike()
	for frame in range(1800):
		if not map.ball_active or bots.total_contacts > 0: break
		map._tick_ball(1.0 / 120)
	var serve_events := seen.filter(func(e): return e.actor == "player_serve")
	var bot_events := seen.filter(func(e): return str(e.actor).begins_with("training_bot_"))
	check(serve_events.size() == 1 and bot_events.size() >= 1, "Serve and bot contacts each publish")
	if not serve_events.is_empty():
		check_fields(serve_events[0], "Serve")
	if not bot_events.is_empty():
		check_fields(bot_events[0], "Bot")
		check(at_receive.get("flow", true) == false, "receive_resolved fires before the Flow record")
		check(at_receive.get("moc", -1) == moc_before + 1, "receive_resolved fires before MoC begins for the bot's own event (only the serve began MoC)")
		check(at_moc.get("flow", false) == true, "The Flow record precedes MoC begin")
	map.queue_free()
	await process_frame
	# Written order of the publish step.
	var source := FileAccess.get_file_as_string("res://scripts/contact_lab.gd")
	var start := source.find("func _publish_impact")
	var end := source.find("\nfunc ", start + 10)
	var body := source.substr(start, end - start)
	var previous := -1
	for step in PUBLISH_ORDER:
		var index := body.find(step)
		check(index > previous, "Publish step '%s' keeps its documented place" % step)
		previous = index
	print("EVENT CONTRACT: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
