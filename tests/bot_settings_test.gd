extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await process_frame
	var bots = lab.training_bots
	check(not lab.hud.bot_panel.visible, "Bot menu starts hidden")
	lab.hud.toggle_bot_menu()
	check(lab.hud.bot_panel.visible, "Bot menu opens")
	bots.toggle(1)
	lab.ball_active = true
	lab.ball.position = Vector3(0, 5, 5)
	lab.ball_velocity = Vector3(0, -1, 0)
	lab.side_contacts[0] = 0
	lab.side_contacts[1] = 0
	bots.replan()
	check(bots.active_action == -1, "Default setter waits for second contact")
	bots.set_contact_order(1, 1)
	check(bots.active_action == 1, "Setter can be assigned first contact")
	lab.player.position = Vector3(4, 0, 5)
	bots.place_at_player(1)
	check(bots.active_action == 1 and bots.motion.plans.has(1), "Static setter attempts a jump despite a distant unreachable flight")
	var fixed: Vector3 = bots.actors[1].position
	lab.ball.position.x = 4
	bots.replan()
	check(bots.active_action == 1, "Static bot intercepts flight through its box")
	check(bots.actors[1].position == fixed, "Static bot stays fixed")
	bots.reset()
	check(bots.actors[1].position == fixed and not bots.follows_ball[1], "Reset preserves static placement")
	bots.set_following(1, true)
	lab.ball.position.x = 0
	bots.replan()
	check(bots.active_action == 1 and bots.actors[1].position.x == 0, "Tracking resumes after mode change")
	bots.set_contact_order(1, 0)
	lab.side_contacts[0] = 2
	bots.replan()
	check(bots.active_action == 1, "Any contact includes third")
	lab.side_contacts[0] = 3
	bots.replan()
	check(bots.active_action == -1, "Any contact never creates fourth touch")
	if "--render" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rally-bot-settings.png")
	print("BOT SETTINGS: %d checks passed" % checks)
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
