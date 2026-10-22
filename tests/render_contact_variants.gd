extends SceneTree
## Rows cover handedness/proportion extremes; columns sample anticipation through recovery.
const Store := preload("res://scripts/athlete_store.gd")
const Spike := preload("res://scripts/spike_stage.gd")
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
	for hand in ["Left", "Right"]:
		for tall in [false, true]:
			var config := Store.blank()
			config.height = 2.05 if tall else 1.55
			config.dominant_hand = hand
			Store.set_proportions(config, 1.2 if tall else 0.8, 0.8 if tall else 1.2)
			lab.apply_created_athlete(config)
			for action in [0,2,3]:
				lab._reset()
				lab.player.position = Vector3(15, 0.8 if action != 0 else 0.0, 20)
				lab.aim = lab.player.position+Vector3(0,0,-3)
				lab.selected = action
				lab.locked_action = action
				lab.armed = true
				lab.motion.jumped = action != 0
				lab.motion.airborne_action = action
				var times := [-0.2, 0.0, 0.07, 0.15, 0.25, 0.38, 0.6]
				var strip := Image.create(400*times.size(),320,false,Image.FORMAT_RGBA8)
				lab.animation.on_contact({"actor":"player", "action":action, "physical_hit":true, "charge_match":{"severity":1.0}, "block_response":{"severity":1.0,"side":-0.8 if hand == "Left" else 0.8}})
				for column in range(times.size()):
					lab.animation.contact_age = times[column]
					lab.animation.update()
					if action == 2:
						Spike.apply(lab.body, times[column], -1.0 if hand == "Left" else 1.0, 0.8, "Power swing", {"ball_local":Vector3(-0.2 if hand == "Left" else 0.2,2.3,-0.5)})
					lab.camera.position = lab.player.position+Vector3(3.2,1.8,-3.2)
					lab.camera.look_at(lab.player.position+Vector3(0,1.2,0))
					await process_frame
					await RenderingServer.frame_post_draw
					var shot := root.get_texture().get_image()
					shot.resize(400,320)
					strip.blit_rect(shot,Rect2i(0,0,400,320),Vector2i(column*400,0))
				strip.save_png("res://artifacts/variant-%s-%s-%d.png" % [hand,"tall" if tall else "short",action])
	lab.queue_free()
	await process_frame
	quit()
