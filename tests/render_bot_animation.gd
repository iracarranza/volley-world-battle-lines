extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.hud.ui.hide()
	var bots = lab.training_bots
	var rig: Dictionary = bots.rigs[1]
	bots.actors[1].position = Vector3(15, 0, 20)
	bots.actors[1].visible = true
	bots.actors[1].rotation.y = 0
	lab.camera.position = Vector3(17, 2.6, 16.5)
	lab.camera.look_at(Vector3(15, 1.3, 20))
	for phase in ["gather", "contact", "extend"]:
		if phase == "gather":
			bots.animation.update(rig, 0.1, {"action": 1, "planned": true, "remaining": 0.02})
		elif phase == "contact":
			bots.animation.contact(rig, 1, Vector3(0, 2.2, 0))
			bots.animation.update(rig, 0)
		else:
			bots.animation.update(rig, 0.23)
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/rally-bot-set-%s.png" % phase)
	lab.queue_free()
	await process_frame
	quit()
