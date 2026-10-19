extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	for action in range(4):
		lab._reset()
		lab.athlete.hp = 50
		lab.locked_action = action
		lab.selected = action
		lab.armed = true
		lab.ball_active = true
		lab.aim = Vector3(0, 0, -5)
		var shape: Dictionary = lab._raw_hurtbox_definition(action)
		var point: Vector3 = shape.center
		if action == 1:
			point.y += shape.radius * 0.5
		elif action == 2:
			point += lab.Geometry.sector_point(shape, 0.74, 67.5, 0)
		elif action == 3:
			point.x += shape.column_x
		lab.ball.position = lab.player.position + point
		lab._confirm_action()
		lab._contact()
		check(lab.athlete.hp == 50 and lab.athlete.stamina < 100, "Ordinary action %d spends only stamina" % action)
	lab._reset()
	for frame in range(6):
		lab.player.velocity = Vector3.DOWN * 2
		lab.player.move_and_slide()
		await physics_frame
	lab.athlete.hp = 50
	lab.selected = 2
	lab.armed = true
	lab.locked_action = 2
	lab.motion.approach_action = 2
	lab.motion.jump_charge = 0.8
	lab.motion.takeoff()
	check(lab.athlete.hp == 50 and lab.athlete.stamina < 100, "Jump spends stamina without HP")
	var spike: Dictionary = lab._raw_hurtbox_definition(2)
	for depth in [-0.95, 0.95]:
		var point: Vector3 = spike.center + lab.Geometry.sector_point(spike, 0.74, 67.5, depth)
		var result: Dictionary = lab.Execution.assess(lab.Geometry.evaluate(spike, point), 0.22, false, 2)
		check(result.hit and not result.sweet, "Extended spike depth permits forgiving contact on either side of the arm plane")
	var sweet: Vector3 = spike.center + lab.Geometry.sector_point(spike, 0.74, 67.5, 0)
	check(lab.Execution.assess(lab.Geometry.evaluate(spike, sweet), 0.22, false, 2).sweet, "Physical sweetspot stays available")
	var outside: Vector3 = sweet + Vector3(0, 0, 1.3)
	check(not lab.Geometry.contains(spike, outside), "Forgiving spike depth still has a finite boundary")
	print("STAMINA / SPIKE DEPTH: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
