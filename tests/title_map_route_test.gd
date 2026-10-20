extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	var enter: Button
	var lab_button: Button
	for button in title.find_children("*","Button",true,false):
		if button.text.contains("ENTER MAP"): enter = button
		if button.text.contains("CONTACT LAB"): lab_button = button
	check(enter != null and lab_button != null,"Title exposes Map and Contact Lab destinations")
	if enter:
		enter.pressed.emit()
		await scene_changed
		await process_frame
		check(current_scene.scene_file_path == "res://map_graybox.tscn","Enter Map button opens the playable map scene")
		check(current_scene.serve != null and current_scene.drills != null and current_scene.moc != null,"Map destination retains serve, drill and MoC systems")
	check(current_scene.training_bots.count_net_side(1,false) == 4 and current_scene.training_bots.count_net_side(1,true) == 4,"Interactive Map entry loads the default Net 2 lineup")
	current_scene.queue_free()
	await process_frame
	print("TITLE MAP ROUTE: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
