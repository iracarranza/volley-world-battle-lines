extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	if "--avi" in OS.get_cmdline_user_args():
		lab.body_type = "Avi"
		lab._rebuild_visual()
		lab.athlete_name = "Avi"
		lab.position_role = "S"
		lab.athlete_level = 4
	lab.athlete.stamina = 8 if "--low" in OS.get_cmdline_user_args() else 72
	lab.athlete.hp = 0 if "--low" in OS.get_cmdline_user_args() else 84
	lab.station.earned_xp = 35
	lab.selected = 2
	lab.locked_action = 2
	lab.locked_charge = 0.4 if "--half" in OS.get_cmdline_user_args() else 1.0
	lab.armed = true
	lab.animation.update()
	lab.camera_rig.update(2)
	lab.hud.update()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/rally-hud-alternate.png" if "--avi" in OS.get_cmdline_user_args() else "res://artifacts/rally-hud.png")
	print("HUD capture: res://artifacts/rally-hud.png")
	lab.queue_free()
	await process_frame
	quit()
