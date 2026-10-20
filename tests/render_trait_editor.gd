extends SceneTree
# godot --path . --script res://tests/render_trait_editor.gd [-- --page=power]
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(3400, 760)
	var editor = load("res://scripts/trait_tree_editor.gd").new()
	editor.save_path = "res://data/trait_tree.json"
	root.add_child(editor)
	await process_frame
	editor.show_page("power")
	editor.select("pow_tooler")
	for i in range(4):
		await process_frame
	root.get_texture().get_image().save_png("res://artifacts/pow-tree-full.png")
	quit()
