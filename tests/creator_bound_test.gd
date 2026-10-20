extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	call_deferred("run")

func settle(lab: Node3D) -> void:
	for frame in range(12):
		lab._physics_process(1.0 / 60.0)
		await physics_frame

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.auto_feed = false
	await settle(lab)
	var creator = lab.creator
	creator.open()
	check(creator.visible and lab.paused, "Creator must pause the live lab and show editing controls")
	for type in creator.Bodies.MODELLED:
		creator.draft.body_type = type
		creator.draft.appearance.palette_index = 0
		creator.draft.appearance.marking = "none"
		creator.refresh_choices()
		creator.refresh_preview()
		check(is_instance_valid(creator.preview_actor) and creator.preview_actor.get_node_or_null("Torso") != null, "Every VWM body must render in the shared live preview")
		check(creator.preview_actor.get_meta("vwm_construction", false), "Preview must come from the actual VWM actor construction")
		check(creator.preview_actor.get_node_or_null("LeftArm/Elbow/Wrist/Palm") != null, "Actual VWM articulated hands must survive transfer")
		check(creator.preview_actor.get_node_or_null("Torso/Ink") != null, "Actual VWM ink hull must survive transfer")
		check(creator.preview_actor.get_node("Head/Face").get_child_count() > 0, "Actual VWM facial geometry must survive transfer")
		if type == "Avi":
			check(creator.preview_actor.find_child("Beak", true, false) != null and creator.preview_actor.find_child("WingPrimaryLeft", true, false) != null, "Avi must reuse VWM's beak and attached wing meshes")
		if type == "Feli":
			check(creator.preview_actor.find_child("EarLeft", true, false) != null, "Feli must reuse VWM's authored ears")
	creator.draft.body_type = "Avi"
	creator.draft.role = "L"
	creator.draft.name = "Test Athlete"
	creator.draft.height = 1.90
	creator.draft.span = 1.96
	creator.stat_sliders[0].value = 77
	check(creator.ap_spent() == 12, "Shared AP pool must charge one point per attribute increase")
	creator.stat_sliders[1].value = 66
	check(creator.draft.speed == 65 and creator.ap_spent() == 12, "Creator must reject attribute investment beyond the shared budget")
	creator.apply()
	check(not creator.visible and not lab.paused, "Applying creation must resume the lab")
	check(lab.body_type == "Avi" and lab.body.find_child("Beak", true, false) != null, "On-court body must match the chosen VWM body")
	check(lab.athlete.build.power == 77 and lab.athlete.build.speed == 65 and lab.position_role == "L", "Rally Lanes role/attribute choices must reach the gameplay model")
	check(absf(lab.athlete.reach() - (1.215 * 1.90 + 0.32 * 0.06)) < 0.001, "Creator physique must change authoritative reach")
	check(lab.athlete.contact_cost(0, 1).y == 0 and lab.athlete.contact_cost(2, 1).y == 0, "Created athletes reserve HP for abilities, not ordinary contacts")
	var prior: Dictionary = lab.athlete.build.duplicate()
	creator.open()
	creator.draft.power = 65
	creator.draft.name = "Cancelled"
	creator.close()
	check(lab.athlete.build == prior, "Cancel must preserve the previous athlete")
	lab._reset()
	await settle(lab)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	lab.selected = 2
	lab.motion.begin_approach()
	var bound_seen := false
	var peak := 0.0
	var second_step_grounded := false
	for frame in range(60):
		lab._physics_process(1.0 / 60.0)
		await physics_frame
		if lab.motion.approach_bound:
			bound_seen = true
			peak = maxf(peak, lab.player.position.y)
		if lab.motion.jump_charge >= 0.5 and lab.motion.jump_charge < 0.72 and lab.player.is_on_floor():
			second_step_grounded = true
		if lab.motion.jumped:
			break
	check(bound_seen and peak > 0.12, "First step must have a real ballistic bound rather than cosmetic bob")
	check(second_step_grounded, "Bound must land before the short second step")
	lab._reset()
	await settle(lab)
	lab.selected = 1
	lab.motion.begin_approach()
	for frame in range(20):
		lab._physics_process(1.0 / 60.0)
		await physics_frame
		if lab.motion.approach_bound:
			break
	lab.motion.takeoff()
	check(not lab.motion.approach_release_pending and not lab.motion.approach_bound and lab.motion.jumped, "Direct Jump Set launches on release without a bound or buffered plant")
	for frame in range(50):
		lab._physics_process(1.0 / 60.0)
		await physics_frame
		if lab.motion.jumped:
			break
	check(lab.motion.jumped and lab.motion.airborne_action == 1 and lab.player.velocity.y > 0, "Direct Jump Set retains its upward action flight")
	lab._reset()
	await settle(lab)
	lab.selected = 0
	lab.motion.begin_approach()
	for frame in range(20):
		lab._physics_process(1.0 / 60.0)
		await physics_frame
		if lab.motion.jump_charge >= 0.16:
			break
	check(lab.motion.approach_bound, "Timed first-step Receive should occur during the bound")
	lab.motion.takeoff()
	check(lab.motion.jumped and not lab.motion.approach_bound and lab.confirm_window > 0, "Receive must convert a live bound directly to a confirmed dive")
	key.pressed = false
	Input.parse_input_event(key)
	print("CREATOR / BOUND CHECKS: %d passed / %d total" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
