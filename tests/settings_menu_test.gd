extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func escape(lab: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	lab._input(event)
func key(lab: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	lab._unhandled_input(event)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await physics_frame
	var hud = lab.hud
	var menu = hud.settings_menu
	check(menu != null and not menu.is_open(), "The settings menu exists and starts closed")
	# The ribbon is gone: no row of buttons is left on the HUD itself
	var loose := 0
	for child in hud.ui.get_children():
		if child is HBoxContainer:
			for inner in child.get_children():
				if inner is Button: loose += 1
	check(loose == 0, "No ribbon of buttons is left along the top of the HUD")
	# Everything that was in it is in the menu
	for pair in [["build", hud.build_button], ["boxes", hud.debug_button], ["tilt", hud.rotate_button], ["MoC", hud.moc_button], ["auto feed", hud.auto_feed_button], ["info panels", hud.menus_button]]:
		check(menu.panel.is_ancestor_of(pair[1]), "The %s control is in the settings menu" % pair[0])
	var labels := []
	for button in menu.panel.find_children("*", "Button", true, false):
		labels.append(button.text)
	for needle in ["TITLE", "FEED BALL", "RESET", "CREATE", "HIDE HUD", "BOTS", "CONTACT SETTINGS", "PERFORMANCE"]:
		var found := false
		for text in labels:
			if String(text).contains(needle): found = true
		check(found, "%s is in the settings menu" % needle)
	# Esc opens and closes it
	escape(lab)
	check(menu.is_open() and menu.panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc opens the settings menu and frees the cursor")
	lab.contacts = 5
	key(lab, KEY_T)
	check(lab.contacts == 5, "The game takes no keys while the menu is open")
	hud.debug_button.pressed.emit()
	check(not lab.debug_volumes_visible and hud.debug_button.text.contains("OFF"), "A moved control still works (boxes)")
	hud.debug_button.pressed.emit()
	hud.rotate_button.pressed.emit()
	check(not lab.rotate_hurtboxes, "...and the tilt toggle")
	hud.rotate_button.pressed.emit()
	hud.auto_feed_button.pressed.emit()
	check(lab.auto_feed and hud.auto_feed_button.text == "AUTO FEED: ON", "...and auto feed")
	hud.auto_feed_button.pressed.emit()
	escape(lab)
	check(not menu.is_open() and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"), "Esc closes it and recaptures the cursor")
	key(lab, KEY_T)
	check(lab.contacts == 0, "The game takes keys again once it is closed")
	# Contact settings open from the menu and the menu gets out of the way
	menu.set_open(true)
	for button in menu.panel.find_children("*", "Button", true, false):
		if String(button.text) == "CONTACT SETTINGS":
			button.pressed.emit()
	check(not menu.is_open() and hud.moc_menu.panel.visible, "Contact settings open from the menu, which closes")
	hud.moc_menu.toggle()
	# A vision section is part of it, off by default
	var vision := preload("res://scripts/vision_focus.gd")
	check(hud.vision_menu != null and not vision.enabled and not hud.vision_menu.master.button_pressed, "The vision focus settings are in the menu, off by default")
	hud.vision_menu.master.button_pressed = true
	check(vision.enabled and not (hud.vision_menu.controls[0] as BaseButton).disabled, "The master switch turns vision focus on and frees its parts")
	hud.vision_menu.master.button_pressed = false
	check(not vision.enabled and (hud.vision_menu.controls[0] as BaseButton).disabled, "...and off again")
	lab.queue_free()
	await process_frame
	print("SETTINGS MENU: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
