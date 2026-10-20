extends SceneTree
# Hips, legs and head while moving, as frames: godot --path . --script res://tests/render_locomotion_strip.gd -- --case=strafe|reverse|start|backpedal [--side]
const FRAMES := 12
const CELL := Vector2i(450, 330)
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var case_name := "strafe"
	var side_view := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--case="):
			case_name = a.substr(7)
		elif a == "--side":
			side_view = true
	root.size = Vector2i(1800, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.animation.pose_smoothing = false
	await process_frame
	var cam := Camera3D.new()
	cam.fov = 34.0
	lab.add_child(cam)
	cam.make_current()
	lab.animation.pose_frame_dt = 1.0 / 60.0
	var dt := 1.0 / 60.0
	var velocity := Vector3.ZERO
	var images: Array[Image] = []
	var total_steps := 0
	var plan := []   # [seconds, wish direction, top speed]
	match case_name:
		"strafe": plan = [[1.6, Vector3.RIGHT, 5.0]]
		"backpedal": plan = [[1.6, Vector3.BACK, 4.0]]
		"start": plan = [[0.9, Vector3.RIGHT, 5.0]]
		"reverse": plan = [[0.8, Vector3.FORWARD, 6.0], [1.2, Vector3.BACK, 6.0]]
	var duration := 0.0
	for p in plan:
		duration += float(p[0])
	var capture_every := int(duration / dt) / FRAMES
	var step_index := 0
	var elapsed := 0.0
	for p in plan:
		var steps := int(float(p[0]) / dt)
		for i in range(steps):
			var wish: Vector3 = p[1]
			velocity = velocity.move_toward(wish * float(p[2]), 28.0 * dt)
			lab.player.velocity = velocity
			lab.directional_input.sample(wish, dt)
			lab.motion.gait_cycle += velocity.length() * dt / maxf(lab.athlete.stride() * 2.0, 0.1)
			lab.body.rotation.y = 0.0
			lab.animation.update()
			await process_frame
			step_index += 1
			elapsed += dt
			if step_index % maxi(capture_every, 1) == 0 and images.size() < FRAMES:
				var offset := Vector3(6.0, 2.2, -0.6) if side_view else Vector3(0.0, 4.4, 0.9)
				cam.global_position = lab.player.global_position + offset
				cam.look_at(lab.player.global_position + Vector3(0, 0.5, 0))
				cam.make_current()
				await RenderingServer.frame_post_draw
				images.append(root.get_texture().get_image())
	var columns := 4
	var rows := (images.size() + columns - 1) / columns
	var strip := Image.create(columns * CELL.x, rows * CELL.y, false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		var small := images[i].duplicate() as Image
		small.resize(CELL.x, CELL.y)
		strip.blit_rect(small, Rect2i(0, 0, CELL.x, CELL.y), Vector2i((i % columns) * CELL.x, (i / columns) * CELL.y))
	strip.save_png("res://artifacts/locomotion-%s%s.png" % [case_name, "-side" if side_view else ""])
	quit()
