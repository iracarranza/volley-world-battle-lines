extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.ball_active = true
	lab.armed = true
	lab.locked_action = 0
	lab.begin_auto_preparation(0)
	lab.ball_shot = {"kind":"serve","charge":0.6}
	lab.ball.position = lab.player.position+Vector3(0,2,-2)
	lab.ball_velocity = Vector3(0,-5,10)
	lab.auto_preparation.tick(0.4,lab.athlete,lab.ball_shot,lab.ball_velocity)
	lab.camera_rig.update_aim()
	lab.camera_rig.update(2)
	lab.hud.update()
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/auto-charge.png")
	lab.queue_free()
	await process_frame
	quit()
