extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1440,900)
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	await capture("res://artifacts/map-play-title.png")
	title.queue_free()
	await process_frame
	var map = load("res://map_graybox.tscn").instantiate()
	root.add_child(map)
	map.set_process(false)
	map.set_physics_process(false)
	map.player.position = Vector3(-36,0.03,7)
	map.select_net(0)
	map.camera_rig.update_aim()
	map.camera_rig.update(2)
	var bots = map.training_bots
	bots.summon_generic(false,0,{2:1,3:2},true)
	bots.summon_generic(true,0,{1:0,2:1,3:2},true)
	bots.summon_generic(true,2,{1:0,3:2},false)
	map.hud.update()
	await capture("res://artifacts/map-play-net1.png")
	map.open_bot_menu()
	map.bot_menu.open_bot(0)
	await capture("res://artifacts/map-play-bots.png")
	map.queue_free()
	await process_frame
	quit()
