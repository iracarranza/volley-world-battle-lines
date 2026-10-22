extends "res://tests/support/test_case.gd"
const Geometry = preload("res://scripts/contact_geometry.gd")
const Execution = preload("res://scripts/contact_execution.gd")
const SpikeDirection = preload("res://scripts/spike_direction.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	for hand in ["Right", "Left"]:
		lab.dominant_hand = hand
		var shape: Dictionary = lab._raw_hurtbox_definition(2)
		var sweet: Vector3 = shape.center + Geometry.sector_point(shape, 0.74, 67.5, 0)
		for yaw in [0.0, 1.2]:
			var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw)
			var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
			for side in [-1.0, 1.0]:
				var point: Vector3 = sweet + Vector3.RIGHT * side * shape.radius * 0.35
				var assessment := Execution.assess(Geometry.evaluate(shape, point), Execution.SPIKE_PEAK, false, 2)
				var base: Vector3 = forward * 24 + Vector3.DOWN * 2
				var neutral := SpikeDirection.resolve(base, assessment, Vector3.ZERO, forward)
				var matching := SpikeDirection.resolve(base, assessment, right * side, forward)
				var contrary := SpikeDirection.resolve(base, assessment, -right * side, forward)
				check(Vector3(neutral.velocity).dot(right) * side > 0, "Neutral contact travels toward its side of the sweetspot for either hand/facing")
				check(absf(matching.shot_yaw_radians) > absf(neutral.shot_yaw_radians), "Complementary DI accentuates geometry angle")
				check(Vector3(matching.velocity).length() > Vector3(neutral.velocity).length(), "Complementary DI recovers ball speed")
				check(absf(contrary.shot_yaw_radians) < absf(neutral.shot_yaw_radians), "Contrary DI steers back toward facing")
				check(Vector3(contrary.velocity).length() < Vector3(neutral.velocity).length(), "Contrary DI trades speed for correction")
				check(contrary.shot_yaw_radians * neutral.shot_yaw_radians >= -0.00001, "Correction does not flip to the other side of facing")
				var actual: Array[Vector3] = []
				for input in [Vector3.ZERO, right * side, -right * side]:
					lab._reset()
					lab.dominant_hand = hand
					lab.camera_rig.facing_yaw = yaw
					lab.motion.jumped = true
					lab.motion.airborne_action = 2
					lab.motion.airborne_aim = forward
					lab.locked_action = 2
					lab.selected = 2
					lab.locked_charge = 0.6
					lab.armed = true
					lab.ball_active = true
					lab.ball.position = lab.player.position + point.rotated(Vector3.UP, yaw)
					lab.aim = lab.player.position + forward * 10
					lab.directional_input.sample(input, 0.08)
					lab._confirm_action()
					lab.confirm_window = lab.confirm_duration - (preload("res://scripts/contact_execution.gd").SPIKE_PEAK if lab.locked_action == 2 else 0.22)
					lab._contact()
					actual.append(lab.ball_velocity)
					check(lab.camera_rig.facing_yaw == yaw and lab.athlete.build.power == 65, "Contact changes neither committed facing nor Power stat")
				check(actual[0].dot(right) * side > 0, "Actual neutral spike uses physical intersection side")
				check(actual[1].length() > actual[0].length() and actual[2].length() < actual[0].length(), "Actual contacts apply complementary/contrary speed tradeoff")
	print("SPIKE GEOMETRY / DI: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
