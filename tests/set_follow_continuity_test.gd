extends "res://tests/support/test_case.gd"
const SetStage := preload("res://scripts/set_stage.gd")
const Library := preload("res://scripts/pose_library.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(is_equal_approx(SetStage.follow_phase(0.0), SetStage.GATHER_PHASE), "Follow-through starts at the armed gather pose")
	check(is_equal_approx(SetStage.follow_phase(SetStage.FOLLOW_BLEND), lerpf(0.04, 0.88, SetStage.FOLLOW_BLEND / SetStage.FOLLOW_SECONDS)), "Blend has fully run down by the end of the window")
	check(is_equal_approx(SetStage.follow_phase(SetStage.FOLLOW_SECONDS), 0.88), "Follow-through still ends at 0.88")
	var previous := SetStage.follow_phase(0.0)
	var monotonic := true
	for frame in range(1, 31):
		var phase := SetStage.follow_phase(frame / 60.0)
		monotonic = monotonic and phase >= previous
		previous = phase
	check(monotonic, "Follow phase never moves backwards")
	# Pose continuity: the biggest one-frame joint change across contact must be no larger than normal motion.
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	for i in 20:
		await process_frame
	var body: Node3D = lab.training_bots.rigs[0].body
	var armed_pose: Dictionary = SetStage.data_pose(SetStage.GATHER_PHASE, false, 1.0)
	var worst_across := 0.0
	var worst_after := 0.0
	var previous_pose := {}
	for frame in range(0, 20):
		var since := frame / 60.0
		SetStage.apply_data(body, SetStage.follow_phase(since), false, 1.0)
		var pose: Dictionary = Library.read_rig(body)
		if frame == 0:
			SetStage.apply_data(body, SetStage.GATHER_PHASE, false, 1.0)
			var gather: Dictionary = Library.read_rig(body)
			for key in pose:
				if gather.has(key):
					worst_across = maxf(worst_across, absf(float(pose[key]) - float(gather[key])))
		elif not previous_pose.is_empty():
			for key in pose:
				if previous_pose.has(key):
					worst_after = maxf(worst_after, absf(float(pose[key]) - float(previous_pose[key])))
		previous_pose = pose
	check(worst_across < 0.5, "No pose jump between the armed pose and the first follow-through frame (%.2f)" % worst_across)
	check(worst_after < 25.0, "Follow-through frames move smoothly (%.2f per frame): the push snaps out quickly now, and is held" % worst_after)
	print("SET FOLLOW CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
