extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	if "--avi" in OS.get_cmdline_user_args():
		lab.body_type = "Avi"
		lab._rebuild_visual()
	lab.locked_action = 0
	lab.selected = 0
	lab.locked_charge = 0.7
	lab.armed = true
	lab.ball_active = false
	var shape: Dictionary = lab._raw_hurtbox_definition(0)
	var sample: Vector3 = shape.center
	if "--reaching" in OS.get_cmdline_user_args():
		sample = Vector3(0, shape.center.y, -shape.forward_reach * 0.8)
	elif "--off-axis" in OS.get_cmdline_user_args():
		sample = Vector3(shape.side_reach * 0.75, shape.center.y, -shape.forward_reach * 0.18)
	elif "--moving" in OS.get_cmdline_user_args():
		lab.player.velocity = Vector3(2, 0, 0)
	lab.ball_active = true
	lab.ball.position = lab.player.position + sample
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab._confirm_action()
	lab.hud.update()
	lab.camera.position = lab.player.position + Vector3(3.5, 2.7, -4.5)
	lab.camera.look_at(lab.player.position + Vector3(0, 1.0, -0.35))
	await process_frame
	await RenderingServer.frame_post_draw
	var suffix := ""
	for option in ["avi", "reaching", "off-axis", "moving"]:
		if "--" + option in OS.get_cmdline_user_args():
			suffix += "-" + option
	root.get_texture().get_image().save_png("res://artifacts/receive-platform" + suffix + ".png")
	quit()
