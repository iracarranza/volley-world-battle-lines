extends "res://tests/support/test_case.gd"
const Wing := preload("res://scripts/wing_pose.gd")
const Visual := preload("res://scripts/voli_visual.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	var rig := Visual.build(lab, parent, "Avi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"})
	var body: Node3D = rig.body
	check(Wing.has_wing(body), "Avi body carries wing joints")
	var elbow := body.get_node("LeftArm/Elbow") as Node3D
	var before := elbow.global_transform
	Wing.apply(body, "tucked", "balance", 1.0)
	check(absf((body.get_node("LeftArm/WingShoulder") as Node3D).rotation_degrees.z) > 10.0, "balance spreads the wing")
	check(elbow.global_transform.is_equal_approx(before), "wing pose leaves the arm unchanged")
	Wing.apply(body, "tucked", "tucked", 0.0)
	check(absf((body.get_node("LeftArm/WingShoulder") as Node3D).rotation_degrees.z) < 0.001, "tucked folds the wing")
	var cat := Visual.build(lab, parent, "Feli", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"})
	check(not Wing.has_wing(cat.body), "non-Avi has no wing and apply is a no-op")
	Wing.apply(cat.body, "tucked", "balance", 1.0)
	print("wing pose: %d failures" % failures)
	quit(1 if failures > 0 else 0)
