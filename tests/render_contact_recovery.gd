extends SceneTree
## Existing recovery ownership and the confirmation-only block press, without a contact recoil.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(800,640)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.hud.ui.hide()
	lab.animation.pose_smoothing = false
	for name in ["press", "shrug", "blown_away", "knocked_away", "collapse"]:
		lab._reset()
		lab.player.position = Vector3(15,0.8 if name == "press" else 0.0,20)
		lab.aim = lab.player.position+Vector3(0,0,-3)
		lab.selected = 3 if name == "press" else 0
		lab.locked_action = lab.selected
		lab.armed = true
		lab.motion.jumped = name == "press"
		lab.motion.airborne_action = lab.selected
		lab.animation.update()
		var times := [0.0,0.03,0.06,0.12,0.25,0.4,0.6]
		if name == "press":
			lab.block_state.start()
			lab.block_state.confirm()
		else:
			lab.animation.on_receive_resolved({"actor":"player", "recovery":name, "receive_outcome":{"platform_coord":Vector3(0.4,0,0), "penalty_factor":1.0}})
			lab.animation.on_contact({"actor":"player", "action":0, "physical_hit":true, "charge_match":{"severity":1.0}})
			var duration: float = lab.animation.floor_recovery_total()
			times = [0.0,duration*0.12,duration*0.25,duration*0.45,duration*0.65,duration*0.85,duration]
		var strip := Image.create(400*times.size(),320,false,Image.FORMAT_RGBA8)
		for column in range(times.size()):
			lab.animation.contact_age = times[column] if name != "press" else -1.0
			if name == "press": lab.block_state.confirmation_age = times[column]
			else: lab.animation.floor_recovery_time = times[column]
			lab.animation.update()
			lab.camera.position = lab.player.position+Vector3(3.2,1.8,-3.2)
			lab.camera.look_at(lab.player.position+Vector3(0,1.0,0))
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.resize(400,320)
			strip.blit_rect(shot,Rect2i(0,0,400,320),Vector2i(column*400,0))
		strip.save_png("res://artifacts/contact-%s.png" % name)
	lab.queue_free()
	await process_frame
	quit()
