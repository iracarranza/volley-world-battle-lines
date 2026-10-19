extends Node3D

# Pose editor: drag the joints of the real voli rig and save the result to the pose
# data file the game reads. Left-drag a handle, right-drag to orbit, wheel to zoom.
const Library := preload("res://scripts/pose_library.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const SpineRig := preload("res://scripts/spine_rig.gd")
const Blender := preload("res://scripts/pose_blender.gd")
const Receive := preload("res://scripts/receive_pose.gd")
const Bodies := preload("res://vendor/vwm/body_type_models.gd")
const TEAL := Color("54ead0")
const GOLD := Color("ffce73")
const PICK_RADIUS := 22.0
const DEGREES_PER_PIXEL := 0.5
const UNDO_LIMIT := 100

# Each handle drags up to three channels: vertical, horizontal, and (holding Shift) vertical
# again for the twist or rotation. v_sign flips the vertical so "up" means what the hint says.
# h_mode: "outward" is away from the body's centre on screen, "left" is toward the character's
# left on screen, so the drag follows the body from any view.
const HANDLES := [
	{"id": "pelvis", "spine": "pelvis", "side": "", "vertical": "hip_hinge", "v_sign": -1.0, "horizontal": "hip_shift", "h_mode": "forward", "shift": "", "hint": "up = more upright, down = hinge forward, sideways = hips forward/back (feet stay planted)"},
	{"id": "lumbar", "spine": "lumbar", "side": "", "vertical": "lumbar_flexion", "v_sign": -1.0, "horizontal": "lumbar_bend", "h_mode": "left", "shift": "lumbar_twist", "hint": "up = straighter, down = bend forward at the waist, sideways = side bend, Shift = twist"},
	{"id": "thoracic", "spine": "thoracic", "side": "", "vertical": "thoracic_flexion", "v_sign": -1.0, "horizontal": "thoracic_bend", "h_mode": "left", "shift": "thoracic_twist", "hint": "up = open the chest, down = round forward, sideways = side bend, Shift = twist"},
	{"id": "neck", "spine": "neck", "side": "", "vertical": "neck_flexion", "v_sign": -1.0, "horizontal": "neck_bend", "h_mode": "left", "shift": "neck_twist", "hint": "up = chin up, down = chin down, sideways = tilt, Shift = turn"},
	{"id": "shoulder_l", "node": "LeftArm", "side": "Left", "vertical": "shoulder_pitch", "v_sign": 1.0, "horizontal": "shoulder_roll", "h_mode": "outward", "shift": "shoulder_rotation", "hint": "up = raise arm, sideways = arms apart, Shift = rotate"},
	{"id": "shoulder_r", "node": "RightArm", "side": "Right", "vertical": "shoulder_pitch", "v_sign": 1.0, "horizontal": "shoulder_roll", "h_mode": "outward", "shift": "shoulder_rotation", "hint": "up = raise arm, sideways = arms apart, Shift = rotate"},
	{"id": "elbow_l", "node": "LeftArm/Elbow", "side": "Left", "vertical": "elbow", "v_sign": 1.0, "horizontal": "", "shift": "forearm_rotation", "hint": "up = bend elbow, Shift = rotate forearm"},
	{"id": "elbow_r", "node": "RightArm/Elbow", "side": "Right", "vertical": "elbow", "v_sign": 1.0, "horizontal": "", "shift": "forearm_rotation", "hint": "up = bend elbow, Shift = rotate forearm"},
	{"id": "hip_l", "node": "LeftLeg", "side": "Left", "vertical": "hip", "v_sign": 1.0, "horizontal": "abduction", "h_mode": "outward", "shift": "hip_rotation", "hint": "up = thigh forward, sideways = legs apart, Shift = rotate toes in/out"},
	{"id": "hip_r", "node": "RightLeg", "side": "Right", "vertical": "hip", "v_sign": 1.0, "horizontal": "abduction", "h_mode": "outward", "shift": "hip_rotation", "hint": "up = thigh forward, sideways = legs apart, Shift = rotate toes in/out"},
	{"id": "knee_l", "node": "LeftLeg/Knee", "side": "Left", "vertical": "knee", "v_sign": -1.0, "horizontal": "", "shift": "", "hint": "up = bend knee more"},
	{"id": "knee_r", "node": "RightLeg/Knee", "side": "Right", "vertical": "knee", "v_sign": -1.0, "horizontal": "", "shift": "", "hint": "up = bend knee more"},
]

var pose_name := "planted_receive"
var pose: Dictionary
var baseline: Dictionary
var body: Node3D
var body_type := "Vegi"
var camera: Camera3D
var orbit_yaw := 0.55
var orbit_pitch := 0.12
var orbit_distance := 4.4
var orbit_target := Vector3(0, 0.95, 0)
var handle_nodes := {}
var hovered := ""
var selected := ""
var dragging := false
var orbiting := false
var showing_baseline := false
var dirty := false
var blender := Blender.new()
var transition_active := false
var transition_playing := false
var from_pick: OptionButton
var to_pick: OptionButton
var pose_pick: OptionButton
var ms_box: SpinBox
var ease_pick: OptionButton
var scrub: HSlider
var undo_stack: Array = []
var redo_stack: Array = []
var title_label: Label
var status_label: Label
var hint_label: Label
var mirror_box: CheckBox
var rows_box: VBoxContainer
var sliders := {}
var readouts := {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pose = Library.read_file(pose_name)
	baseline = pose.duplicate(true)
	_build_world()
	_build_body()
	_build_ui()
	_refresh()

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a1520")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.76)
	environment.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("16283a")
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	var grid := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-4, 5):
		lines.surface_add_vertex(Vector3(i, 0.003, -4))
		lines.surface_add_vertex(Vector3(i, 0.003, 4))
		lines.surface_add_vertex(Vector3(-4, 0.003, i))
		lines.surface_add_vertex(Vector3(4, 0.003, i))
	lines.surface_end()
	grid.mesh = lines
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color = Color(0.33, 0.92, 0.82, 0.16)
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid.material_override = grid_material
	add_child(grid)
	camera = Camera3D.new()
	camera.fov = 38
	add_child(camera)
	_place_camera()

func _build_body() -> void:
	if body != null:
		body.get_parent().queue_free()
		body = null
	var stub := Node3D.new()
	stub.set_script(load("res://scripts/preview_stub.gd"))
	add_child(stub)
	var parent := Node3D.new()
	stub.add_child(parent)
	body = Visual.build(stub, parent, body_type, {}, {"height": 1.9, "span": 1.95, "name": "Pose", "dominant_hand": "Right", "role": "OH"}).body
	if handle_nodes.is_empty():
		for handle in HANDLES:
			var marker := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.045
			sphere.height = 0.09
			marker.mesh = sphere
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.no_depth_test = true
			material.render_priority = 20
			marker.material_override = material
			add_child(marker)
			handle_nodes[handle.id] = marker

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.offset_left = -360
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(340, 0)
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	title_label = _label("", 22, TEAL)
	column.add_child(title_label)
	var pose_row := HBoxContainer.new()
	column.add_child(pose_row)
	pose_row.add_child(_label("Pose", 14, Color.WHITE))
	pose_pick = OptionButton.new()
	pose_pick.fit_to_longest_item = false
	pose_pick.custom_minimum_size = Vector2(190, 0)
	for name in Library.list_poses():
		pose_pick.add_item(name)
		if name == pose_name:
			pose_pick.select(pose_pick.item_count - 1)
	pose_pick.item_selected.connect(_choose_pose)
	pose_row.add_child(pose_pick)
	hint_label = _label("Left-drag a joint handle (hold Shift for twist). Right-drag orbits, wheel zooms.", 13, Color("8faabb"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint_label)
	var type_row := HBoxContainer.new()
	column.add_child(type_row)
	type_row.add_child(_label("Body", 14, Color.WHITE))
	var type_pick := OptionButton.new()
	for kind in Bodies.MODELLED:
		type_pick.add_item(kind)
	type_pick.item_selected.connect(func(index: int):
		body_type = Bodies.MODELLED[index]
		_build_body()
		_refresh()
	)
	type_row.add_child(type_pick)
	mirror_box = CheckBox.new()
	mirror_box.text = "Mirror left / right"
	mirror_box.tooltip_text = "On: one value drives both sides. Turning it back on keeps the left side's values."
	mirror_box.toggled.connect(func(on: bool):
		_push_undo()
		Library.set_mirror(pose, on)
		_changed()
		_rebuild_rows()
	)
	column.add_child(mirror_box)
	var views := HBoxContainer.new()
	column.add_child(views)
	for entry in [["Front", 0.0], ["Side", PI * 0.5], ["Back", PI], ["3/4", 0.55]]:
		var view := Button.new()
		view.text = entry[0]
		view.focus_mode = Control.FOCUS_NONE
		var yaw: float = entry[1]
		view.pressed.connect(func():
			orbit_yaw = yaw
			orbit_pitch = 0.12
			_place_camera()
		)
		views.add_child(view)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4)
	column.add_child(rows_box)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	actions.add_child(_button("Undo", undo))
	actions.add_child(_button("Redo", redo))
	actions.add_child(_button("Revert", revert))
	actions.add_child(_button("Built-in", reset_to_builtin))
	_build_transition_ui(column)
	var save := _button("SAVE POSE", save_pose)
	save.custom_minimum_size = Vector2(0, 44)
	column.add_child(save)
	column.add_child(_button("Back to title", back_to_title))
	status_label = _label("Hold B to see the saved pose. Ctrl+Z undo, Ctrl+S save.", 13, GOLD)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)
	_rebuild_rows()

