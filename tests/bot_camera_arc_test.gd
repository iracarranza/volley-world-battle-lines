extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await physics_frame
	var bots = lab.training_bots
	check(bots.physique.build.power == 65 and bots.physique.build.accuracy == 65 and bots.physique.build.speed == 65 and bots.physique.build.endurance == 65, "Default bot attributes are all 65")
	for slot in range(8):
		check(bots.actors[slot].get_child(0).get_meta("vwm_construction", false), "Bot uses actual default VWM physique")
		var shape: Dictionary = bots.shapes[slot]
		var anchor: Vector3 = bots.contact_anchor(slot)
		check(lab.Geometry.contains(shape, anchor), "Bot ideal contact belongs to player geometry")
		check(not lab.Geometry.contains(shape, anchor + Vector3(5, 0, 0)), "Bot cannot hit outside player geometry")
	bots.random.seed = 42
	bots.set_tracking_accuracy(0, 100)
	bots._plan(0, Vector3(0, 1, 5), 0.5)
	check(bots.contains_ball(0, Vector3(0, 1, 5)), "Perfect tracking centers contact")
	bots.set_tracking_accuracy(0, 0)
	var misses := 0
	for trial in range(100):
		bots._plan(0, Vector3(0, 1, 5), 0.5)
		if not bots.contains_ball(0, Vector3(0, 1, 5)):
			misses += 1
	check(misses > 40, "Poor tracking causes real geometry misses")
	var origin := Vector3(0, 2.1, 5)
	for action in [1]: # a receive is no longer lofted by the camera: its height is steered at contact
		var rises: Array[float] = []
		var ranges: Array[float] = []
		for pitch in [-0.65, 0.27, 1.15]:
			lab.camera_rig.view_pitch = pitch
			var v: Vector3 = lab._loft_velocity(origin, action, 0.7, Vector3.FORWARD)
			rises.append(v.y * v.y / (2 * lab.GRAVITY))
			var t: float = (v.y + sqrt(v.y * v.y + 2 * lab.GRAVITY * (origin.y - 0.105))) / lab.GRAVITY
			ranges.append(Vector2(v.x, v.z).length() * t)
		check(rises[0] < rises[1] and rises[1] < rises[2], "Pitch changes outgoing arc monotonically")
		check(absf(rises[0] / rises[1] - 0.35) < 0.001 and absf(rises[2] / rises[1] - 2.5) < 0.001, "Loft caps are enforced")
		check(absf(ranges[0] - ranges[2]) < 0.001, "Pitch preserves charge-dependent range")
	lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
	lab.camera_rig.view_pitch = 0.8
	lab.camera_rig.update(2.0)
	var floor_position: Vector3 = lab.camera.position
	var old_up: float = (-lab.camera.global_basis.z).y
	lab.camera_rig.view_pitch = 1.1
	lab.camera_rig.update(2.0)
	check(lab.camera.position.distance_to(floor_position) < 0.001, "Further look-up does not drag floor camera closer")
	check((-lab.camera.global_basis.z).y > old_up, "Further look-up tilts upward in place")
	if "--render" in OS.get_cmdline_user_args():
		lab.camera_rig.view_pitch = -0.12
		lab.camera_rig.update(2)
		bots.toggle_all()
		lab.hud.toggle_bot_menu()
		lab.hud.update()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rally-bot-geometry.png")
	print("BOT / CAMERA / ARC: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
