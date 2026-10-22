extends SceneTree
# Loading and jumping a block, side on: godot --path . --script res://tests/render_block_jump.gd
func _initialize() -> void: call_deferred("capture")
func tile() -> Image:
	for i in range(3): await process_frame
	var image := root.get_texture().get_image()
	var t := image.get_region(Rect2i(110, 60, 190, 190))
	t.resize(300, 300, Image.INTERPOLATE_LANCZOS)
	return t
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
	camera.global_position = lab.player.global_position + Vector3(4.6, 1.8, 0.0)
	camera.look_at(lab.player.global_position + Vector3(0, 1.2, 0))
	camera.make_current()
	lab.animation.pose_smoothing = false
	var strip := Image.create(300 * 6, 600, false, Image.FORMAT_RGBA8)
	for index in range(6):
		var charge: float = [0.0, 0.3, 0.6, 0.9, 0.9, 0.9][index]
		lab._reset()
		lab.animation.pose_smoothing = false
		lab.selected = 3
		lab.locked_action = 3
		lab.armed = true
		lab.motion.approach_action = 3
		lab.motion.generic_jump = false
		lab.motion.jump_charge = charge
		lab.motion.gait_cycle = 0.1 + 0.18 * index
		lab.player.velocity = Vector3(0, 0, -3.0)
		lab.animation.update()
		var t: Image = await tile()
		strip.blit_rect(t, Rect2i(0, 0, 300, 300), Vector2i(300 * index, 0))
	for index in range(6):
		var f: float = [0.0, 0.15, 0.3, 0.5, 0.75, 0.95][index]
		lab._reset()
		lab.animation.pose_smoothing = false
		lab.selected = 3
		lab.locked_action = 3
		lab.armed = true
		lab.motion.jump_charge = -1.0
		lab.motion.jumped = true
		lab.motion.airborne_action = 3
		lab.motion.last_jump_height = 0.55
		lab.player.position.y = 0.5 + 0.5 * sin(f * PI)
		lab.animation.jump_air_time = f * lab.athlete.jump_flight_time(0.55, lab.GRAVITY)
		lab.animation.update()
		var t: Image = await tile()
		strip.blit_rect(t, Rect2i(0, 0, 300, 300), Vector2i(300 * index, 300))
	strip.save_png("res://artifacts/block-jump-strip.png")
	quit()
