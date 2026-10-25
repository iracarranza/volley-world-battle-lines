extends SceneTree
# The rig drawn each way, in the same pose, and how far the pictures differ:
# godot --path . --script res://tests/render_rig_modes.gd
func _initialize() -> void: call_deferred("capture")
func shot(mode: int, pose: int) -> Image:
	var Visual = load("res://scripts/voli_visual.gd")
	Visual.rig_mode = mode
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	for i in range(6): await process_frame
	for child in lab.get_children():
		if child is CanvasLayer: child.hide()
	var camera := Camera3D.new()
	lab.add_child(camera)
	camera.global_position = lab.player.global_position + Vector3(3.0, 1.5, 2.6)
	camera.look_at(lab.player.global_position + Vector3(0, 1.0, 0))
	camera.make_current()
	lab.animation.pose_smoothing = false
	match pose:
		0: # running with a block ready
			lab.selected = 3
			lab.locked_action = 3
			lab.armed = true
			lab.motion.gait_cycle = 0.3
			lab.player.velocity = Vector3(0, 0, -3.0)
		1: # the other half of the stride
			lab.selected = 1
			lab.locked_action = 1
			lab.armed = true
			lab.motion.gait_cycle = 0.7
			lab.player.velocity = Vector3(0, 0, -4.5)
		2: # a spike swing at its peak
			lab.player.position.y = 1.2
			lab.motion.jumped = true
			lab.motion.airborne_action = 2
			lab.locked_action = 2
			lab.animation.spike_air_time = 0.3
			lab.animation.spike_flight_time = 0.8
			lab.animation.spike_swing_time = 0.5
		3: # a block jump at the top
			lab.player.position.y = 1.0
			lab.motion.jumped = true
			lab.motion.airborne_action = 3
			lab.motion.last_jump_height = 0.55
			lab.animation.jump_air_time = 0.5 * lab.athlete.jump_flight_time(0.55, lab.GRAVITY)
		4: # a ground set pushed out
			lab.last_contact = lab.elapsed - 0.2
			lab.last_contact_result = {"action": 1}
	lab.animation.update()
	for i in range(4): await process_frame
	var image := root.get_texture().get_image().get_region(Rect2i(250, 90, 360, 330))
	lab.queue_free()
	await process_frame
	return image
func difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
	return total / float(a.get_width() * a.get_height() * 3)
func capture() -> void:
	root.size = Vector2i(640, 480)
	var names := ["run, block ready", "run, set ready", "spike peak", "block jump top", "set push"]
	var strip := Image.create(360 * 5, 330 * 3, false, Image.FORMAT_RGBA8)
	for pose in range(names.size()):
		var separate: Image = await shot(0, pose)
		var merged: Image = await shot(1, pose)
		var skinned: Image = await shot(2, pose)
		print("%-18s merged vs separate %.5f   skeleton vs separate %.5f" % [names[pose], difference(separate, merged), difference(separate, skinned)])
		strip.blit_rect(separate, Rect2i(0, 0, 360, 330), Vector2i(360 * pose, 0))
		strip.blit_rect(merged, Rect2i(0, 0, 360, 330), Vector2i(360 * pose, 330))
		strip.blit_rect(skinned, Rect2i(0, 0, 360, 330), Vector2i(360 * pose, 660))
	strip.save_png("res://artifacts/rig-modes.png")
	quit()
