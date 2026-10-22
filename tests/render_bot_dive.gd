extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(600,500)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.hud.ui.hide()
	lab.player.hide()
	var bots = lab.training_bots
	bots.settings[0].enabled = true
	bots.settings[0].moves = true
	bots.settings[0].tracking_accuracy = 100
	bots.settings[0].charge_accuracy = 100
	bots.actors[0].position = Vector3(0,0,5)
	bots.settings[0].fixed_position = bots.actors[0].position
	bots.actors[0].rotation.y = 0
	bots.actors[0].show()
	lab.ball_active = true
	lab.ball.position = Vector3(2.5,2.5,4.5)
	lab.ball_velocity = Vector3(0,-7,0)
	lab.ball_shot = {"kind":"attack","charge":0.3}
	bots.replan()
	var strip := Image.create(1800,500,false,Image.FORMAT_RGBA8)
	var elapsed := 0.0
	for column in range(3):
		var until: float = [0.1,0.3,0.9][column]
		while elapsed < until:
			if lab.ball_active: lab._tick_ball(1.0/120)
			else: bots.tick_motion(1.0/120)
			elapsed += 1.0/120
		lab.camera.position = bots.actors[0].position+Vector3(3,2,-3)
		lab.camera.look_at(bots.actors[0].position+Vector3.UP*0.65)
		await process_frame
		await RenderingServer.frame_post_draw
		strip.blit_rect(root.get_texture().get_image(),Rect2i(0,0,600,500),Vector2i(column*600,0))
	strip.save_png("res://artifacts/bot-receive-dive.png")
	lab.queue_free()
	await process_frame
	quit()
