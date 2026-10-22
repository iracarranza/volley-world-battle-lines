extends SceneTree
# The builder's Build tab with the Wingspan / Stride sliders: godot --path . --script res://tests/render_morphology.gd
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1500, 900)
	var Store = load("res://scripts/athlete_store.gd")
	Store.roster = []
	Store.selected = -1
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	await process_frame
	menu.wingspan_slider.value = 1.14
	for i in range(8):
		await process_frame
	root.get_texture().get_image().save_png("res://artifacts/morphology-sliders.png")
	quit()
