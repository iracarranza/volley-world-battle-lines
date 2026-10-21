extends SceneTree
# The whole map from above: godot --path . --script res://tests/render_map_overview.gd -- name
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var out := "map-overview"
	for a in OS.get_cmdline_user_args():
		out = a
	root.size = Vector2i(1400, 1400)
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	for i in range(12): await process_frame
	lab.set_process(false)
	lab.set_physics_process(false)
	for child in lab.get_children():
		if child is CanvasLayer: child.hide()
	lab.camera.current = false
	lab.overview_camera.current = true
	for i in range(20): await process_frame
	root.get_texture().get_image().save_png("res://artifacts/%s.png" % out)
	quit()
