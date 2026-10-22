extends SceneTree
# Rough per-frame cost of a map rally: godot --headless --path . --script res://tests/profile_rally.gd
func _initialize() -> void: call_deferred("run")
var totals := {}
func timed(key: String, callable: Callable) -> void:
	var start := Time.get_ticks_usec()
	callable.call()
	totals[key] = float(totals.get(key, 0.0)) + float(Time.get_ticks_usec() - start)
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.inventory.enabled = false
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var bots = lab.training_bots
	lab._reset()
	lab.select_net(1)
	for slot in range(bots.settings.size()): bots.dismiss(slot)
	for action in [0,1,2]:
		bots.summon(true,1,action,action+1)
		bots.summon(false,1,action,action+1)
	lab.player.position = lab.court_center+Vector3(0,0.03,lab.court_half_depth+0.4)
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab.serve.press()
	lab.serve.basic_strike()
	var frames := 0
	var contacts_before: int = bots.total_contacts
	for frame in range(900):
		if not lab.ball_active:
			lab.serve.press()
			lab.serve.basic_strike()
		timed("physics_process", func(): lab._physics_process(1.0 / 60.0))
		timed("process", func(): lab._process(1.0 / 60.0))
		frames += 1
	print("frames ", frames, " bot contacts ", bots.total_contacts - contacts_before, " nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " physics objects ", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	for key in totals:
		print("%-18s %.3f ms/frame" % [key, float(totals[key]) / 1000.0 / float(frames)])
	# Isolated costs of the pieces a frame runs
	var pieces := {}
	var repeat := 120
	for name in ["bots_tick_motion", "animation_update", "contact_preview", "hurtbox_visual", "activities_tick", "camera_update", "ball_tick"]:
		var start := Time.get_ticks_usec()
		for i in range(repeat):
			match name:
				"bots_tick_motion": bots.tick_motion(1.0 / 60.0)
				"animation_update": lab.animation.update()
				"contact_preview": lab._update_contact_preview()
				"hurtbox_visual": lab._update_hurtbox_visual(1.0 / 60.0)
				"activities_tick": lab.activities.tick(1.0 / 60.0)
				"camera_update": lab.camera_rig.update(1.0 / 60.0)
				"ball_tick": if lab.ball_active: lab._tick_ball(1.0 / 60.0)
		pieces[name] = float(Time.get_ticks_usec() - start) / 1000.0 / float(repeat)
	for key in pieces:
		print("%-18s %.3f ms each" % [key, pieces[key]])
	quit()
