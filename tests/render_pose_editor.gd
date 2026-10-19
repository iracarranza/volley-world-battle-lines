extends SceneTree
# Screenshot of the pose editor. Pass --edited to drag a knee handle first, --side for the side view.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var editor = load("res://pose_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--pose="):
			editor._choose_pose(editor.Library.list_poses().find(a.substr(7)))
	if "--side" in args:
		editor.orbit_yaw = PI * 0.5
		editor._place_camera()
	if "--edited" in args:
		editor.selected = "knee_l"
		editor._push_undo()
		editor.dragging = true
		editor._drag(Vector2(0, 40))
		editor.dragging = false
	if "--transition" in args:
		editor.from_pick.select(editor.Library.list_poses().find("ready_stance"))
		editor.to_pick.select(editor.Library.list_poses().find("planted_receive"))
		editor._load_transition_settings()
		editor.play_transition()
		editor.transition_playing = false
		editor.blender.seek(editor.blender.duration() * 0.5)
		editor._show_transition()
	if "--hips" in args:
		editor._push_undo()
		editor.Library.set_value(editor.pose, "hip_shift", "", -22.0)
		editor.Library.set_value(editor.pose, "hip_hinge", "", 35.0)
		editor._changed()
	if "--lean" in args:
		editor._push_undo()
		editor.Library.set_value(editor.pose, "hip_hinge", "", 20.0)
		editor.Library.set_value(editor.pose, "lumbar_flexion", "", 30.0)
		editor.Library.set_value(editor.pose, "thoracic_bend", "", 15.0)
		editor.Library.set_value(editor.pose, "thoracic_twist", "", 30.0)
		editor.Library.set_value(editor.pose, "neck_twist", "", 35.0)
		editor.Library.set_value(editor.pose, "hip_rotation", "", 25.0)
		editor._changed()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var pose_tag := ""
	for a in args:
		if a.begins_with("--pose="):
			pose_tag = "-" + a.substr(7)
	var name := "pose-editor" + pose_tag + ("-edited" if "--edited" in args else "") + ("-side" if "--side" in args else "") + ("-lean" if "--lean" in args else "") + ("-hips" if "--hips" in args else "") + ("-transition" if "--transition" in args else "")
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
	quit()
