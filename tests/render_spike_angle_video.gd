extends SceneTree
# Deterministic presentation-only sweep. Capture PNG frames under --output and encode with ffmpeg.
const Spike := preload("res://scripts/spike_stage.gd")
const ANGLES := [-60.0, -30.0, 0.0, 30.0, 60.0]
const FPS := 30
const FRAMES := 30
const SIZE := Vector2i(960, 540)

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var output := "res://artifacts/spike-video"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = SIZE
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.animation.pose_smoothing = false
	lab.ball_active = false
	if is_instance_valid(lab.hud) and is_instance_valid(lab.hud.ui):
		lab.hud.ui.hide()
	await process_frame
	var cam := Camera3D.new()
	cam.fov = 42.0
	lab.add_child(cam)
	cam.make_current()
	var ball_local := Vector3(0.25, 2.3, -0.4)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	ball.mesh = sphere
	lab.add_child(ball)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.85, 0.1)
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.material_override = marker_material
	for angle in ANGLES:
		var label := ("minus" if angle < 0 else "plus") + str(absi(int(angle)))
		if is_zero_approx(angle):
			label = "zero"
		for frame in range(FRAMES):
			var t := float(frame) / FPS
			var phase := Spike.phase_for(0.4, 0.6, t, 0.14 if t >= 0.14 else -1.0)
			lab.body.rotation = Vector3.ZERO
			lab.body.position = Vector3.ZERO
			lab.body.scale = Vector3.ONE * float(lab.athlete.build.height) / lab.visual_rig_height
			Spike.apply(lab.body, phase, 1.0, 0.8, "Power swing", {"shot_yaw": deg_to_rad(angle), "ball_local": ball_local})
			var impact: Vector3 = lab.body.global_transform * ball_local
			var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle))
			ball.global_position = impact + direction * maxf(0.0, t - 0.14) * 8.0
			cam.global_position = lab.player.global_position + Vector3(2.9, 2.7, 4.6)
			cam.look_at(lab.player.global_position + Vector3(0.0, 1.5, -0.5))
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var status := img.save_png(output.path_join("%s_%03d.png" % [label, frame]))
			if status != OK:
				push_error("Failed to save spike frame: %s" % error_string(status))
				quit(1)
				return
	print("Rendered %d frames into %s" % [ANGLES.size() * FRAMES, output])
	lab.queue_free()
	quit()