func _build_transition_ui(column: VBoxContainer) -> void:
	column.add_child(_label("TRANSITION PREVIEW", 12, TEAL))
	var names := Library.list_poses()
	var row := HBoxContainer.new()
	column.add_child(row)
	from_pick = OptionButton.new()
	to_pick = OptionButton.new()
	for pick in [from_pick, to_pick]:
		pick.fit_to_longest_item = false
		pick.clip_text = true
		pick.custom_minimum_size = Vector2(130, 0)
		for name in names:
			pick.add_item(name)
		pick.item_selected.connect(func(_i: int): _load_transition_settings())
	if names.has("ready_stance"):
		from_pick.select(names.find("ready_stance"))
	to_pick.select(maxi(names.find(pose_name), 0))
	row.add_child(from_pick)
	row.add_child(_label("->", 14, Color.WHITE))
	row.add_child(to_pick)
	var timing := HBoxContainer.new()
	column.add_child(timing)
	timing.add_child(_label("Time (ms)", 13, Color.WHITE))
	ms_box = SpinBox.new()
	ms_box.min_value = 0
	ms_box.max_value = 2000
	ms_box.step = 10
	ms_box.value = 160
	timing.add_child(ms_box)
	ease_pick = OptionButton.new()
	ease_pick.fit_to_longest_item = false
	ease_pick.custom_minimum_size = Vector2(110, 0)
	for curve in Blender.EASES:
		ease_pick.add_item(curve)
	timing.add_child(ease_pick)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	buttons.add_child(_button("Play", play_transition))
	buttons.add_child(_button("Save time", save_transition_settings))
	buttons.add_child(_button("Stop", stop_transition))
	scrub = HSlider.new()
	scrub.min_value = 0.0
	scrub.max_value = 1.0
	scrub.step = 0.001
	scrub.focus_mode = Control.FOCUS_NONE
	scrub.value_changed.connect(func(v: float):
		if scrub.has_meta("silent") or not transition_active:
			return
		transition_playing = false
		blender.seek(v * blender.duration())
		_show_transition()
	)
	column.add_child(scrub)
	_load_transition_settings()

