extends SceneTree
# A floor recovery as a grid of frames: godot --path . --script res://tests/render_recovery_strip.gd -- --name=knee|fall_roll|fall_slide|blown_away [--side=left] [--view=front]
const FRAMES := 12
const CELL := Vector2i(400, 240)
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var recovery := "knee"
	var side := 1.0
	var front := false
	var top := false
	var close := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			recovery = a.substr(7)
		elif a == "--side=left":
			side = -1.0
		elif a == "--far":
			close = 1.6
		elif a == "--close":
			close = 0.55
		elif a == "--view=top":
			top = true
		elif a == "--view=front":
			front = true
	root.size = Vector2i(1800, 720)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.pose_smoothing = false
	await process_frame
	var cam := Camera3D.new()
	cam.fov = 45.0
	lab.add_child(cam)
	cam.make_current()
	var R = load("res://scripts/floor_recovery.gd")
	var Lib = load("res://scripts/pose_library.gd")
	var rig: Dictionary = Lib.read_rig(lab.body)
	var total: float = R.duration(recovery)
	var images: Array[Image] = []
	for i in range(FRAMES):
		await process_frame
		lab.body.rotation = Vector3.ZERO
		lab.body.global_position = lab.player.position
		var state: Dictionary = R.at(recovery, total * float(i) / float(FRAMES - 1), side, Vector2.ZERO, rig)
		R.apply(lab.body, state)
		load("res://scripts/dive_recovery.gd").rest_on_floor(lab.body, lab.player.position.y)
		var offset := Vector3(0.6, 1.3, -3.4) if front else Vector3(3.4, 1.3, -0.4)
		if top:
			offset = Vector3(0.0, 4.2, -0.4)
		cam.global_position = lab.player.global_position + offset * close
		cam.look_at(lab.player.global_position + Vector3(0, 0.55, 0))
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
	strip.save_png("res://artifacts/recovery-%s.png" % recovery)
	quit()
