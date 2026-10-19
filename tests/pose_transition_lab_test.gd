extends "res://tests/support/test_case.gd"
# In the running lab, going from standing to a receive stance (and back) must not jump a joint.
func _initialize() -> void:
	call_deferred("run")
func _joints(lab) -> Array:
	return [lab.legs[0].get_node("Knee").rotation_degrees.x, lab.legs[0].rotation_degrees.x, lab.arms[0].rotation_degrees.x, lab.arms[1].rotation_degrees.z]
func _largest_step(lab, frames: int) -> float:
	var worst := 0.0
	var previous := _joints(lab)
	for i in range(frames):
		await process_frame
		lab.animation.pose_frame_dt = 0.016
		lab.animation.update()
		var now := _joints(lab)
		for j in range(now.size()):
			worst = maxf(worst, absf(float(now[j]) - float(previous[j])))
		previous = now
	return worst
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.animation.pose_frame_dt = 0.016
	lab.armed = false
	for i in range(3):
		await process_frame
		lab.animation.update()
	# Standing to receive, without smoothing: the stance appears in one frame.
	lab.animation.pose_smoothing = false
	lab.armed = true
	lab.locked_action = 0
	lab.animation.pose_smoothing = false
	var abrupt: float = await _largest_step(lab, 1)
	lab.armed = false
	lab.animation.pose_smoothing = false
	await _largest_step(lab, 2)
	# The same change with smoothing on.
	lab.animation.pose_smoothing = true
	lab.animation.pose_smoother.reset()
	for i in range(3):
		await process_frame
		lab.animation.pose_frame_dt = 0.016
		lab.animation.update()
	lab.armed = true
	lab.locked_action = 0
	var smooth: float = await _largest_step(lab, 30)
	check(abrupt > 15.0, "Without smoothing the receive stance snaps in (%.1f deg in one frame)" % abrupt)
	check(smooth < abrupt * 0.45, "With smoothing no joint moves more than %.1f deg in a frame (snap was %.1f)" % [smooth, abrupt])
	# And it still arrives at the same stance.
	var arrived := _joints(lab)
	lab.animation.pose_smoothing = false
	lab.animation.update()
	var target := _joints(lab)
	for j in range(arrived.size()):
		check(absf(float(arrived[j]) - float(target[j])) < 0.5, "Smoothed stance arrives at the authored one (joint %d: %.1f vs %.1f)" % [j, arrived[j], target[j]])
	# Back out of the stance, smoothly.
	lab.animation.pose_smoothing = true
	for i in range(3):
		await process_frame
		lab.animation.pose_frame_dt = 0.016
		lab.animation.update()
	lab.armed = false
	var leaving: float = await _largest_step(lab, 30)
	check(leaving < abrupt * 0.45, "Leaving the stance is smooth too (%.1f deg largest step)" % leaving)
	print("POSE TRANSITION LAB CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
