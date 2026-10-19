extends SceneTree
const Visual := preload("res://scripts/voli_visual.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const Receive := preload("res://scripts/receive_pose.gd")
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
func _rig() -> Node3D:
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	return Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"}).body
func _knee(body: Node3D, side: String) -> float:
	return (body.get_node(side + "Leg/Knee") as Node3D).rotation_degrees.x
func _planted(body: Node3D, pose: Dictionary) -> void:
	var gait := Pose.base(body, 0.0, 0.0, 0.0, true, 1.0)
	body.get_node("Torso").rotation.x = float(gait.torso_pitch_radians)
	Receive.apply(body, "planted", Vector3(0, 1, -1), 1.0, pose)
func run() -> void:
	var body := _rig()
	# Joint values measured from the code-driven planted receive before it became data.
	_planted(body, Library.builtin("planted_receive"))
	var left := body.get_node("LeftLeg") as Node3D
	var arm := body.get_node("RightArm") as Node3D
	check(left.rotation_degrees.is_equal_approx(Vector3(16.0, 0.0, -15.0)), "Built-in planted legs match the old stance")
	check((left.get_node("Knee") as Node3D).rotation_degrees.is_equal_approx(Vector3(-60.0, 0.0, 0.0)), "Built-in planted knees match")
	# The arm now rides the trunk lean (-5.729578 deg), so its pitch is the authored 56.14986 plus the lean.
	check(arm.rotation_degrees.is_equal_approx(Vector3(56.14986 - 5.729578, 0.0, -18.33465)), "Built-in planted arm matches, carried by the trunk lean (right arm rolls the other way)")
	check((arm.get_node("Elbow") as Node3D).rotation_degrees.x > 17.18 and (arm.get_node("Elbow") as Node3D).rotation_degrees.x < 17.2, "Built-in planted elbow matches")
	check((body.get_node("Torso") as Node3D).rotation_degrees.is_zero_approx(), "The torso node itself stays unrotated; the spine skins its mesh instead")
	# The shipped file must load and agree with the built-in until someone edits it on purpose.
	var file := Library.read_file("planted_receive")
	check(file.mirror and file.channels.size() == Library.CHANNELS.size(), "Shipped planted_receive.json defines every channel")
	# Editing: mirrored writes both sides, unmirrored writes one.
	var pose := Library.builtin("planted_receive")
	Library.set_value(pose, "knee", "Left", -40.0)
	_planted(body, pose)
	check(is_equal_approx(_knee(body, "Left"), -40.0) and is_equal_approx(_knee(body, "Right"), -40.0), "Mirrored edit moves both knees")
	Library.set_mirror(pose, false)
	Library.set_value(pose, "knee", "Left", -20.0)
	_planted(body, pose)
	check(is_equal_approx(_knee(body, "Left"), -20.0) and is_equal_approx(_knee(body, "Right"), -40.0), "Unmirrored edit moves one knee")
	Library.set_mirror(pose, true)
	check(Library.value(pose, "knee", "Right") == -20.0 and pose.left.is_empty(), "Turning mirror back on keeps the left value for both")
	check(Library.value(pose, "knee") == Library.value(pose, "knee", "Left"), "Unsided read agrees")
	# Limits and weight.
	Library.set_value(pose, "knee", "", -999.0)
	check(Library.value(pose, "knee") == Library.CHANNELS.knee.range.x, "Values clamp to joint limits")
	var rest := _rig()
	var before := (rest.get_node("LeftLeg/Knee") as Node3D).rotation_degrees
	Library.apply(rest, Library.builtin("planted_receive"), 0.0)
	check((rest.get_node("LeftLeg/Knee") as Node3D).rotation_degrees.is_equal_approx(before), "Weight zero leaves the rig alone")
	# Trunk lean carries head and shoulders about the hips, never accumulates, and releases.
	var lean_rig := _rig()
	var head := lean_rig.get_node("Head") as Node3D
	var shoulder := lean_rig.get_node("LeftArm") as Node3D
	var upright_head := head.position
	var upright_shoulder := shoulder.position
	var upright := Library.builtin("planted_receive")
	Library.set_value(upright, "hip_hinge", "", 0.0)
	_planted(lean_rig, upright)
	check(head.position.is_equal_approx(upright_head) and shoulder.position.is_equal_approx(upright_shoulder), "Upright trunk leaves head and shoulders where the rig built them")
	var leaning := Library.builtin("planted_receive")
	Library.set_value(leaning, "hip_hinge", "", 45.0)
	_planted(lean_rig, leaning)
	var first_head := head.position
	check(head.position.z < upright_head.z - 0.2 and head.position.y < upright_head.y, "Leaning forward moves the head forward and down")
	check(shoulder.position.z < upright_shoulder.z - 0.1, "Leaning forward moves the shoulders forward")
	check(is_equal_approx(head.position.distance_to(Vector3(0, (lean_rig.get_node("LeftLeg") as Node3D).position.y, 0)), upright_head.distance_to(Vector3(0, (lean_rig.get_node("LeftLeg") as Node3D).position.y, 0))), "The lean is a rotation about the hips, so head-to-hip distance holds")
	_planted(lean_rig, leaning)
	check(head.position.is_equal_approx(first_head), "Posing twice does not stack the lean")
	Pose.base(lean_rig, 0.0, 0.0, 0.0, false)
	check(head.position.is_equal_approx(upright_head) and shoulder.position.is_equal_approx(upright_shoulder), "Leaving the pose puts the upper body back")
	# Spine: skinned meshes deform, twist turns the chest about the spine, and everything restores.
	var spine_rig := _rig()
	var torso_node := spine_rig.get_node("Torso") as MeshInstance3D
	var rest_mesh := torso_node.mesh
	var flat := Library.builtin("planted_receive")
	for channel in ["hip_hinge", "lumbar_flexion", "thoracic_flexion"]:
		Library.set_value(flat, channel, "", 0.0)
	_planted(spine_rig, flat)
	var chest_flat := (spine_rig.get_node("LeftArm") as Node3D).position
	var bent := flat.duplicate(true)
	Library.set_value(bent, "lumbar_flexion", "", 40.0)
	_planted(spine_rig, bent)
	check(torso_node.mesh != rest_mesh, "Lumbar flexion skins the torso mesh")
	check(torso_node.mesh.get_aabb().size.z > rest_mesh.get_aabb().size.z, "A bent torso is deeper front to back than a straight one")
	check((spine_rig.get_node("LeftArm") as Node3D).position.z < chest_flat.z - 0.1, "Bending at the waist carries the chest forward")
	var twisted := flat.duplicate(true)
	Library.set_value(twisted, "thoracic_twist", "", 35.0)
	_planted(spine_rig, twisted)
	var left_shoulder := (spine_rig.get_node("LeftArm") as Node3D).position
	var right_shoulder := (spine_rig.get_node("RightArm") as Node3D).position
	check(absf(left_shoulder.z - right_shoulder.z) > 0.1 and is_equal_approx(left_shoulder.y, right_shoulder.y), "Chest twist turns the shoulders about the spine without tipping them")
	Pose.base(spine_rig, 0.0, 0.0, 0.0, false)
	check(torso_node.mesh == rest_mesh, "Torso mesh is the original again after Pose.base")
	# Hip rotation turns the leg about its own long axis, so the knee does not move.
	var leg_rig := _rig()
	var straight := Library.builtin("planted_receive")
	_planted(leg_rig, straight)
	var knee_before := (leg_rig.get_node("LeftLeg/Knee") as Node3D).global_position
	var foot_before := (leg_rig.get_node("LeftLeg/Knee/Shoe") as Node3D).global_position
	var rotated := straight.duplicate(true)
	Library.set_value(rotated, "hip_rotation", "", 30.0)
	_planted(leg_rig, rotated)
	check((leg_rig.get_node("LeftLeg/Knee") as Node3D).global_position.is_equal_approx(knee_before), "Hip rotation leaves the knee where it was")
	check(not (leg_rig.get_node("LeftLeg/Knee/Shoe") as Node3D).global_position.is_equal_approx(foot_before), "Hip rotation swings the foot because the knee hinge turns with the thigh")
	# Hips back: the pelvis moves, the feet do not, and the legs fold to meet them.
	var shift_rig := _rig()
	var level := Library.builtin("planted_receive")
	_planted(shift_rig, level)
	var feet_before := [(shift_rig.get_node("LeftLeg/Knee/Shoe") as Node3D).global_position, (shift_rig.get_node("RightLeg/Knee/Shoe") as Node3D).global_position]
	var hips_before := (shift_rig.get_node("LeftLeg") as Node3D).global_position
	var knee_before_shift := _knee(shift_rig, "Left")
	var hips_back := level.duplicate(true)
	Library.set_value(hips_back, "hip_shift", "", -20.0)
	_planted(shift_rig, hips_back)
	var hips_after := (shift_rig.get_node("LeftLeg") as Node3D).global_position
	check(hips_after.z > hips_before.z + 0.15, "Hips back moves the hip sockets backward (the rig faces -Z)")
	check((shift_rig.get_node("LeftLeg/Knee/Shoe") as Node3D).global_position.distance_to(feet_before[0]) < 0.02 and (shift_rig.get_node("RightLeg/Knee/Shoe") as Node3D).global_position.distance_to(feet_before[1]) < 0.02, "Feet stay planted when the hips move")
	check(absf(_knee(shift_rig, "Left") - knee_before_shift) > 1.0, "The knee folds differently to keep the foot planted")
	var hips_forward := level.duplicate(true)
	Library.set_value(hips_forward, "hip_shift", "", 15.0)
	_planted(shift_rig, hips_forward)
	check((shift_rig.get_node("LeftLeg") as Node3D).global_position.z < hips_before.z - 0.1, "Hips forward moves the hip sockets forward")
	Pose.base(shift_rig, 0.0, 0.0, 0.0, false)
	check(absf((shift_rig.get_node("LeftLeg") as Node3D).global_position.z - hips_before.z) < 0.001, "Leaving the pose puts the hips back")
	# Tails grow from the pelvis: they follow the hips, not the neck.
	for kind in ["Feli", "Cani", "Avi"]:
		var tail_lab := Node3D.new()
		tail_lab.set_script(load("res://scripts/preview_stub.gd"))
		root.add_child(tail_lab)
		var tail_parent := Node3D.new()
		tail_lab.add_child(tail_parent)
		var tail_body: Node3D = Visual.build(tail_lab, tail_parent, kind, {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"}).body
		var tail := tail_body.get_node_or_null("Tail") as Node3D
		if tail == null:
			tail = tail_body.get_node("TailFeathers") as Node3D
		Pose.base(tail_body, 0.0, 0.0, 0.0, true, 1.0)
		var tail_flat := Library.builtin("planted_receive")
		Library.set_value(tail_flat, "hip_hinge", "", 0.0)
		_planted(tail_body, tail_flat)
		var tail_up := tail.position
		var turned := tail_flat.duplicate(true)
		Library.set_value(turned, "neck_twist", "", 60.0)
		Library.set_value(turned, "thoracic_twist", "", 30.0)
		Library.set_value(turned, "neck_flexion", "", 40.0)
		_planted(tail_body, turned)
		check(tail.position.is_equal_approx(tail_up), "%s: turning the chest and neck does not move the tail" % kind)
		var hinged := tail_flat.duplicate(true)
		Library.set_value(hinged, "hip_hinge", "", 45.0)
		_planted(tail_body, hinged)
		check(not tail.position.is_equal_approx(tail_up), "%s: hinging at the hips carries the tail" % kind)
	# Anatomical limits.
	Library.set_value(straight, "knee", "", 20.0)
	check(Library.value(straight, "knee") == 0.0, "The knee cannot hyperextend")
	Library.set_value(straight, "neck_twist", "", 200.0)
	check(Library.value(straight, "neck_twist") == 70.0, "The neck turns at most 70 degrees")
	# Save and reload.
	var written := Library.builtin("pose_library_test")
	written.channels = {"knee": -33.0, "hip_hinge": 4.0}
	check(Library.save_pose("pose_library_test", written) == OK, "Pose file saves")
	Library.forget("pose_library_test")
	var back := Library.load_pose("pose_library_test")
	check(back.channels.get("knee") == -33.0 and back.channels.get("hip_hinge") == 4.0, "Saved pose reads back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Library.file_path("pose_library_test")))
	# Old pose files carry `trunk_pitch` (negative leans forward); they load as hip hinge.
	var legacy_file := FileAccess.open(Library.file_path("pose_library_legacy"), FileAccess.WRITE)
	legacy_file.store_string('{"mirror": true, "channels": {"trunk_pitch": -12.0, "knee": -50.0}}')
	legacy_file.close()
	var legacy := Library.read_file("pose_library_legacy")
	check(is_equal_approx(Library.value(legacy, "hip_hinge"), 12.0) and not legacy.channels.has("trunk_pitch"), "A legacy trunk_pitch file migrates to hip_hinge")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Library.file_path("pose_library_legacy")))
	print("pose library: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
