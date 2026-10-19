extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1500,1000)
	var store = load("res://scripts/athlete_store.gd")
	store.roster = []
	store.selected = -1
	var menu = load("res://scripts/athlete_menu.gd").new()
	root.add_child(menu)
	var tabs: Array = menu.find_children("*","TabContainer",true,false)
	if not tabs.is_empty():
		tabs[0].current_tab = 1
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/stat-roster-six.png")
	menu.queue_free()
	await process_frame
	quit()