func _transition_names() -> Array:
	return [Library.list_poses()[from_pick.selected], Library.list_poses()[to_pick.selected]]

func _load_transition_settings() -> void:
	var names := _transition_names()
	var entry := Blender.transition(names[0], names[1])
	ms_box.value = roundi(float(entry.seconds) * 1000.0)
	ease_pick.select(maxi(Blender.EASES.find(entry.ease), 0))

# The pose being edited stands in for its file, so unsaved edits can be previewed.
func _pose_for_preview(name: String) -> Dictionary:
	return pose if name == pose_name else Library.read_file(name)

func play_transition() -> void:
	var names := _transition_names()
	blender = Blender.new()
	blender.snap(_pose_for_preview(names[0]))
	blender.go(_pose_for_preview(names[1]), ms_box.value / 1000.0, Blender.EASES[ease_pick.selected])
	transition_active = true
	transition_playing = true
	showing_baseline = false
	status_label.text = "Playing %s -> %s in %d ms." % [names[0], names[1], ms_box.value]

func stop_transition() -> void:
	transition_active = false
	transition_playing = false
	_refresh()

func save_transition_settings() -> void:
	var names := _transition_names()
	var error := Blender.save_transition(names[0], names[1], ms_box.value / 1000.0, Blender.EASES[ease_pick.selected])
	status_label.text = "Saved %s -> %s: %d ms." % [names[0], names[1], ms_box.value] if error == OK else "Could not save (%s)." % error_string(error)

func _show_transition() -> void:
	var gait := Pose.base(body, 0.0, 0.0, 0.0, true, 1.0)
	body.get_node("Torso").rotation.x = float(gait.torso_pitch_radians)
	Library.apply(body, blender.pose(), 1.0)
	body.get_node("Head").rotation.y = 0.0
	Pose.ground_feet(body)

