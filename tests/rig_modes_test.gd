extends "res://tests/support/test_case.gd"
const Visual := preload("res://scripts/voli_visual.gd")
const Merge := preload("res://scripts/rig_merge.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
func _initialize() -> void: call_deferred("run")
func rig(mode: int) -> Node3D:
	Visual.rig_mode = mode
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	return lab
func total_vertices(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		count += (node as MeshInstance3D).mesh.get_faces().size()
	for child in node.get_children():
		count += total_vertices(child)
	return count
func run() -> void:
	var original := Visual.rig_mode
	var separate = rig(Visual.RigMode.SEPARATE)
	await physics_frame
	var merged = rig(Visual.RigMode.MERGED)
	var skinned = rig(Visual.RigMode.SKELETON)
	for i in 4: await physics_frame
	var count_separate := Merge.count_meshes(separate.body)
	var count_merged := Merge.count_meshes(merged.body)
	var count_skinned := Merge.count_meshes(skinned.body)
	check(count_separate == 77, "The separate rig is every part its own mesh (%d)" % count_separate)
	check(count_merged < count_separate * 0.75, "Merging the limb joints' rigid parts drops the mesh count (%d from %d)" % [count_merged, count_separate])
	check(count_skinned < count_separate * 0.3, "The skeleton rig bakes the rigid parts into two skinned meshes (%d from %d)" % [count_skinned, count_separate])
	# The same geometry, drawn fewer ways
	var faces_separate := total_vertices(separate.body)
	check(absf(float(total_vertices(merged.body) - faces_separate)) < 1.0, "Merging keeps every triangle")
	# The joint nodes the animation code reaches are all still there
	for path in ["LeftArm/Elbow/Wrist/ContactAnchor", "RightLeg/Knee/Shoe", "Torso", "Head/Face"]:
		check(merged.body.get_node_or_null(path) != null and skinned.body.get_node_or_null(path) != null, "%s is still reachable in every mode" % path)
	# Standing on the floor is the same
	check(absf(float(merged.body.position.y) - float(separate.body.position.y)) < 0.001 and absf(float(skinned.body.position.y) - float(separate.body.position.y)) < 0.001, "The feet find the floor at the same height in every mode")
	# The skeleton follows the joints
	var node = skinned.body.get_node("RigSkeletonSync") if skinned.body.has_node("RigSkeletonSync") else null
	var sync = null
	for child in skinned.body.get_children():
		if child.get_script() != null and String(child.get_script().resource_path).ends_with("rig_skeleton.gd"):
			sync = child
	check(sync != null and sync.skeleton != null and sync.skeleton.get_bone_count() == sync.owners.size() and sync.owners.size() >= 15, "The skeleton has a bone for each carrying joint (%d)" % (sync.owners.size() if sync != null else -1))
	skinned.legs[0].rotation.x = -0.9
	skinned.legs[0].get_node("Knee").rotation_degrees.x = -70.0
	sync._process(0.016)
	var matched := true
	var root_inverse: Transform3D = skinned.body.global_transform.affine_inverse()
	for bone in range(sync.owners.size()):
		var expected: Transform3D = root_inverse * (sync.owners[bone] as Node3D).global_transform
		var actual: Transform3D = sync.skeleton.get_bone_pose(bone)
		if not expected.origin.is_equal_approx(actual.origin) or not expected.basis.get_rotation_quaternion().is_equal_approx(actual.basis.get_rotation_quaternion()):
			matched = false
	check(matched, "Each bone's pose is its joint's transform")
	check(skinned.body.get_node("RigSkeleton") != null and String(skinned.body.get_node("RigSkeleton").get_class()) == "Skeleton3D", "The skeleton is a Skeleton3D on the rig")
	# The spine rig does not treat the skeleton as a rider
	check(preload("res://scripts/spine_rig.gd").NOT_SPINE.has("RigSkeleton"), "The spine rig leaves the skeleton alone")
	for lab in [separate, merged, skinned]:
		lab.queue_free()
	Visual.rig_mode = original
	await process_frame
	print("RIG MODES: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
