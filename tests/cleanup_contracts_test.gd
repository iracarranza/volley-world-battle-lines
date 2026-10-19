extends "res://tests/support/test_case.gd"
const Store := preload("res://scripts/athlete_store.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Event := preload("res://scripts/contact/contact_event.gd")
const Resolver := preload("res://scripts/contact/contact_resolver.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var config := Store.blank()
	config.offsets.accuracy = [-8, 0, 8]
	config.statistics.ball_control = 88.0
	var migrated := Store.migrate(config)
	check(migrated.statistics.ball_control == 88.0, "Canonical named stat wins over conflicting editor offsets")
	var athlete := Athlete.new()
	athlete.build = migrated
	check(athlete.stat("ball_control") == 88.0, "Gameplay uses the migrated named stat")
	var book = Store.trait_book()
	for node in book.nodes:
		if node.get("effects", {}).is_empty():
			continue
		athlete.trait_ids.assign([str(node.id)])
		var effect: String = node.effects.keys()[0]
		var expected := float(node.effects[effect])
		var original_name: String = node.name
		node.name = "Renamed for contract verification"
		check(athlete.trait_effect(effect) == expected, "Display-name changes cannot remove owned gameplay effects")
		node.name = original_name
		break

	var event := Event.new()
	event.assessment = {"hit": true, "receive_outcome": {"items": [{"value": 3}]}}
	var published := event.publish()
	event.assessment.receive_outcome.items[0].value = 9
	check(published.is_read_only() and published.receive_outcome.is_read_only() and published.receive_outcome.items.is_read_only() and published.receive_outcome.items[0].is_read_only(), "Contact evidence is recursively read-only")
	check(published.receive_outcome.items[0].value == 3, "Published events do not alias mutable resolver state")

	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.moc.enabled = false
	for action in range(4):
		lab._reset()
		lab.locked_action = action
		lab.armed = true
		lab.ball_active = true
		var shape: Dictionary = lab._raw_hurtbox_definition(action)
		lab.ball.position = lab.player.position + shape.center
		if action == 2:
			lab.ball.position += lab.Geometry.sector_point(shape, 0.74, 67.5, 0)
		lab._confirm_action()
		var id: int = lab.hurtbox_mesh.mesh.get_instance_id()
		lab.confirm_window = lab.confirm_duration - 0.22
		var request = lab.contact_request(action)
		var before := var_to_str(request.shape)
		var assessment := Resolver.assess(request)
		request.base_velocity = Vector3(0, 5, -10)
		var resolved = Resolver.resolve(request, assessment)
		request.actor_id = "training_bot_0"
		var bot = Resolver.resolve(request, assessment)
		check(resolved.velocity == bot.velocity, "Identical actor inputs resolve identically regardless of player/bot identity")
		check(before == var_to_str(request.shape), "Resolver preserves input geometry")
		lab._confirm_action()
		check(lab.hurtbox_mesh.mesh.get_instance_id() == id, "Repeated confirmation reuses geometry")
		lab._update_hurtbox_visual(0)
		var material_id: int = lab.hurtbox_mesh.material_override.get_instance_id()
		lab._confirm_action()
		check(lab.hurtbox_mesh.material_override.get_instance_id() == material_id, "Repeated phase reuses its material")
	lab.queue_free()
	await process_frame
	print("CLEANUP CONTRACTS: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
