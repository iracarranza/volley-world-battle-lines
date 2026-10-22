extends SceneTree
## Reproducible temporal strips. Columns are real seconds; clocks use actual MoC scales.
const Library = preload("res://scripts/pose_library.gd")
var now := 1000000
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(800, 640)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.hud.ui.hide()
	lab.auto_feed = false
	lab.animation.pose_smoothing = false
	lab.moc.clock = func(): return now
	var records := []
	var times := [0.0, 0.05, 0.12, 0.22, 0.38, 0.60, 1.0]
	for mode in range(4):
		for actor in ["player", "bot"]:
			for action in [0, 3]:
				for severity in [0.0, 1.0]:
					lab._reset()
					lab.moc.set_mode(mode)
					lab.player.position = Vector3(15, 0.8 if action == 3 else 0.0, 20)
					lab.selected = action
					lab.locked_action = action
					lab.armed = true
					lab.motion.jumped = action == 3
					lab.motion.airborne_action = action
					lab.motion.jump_charge = -1
					lab.block_state.start()
					lab.block_state.confirm()
					lab.animation.receive_pose_remaining = 0.42
					var bot = lab.training_bots
					var rig: Dictionary = bot.rigs[0]
					bot.animation.reset()
					bot.actors[0].position = lab.player.position
					bot.actors[0].rotation.y = 0
					bot.actors[0].visible = actor == "bot"
					lab.player.visible = actor == "player"
					var evidence := {"hit": true, "charge_match": {"severity": severity}, "block_response": {"severity": severity, "side": 0.6}}
					var actor_id := "player" if actor == "player" else "training_bot_0"
					var event := {"id": "%d-%s-%d-%s" % [mode, actor, action, severity], "actor": actor_id, "action": action, "physical_hit": true, "incoming_velocity": Vector3(0,-6,24), "outgoing_velocity": Vector3(0,8,-10), "charge": 0.8, "charge_match": evidence.charge_match, "block_response": evidence.block_response}
					if actor == "player" and lab.animation.has_method("on_contact"):
						lab.animation.on_contact(event)
					else:
						bot.animation.contact(rig, action, Vector3(0,1,-0.6))
						# The same snapshot can drive old and new implementations for before/after capture.
						bot.animation.state_for(rig.body)["contact_evidence"] = evidence
					lab.moc.begin(event)
					var strip := Image.create(400*times.size(), 320, false, Image.FORMAT_RGBA8)
					var real_age := 0.0
					var actor_age := 0.0
					var row := {"mode": mode, "actor": actor, "action": action, "severity": severity, "samples": []}
					for column in range(times.size()):
						while real_age < float(times[column])-0.00001:
							var dt := minf(0.01, float(times[column])-real_age)
							var scale: float = lab.moc.actor_scale(actor_id) if actor == "player" else lab.moc.bot_scale(actor_id)
							actor_age += dt*scale
							lab.animation.tick_action_clocks(dt*scale)
							lab.block_state.tick(dt*scale)
							if actor == "bot": bot.animation.update(rig, dt*scale, {"action": action, "planned": true, "airborne": action == 3, "block_age": actor_age})
							real_age += dt
							now += roundi(dt*1000000)
						if actor == "player": lab.animation.update()
						else: bot.animation.update(rig, 0, {"action": action, "planned": true, "airborne": action == 3, "block_age": actor_age})
						lab.camera.position = lab.player.position + Vector3(3.2, 1.8, -3.2)
						lab.camera.look_at(lab.player.position+Vector3(0,1.2,0))
						await process_frame
						await RenderingServer.frame_post_draw
						var shot := root.get_texture().get_image()
						shot.resize(400, 320)
						strip.blit_rect(shot, Rect2i(0,0,400,320), Vector2i(column*400,0))
						row.samples.append({"real_seconds": real_age, "actor_seconds": actor_age, "pose": Library.read_rig(lab.body if actor == "player" else rig.body)})
					strip.save_png("res://artifacts/motion-%s-%d-%d-%d.png" % [actor, action, int(severity), mode])
					records.append(row)
	var file := FileAccess.open("res://artifacts/contact-motion.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records))
	lab.queue_free()
	await process_frame
	quit()
