extends SceneTree
# A dive as a grid of frames, flight then floor recovery, 4 per row:
#   godot --path . --script res://tests/render_dive_strip.gd -- --dir=right|left|forward|back|diagonal [--recovery=off] [--quality=0.7]
# --recovery=off draws the landing the old way (upright at touchdown) for a before/after.
const FLIGHT_FRAMES := 4
const RECOVERY_FRAMES := 8
const CELL := Vector2i(400, 240)
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var dir_name := "forward"
	var recovery_on := true
	var quality := 0.7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir_name = a.substr(6)
		elif a == "--recovery=off":
			recovery_on = false
		elif a.begins_with("--quality="):
			quality = float(a.substr(10))
	var direction := {"right": Vector3.RIGHT, "left": Vector3.LEFT, "forward": Vector3.FORWARD, "back": Vector3.BACK, "diagonal": Vector3(0.7, 0, -0.7)}[dir_name] as Vector3
	root.size = Vector2i(1800, 500)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.pose_smoothing = false
	lab.armed = true
	lab.locked_action = 0
	lab.jump_charge = -1
	lab.airborne_action = 0
	lab.dive_world_direction = direction
	lab.dive_flight_time = 0.5
	lab.dive_quality_value = quality
	lab.dive_turn_total = lab._dive_turn_for(direction, 0.0)
	var Recovery = load("res://scripts/dive_recovery.gd")
	var total: float = Recovery.duration(quality)
	var side_view := dir_name in ["forward", "back", "diagonal"]
	var images: Array[Image] = []
	for i in range(FLIGHT_FRAMES + RECOVERY_FRAMES):
		if i < FLIGHT_FRAMES:
			lab.jumped = true
			lab.dive_launched = true
			lab.dive_air_time = 0.5 * float(i + 1) / float(FLIGHT_FRAMES)
			lab.body.rotation.y = 0.0
			lab._update_pose()
		else:
			if lab.jumped:
				lab.dive_air_time = 0.5
				lab._update_pose()
				lab.jumped = false
				lab.player.velocity = direction * 5.0
				if recovery_on:
					lab._begin_dive_recovery()
			var t := total * float(i - FLIGHT_FRAMES) / float(RECOVERY_FRAMES - 1)
			lab.dive_recovery_time = t if recovery_on else -1.0
			lab._update_pose()
		var offset := Vector3(3.4, 1.3, -0.4) if side_view else Vector3(0.6, 1.3, -3.6)
		lab.camera.position = lab.player.position + offset
		lab.camera.look_at(lab.player.position + Vector3(0, 0.45, -0.3))
		await process_frame
		await RenderingServer.frame_post_draw
		images.append(root.get_texture().get_image())
	var columns := 4
	var rows := (images.size() + columns - 1) / columns
	var strip := Image.create(columns * CELL.x, rows * CELL.y, false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		var small := images[i].duplicate() as Image
		small.resize(CELL.x, CELL.y)
		strip.blit_rect(small, Rect2i(0, 0, CELL.x, CELL.y), Vector2i((i % columns) * CELL.x, (i / columns) * CELL.y))
	strip.save_png("res://artifacts/dive-strip-%s%s.png" % [dir_name, "" if recovery_on else "-before"])
	quit()
