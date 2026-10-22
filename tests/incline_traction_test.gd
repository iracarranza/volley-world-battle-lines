extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func advance(lab: Node3D, frames: int) -> void:
	for i in range(frames):
		lab.motion.tick(1.0 / 60.0, 1.0)
		await physics_frame
func run() -> void:
	var lab = load("res://drill_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.auto_feed = false
	var slope = lab.activities.by_name.inclined_obstacles
	lab.drills = slope
	slope.interaction_enabled = true
	lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
	lab.camera_rig.view_yaw = 0
	lab.camera_rig.facing_yaw = 0
	lab.athlete.build["statistics"] = {"acceleration":99, "explosiveness":99}
	await physics_frame
	for sprint in [false, true]:
		lab.player.position = slope.anchor + Vector3(2.3, 4.25 + 0.04, -7)
		lab.player.velocity = Vector3.ZERO
		key(KEY_W, true)
		key(KEY_SHIFT, sprint)
		await advance(lab, 60)
		check(lab.player.position.z > slope.anchor.z - 6.5, "Sustained %s cannot overcome smooth rock even at maximum acceleration" % ("sprint" if sprint else "walk"))
		key(KEY_W, false)
		key(KEY_SHIFT, false)
	for rating in [50, 99]:
		lab.athlete.build.statistics.explosiveness = rating
		var start: Vector3 = slope.footholds[1].lerp(slope.footholds[2], 0.5)
		var direction: Vector3 = slope.route_at(start).direction
		lab.player.position = start + Vector3.UP * 0.03
		lab.player.velocity = Vector3.ZERO
		lab.athlete.stamina = lab.athlete.max_stamina()
		var stamina_before: float = lab.athlete.stamina
		var floor_angle: float = lab.player.floor_max_angle
		lab.camera_rig.view_yaw = atan2(-direction.x, -direction.z)
		key(KEY_W, true)
		key(KEY_SHIFT, true)
		await advance(lab, 24)
		key(KEY_W, false)
		key(KEY_SHIFT, false)
		check(lab.player.is_on_floor(), "Uphill traction stays physically grounded at rating %d" % rating)
		check(lab.player.position.z < start.z - 0.15 and lab.player.position.y > start.y + 0.08, "Ridge sprinting climbs at rating %d" % rating)
		check(lab.athlete.stamina < stamina_before - 5, "Climbing spends stamina rather than floating over the collision surface")
		check(is_equal_approx(lab.player.floor_max_angle, floor_angle), "Ridge grip does not alter the athlete's normal floor limit")
	lab.player.position = slope.footholds[2] + Vector3.UP * 0.015
	lab.player.velocity = Vector3.ZERO
	await advance(lab, 30)
	check(lab.player.position.distance_to(slope.footholds[2]) < 0.12, "Level foothold supports resting without sliding")
	lab.queue_free()
	await process_frame
	print("INCLINE TRACTION: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
