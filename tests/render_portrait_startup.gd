extends "res://tests/support/test_case.gd"
## Regression: the first map HUD must show the complete cached Feli portrait.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	var hud = lab.hud.athlete_hud
	for frame in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	capture.save_png("res://artifacts/portrait-startup.png")
	# Count the default Feli face in the final canvas, not just its source viewport.
	# This caught a complete source texture displaying a partial portrait in the HUD.
	var face_pixels := 0
	for y in range(capture.get_height() - 155, capture.get_height() - 95):
		for x in range(70, 130):
			var color := capture.get_pixel(x, y)
			if color.r > 0.59 and color.g > 0.35 and color.b < 0.63 and color.r > color.b * 1.4:
				face_pixels += 1
	check(face_pixels > 200, "The final HUD contains the Feli face on initial map load")
	check(hud.portrait.texture is ImageTexture, "Portrait owns a stable snapshot")
	check(hud.portrait_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Portrait stops rendering after its snapshot")
	lab.queue_free()
	await process_frame
	print("PORTRAIT STARTUP: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
