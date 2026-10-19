extends SceneTree
# Through a whole dive in the running lab, no joint may jump at the seams: dive -> landing and slide ->
# recovery -> standing. Compared with the same dive unsmoothed.
const Library := preload("res://scripts/pose_library.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func _step(a: Dictionary, b: Dictionary) -> float:
	var worst := 0.0
	for key in a:
		if String(key).begins_with("hip_shift"):
			continue
		worst = maxf(worst, absf(wrapf(float(b.get(key, 0.0)) - float(a[key]), -180.0, 180.0)))
	return worst
# Plays a dive to the right, then the recovery, one frame at a time. Returns the largest joint step
# near each source change, keyed by "from>to", plus the largest anywhere.
func play(lab, smooth: bool) -> Dictionary:
	lab._reset()
	lab.pose_smoothing = smooth
	lab.pose_smoother.reset()
	lab.pose_frame_dt = 0.016
	lab.jumped = true
	lab.airborne_action = 0
	lab.jump_charge = -1
	lab.dive_launched = true
	lab.dive_quality_value = 0.7
	lab.dive_world_direction = Vector3.RIGHT
	lab.dive_flight_time = 0.5
	lab.armed = true
	lab.locked_action = 0
	var steps := {}
	var worst := 0.0
	var last_source := ""
	var near_seam := 0
	var seam := ""
	var previous := {}
	var frames := 0
	var landed := false
	while frames < 220:
		frames += 1
		await process_frame
		if not landed:
			lab.dive_air_time = minf(0.5, frames * 0.016)
			if lab.dive_air_time >= 0.5:
				lab.player.velocity = Vector3.RIGHT * 5.0
				lab.jumped = false
				lab.armed = false
				lab._begin_dive_recovery()
				landed = true
		else:
			lab._tick_dive_recovery(0.016)
		lab._update_pose()
		var source: String = lab._pose_source(lab.jumped and lab.airborne_action == 0, false, false)
		var now := Library.read_rig(lab.body)
		if not previous.is_empty():
			var step := _step(previous, now)
			worst = maxf(worst, step)
			if source != last_source and last_source != "":
				near_seam = 6
				seam = "%s>%s" % [last_source, source]
				steps[seam] = 0.0
			if near_seam > 0:
				steps[seam] = maxf(float(steps[seam]), step)
				near_seam -= 1
		previous = now
		last_source = source
		if landed and lab.dive_recovery_time < 0.0 and frames > 40:
			break
	steps["worst"] = worst
	steps["frames"] = frames
	return steps
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	var raw: Dictionary = await play(lab, false)
	var smooth: Dictionary = await play(lab, true)
	print("unsmoothed seams ", raw)
	print("smoothed seams   ", smooth)
	var seams := ["dive>locomotion"]
	for name in seams:
		check(smooth.has(name), "the dive passes through the %s seam" % name)
		check(float(raw.get(name, 0.0)) < 20.0 or float(smooth.get(name, 99.0)) < float(raw.get(name, 0.0)) * 0.6 + 1.0, "a seam that would jump is softened, one that is already continuous is left alone: %s (%.1f vs %.1f deg in a frame)" % [name, float(smooth.get(name, 99.0)), float(raw.get(name, 0.0))])
	check(float(smooth.worst) < 22.0, "no joint jumps more than 22 deg in a frame anywhere in the dive (%.1f)" % float(smooth.worst))
	check(float(smooth.worst) <= float(raw.worst), "smoothing never makes the worst jump bigger (%.1f vs %.1f)" % [float(smooth.worst), float(raw.worst)])
	print("DIVE SEAMS CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
