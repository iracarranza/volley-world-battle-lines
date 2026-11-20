extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1100,800)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.ball_active = false
	lab.locked_action = 0
	lab.selected = 0
	lab.armed = true
	lab.camera_rig.facing_yaw = 0
	lab.aim = lab.player.position + Vector3.FORWARD * 10
	lab.hud.ui.hide()
	lab.camera.position = lab.player.position + Vector3(3.0,2.5,-4)
	lab.camera.look_at(lab.player.position + Vector3(0,1,-0.4))
	for entry in [["neutral",Vector2.ZERO,0.02],["push",Vector2.ZERO,0.4],["forward",Vector2(0,1),0.35],["right",Vector2(1,0),0.35],["left",Vector2(-1,0),0.35]]:
		lab.receive_plant.begin(0,0)
		lab.receive_plant.age = entry[2]
		lab.receive_plant.lean = entry[1]
		for i in range(20):
			lab.animation.update()
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/receive-plant-%s.png" % entry[0])
	lab.queue_free()
	await process_frame
	quit()
