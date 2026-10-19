extends "res://tests/support/test_case.gd"
const Smoother := preload("res://scripts/pose_smoother.gd")
const Library := preload("res://scripts/pose_library.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const Receive := preload("res://scripts/receive_pose.gd")
func _initialize() -> void:
	call_deferred("run")
func _gap(a: Dictionary, b: Dictionary) -> float:
	var worst := 0.0
	for key in a:
		worst = maxf(worst, absf(float(a[key]) - float(b.get(key, 0.0))))
	return worst
func _rig() -> Node3D:
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	return Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"}).body
func _landmarks(body: Node3D) -> Array:
	var points := []
	for path in ["Head", "LeftArm", "RightArm", "LeftArm/Elbow", "RightArm/Elbow", "LeftLeg/Knee", "RightLeg/Knee", "LeftLeg/Knee/Shoe", "RightLeg/Knee/Shoe", "Singlet", "Torso"]:
		var node := body.get_node_or_null(path) as Node3D
		if node != null:
			points.append(body.to_local(node.global_position))
	return points
# Local rotation of every limb joint as a flat list of vectors.
func _limb_angles(body: Node3D) -> Array:
	var angles := []
	for path in ["LeftArm", "RightArm", "LeftArm/Elbow", "RightArm/Elbow", "LeftLeg", "RightLeg", "LeftLeg/Knee", "RightLeg/Knee"]:
		var node := body.get_node(path) as Node3D
		var basis := node.basis
		# Arms ride the thorax once the spine has posed them; compare them without it.
		if path.ends_with("Arm") and body.has_meta("spine_xf"):
			basis = (body.get_meta("spine_xf").thorax as Transform3D).basis.inverse() * basis
		angles.append(basis.get_euler(EULER_ORDER_XZY))
	return angles
func _same(a: Array, b: Array, tolerance: float) -> bool:
	for i in range(a.size()):
		if (a[i] as Vector3).distance_to(b[i]) > tolerance:
			return false
	return true
func run() -> void:
	# A source that never changes is untouched, and a repeat call in the same frame changes nothing.
	var smoother := Smoother.new()
	var a := {"knee:Left": -60.0, "hip_hinge": 5.0}
	var b := {"knee:Left": -5.0, "hip_hinge": 0.0}
	for i in range(5):
		check(_gap(smoother.update(a, "one", 0.016), a) < 0.0001, "One source passes straight through")
	# At a switch the drawn pose does not jump, then it runs down to the new source.
	var at_switch := smoother.update(b, "two", 0.016)
	check(absf(float(at_switch["knee:Left"]) - (-60.0)) < 1.0, "At a switch the pose starts where it was (%.2f)" % float(at_switch["knee:Left"]))
	var previous := float(at_switch["knee:Left"])
	var worst_step := 0.0
	var overshoot := false
	for i in range(40):
		var shown := smoother.update(b, "two", 0.016)
		worst_step = maxf(worst_step, absf(float(shown["knee:Left"]) - previous))
		previous = float(shown["knee:Left"])
		if previous > -5.0 + 0.001:
			overshoot = true
	check(_gap(smoother.update(b, "two", 0.016), b) < 0.001 and not smoother.is_blending(), "After the transition time the new source stands alone")
	check(worst_step < 12.0 and not overshoot, "The run-down is gradual and does not overshoot (largest step %.2f deg)" % worst_step)
	# Switching mid-transition keeps moving smoothly.
	smoother.reset()
	smoother.update(a, "one", 0.016)
	smoother.update(b, "two", 0.016)
	for i in range(3):
		smoother.update(b, "two", 0.016)
	var before_mid := smoother.update(b, "two", 0.016)
	var mid := smoother.update(b, "two", 0.016)
	var frame_step := absf(float(mid["knee:Left"]) - float(before_mid["knee:Left"]))
	var interrupted := smoother.update(a, "one", 0.016)
	check(absf(float(interrupted["knee:Left"]) - float(mid["knee:Left"])) < frame_step * 1.6 + 0.5, "Switching back mid-transition carries on at the speed it had (step %.2f vs %.2f)" % [absf(float(interrupted["knee:Left"]) - float(mid["knee:Left"])), frame_step])
	# Same-frame repeat calls do not advance the transition.
	smoother.reset()
	smoother.update(a, "one", 0.016)
	var first := smoother.update(b, "two", 0.016)
	var again := smoother.update(b, "two", 0.0)
	check(absf(float(first["knee:Left"]) - float(again["knee:Left"])) < 0.01, "A repeat call in the same frame changes nothing")
	# Reading the rig back and writing it again must change nothing on the body.
	for kind in ["planted", "reaching", "off-axis", "moving"]:
		var body := _rig()
		Pose.base(body, 0.0, 0.0, 0.0, true, 1.0)
		Receive.apply(body, kind, Vector3(0.5, 1, -1), 1.0)
		var before := _landmarks(body)
		var angles_before := _limb_angles(body)
		Library.apply(body, Library.from_flat(Library.read_rig(body), false), 1.0)
		check(_same(angles_before, _limb_angles(body), 0.0001), "Reading back the %s receive keeps every arm and leg joint angle" % kind)
		if kind == "planted":
			check(_same(before, _landmarks(body), 0.012), "Reading back the planted receive leaves the whole body where it was")
	# Overhead arms, the way the attack sets them (beyond the editor's slider range).
	var jump := _rig()
	Pose.base(jump, 0.0, 0.0, 0.0, false)
	for side in ["Left", "Right"]:
		(jump.get_node(side + "Arm") as Node3D).rotation = Vector3(-2.7, 0.0, 0.35)
	var jump_before := _landmarks(jump)
	Library.apply(jump, Library.from_flat(Library.read_rig(jump), false), 1.0)
	check(_same(jump_before, _landmarks(jump), 0.012), "Overhead arms survive a read-back")
	# A planted receive with the hips moved reads back to the pre-solve legs, so it does not shift twice.
	var shifted := _rig()
	Pose.base(shifted, 0.0, 0.0, 0.0, true, 1.0)
	var hips_back := Library.builtin("planted_receive")
	Library.set_value(hips_back, "hip_shift", "", -25.0)
	Receive.apply(shifted, "planted", Vector3(0, 1, -1), 1.0, hips_back)
	var shifted_before := _landmarks(shifted)
	Library.apply(shifted, Library.from_flat(Library.read_rig(shifted), false), 1.0)
	check(_same(shifted_before, _landmarks(shifted), 0.012), "A planted receive with hips back survives a read-back without shifting twice")
	print("POSE SMOOTHER CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
