extends SceneTree
const SetStage := preload("res://scripts/set_stage.gd")
const Library := preload("res://scripts/pose_library.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# The set is in the editor's library, and it is the set VWM defines.
	for name in ["set_gather", "set_contact", "set_extend", "set_jump_contact", "set_underhand_contact"]:
		check(Library.list_poses().has(name), "%s is in the pose library" % name)
	var gather := Library.read_file("set_gather")
	var contact := Library.read_file("set_contact")
	var extend := Library.read_file("set_extend")
	check(Library.value(gather, "shoulder_pitch", "Left") < Library.value(contact, "shoulder_pitch", "Left") and Library.value(contact, "shoulder_pitch", "Left") < Library.value(extend, "shoulder_pitch", "Left"), "the hands travel up through gather, contact and extension")
	check(Library.value(gather, "elbow", "Left") > Library.value(contact, "elbow", "Left") and Library.value(contact, "elbow", "Left") > Library.value(extend, "elbow", "Left"), "the elbows open through the set")
	check(Library.value(gather, "knee", "Left") < Library.value(extend, "knee", "Left") - 30.0, "the legs drive from loaded knees to nearly straight")
	check(Library.value(gather, "hip", "Left") < 0.0 and Library.value(gather, "hip", "Right") > 0.0, "one foot is slightly ahead of the other, as VWM splits the hips")
	var jump := Library.read_file("set_jump_contact")
	check(Library.value(jump, "knee", "Left") < Library.value(contact, "knee", "Left"), "the jump set tucks the knees")
	# Straight from the data to the rig: hands end up above the face at contact.
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	var body: Node3D = Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "S"}).body
	Pose.base(body, 0.0, 0.0, 0.0, false)
	Library.apply(body, contact, 1.0)
	var hand := (body.get_node("RightArm/Elbow/Wrist") as Node3D).global_position
	var head := (body.get_node("Head") as Node3D).global_position
	check(hand.y > head.y - 0.1 and hand.z < head.z - 0.1, "at contact the hands are up in front of the face (%.2f above, %.2f ahead)" % [hand.y - head.y, head.z - hand.z])
	# Shuffle: with a receive ready the walk is a shuffle, whichever way the voli moves.
	for heading in [0.0, PI, PI * 0.5, -PI * 0.5]:
		var rig: Node3D = Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "L"}).body
		var ready: Dictionary = Pose.base(rig, 0.25, 2.0, heading, true, 1.0)
		check(float(ready.shuffle_blend) > 0.99 and float(ready.backpedal_blend) < 0.01, "receive ready: travelling at %.0f deg is a shuffle (%.2f), not a run or backpedal (%.2f)" % [rad_to_deg(heading), float(ready.shuffle_blend), float(ready.backpedal_blend)])
	var rig2: Node3D = Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "L"}).body
	var free: Dictionary = Pose.base(rig2, 0.25, 2.0, 0.0, false)
	check(float(free.shuffle_blend) < 0.01, "without a receive ready, forward travel is the ordinary gait")
	var half: Dictionary = Pose.base(rig2, 0.25, 2.0, 0.0, true, 0.5)
	check(float(half.shuffle_blend) > 0.4 and float(half.shuffle_blend) < 0.99, "the shuffle comes in with the stance, not as a snap")
	# A shuffle swings the thighs far less than a run does.
	var run_swing := 0.0
	var shuffle_swing := 0.0
	for i in range(16):
		var cycle := float(i) / 16.0
		run_swing = maxf(run_swing, absf(float(Pose.base(rig2, cycle, 3.5, 0.0, false).right_hip_degrees)))
		shuffle_swing = maxf(shuffle_swing, absf(float(Pose.base(rig2, cycle, 3.5, 0.0, true, 1.0).right_hip_degrees)))
	check(shuffle_swing < run_swing, "the shuffle's thighs swing less than a run's (%.0f vs %.0f deg)" % [shuffle_swing, run_swing])
	print("SET AND SHUFFLE CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
