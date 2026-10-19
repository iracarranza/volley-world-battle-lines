extends "res://tests/support/test_case.gd"
const Recovery := preload("res://scripts/dive_recovery.gd")
const Stage := preload("res://scripts/dive_stage.gd")
func _initialize() -> void:
	call_deferred("run")
# A dive that has just touched down heading `direction`, with the clock at `t`.
func land(lab: Node3D, direction: Vector3, quality: float = 0.7) -> void:
	lab.motion.jumped = true
	lab.motion.airborne_action = 0
	lab.motion.jump_charge = -1
	lab.animation.dive_launched = true
	lab.animation.dive_quality_value = quality
	lab.animation.dive_world_direction = direction
	lab.animation.dive_flight_time = 0.5
	lab.animation.dive_air_time = 0.5
	lab.body.rotation = Vector3(0, 0, 0)
	lab.animation.update()
	lab.player.velocity = direction * 5.0
	lab.motion.jumped = false
	lab.animation.begin_dive_recovery()
func at(lab: Node3D, t: float) -> void:
	lab.animation.dive_recovery_time = t
	lab.animation.update()
func floor_gap(lab: Node3D) -> float:
	return Recovery.lowest_world_y(lab.body) - lab.player.global_position.y
func run() -> void:
	var plan: Dictionary = Recovery.plan()
	check(plan.stages.size() >= 4, "the recovery plan loads its stages from data")
	check(Recovery.duration(1.0) < Recovery.duration(0.0), "a clean dive recovers faster than a poor one")
	check(Recovery.lock_seconds(0.5) > 0.2 and Recovery.lock_seconds(0.5) < Recovery.duration(0.5), "input is locked for part of the recovery, not all of it")
	var ahead := Vector2(0, 1)
	var right := Vector2(1, 0)
	var left := Vector2(-1, 0)
	var r := Recovery.at(0.4, right, 0.5, Vector2.ZERO)
	var l := Recovery.at(0.4, left, 0.5, Vector2.ZERO)
	check(is_equal_approx(float(r.roll), -float(l.roll)) and float(r.roll) < -0.5, "right and left dives roll onto opposite sides equally")
	check(is_equal_approx(float(r.pitch), float(l.pitch)), "left and right share the same pitch")
	for key in r.flat:
		var parts: PackedStringArray = String(key).split(":")
		var mirror_key: String = key if parts.size() == 1 else "%s:%s" % [parts[0], "Right" if parts[1] == "Left" else "Left"]
		var sign := -1.0 if Recovery.LEFT_POSITIVE.has(parts[0]) else 1.0
		if not is_equal_approx(float(r.flat[key]), sign * float(l.flat[mirror_key])):
			check(false, "left pose mirrors right at " + key)
			break
	var fwd := Recovery.at(0.19, ahead, 0.5, Vector2.ZERO)
	check(float(fwd.pitch) < -1.2 and absf(float(fwd.roll)) < 0.01, "a forward dive lies chest down, level side to side")
	var back := Recovery.at(0.35, Vector2(0, -1), 0.5, Vector2.ZERO)
	check(float(back.pitch) > 0.8, "a backward dive lands on the back")
	var end := Recovery.at(Recovery.duration(0.5) + 0.01, right, 0.5, Vector2.ZERO)
	check(absf(float(end.pitch)) < 0.001 and absf(float(end.roll)) < 0.001 and end.stage == "stand", "the recovery ends upright and level")

	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.animation.pose_smoothing = false
	# Touchdown: continuous with the airborne layout, not snapped upright.
	land(lab, Vector3.FORWARD)
	var air_pitch: float = lab.animation.dive_recovery_root.x
	check(air_pitch < -0.4, "the dive is laid out when it touches down (%.2f)" % air_pitch)
	at(lab, 0.0)
	check(absf(lab.body.rotation.x - air_pitch) < 0.02, "touchdown does not snap the body upright (%.2f vs %.2f)" % [lab.body.rotation.x, air_pitch])
	check(lab.animation.dive_input_locked(), "input is locked at touchdown")
	check(lab.animation.dive_slide_decel > 0.0, "the body decelerates into the floor")
	var stop: float = 25.0 / (2.0 * lab.animation.dive_slide_decel)
	check(stop > 0.3 and stop < 1.6, "slide distance is short (%.2f m)" % stop)
	# The floor, for every direction and both ends of dive quality.
	for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, -0.7)]:
		for quality in [0.0, 1.0]:
			land(lab, direction, quality)
			var worst := INF
			var total: float = Recovery.duration(quality)
			for i in range(41):
				at(lab, total * float(i) / 40.0)
				worst = minf(worst, floor_gap(lab))
			check(worst > -0.003, "body stays above the floor: %s q%.0f (%.3f m)" % [direction, quality, worst])
	# Lock, release, finish.
	land(lab, Vector3.RIGHT, 0.5)
	var total2: float = Recovery.duration(0.5)
	lab.animation.dive_recovery_time = 0.1
	check(lab.animation.dive_input_locked(), "locked early in the recovery")
	lab.animation.dive_recovery_time = Recovery.lock_seconds(0.5) + 0.02
	check(not lab.animation.dive_input_locked(), "control returns when the body starts to rise")
	lab.animation.dive_recovery_time = total2 - 0.01
	lab.animation.tick_dive_recovery(0.02)
	check(lab.animation.dive_recovery_time < 0.0, "the recovery ends at the end of its clock")
	lab.animation.update()
	check(absf(lab.body.rotation.x) < 0.0001 and absf(lab.body.rotation.z) < 0.0001, "ground state is level after recovery")
	# Any new action cancels it.
	land(lab, Vector3.RIGHT, 0.5)
	lab.animation.dive_recovery_time = 0.5
	lab.motion.jump_charge = 0.1
	lab.animation.tick_dive_recovery(0.016)
	check(lab.animation.dive_recovery_time < 0.0, "starting an action cancels the recovery")
	lab.motion.jump_charge = -1.0
	# The rolling receive owns its own landing.
	lab.animation.roll_lock = 0.5
	lab.animation.dive_launched = true
	lab.animation.begin_dive_recovery()
	check(lab.animation.dive_recovery_time < 0.0, "a rolling receive does not also play the floor recovery")
	lab.animation.roll_lock = 0.0
	# One continuous animation: the crouching step, the dive, the landing and the getting up share a source.
	var q := 0.7
	land(lab, Vector3.FORWARD, q)
	lab.animation.dive_recovery_time = 0.05
	check(lab.animation.pose_source(false, false, false) == "dive", "just after touchdown the source is still the dive")
	lab.animation.dive_recovery_time = Recovery.lock_seconds(q) + 0.05
	check(lab.animation.pose_source(false, false, false) == "dive", "through the rise it is still the dive")
	lab.animation.dive_recovery_time = -1.0
	check(lab.animation.pose_source(false, false, false) == "locomotion", "after the recovery the source is locomotion")
	# Short, and with no stops: the pose keeps moving through every stage.
	check(Recovery.duration(0.5) < 0.95 and Recovery.lock_seconds(0.5) < 0.65, "the whole recovery is under a second (%.2f s, locked %.2f s)" % [Recovery.duration(0.5), Recovery.lock_seconds(0.5)])
	var dt := 1.0 / 60.0
	var total: float = Recovery.duration(0.5)
	var speeds := []
	var previous: Dictionary = Recovery.at(0.0, ahead, 0.5, Vector2(-0.64, 0.0))
	var t := dt
	while t < total:
		var now: Dictionary = Recovery.at(t, ahead, 0.5, Vector2(-0.64, 0.0))
		var speed := 0.0
		for key in now.flat:
			speed += absf(float(now.flat[key]) - float(previous.flat[key])) / dt
		speed += absf(float(now.pitch) - float(previous.pitch)) / dt * 57.3
		speeds.append(speed)
		previous = now
		t += dt
	var stalls := 0
	for i in range(3, speeds.size() - 8):
		var around := (float(speeds[i - 3]) + float(speeds[i + 3])) * 0.5
		if float(speeds[i]) < around * 0.25 and around > 200.0:
			stalls += 1
	check(stalls == 0, "no stop-and-go: the pose never stalls between stages (%d stalled frames)" % stalls)
	# It starts from the pose the dive ended in, not from an authored landing pose.
	var touchdown := {}
	for key in Recovery.at(0.2, ahead, 0.5, Vector2.ZERO).flat:
		touchdown[key] = 33.0
	var started: Dictionary = Recovery.at(0.0, ahead, 0.5, Vector2(-0.5, 0.0), touchdown)
	check(is_equal_approx(float(started.flat["elbow:Left"]), 33.0) and is_equal_approx(float(started.pitch), -0.5), "the recovery begins exactly at the touchdown pose")
	var Blender = load("res://scripts/pose_blender.gd")
	check(float(Blender.transition("dive", "locomotion").seconds) > 0.16 and float(Blender.transition("locomotion", "dive").seconds) < 0.16, "entering the dive is quick and leaving it is soft")
	print("DIVE RECOVERY CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
