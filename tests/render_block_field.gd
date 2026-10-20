extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.player.position = Vector3(15,0.8,20)
	lab.camera_rig.view_yaw = 0.5
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.view_pitch = 0.12
	lab.debug_volumes_visible = true
	lab.motion.jumped = true
	lab.motion.airborne_action = 3
	lab.selected = 3
	lab.begin_passive_block()
	lab.animation.update()
	lab.camera_rig.update(2)
	for age in [-1.0,0.0,0.25,0.5]:
		lab.block_state.confirmation_age = age
		lab._update_hurtbox_visual(0)
		lab.hud.update()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/block-field-%d.png"%roundi(age*100))
	lab.queue_free()
	await process_frame
	quit()
