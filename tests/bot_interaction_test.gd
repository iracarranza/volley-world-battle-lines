extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.training_bots.toggle(0,true)
	lab.player.position = lab.training_bots.actors[4].position+Vector3.RIGHT*0.5
	var interact := InputEventKey.new()
	interact.keycode = KEY_I
	interact.pressed = true
	lab._unhandled_input(interact)
	await process_frame
	await process_frame
	check(lab.bot_menu.panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Nearby I opens the lab helper settings with usable cursor")
	check(lab.bot_menu.selected_slot == 4,"Specific away bot is selected in the inspector")
	check(not lab.station.running() and not lab.drills.running(),"Nearby bot interaction does not start an unrelated drill")
	lab.queue_free()
	await process_frame
	print("BOT INTERACTION: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
