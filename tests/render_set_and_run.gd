extends SceneTree
# A ground set (gather, push, hold, recover) and a run with each action prepared, side on:
# godot --path . --script res://tests/render_set_and_run.gd
func _initialize() -> void: call_deferred("capture")
func tile(lab: Node3D) -> Image:
	for i in range(3): await process_frame
	var image := root.get_texture().get_image()
	var t := image.get_region(Rect2i(120, 70, 170, 170))
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
	camera.global_position = lab.player.global_position + Vector3(4.2, 1.6, 0.0)
	camera.look_at(lab.player.global_position + Vector3(0, 1.1, 0))
	camera.make_current()
	lab.animation.pose_smoothing = false
	var strip := Image.create(300 * 6, 600, false, Image.FORMAT_RGBA8)
	var set_stage = load("res://scripts/set_stage.gd")
	for index in range(6):
		var since: float = [0.0, 0.08, 0.15, 0.3, 0.45, 0.58][index]
		lab._reset()
		lab.animation.pose_smoothing = false
		lab.last_contact = lab.elapsed - since
		lab.last_contact_result = {"action": 1}
		lab.armed = false
		lab.animation.update()
		var t: Image = await tile(lab)
		strip.blit_rect(t, Rect2i(0, 0, 300, 300), Vector2i(300 * index, 0))
	var runs := [[2, 0, 4.5], [0, 0, 4.5], [1, 0, 4.5], [1, 0, 0.0], [0, 0, 0.0], [0, 0, 2.0]]
	for index in range(6):
		lab._reset()
		lab.animation.pose_smoothing = false
		lab.selected = int(runs[index][0])
		lab.locked_action = int(runs[index][0])
		lab.armed = true
		lab.motion.gait_cycle = 0.35
		lab.player.velocity = Vector3(0, 0, -float(runs[index][2]))
		lab.animation.update()
		var t: Image = await tile(lab)
		strip.blit_rect(t, Rect2i(0, 0, 300, 300), Vector2i(300 * index, 300))
	strip.save_png("res://artifacts/set-and-run-strip.png")
	quit()
