extends SceneTree
const MoC := preload("res://scripts/moment_of_contact.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.hud.moc_menu.mode.item_selected.emit(MoC.Mode.TRAJECTORY_STEERING)
	lab.player.position = Vector3(15,0.03,20)
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.view_yaw = 0.3
	lab.camera_rig.update(2)
	lab.ball_active = true
	lab.ball.position = lab.player.position+Vector3(0,2.4,-0.5)
	lab.ball_velocity = Vector3(0,5,-18)
	var fixed := Time.get_ticks_usec()
	lab.moc.clock = func(): return fixed
	lab.moc.begin({"id":"render","actor":"player","action":2,"physical_hit":true,"quality":1,"outgoing_velocity":lab.ball_velocity,"steering":{"facing":Vector3.FORWARD}})
	for amount in [0.0,0.8]:
		lab.moc.steer(amount,Vector3.RIGHT)
		lab._update_contact_preview()
		lab.hud.update()
		lab.hud.athlete_hud.update_hp_feedback(0.1)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/moc-steering-%d.png"%roundi(amount*100))
	lab.hud.moc_menu.toggle()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/moc-steering-menu.png")
	lab.queue_free()
	await process_frame
	quit()
