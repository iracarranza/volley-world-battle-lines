extends SceneTree
const Library := preload("res://scripts/pose_library.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func pose_with(lab, action: int, speed: float, cycle: float) -> Dictionary:
	lab._reset()
	lab.selected = action
	lab.locked_action = action
	lab.armed = true
	lab.motion.gait_cycle = cycle
	lab.player.velocity = Vector3(0, 0, -speed)
	lab.animation.pose_smoothing = false
	lab.animation.update()
	return Library.read_rig(lab.body)

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	for i in 20:
		await physics_frame
	for action in [2, 3]:
		var still := pose_with(lab, action, 0.0, 0.0)
		var moving := pose_with(lab, action, 4.5, 0.6)
		var hand := "Right" if action == 2 else "Left"
		check(float(still["shoulder_pitch:" + hand]) < -140.0, "Prepared %s raises the hands when standing" % ["attack", "block"][action - 2])
		check(float(moving["shoulder_pitch:" + hand]) > -60.0, "Prepared %s lowers the hands while moving" % ["attack", "block"][action - 2])
		check(absf(float(still["elbow:Left"])) < 1.0 and absf(float(still["elbow:Right"])) < 1.0, "Raised hands have a straight elbow even when standing")
	# Raised arm while travelling slowly: elbow must not carry the walk bend
	var slow := pose_with(lab, 3, 0.2, 0.9)
	check(absf(float(slow["elbow:Left"])) < 6.0, "A raised arm does not inherit the walk's elbow bend (%.1f)" % float(slow["elbow:Left"]))
	# Set preparation keeps the walk cycle in the legs
	var set_still := pose_with(lab, 1, 0.0, 0.0)
	var walk_a := pose_with(lab, 1, 4.5, 0.0)
	var walk_b := pose_with(lab, 1, 4.5, 1.6)
	check(absf(float(walk_a["hip:Left"]) - float(walk_b["hip:Left"])) > 5.0, "Moving set preparation still swings the legs (%.1f vs %.1f)" % [float(walk_a["hip:Left"]), float(walk_b["hip:Left"])])
	check(absf(float(set_still["hip:Left"]) - float(preload("res://scripts/set_stage.gd").data_pose(-0.16)["hip:Left"])) < 0.5, "Standing set preparation is the set gather pose")
	check(float(walk_a["shoulder_pitch:Left"]) > 60.0 and float(walk_b["shoulder_pitch:Left"]) > 60.0, "Moving set preparation keeps the hands up")
	print("MOVING PREPARED POSE CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
