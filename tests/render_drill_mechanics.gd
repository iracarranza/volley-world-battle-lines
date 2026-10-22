extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1100, 800)
	var lab = load("res://drill_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	for child in lab.get_children():
		if child is CanvasLayer: child.hide()
	var camera := Camera3D.new()
	lab.add_child(camera)
	camera.current = true
	for key in ["salmon_ladder", "weighted_balancing", "inclined_obstacles", "balance_ball_setting"]:
		var drill = lab.activities.by_name[key]
		lab.drills = drill
		lab.player.position = drill.anchor
		lab.inventory.enabled = false
		drill.interact()
		var target: Vector3 = drill.anchor + Vector3(0, 2, -3)
		if key == "salmon_ladder":
			drill.kip_power = 1
			drill.kip_age = 0.2
			drill.drill_motion(0.01, Vector3.ZERO)
		elif key == "weighted_balancing":
			lab.player.position = drill.anchor + Vector3(0, drill.BEAM_TOP, -5)
			drill.on_beam = true
			drill.lean = 0.2
			target = lab.player.position + Vector3.UP
		elif key == "balance_ball_setting":
			drill.lean = Vector2(0.2, 0.1)
			target = drill.anchor + Vector3(0, 1.5, -2)
		else:
			target = drill.anchor + Vector3(0, 4, -6)
		lab.camera_rig.update_aim()
		lab.animation.update()
		camera.position = target + Vector3(7, 4, 9)
		camera.look_at(target)
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/drill-%s.png" % key)
		if key == "salmon_ladder":
			camera.position = drill.anchor + Vector3(4.5, 3.2, 3.5)
			camera.look_at(drill.anchor + Vector3(0, 2.7, -2.7))
			for stage in ["backswing", "crunch", "launch", "catch", "failed_launch", "failed_catch"]:
				match stage:
					"backswing":
						drill.kip = 1
						drill.kip_power = 0
					"crunch":
						drill.kip = 0
						drill.kip_power = 1
						drill.kip_age = 0.25
					"launch":
						drill.pull = 1
						drill.propel()
						drill.drill_motion(0.45, Vector3.ZERO)
					"catch": drill.drill_motion(0.45, Vector3.ZERO)
					"failed_launch":
						drill.drill_motion(1.1, Vector3.ZERO)
						drill.pull = 0.3
						drill.kip_power = 0
						drill.propel()
						drill.drill_motion(0.45, Vector3.ZERO)
					"failed_catch": drill.drill_motion(0.45, Vector3.ZERO)
				lab.animation.update()
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/ladder-%s.png" % stage)
		drill.reset()
	lab.queue_free()
	await process_frame
	quit()
