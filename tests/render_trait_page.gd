extends SceneTree
# The whole of one trait page as a single picture, stitched from panned captures:
#   godot --path . --script res://tests/render_trait_page.gd -- power
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var page := "power"
	for a in OS.get_cmdline_user_args():
		page = a
	root.size = Vector2i(1200, 760)
	var editor = load("res://scripts/trait_tree_editor.gd").new()
	editor.save_path = "res://data/trait_tree.json"
	root.add_child(editor)
	await process_frame
	editor.show_page(page)
	editor.select("")
	for f in range(6):
		await process_frame
	var book = editor.book
	var width := 0.0
	var height := 0.0
	for node in book.page(page):
		width = maxf(width, float(node.pos[0]) + 24.0 + 132.0 + 24.0)
		height = maxf(height, float(node.pos[1]) + 24.0 + 62.0 + 24.0)
	var rect: Rect2 = editor.canvas.get_global_rect()
	var ratio: float = root.get_texture().get_size().x / float(root.size.x)
	var step := int(rect.size.x) - 80
	var shots := int(ceil(maxf(width - rect.size.x, 0.0) / float(step))) + 1
	var out := Image.create(int(width * ratio), int(height * ratio), false, Image.FORMAT_RGBA8)
	for i in range(shots):
		editor.view_offset = Vector2(-float(step * i), 0.0)
		editor.canvas.queue_redraw()
		for f in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = root.get_texture().get_image()
		var crop := shot.get_region(Rect2i(Vector2i(rect.position * ratio), Vector2i(rect.size * ratio)))
		var at := int(step * i * ratio)
		var paste_w: int = mini(crop.get_width(), out.get_width() - at)
		out.blit_rect(crop, Rect2i(0, 0, paste_w, mini(crop.get_height(), out.get_height())), Vector2i(at, 0))
	out.save_png("res://artifacts/trait-page-%s.png" % page)
	quit()
