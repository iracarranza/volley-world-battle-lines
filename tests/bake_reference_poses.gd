extends SceneTree
# Writes the reference poses the blender and the transition preview use, from the code that
# drives them today: godot --headless --path . --script res://tests/bake_reference_poses.gd
# Existing files are left alone unless --force is passed, so hand edits survive.
const Visual := preload("res://scripts/voli_visual.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const Library := preload("res://scripts/pose_library.gd")
const Stage := preload("res://scripts/dive_stage.gd")
const SetStage := preload("res://scripts/set_stage.gd")
func _initialize() -> void:
	call_deferred("run")
func _write(name: String, pose: Dictionary) -> void:
	if FileAccess.file_exists(Library.file_path(name)) and not "--force" in OS.get_cmdline_user_args():
		print("kept ", name)
		return
	Library.save_pose(name, pose)
	print("wrote ", name)
func run() -> void:
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	var body: Node3D = Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"}).body
	# Ready stance: whatever the gait leaves at rest when not receiving, read back off the rig.
	Pose.base(body, 0.0, 0.0, 0.0, false)
	var ready := {"mirror": false, "channels": {}, "left": {}, "right": {}}
	for channel in Library.CHANNELS:
		ready.channels[channel] = 0.0
	for joint in Library.JOINTS:
		for index in range(2):
			var node := body.get_node(joint.path % Library.SIDES[index]) as Node3D
			var euler := node.basis.get_euler(EULER_ORDER_XZY)
			for axis in [["x", 0], ["y", 1], ["z", 2]]:
				if joint.has(axis[0]):
					var channel: String = joint[axis[0]]
					var v := rad_to_deg(euler[axis[1]]) * float(Library.CHANNELS[channel].sign[index])
					ready[["left", "right"][index]][channel] = v
	ready.channels = ready.left.duplicate()
	ready.channels["hip_hinge"] = -rad_to_deg((body.get_node("Torso") as Node3D).rotation.x)
	_write("ready_stance", ready)
	# Dive poses for a dive to the right: loading, and at contact.
	var base := Library.load_pose("planted_receive")
	_write("dive_load_right", Stage.pose_for(Stage.resolve(-0.30, Vector2(1, 0)), base))
	_write("dive_contact_right", Stage.pose_for(Stage.resolve(0.0, Vector2(1, 0)), base))
	# The set, from VWM's SetBiomechanics: hands up at the forehead, at contact, arms fully extended after it, a jump set, and a
	# set off the forearms.
	for entry in [["set_gather", -0.16, &"standing"], ["set_contact", 0.04, &"standing"], ["set_extend", 0.40, &"standing"], ["set_jump_contact", 0.04, &"jump"], ["set_underhand_contact", 0.0, &"underhand"]]:
		_write(entry[0], Library.from_flat(SetStage.pose_for(entry[1], 1.0, entry[2]), false))
	quit()
