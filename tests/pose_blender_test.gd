extends "res://tests/support/test_case.gd"
const Blender := preload("res://scripts/pose_blender.gd")
const Library := preload("res://scripts/pose_library.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
func _initialize() -> void:
	call_deferred("run")
func _max_gap(a: Dictionary, b: Dictionary) -> float:
	var worst := 0.0
	for key in a:
		worst = maxf(worst, absf(float(a[key]) - float(b[key])))
	return worst
func run() -> void:
	var ready := Library.read_file("ready_stance")
	var planted := Library.read_file("planted_receive")
	check(Library.list_poses().has("ready_stance") and Library.list_poses().has("dive_contact_right") and not Library.list_poses().has("transitions"), "The pose library lists its files and not the transition table")
	var flat := Library.flatten(planted)
	check(_max_gap(flat, Library.flatten(Library.from_flat(flat))) < 0.0001, "Flattening a pose and rebuilding it loses nothing")
	# Reaches the target exactly, in the time asked.
	var blender := Blender.new()
	blender.snap(ready)
	blender.go(planted, 0.2)
	for i in range(10):
		blender.update(0.02)
	check(not blender.is_moving() and _max_gap(blender.position, flat) < 0.001, "Arrives at the target after exactly the duration")
	# Starts and stops at rest, never overshoots, and every joint finishes together.
	blender.snap(ready)
	blender.go(planted, 0.2)
	var start := Library.flatten(ready)
	var start_gap := _max_gap(blender.position, start)
	var halfway := 0.0
	var overshoot := false
	var top_speed := 0.0
	for i in range(100):
		blender.update(0.002)
		for key in flat:
			var lo := minf(float(start[key]), float(flat[key])) - 0.01
			var hi := maxf(float(start[key]), float(flat[key])) + 0.01
			if float(blender.position[key]) < lo or float(blender.position[key]) > hi:
				overshoot = true
			top_speed = maxf(top_speed, absf(float(blender.velocity[key])))
		if i == 49:
			halfway = _max_gap(blender.position, start)
	check(start_gap < 0.0001 and not overshoot, "A transition from rest starts at the old pose and does not overshoot")
	check(halfway > 0.0 and top_speed > 0.0, "A transition moves")
	# Interrupting keeps position and speed: no joint jumps when the target changes.
	blender.snap(ready)
	blender.go(planted, 0.3)
	for i in range(8):
		blender.update(0.02)
	var before_pos := blender.position.duplicate()
	var before_vel := blender.velocity.duplicate()
	blender.go(Library.read_file("dive_load_right"), 0.25)
	check(_max_gap(blender.position, before_pos) < 0.0001, "Interrupting does not move any joint")
	blender.update(0.001)
	var jump := _max_gap(blender.position, before_pos)
	var speed_step := 0.0
	for key in before_vel:
		speed_step = maxf(speed_step, absf(float(blender.velocity[key]) - float(before_vel[key])))
	check(jump < 0.5 and speed_step < 15.0, "After an interruption joints keep moving the way they were (jump %.3f deg, speed step %.2f deg/s)" % [jump, speed_step])
	# Scrubbing is deterministic.
	blender.snap(ready)
	blender.go(planted, 0.4)
	blender.seek(0.25)
	var scrub_a := blender.position.duplicate()
	blender.seek(0.1)
	blender.seek(0.25)
	check(_max_gap(scrub_a, blender.position) < 0.0001, "Scrubbing to the same time gives the same pose")
	# Zero duration snaps; curves other than the default reach the target too.
	blender.go(ready, 0.0)
	check(_max_gap(blender.position, Library.flatten(ready)) < 0.0001, "Zero seconds is an immediate snap")
	for curve in ["linear", "ease_in", "ease_out", "ease_in_out"]:
		blender.snap(ready)
		blender.go(planted, 0.1, curve)
		blender.seek(0.1)
		check(_max_gap(blender.position, flat) < 0.001, "The %s curve arrives at the target" % curve)
	# Limits hold during a blend.
	var wild := Library.from_flat({"knee:Left": -10.0, "knee:Right": -10.0})
	blender.snap(wild)
	blender.go(Library.from_flat({"knee:Left": 100.0, "knee:Right": 100.0}), 0.1)
	blender.seek(0.07)
	check(float(blender.position["knee:Left"]) <= 0.0, "A blend never takes a joint outside its range")
	# The transition table.
	var known := Blender.transition("ready_stance", "planted_receive")
	var unknown := Blender.transition("no_such", "pose")
	check(is_equal_approx(float(known.seconds), 0.18) and is_equal_approx(float(unknown.seconds), 0.16), "Transition times come from the table, with a default")
	# On a real rig the blended pose writes through the same path as everything else.
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	var body: Node3D = Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"}).body
	blender.snap(ready)
	blender.go(planted, 0.2)
	blender.seek(0.2)
	Pose.base(body, 0.0, 0.0, 0.0, false)
	blender.apply(body)
	# The elbow is not touched by the leg solve that keeps the feet planted when the hips move.
	var elbow := (body.get_node("LeftArm/Elbow") as Node3D).rotation_degrees.x
	check(absf(elbow - float(planted.channels.elbow)) < 0.01, "Applying the blend poses the rig's elbow at the target")
	blender.snap(ready)
	Pose.base(body, 0.0, 0.0, 0.0, false)
	blender.apply(body)
	check(absf((body.get_node("LeftLeg/Knee") as Node3D).rotation_degrees.x - float(ready.left.knee)) < 0.01, "Starting from the ready pose poses the ready knee")
	print("POSE BLENDER CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