func _choose_pose(index: int) -> void:
	var chosen: String = Library.list_poses()[index]
	if dirty and chosen != pose_name:
		status_label.text = "Save or Revert %s before opening another pose." % pose_name
		pose_pick.select(Library.list_poses().find(pose_name))
		return
	pose_pick.select(index)
	pose_name = chosen
	pose = Library.read_file(pose_name)
	baseline = pose.duplicate(true)
	undo_stack.clear()
	redo_stack.clear()
	transition_active = false
	_rebuild_rows()
	_refresh()

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _rebuild_rows() -> void:
	for child in rows_box.get_children():
		child.queue_free()
	sliders.clear()
	readouts.clear()
	mirror_box.set_pressed_no_signal(bool(pose.mirror))
	var group := ""
	for channel in Library.CHANNELS:
		var spec: Dictionary = Library.CHANNELS[channel]
		if spec.group != group:
			group = spec.group
			var header := _label(group.to_upper(), 12, TEAL)
			rows_box.add_child(header)
		if not spec.sided or bool(pose.mirror):
			_add_row(channel, "", spec.label)
		else:
			for side in Library.SIDES:
				_add_row(channel, side, "%s - %s" % [spec.label, side.to_lower()])

func _add_row(channel: String, side: String, text: String) -> void:
	var spec: Dictionary = Library.CHANNELS[channel]
	var key := channel + ":" + side
	var title := HBoxContainer.new()
	var name_label := _label(text, 13, Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	var readout := _label("", 13, GOLD)
	title.add_child(readout)
	rows_box.add_child(title)
	var slider := HSlider.new()
	slider.min_value = spec.range.x
	slider.max_value = spec.range.y
	slider.step = 0.1
	slider.focus_mode = Control.FOCUS_NONE
	slider.drag_started.connect(_push_undo)
	slider.value_changed.connect(func(v: float):
		if slider.has_meta("silent"):
			return
		Library.set_value(pose, channel, side, v)
		_changed()
	)
	rows_box.add_child(slider)
	sliders[key] = slider
	readouts[key] = readout

func _place_camera() -> void:
	var offset := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
	camera.position = orbit_target + offset
	camera.look_at(orbit_target)

# Same path the game uses: stance from the gait, then the authored pose on top.
func _pose_body() -> void:
	var shown := baseline if showing_baseline else pose
	var gait := Pose.base(body, 0.0, 0.0, 0.0, true, 1.0)
	body.get_node("Torso").rotation.x = float(gait.torso_pitch_radians)
	Receive.apply(body, "planted", Vector3(0, 1, -1), 1.0, shown)
	Pose.ground_feet(body)

func _refresh() -> void:
	if transition_active:
		_show_transition()
	else:
		_pose_body()
	for key in sliders:
		var parts: PackedStringArray = key.split(":")
		var v := Library.value(pose, parts[0], parts[1])
		var slider: HSlider = sliders[key]
		slider.set_meta("silent", true)
		slider.value = v
		slider.remove_meta("silent")
		(readouts[key] as Label).text = "%.1f%s" % [v, " cm" if parts[0] == "hip_shift" else "°"]
	title_label.text = "%s%s" % [pose_name.capitalize().replace("_", " "), " *" if dirty else ""]

func _changed() -> void:
	transition_active = false
	dirty = true
	redo_stack.clear()
	_refresh()

func _push_undo() -> void:
	undo_stack.append(pose.duplicate(true))
	if undo_stack.size() > UNDO_LIMIT:
		undo_stack.pop_front()

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(pose.duplicate(true))
	pose = undo_stack.pop_back()
	dirty = true
	_rebuild_rows()
	_refresh()

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(pose.duplicate(true))
	pose = redo_stack.pop_back()
	dirty = true
	_rebuild_rows()
	_refresh()

func revert() -> void:
	_push_undo()
	pose = baseline.duplicate(true)
	dirty = false
	_rebuild_rows()
	_refresh()

func reset_to_builtin() -> void:
	_push_undo()
	pose = Library.builtin(pose_name)
	dirty = true
	_rebuild_rows()
	_refresh()

func save_pose() -> void:
	var error := Library.save_pose(pose_name, pose)
	if error == OK:
		baseline = pose.duplicate(true)
		dirty = false
		status_label.text = "Saved %s. The game reads it on next launch." % Library.file_path(pose_name)
	else:
		status_label.text = "Could not save (%s)." % error_string(error)
	_refresh()

func back_to_title() -> void:
	get_tree().change_scene_to_file("res://title.tscn")

func _process(delta: float) -> void:
	if transition_active and transition_playing:
		blender.update(delta)
		_show_transition()
		scrub.set_meta("silent", true)
		scrub.value = blender.progress()
		scrub.remove_meta("silent")
		if not blender.is_moving():
			transition_playing = false
	for handle in HANDLES:
		var marker: MeshInstance3D = handle_nodes[handle.id]
		marker.global_position = _handle_world_position(handle)
		var material := marker.material_override as StandardMaterial3D
		var active: bool = handle.id == selected
		material.albedo_color = GOLD if active else (Color.WHITE if handle.id == hovered else TEAL)
		marker.scale = Vector3.ONE * (1.5 if active or handle.id == hovered else 1.0)
	if not dragging and not orbiting:
		hovered = _handle_at(get_viewport().get_mouse_position())
	if selected != "":
		var spec := _handle(selected)
		hint_label.text = "%s: %s" % [selected.replace("_l", " (left)").replace("_r", " (right)").capitalize(), spec.hint]

func _handle_world_position(handle: Dictionary) -> Vector3:
	if handle.has("spine"):
		var joints := SpineRig.joint_positions(body)
		return body.to_global(joints[handle.spine]) if joints.has(handle.spine) else body.global_position
	return (body.get_node(handle.node) as Node3D).global_position

func _handle(id: String) -> Dictionary:
	for handle in HANDLES:
		if handle.id == id:
			return handle
	return {}

func _handle_at(mouse: Vector2) -> String:
	var best := ""
	var best_distance := PICK_RADIUS
	for handle in HANDLES:
		var position_3d: Vector3 = (handle_nodes[handle.id] as Node3D).global_position
		if camera.is_position_behind(position_3d):
			continue
		var distance := camera.unproject_position(position_3d).distance_to(mouse)
		if distance < best_distance:
			best_distance = distance
			best = handle.id
	return best

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_B:
			showing_baseline = event.pressed
			_refresh()
		elif event.pressed and event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			redo() if event.shift_pressed else undo()
		elif event.pressed and event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed):
			save_pose()
		elif event.pressed and event.keycode == KEY_ESCAPE:
			back_to_title()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				selected = _handle_at(event.position)
				dragging = selected != ""
				if dragging:
					_push_undo()
			else:
				dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = clampf(orbit_distance * 0.92, 1.6, 9.0)
			_place_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = clampf(orbit_distance * 1.08, 1.6, 9.0)
			_place_camera()
	elif event is InputEventMouseMotion:
		if orbiting:
			orbit_yaw -= event.relative.x * 0.008
			orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, -0.3, 1.2)
			_place_camera()
		elif dragging:
			_drag(event.relative, event.shift_pressed)

