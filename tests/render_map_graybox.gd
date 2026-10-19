extends SceneTree
# Screenshots of the lab-hosted map graybox:
#   godot --path . --script res://tests/render_map_graybox.gd [-- --overview | --tower | --trainer | --station | --pit | --base]
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1500, 900)
	var map = load("res://map_graybox.tscn").instantiate()
	root.add_child(map)
	for i in range(10):
		await physics_frame
	var args := OS.get_cmdline_user_args()
	var name := "map-graybox"
	if "--overview" in args:
		map.overview = true
		map.overview_camera.current = true
		name += "-overview"
	elif "--tower" in args:
		map.player.position = Vector3(-46.0, 0.03, 26.5)
		map.view_yaw = PI * 0.15
		name += "-tower"
	elif "--trainer" in args:
		map.player.position = map.drills.spike_start_world() + Vector3(0, 0.03, 1.0)
		name += "-trainer"
	elif "--station" in args:
		map.player.position = map.station.start_world() + Vector3(0, 0.03, 0.0)
		name += "-station"
	elif "--pit" in args:
		map.player.position = Vector3(-18.0, 0.03, 18.0)
		name += "-pit"
	else:
		name += "-base"
	for i in range(40):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
	quit()
