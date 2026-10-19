extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var menu = lab.hud.moc_menu
	menu.toggle()
	check(menu.panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Menu opens with usable cursor")
	menu.mode.select(1)
	menu.mode.item_selected.emit(1)
	menu.speed.value = 25
	menu.duration.value = 350
	lab.moc.begin({"action":2,"physical_hit":true,"actor":"player"})
	check(is_equal_approx(lab.moc.simulation_scale(),0.25) and is_equal_approx(lab.moc.last_event.duration_seconds,0.35),"Sliders tune the actual contact resolver")
	menu.ball.button_pressed = false
	check(lab.moc.simulation_scale() == 1 and lab.moc.actor_scale("player") == 0.25,"Ball toggle leaves acting athlete slowdown independent")
	menu.ball.button_pressed = true
	menu.actor.button_pressed = false
	check(lab.moc.simulation_scale() == 0.25 and lab.moc.actor_scale("player") == 1,"Athlete toggle leaves ball slowdown independent")
	menu.mode.select(2)
	menu.mode.item_selected.emit(2)
	check(not lab.moc.active and lab.moc.simulation_scale() == 1,"Off cancels the effect immediately")
	lab._reset()
	check(lab.moc.tuned_speed == 0.25 and lab.moc.tuned_duration == 0.35,"Lab reset preserves tuning")
	menu = null
	lab.queue_free()
	await process_frame
	print("MOC MENU: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
