extends SceneTree
# The title screen with its live bot-rally backdrop: godot --path . --script res://tests/render_title.gd
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1500, 900)
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	for second in range(0, 96, 6):
		var until := Time.get_ticks_msec() + 6000
		while Time.get_ticks_msec() < until:
			await process_frame
		root.get_texture().get_image().save_png("res://artifacts/title-rally-%02d.png" % second)
	quit()
