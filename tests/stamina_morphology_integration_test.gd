extends "res://tests/support/test_case.gd"
const Hint := preload("res://scripts/trajectory_preview.gd")
func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	lab.athlete.build = {"height":1.86,"span":1.86*1.2,"wingspan_ratio":1.2,"stride_ratio":1.0,"power":65,"speed":65,"accuracy":65,"endurance":65}
	lab.athlete.trait_ids.clear()
	lab.athlete.gameplay_effects.clear()
	lab._reset()
	var bots = lab.training_bots
	var slot: int = bots.summon_generic(false,1,{1:0},false)
	bots.athlete_for(slot).build = lab.athlete.build.duplicate(true)
	bots.set_execution_action(slot,0)
	var player_shape: Dictionary = lab._raw_hurtbox_definition(0)
	var bot_shape: Dictionary = bots.contact_shape(slot)
	lab.pepper.partner = 0
	lab.pepper.stage = 0
	lab.pepper.athlete_for(0).build = lab.athlete.build.duplicate(true)
	var pepper_shape: Dictionary = lab.pepper.shape()
	check(player_shape.center.is_equal_approx(bot_shape.center) and player_shape.center.is_equal_approx(pepper_shape.center),"Player, bot and Pepper use identical morphology-derived platform centers")
	check(player_shape.size.is_equal_approx(bot_shape.size) and player_shape.size.is_equal_approx(pepper_shape.size),"All receiving paths share anatomical reach")
	lab.pepper.partner = -1
	lab.ball_active = true
	lab.armed = true
	lab.locked_action = 0
	lab.locked_charge = 0.65
	lab.ball.position = lab.player.position+Vector3(0,0.6,-0.4)
	lab.ball_velocity = Vector3(0,-4,8)
	lab.ball_shot = {"kind":"set","charge":0.2}
	lab.camera_rig.update_aim()
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration-0.2
	var predicted := Hint.predict(lab)
	var stamina: float = lab.athlete.stamina
	lab._contact()
	check(not predicted.is_empty() and lab.ball_velocity.distance_to(predicted.velocity) < 0.0001,"Morphed receiver preview matches actual contact response")
	check(is_equal_approx(stamina-lab.athlete.stamina,20),"Long-arm contact pays fifteen plus five exactly once")
	check(lab.athlete.last_stamina_cost.base == 15 and is_equal_approx(lab.athlete.last_stamina_cost.wingspan,5),"Contact cost breakdown remains inspectable")
	lab._reset()
	lab.player.position = Vector3(15,0.03,20)
	for frame in range(8):
		lab.motion.tick(1.0/60,1)
		await physics_frame
	lab.athlete.stamina = 60
	key(KEY_W,true)
	await process_frame
	for frame in range(60):
		lab.motion.tick(1.0/60,1)
		await physics_frame
	key(KEY_W,false)
	check(absf(lab.athlete.stamina-59) < 0.15,"Actual ordinary locomotion spends three and regenerates two per second")
	key(KEY_SHIFT,true)
	key(KEY_W,true)
	await process_frame
	lab.athlete.stamina = 60
	for frame in range(60):
		lab.motion.tick(1.0/60,1)
		await physics_frame
	key(KEY_SHIFT,false)
	key(KEY_W,false)
	check(absf(lab.athlete.stamina-47) < 0.15,"Actual Sprint spends fifteen total rather than stacking walking")
	lab.queue_free()
	await process_frame
	print("STAMINA/MORPHOLOGY INTEGRATION: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
