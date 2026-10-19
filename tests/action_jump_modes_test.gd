extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func settle(lab: Node) -> void:
	for frame in range(12):
		lab._physics_process(1.0/60)
		await physics_frame
func prepare(lab: Node,action: int) -> void:
	lab._reset()
	await settle(lab)
	lab.selected = action
	lab.locked_action = action
	lab.locked_charge = 0.7
	lab.armed = true
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	await prepare(lab,0)
	key(KEY_D,true)
	lab.motion.begin_jump()
	check(lab.motion.approach_bound and lab.player.velocity.y > 0,"Receive begins a real small bounding split step")
	check(is_equal_approx(lab.locked_charge,0.7),"Split step preserves charged Receive")
	var peak: float = lab.player.position.y
	for frame in range(90):
		lab._physics_process(1.0/60)
		peak = maxf(peak,lab.player.position.y)
		await physics_frame
	check(peak < 0.12 and not lab.motion.approach_bound,"Split step is smaller than the attack bound and lands")
	check(lab.motion.jump_charge == 1 and not lab.motion.jumped and lab.player.velocity.x > lab.athlete.speed()*0.65,"Receive stays mobile while held; full charge never auto-dives")
	lab.motion.approach_direction = Vector3.BACK
	lab.animation.update()
	check(is_zero_approx(lab.animation.dive_turn_offset()),"Mobile Receive preparation does not pre-turn the body into a dive")
	lab._confirm_action()
	check(lab.motion.jump_charge < 0 and not lab.motion.jumped,"Confirming Receive cancels pending dive and jump charge")
	key(KEY_D,false)
	await prepare(lab,0)
	lab.motion.begin_jump()
	lab.motion.takeoff()
	check(lab.motion.jumped and lab.motion.airborne_action == 0 and lab.confirm_window > 0,"Release during split step dives immediately and auto-confirms")
	await prepare(lab,0)
	lab.motion.begin_jump()
	lab._confirm_action()
	var release := InputEventKey.new()
	release.keycode = KEY_SPACE
	release.pressed = false
	lab._unhandled_input(release)
	await settle(lab)
	check(lab.motion.jump_charge < 0 and not lab.motion.jumped and not lab.motion.approach_release_pending,"Confirmation during split step prevents a queued or release-triggered dive")
	for action in [1,3]:
		await prepare(lab,action)
		key(KEY_D,true)
		lab.motion.begin_jump()
		for frame in range(15):
			lab._physics_process(1.0/60)
			await physics_frame
		check(not lab.motion.approach_bound and not lab.motion.approach_bound_started and lab.player.is_on_floor(),"Set/Block prepare without steps or hops")
		lab._update_preview(false)
		check(not lab.approach_footprints[0].visible,"Direct jumps show no attack approach footprints")
		lab.motion.takeoff()
		var held_speed: float = Vector2(lab.player.velocity.x,lab.player.velocity.z).length()
		check(lab.motion.jumped and lab.motion.airborne_action == action and lab.armed and lab.locked_charge == 0.7,"Direct jump preserves prepared action and charge")
		key(KEY_D,false)
		await prepare(lab,action)
		lab.motion.begin_jump()
		lab.motion.jump_charge = 0.3
		lab.player.velocity = Vector3(4,0,0)
		lab.motion.takeoff()
		check(held_speed > Vector2(lab.player.velocity.x,lab.player.velocity.z).length()*2,"Held movement retains substantially more lateral carry")
	# The post-split acceleration bonus composes with the stat and future trait.
	await prepare(lab,0)
	key(KEY_D,true)
	lab.motion.begin_jump()
	lab.motion.approach_bound = false
	lab.motion.jump_charge = 0.5
	lab.player.velocity = Vector3.ZERO
	lab.athlete.build = lab.athlete.build.duplicate(true)
	lab.athlete.build.statistics = {"acceleration":65}
	lab.motion.tick(1.0/60,1.0)
	var neutral_speed: float = lab.player.velocity.x
	check(is_equal_approx(neutral_speed,lab.athlete.acceleration()*1.15/60),"Post-split movement gets a modest acceleration bonus")
	lab.player.velocity = Vector3.ZERO
	lab.athlete.build.statistics.acceleration = 99
	lab.motion.tick(1.0/60,1.0)
	check(lab.player.velocity.x > neutral_speed,"Acceleration subattribute increases post-split acceleration")
	var book = lab.athlete.Store.trait_book()
	var saved_effects: Dictionary = book.nodes[0].effects.duplicate(true)
	book.nodes[0].effects["stride_speed"] = 20.0
	lab.athlete.trait_ids.assign([str(book.nodes[0].id)])
	lab.player.velocity = Vector3.ZERO
	lab.motion.tick(1.0/60,1.0)
	check(is_equal_approx(lab.player.velocity.x,lab.athlete.acceleration()*1.15*1.2/60),"Future Stride Speed effect composes with Acceleration")
	book.nodes[0].effects = saved_effects
	key(KEY_D,false)
	lab.queue_free()
	await process_frame
	print("ACTION JUMP MODES: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
