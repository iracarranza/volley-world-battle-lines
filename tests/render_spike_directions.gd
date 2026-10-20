extends SceneTree
# Cross-body and outward spike swings for a right-hander, from above: godot --path . --script res://tests/render_spike_directions.gd
const PHASES := [-0.3, -0.15, 0.0, 0.2, 0.4]
const CELL := Vector2i(360, 300)
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1800, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.animation.pose_smoothing = false
	await process_frame
	var cam := Camera3D.new()
	cam.fov = 38.0
	lab.add_child(cam)
	cam.make_current()
	var Spike = load("res://scripts/spike_stage.gd")
	var images: Array[Image] = []
	for yaw in [0.6, -0.6]:
		for phase in PHASES:
			await process_frame
			lab.body.rotation = Vector3.ZERO
			Spike.apply(lab.body, phase, 1.0, 0.8, "Power swing", {"shot_yaw": yaw, "ball_local": Vector3(0.0, 2.3, -0.5)})
			cam.global_position = lab.player.global_position + Vector3(0.0, 5.0, 1.2)
			cam.look_at(lab.player.global_position + Vector3(0, 0.9, -0.4))
			cam.make_current()
			await RenderingServer.frame_post_draw
			images.append(root.get_texture().get_image())
	var strip := Image.create(PHASES.size() * CELL.x, 2 * CELL.y, false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		var small := images[i].duplicate() as Image
		small.resize(CELL.x, CELL.y)
		strip.blit_rect(small, Rect2i(0, 0, CELL.x, CELL.y), Vector2i((i % PHASES.size()) * CELL.x, (i / PHASES.size()) * CELL.y))
	strip.save_png("res://artifacts/spike-directions.png")
	quit()
