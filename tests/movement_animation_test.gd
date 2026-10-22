extends "res://tests/support/test_case.gd"
const Pose := preload("res://scripts/athlete_pose.gd")
const Library := preload("res://scripts/pose_library.gd")
const SetStage := preload("res://scripts/set_stage.gd")
func _initialize() -> void: call_deferred("run")

func pose_with(lab, action: int, speed: float) -> Dictionary:
	lab._reset()
	lab.selected = action
	lab.locked_action = action
	lab.armed = true
	lab.motion.gait_cycle = 0.6
	lab.player.velocity = Vector3(0, 0, -speed)
	lab.animation.pose_smoothing = false
	lab.animation.update()
	return Library.read_rig(lab.body)

func takeoff_speed(lab, action: int) -> float:
	lab._reset()
	for frame in range(6):
		lab.player.velocity = Vector3.DOWN * 2
		lab.player.move_and_slide()
		await physics_frame
	lab.selected = action
	lab.locked_action = action
	lab.armed = true
	lab.motion.approach_action = action
	lab.motion.jump_charge = 0.8
	lab.player.velocity = Vector3(0, 0, -5.0)
	lab.motion.takeoff()
	return Vector2(lab.player.velocity.x, lab.player.velocity.z).length()

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	for i in 20:
		await physics_frame
	# The stride is slower and the run bobs less
	check(Pose.GAIT_PACE < 1.0, "The walk cycle is slower than the distance covered alone gives")
	for speed in [3.0, 4.5, 6.0]:
		var low := 99.0
		var high := -99.0
		for step in range(100):
			Pose.base(lab.body, float(step) / 100.0, speed, 0.0, false)
			Pose.ground_feet(lab.body)
			low = minf(low, lab.body.position.y)
			high = maxf(high, lab.body.position.y)
		check(high - low < 0.12, "The run bobs the hips less than 12 cm at %.1f m/s (%.1f cm)" % [speed, (high - low) * 100.0])
	# Receive prepared: the platform is out standing, and the arms stay in the stride on the move
	var receive_still := pose_with(lab, 0, 0.0)
	var receive_moving := pose_with(lab, 0, 4.5)
	var swing_still := absf(float(receive_still["shoulder_pitch:Right"]))
	check(swing_still > 30.0, "Standing with a receive ready, the arms are out in the platform")
	check(absf(float(receive_moving["shoulder_pitch:Right"])) < swing_still * 0.7 and float(receive_moving["shoulder_pitch:Right"]) < 40.0, "Moving with a receive ready, the arms are not out in the platform (%.0f)" % float(receive_moving["shoulder_pitch:Right"]))
	# Set prepared: hands relax down and out a little on the move, still up and in front
	var set_still := pose_with(lab, 1, 0.0)
	var set_moving := pose_with(lab, 1, 4.5)
	check(float(set_moving["shoulder_pitch:Right"]) < float(set_still["shoulder_pitch:Right"]) - 4.0 and float(set_moving["shoulder_pitch:Right"]) > 60.0, "Moving with a set ready, the hands drop a little but stay up")
	check(float(set_moving["shoulder_roll:Right"]) > float(set_still["shoulder_roll:Right"]) + 4.0, "...and go out to the sides")
	# The set's push is visible and held
	var gather := SetStage.data_pose(SetStage.GATHER_PHASE, false, 1.0)
	var pushed := SetStage.data_pose(SetStage.follow_phase(0.16), false, 1.0)
	var held := SetStage.data_pose(SetStage.follow_phase(0.3), false, 1.0)
	check(float(pushed["shoulder_pitch:Right"]) > float(gather["shoulder_pitch:Right"]) + 55.0 and float(pushed["elbow:Right"]) < 5.0, "The set pushes the hands out to full extension")
	check(float(held["elbow:Right"]) < 5.0 and float(held["shoulder_pitch:Right"]) > 160.0, "...and holds the follow-through")
	var later := SetStage.data_pose(SetStage.follow_phase(SetStage.FOLLOW_SECONDS), false, 1.0)
	check(float(later["shoulder_pitch:Right"]) < 20.0, "...before the hands come back to the ready stance")
	var jump_held := SetStage.data_pose(0.4, true, 1.0)
	check(float(jump_held["elbow:Right"]) < 5.0 and float(jump_held["knee:Right"]) > -50.0, "A set jump extends the arms through the push with the legs still bent")
	# A set or block jump sheds its run like the spike jump
	for action in [1, 3]:
		var carried: float = await takeoff_speed(lab, action)
		check(carried < 0.6, "A %s jump sheds most of its run (%.2f of 5.00 m/s)" % [["", "set", "", "block"][action], carried])
	# A block jump reaches overhead and bends to land
	lab._reset()
	lab.motion.jumped = true
	lab.motion.airborne_action = 3
	lab.motion.last_jump_height = 0.5
	var flight: float = lab.athlete.jump_flight_time(0.5, lab.GRAVITY)
	lab.animation.jump_air_time = flight * 0.5
	lab.animation._apply_block_jump_pose()
	check(float(lab.arms[0].rotation.x) < -2.9 and absf(float(lab.arms[0].rotation.z)) > 0.15, "At the top of a block jump the hands are fully overhead and spread a little")
	var rise_knee: float = lab.legs[0].get_node("Knee").rotation_degrees.x
	lab.animation.jump_air_time = flight * 0.95
	lab.animation._apply_block_jump_pose()
	check(float(lab.legs[0].get_node("Knee").rotation_degrees.x) < rise_knee - 15.0, "The knees bend again to land")
	lab.motion.jumped = false
	lab.queue_free()
	await process_frame
	print("MOVEMENT ANIMATION: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
