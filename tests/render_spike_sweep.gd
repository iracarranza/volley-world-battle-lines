extends SceneTree
# The striking shoulder through the sweep, side on: godot --path . --script res://tests/render_spike_sweep.gd
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(420, 560)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	for i in range(8): await process_frame
	for child in lab.get_children():
		if child is CanvasLayer: child.hide()
	var camera := Camera3D.new()
	lab.add_child(camera)
	camera.global_position = lab.player.global_position + Vector3(4.2, 3.2, 0.0)
	camera.look_at(lab.player.global_position + Vector3(0, 3.0, 0))
	camera.make_current()
	lab.player.position.y = 1.2
	lab.motion.jumped = true
	lab.motion.airborne_action = 2
	lab.locked_action = 2
	var strip := Image.create(360 * 5, 360, false, Image.FORMAT_RGBA8)
	var ages := [0.40, 0.45, 0.50, 0.55, 0.60]
	for index in range(ages.size()):
		lab.animation.spike_air_time = 0.3
		lab.animation.spike_flight_time = 0.8
		lab.animation.spike_swing_time = ages[index]
		lab.animation.spike_hit_time = -1.0
		lab.animation.update()
		for i in range(3): await process_frame
		var image := root.get_texture().get_image()
		var tile := image.get_region(Rect2i(140, 90, 130, 130)) # the athlete, enlarged
		tile.resize(360, 360, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(tile, Rect2i(0, 0, 360, 360), Vector2i(360 * index, 0))
	strip.save_png("res://artifacts/spike-sweep-strip.png")
	quit()