func _drag(relative: Vector2, shift: bool = false) -> void:
	var handle := _handle(selected)
	var side: String = handle.side
	if shift:
		if handle.shift != "":
			var t: float = Library.value(pose, handle.shift, side)
			Library.set_value(pose, handle.shift, side, t - relative.y * DEGREES_PER_PIXEL)
			_changed()
		return
	if handle.vertical != "":
		var v: float = Library.value(pose, handle.vertical, side)
		Library.set_value(pose, handle.vertical, side, v - relative.y * DEGREES_PER_PIXEL * float(handle.v_sign))
	if handle.horizontal != "":
		var h: float = Library.value(pose, handle.horizontal, side)
		Library.set_value(pose, handle.horizontal, side, h + relative.x * _horizontal_sign(handle) * DEGREES_PER_PIXEL)
	_changed()

# Which way along the screen's x axis is positive for this handle's horizontal channel.
func _horizontal_sign(handle: Dictionary) -> float:
	var here := _handle_world_position(handle)
	var screen_here := camera.unproject_position(here)
	if handle.get("h_mode", "outward") == "forward":
		var forward_world := here + body.global_basis * Vector3(0, 0, -0.3)
		var fx := camera.unproject_position(forward_world).x - screen_here.x
		return 1.0 if fx >= 0.0 else -1.0
	if handle.get("h_mode", "outward") == "left":
		var left_world := here + body.global_basis * Vector3(-0.3, 0, 0)
		var dx := camera.unproject_position(left_world).x - screen_here.x
		return 1.0 if dx >= 0.0 else -1.0
	var centre := camera.unproject_position(_handle_world_position(_handle("pelvis"))).x
	return 1.0 if screen_here.x >= centre else -1.0
