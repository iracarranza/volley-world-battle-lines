extends "res://tests/support/test_case.gd"
const Clock := preload("res://scripts/moment_of_contact.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var clock := Clock.new()
	root.add_child(clock)
	for mode in [Clock.Mode.CURRENT_SLOWDOWN, Clock.Mode.TUNED_SLOWDOWN]:
		clock.set_mode(mode)
		clock.begin({"action":2,"physical_hit":true,"sweet":true,"incoming_velocity":Vector3(0,-12,0),"outgoing_velocity":Vector3(0,0,-24)})
		check(clock.active and Engine.time_scale == 1.0 and clock.simulation_scale() == 0.60,"Both modes use 60% speed simulation")
		check(clock.simulation_scale() > 0.0,"Neither mode freezes physics, poses, or inputs")
		var simulated := 0.0
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 70000:
			await physics_frame
			simulated += 1.0 / Engine.physics_ticks_per_second * clock.simulation_scale()
		check(simulated > 0.0 and simulated < 0.15,"Physics continues with slowed elapsed time")
		while clock.active:
			await process_frame
		check(Engine.time_scale == 1.0,"Clock restores normal simulation speed")
		clock.begin({"action":2,"physical_hit":true,"sweet":true,"incoming_velocity":Vector3(0,-12,0),"outgoing_velocity":Vector3(0,0,-24)})
		check(clock.active,"Prior spike slowdown is active before set")
		clock.begin({"action":1,"physical_hit":true,"sweet":true,"incoming_velocity":Vector3(0,-12,0),"outgoing_velocity":Vector3(0,12,0)})
		check(not clock.active and Engine.time_scale == 1.0,"Sweet sets cancel prior slowdown and launch at normal speed")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	await physics_frame
	for mode in [Clock.Mode.CURRENT_SLOWDOWN, Clock.Mode.TUNED_SLOWDOWN]:
		for action in range(5):
			lab._reset()
			lab.moc.set_mode(mode)
			lab.ball_active = true
			lab.ball.position = Vector3(0,10,5)
			lab.ball_velocity = Vector3(0,1,-10)
			lab.moc.begin({"action":action,"physical_hit":true,"sweet":true,"incoming_velocity":Vector3(0,-12,0),"outgoing_velocity":lab.ball_velocity})
			var before: Vector3 = lab.ball.position
			var before_time: float = lab.elapsed
			for frame in range(4):
				var prior: Vector3 = lab.ball.position
				lab._physics_process(1.0/60)
				check(lab.ball.position != prior,"Ball advances on every contact frame, action %d mode %d" % [action,mode])
			var slowed := action != 1 if mode == Clock.Mode.CURRENT_SLOWDOWN else action == 2
			var expected := 0.6 if slowed else 1.0
			check(is_equal_approx(lab.elapsed-before_time,4.0/60),"World clock stays at normal speed")
			check(is_equal_approx(before.z-lab.ball.position.z,10*4.0/60*expected),"Outgoing ball travels continuously at exact requested speed")
			check(lab.moc.actor_scale("unrelated_bot") == 1.0,"Other athletes never slow")
			check(Engine.time_scale == 1,"Engine clock never changes on contact")
	lab._reset()
	lab.moc.set_mode(Clock.Mode.CURRENT_SLOWDOWN)
	lab.moc.begin({"action":2,"actor":"training_bot_2","physical_hit":true,"sweet":true,"incoming_velocity":Vector3(0,-12,0),"outgoing_velocity":Vector3(0,0,-24)})
	check(lab.moc.actor_scale("training_bot_2") == 0.6 and lab.moc.actor_scale("player") == 1.0,"Bot contact only slows that bot and ball")
	var bots = lab.training_bots
	bots.motion.begin(0,bots.actors[0],Vector3(0,1,3),1.0,false,lab.GRAVITY)
	bots.motion.begin(2,bots.actors[2],Vector3(0,1,4),1.0,false,lab.GRAVITY)
	bots.tick_motion(0.1)
	check(is_equal_approx(bots.motion.plans[0].elapsed,0.1),"Unrelated bot motion progresses at full speed")
	check(is_equal_approx(bots.motion.plans[2].elapsed,0.06),"Acting bot motion progresses at 60% speed")
	lab.hud.toggle_moc_mode()
	lab.hud.toggle_moc_mode()
	check(lab.moc.mode == Clock.Mode.NONE and lab.hud.moc_button.text.contains("OFF"),"Toolbar cycles to No MoC")
	lab.moc.begin({"action":2,"actor":"player","physical_hit":true,"sweet":true,"incoming_velocity":Vector3(0,-12,0),"outgoing_velocity":Vector3(0,0,-24)})
	check(not lab.moc.active and lab.moc.simulation_scale() == 1 and lab.moc.actor_scale("player") == 1,"No MoC bypasses all contact slowdown")
	check(lab.moc.last_event.duration_seconds == 0,"No MoC reports zero duration while retaining impact visuals")
	check(lab.impact_visual.shell_meshes.size() == 3,"Impact meshes are prebuilt")
	var mesh_ids := []
	for mesh in lab.impact_visual.shell_meshes.values():
		mesh_ids.append(mesh.get_instance_id())
	lab.impact_visual.tick(0.01)
	var mesh_ids_after := []
	for mesh in lab.impact_visual.shell_meshes.values():
		mesh_ids_after.append(mesh.get_instance_id())
	check(mesh_ids == mesh_ids_after,"Impact animation reuses mesh resources")
	lab.moc.clear()
	lab.queue_free()
	clock.queue_free()
	print("MOC SLOWDOWN: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
