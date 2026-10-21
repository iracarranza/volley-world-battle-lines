extends SceneTree
# The Drill Lab row from above and from the player's start: godot --path . --script res://tests/render_drill_lab.gd
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1500, 600)
	var lab = load("res://drill_lab.tscn").instantiate()
	root.add_child(lab)
	for i in range(10): await process_frame
	for child in lab.get_children():
		if child is CanvasLayer: child.hide()
	var camera := Camera3D.new()
	lab.add_child(camera)
	camera.global_position = Vector3(0, 52, 62)
	camera.rotation_degrees = Vector3(-62, 0, 0)
	camera.far = 400.0
	camera.fov = 70
	camera.make_current()
	for i in range(5): await process_frame
	root.get_texture().get_image().save_png("res://artifacts/drill-lab-row.png")
	quit()
