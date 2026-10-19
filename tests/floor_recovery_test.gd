extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var R = load("res://scripts/floor_recovery.gd")
	check(R.names().size() == 5, "Five recoveries are defined")
	check(is_equal_approx(R.duration("knee"), 0.55) and is_equal_approx(R.duration("knocked_away"), 0.95) and is_equal_approx(R.duration("blown_away"), 1.35), "Durations match VWM's priced recovery times")
	var VwmTable := FileAccess.get_file_as_string("res://vendor/vwm/construction/scripts/data/stance_transition.gd")
	check(VwmTable.contains('"knee": 0.55') and VwmTable.contains('"fall": 0.95') and VwmTable.contains('"blown_away": 1.35'), "VWM table still says the same")
	check(R.choose({"hit": true, "zone": "CLEAN", "quality": 1.0, "posture": "planted"}) == "", "Clean planted receive needs no recovery")
	check(R.choose({"hit": true, "zone": "WEAK", "quality": 0.58, "posture": "planted"}) == "shrug", "Mishandled midline receive is a shrug")
	check(R.choose({"hit": true, "zone": "WEAK", "quality": 0.58, "posture": "planted", "contact_x": 0.6}) == "knee", "Mishandled off-centre receive is a knee")
	check(R.choose({"hit": true, "zone": "CLEAN", "quality": 1.0, "posture": "planted", "contact_x": 0.0}) == "", "Handled midline receive needs nothing")
	check(R.choose({"hit": true, "zone": "WEAK", "quality": 0.58, "posture": "reaching"}) == "knee", "Reaching is never a shrug")
	check(R.choose({"hit": true, "zone": "FAIR", "quality": 0.8, "posture": "reaching"}) == "knee", "Stretched fair contact is a knee")
	check(R.choose({"hit": false, "posture": "moving"}) == "collapse", "Missed moving reach slides")
	check(R.choose({"hit": true, "zone": "SOUR SPOT", "edge": true, "quality": 0.4, "posture": "off-axis"}) == "knocked_away", "Sour off-axis edge rolls")
	check(R.choose({"hit": true, "zone": "WEAK", "quality": 0.5, "posture": "planted", "incoming_speed": 22.0}) == "blown_away", "Hard ball on a poor platform blows the defender away")
	check(R.choose({"hit": true, "zone": "CLEAN", "quality": 1.0, "posture": "planted", "incoming_speed": 22.0}) == "", "A clean platform holds against a hard ball")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await process_frame
	var rig: Dictionary = load("res://scripts/pose_library.gd").read_rig(lab.body)
	for name in R.names():
		var total: float = R.duration(name)
		var start: Dictionary = R.at(name, 0.0, 1.0, Vector2.ZERO, rig)
		var finish: Dictionary = R.at(name, total, 1.0, Vector2.ZERO, rig)
		var ready: Dictionary = load("res://scripts/pose_library.gd").flatten(load("res://scripts/pose_library.gd").load_pose("ready_stance"))
		var worst := 0.0
		for key in ready:
			worst = maxf(worst, absf(float(finish.flat[key]) - float(ready[key])))
		check(worst < 0.01, "%s ends exactly in the ready stance (off by %.3f)" % [name, worst])
		check(is_equal_approx(float(start.pitch), 0.0) and String(finish.stage) == "rise", "%s starts level and finishes in its rise stage" % name)
		check(is_equal_approx(float(finish.pitch), 0.0), "%s hands back an upright body" % name)
		var previous: Dictionary = start
		var jump := 0.0
		for i in range(1, 61):
			var s: Dictionary = R.at(name, total * i / 60.0, 1.0, Vector2.ZERO, rig)
			jump = maxf(jump, absf(float(s.pitch) - float(previous.pitch)))
			jump = maxf(jump, absf(float(s.roll) - float(previous.roll)) / 2.0)
			previous = s
		check(jump < 0.9, "%s moves the body without jumps (largest step %.2f)" % [name, jump])
	var at_swing: float = R.duration("knocked_away") * 0.26
	var right: Dictionary = R.at("knocked_away", at_swing, 1.0, Vector2.ZERO, rig)
	var left: Dictionary = R.at("knocked_away", at_swing, -1.0, Vector2.ZERO, rig)
	check(float(right.flat.thoracic_twist) > 30.0 and is_equal_approx(float(right.flat.thoracic_twist), -float(left.flat.thoracic_twist)), "Knocked Away twists the body the other way for the other side")
	check(R.resolve("fall_roll") == "knocked_away" and R.resolve("fall_slide") == "collapse" and R.resolve("knee") == "knee", "The resolver's older event names map to the new animations")
	check(float(R.at("collapse", R.duration("collapse") * 0.45, 1.0, Vector2.ZERO, rig).pitch) < -1.2, "Collapse puts the body level on hands and knees")
	check(R.at("blown_away", 0.4, 1.0, Vector2.ZERO, rig).pitch > 1.5, "Blown away ends up on the back")
	print("floor_recovery: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
