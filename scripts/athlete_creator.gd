extends CanvasLayer
const Store := preload("res://scripts/athlete_store.gd")

const Bodies := preload("res://vendor/vwm/body_type_models.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const ROLES := ["OH", "OP", "S", "MB", "L"]
const ATTRIBUTES := ["power", "speed", "accuracy", "endurance"]
const LABELS := ["POW", "SPD", "ACC", "END"]
const AP_BUDGET := 12
var lab: Node3D
var draft: Dictionary
var controls: PanelContainer
var shape_picker: OptionButton
var shape_row: HBoxContainer
var palette_picker: OptionButton
var marking_picker: OptionButton
var budget_label: Label
var apply_button: Button
var preview_world: Node3D
var preview_actor: Node3D
var wingspan_slider: HSlider
var stride_slider: HSlider
var wingspan_label: Label
var stride_label: Label
var stat_labels: Array[Label] = []
var stat_sliders: Array[HSlider] = []
var last_paused := false

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	layer = 20
	hide()

func open() -> void:
	if visible:
		return
	last_paused = lab.paused
	lab.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	draft = {"body_type": lab.body_type, "appearance": lab.appearance.duplicate(true), "name": lab.athlete_name, "role": lab.position_role, "dominant_hand": lab.dominant_hand, "height": float(lab.athlete.build.height), "span": float(lab.athlete.build.span), "wingspan_ratio": Store.wingspan_ratio(lab.athlete.build), "stride_ratio": Store.stride_ratio(lab.athlete.build), "proportion_version": 1}
	for metadata in ["statistics","offsets","stat_names","stat_version","picks"]:
		if lab.athlete.build.has(metadata):
			draft[metadata] = lab.athlete.build[metadata].duplicate(true) if lab.athlete.build[metadata] is Dictionary or lab.athlete.build[metadata] is Array else lab.athlete.build[metadata]
	for key in ATTRIBUTES:
		draft[key] = clampf(float(lab.athlete.build[key]), 65, 77)
	if ap_spent() > AP_BUDGET:
		for key in ATTRIBUTES:
			draft[key] = 65.0
	_build()
	show()
	refresh_preview()
	refresh_budget()

func close() -> void:
	lab.paused = last_paused
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if lab.paused else Input.MOUSE_MODE_CAPTURED

func ap_spent() -> int:
	var spent := 0
	for key in ATTRIBUTES:
		spent += maxi(0, int(draft.get(key, 65)) - 65)
	return spent

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	stat_labels.clear()
	stat_sliders.clear()
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.04, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	controls = PanelContainer.new()
	controls.position = Vector2(240, 100)
	controls.custom_minimum_size = Vector2(960, 710)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142536")
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	controls.add_theme_stylebox_override("panel", style)
	add_child(controls)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	controls.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 470
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(lab.hud.label("CREATE YOUR ATHLETE", 25, lab.TEAL))
	left.add_child(lab.hud.label("Position + physique + shared attribute investment", 13))
	var name_edit := LineEdit.new()
	name_edit.text = draft.name
	name_edit.placeholder_text = "Athlete name"
	name_edit.text_changed.connect(func(value: String): draft.name = value.left(24))
	row(left, "NAME", name_edit)
	var body_picker := OptionButton.new()
	for type in Bodies.MODELLED:
		body_picker.add_item(type)
	body_picker.select(Bodies.MODELLED.find(draft.body_type))
	body_picker.item_selected.connect(func(index: int):
		draft.body_type = Bodies.MODELLED[index]
		draft.appearance.palette_index = 0
		draft.appearance.marking = "none"
		refresh_choices()
		refresh_preview()
	)
	row(left, "BODY", body_picker)
	shape_picker = OptionButton.new()
	for index in range(Bodies.PRODUCE.size()):
		shape_picker.add_item("Shape %d" % (index + 1))
	shape_picker.item_selected.connect(func(index: int):
		draft.appearance.produce = Bodies.PRODUCE[index]
		draft.appearance.palette_index = 0
		draft.appearance.marking = "none"
		refresh_choices()
		refresh_preview()
	)
	shape_row = row(left, "VARIETY", shape_picker)
	palette_picker = OptionButton.new()
	palette_picker.item_selected.connect(func(index: int):
		draft.appearance.palette_index = index
		refresh_preview()
	)
	row(left, "PALETTE", palette_picker)
	marking_picker = OptionButton.new()
	marking_picker.item_selected.connect(func(index: int):
		draft.appearance.marking = marking_picker.get_item_text(index)
		refresh_preview()
	)
	row(left, "MARKINGS", marking_picker)
	var role_picker := OptionButton.new()
	for role in ROLES:
		role_picker.add_item(role)
	role_picker.select(ROLES.find(draft.role))
	role_picker.item_selected.connect(func(index: int): draft.role = ROLES[index])
	row(left, "POSITION", role_picker)
	var hand_picker := OptionButton.new()
	hand_picker.add_item("Right")
	hand_picker.add_item("Left")
	hand_picker.select(1 if draft.dominant_hand == "Left" else 0)
	hand_picker.item_selected.connect(func(index: int): draft.dominant_hand = "Left" if index == 1 else "Right")
	row(left, "DOMINANT ARM", hand_picker)
	var height := SpinBox.new()
	height.min_value = 152
	height.max_value = 218
	height.step = 1
	height.suffix = "cm"
	height.value = float(draft.height) * 100
	height.value_changed.connect(func(value: float):
		draft.height = value / 100.0
		Store.refresh_span(draft)
		_show_proportions()
		refresh_preview()
	)
	row(left, "HEIGHT", height)
	wingspan_slider = _proportion_slider("WingspanSlider", "wingspan")
	wingspan_label = lab.hud.label("", 14, lab.GOLD)
	row(left, "WINGSPAN", _proportion_row(wingspan_slider, wingspan_label))
	stride_slider = _proportion_slider("StrideSlider", "stride")
	stride_label = lab.hud.label("", 14, lab.GOLD)
	row(left, "STRIDE LENGTH", _proportion_row(stride_slider, stride_label))
	left.add_child(lab.hud.label("No AP. Both can be maxed, at the price of Stamina, a harder platform at speed and strenuous jumps.", 12))
	_show_proportions()
	budget_label = lab.hud.label("", 16, lab.GOLD)
	left.add_child(budget_label)
	left.add_child(lab.hud.label("12 starting AP  /  +1 attribute costs 1 AP", 12))
	for index in range(4):
		var key: String = ATTRIBUTES[index]
		var slider := HSlider.new()
		slider.min_value = 65
		slider.max_value = 77
		slider.step = 1
		slider.value = draft[key]
		slider.custom_minimum_size.x = 260
		var value_label: Label = lab.hud.label(str(int(draft[key])), 15)
		stat_labels.append(value_label)
		stat_sliders.append(slider)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var caption: Label = lab.hud.label(LABELS[index], 14)
		caption.custom_minimum_size.x = 110
		line.add_child(caption)
		line.add_child(slider)
		line.add_child(value_label)
		left.add_child(line)
		slider.value_changed.connect(func(value: float):
			var previous: float = draft[key]
			draft[key] = value
			if ap_spent() > AP_BUDGET:
				draft[key] = previous
				slider.set_value_no_signal(previous)
			refresh_budget()
		)
	var buttons := HBoxContainer.new()
	left.add_child(buttons)
	apply_button = lab.hud.button("APPLY & PLAY", apply)
	buttons.add_child(apply_button)
	buttons.add_child(lab.hud.button("CANCEL", close))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	right.add_child(lab.hud.label("VOLI / LIVE PREVIEW", 16, lab.TEAL))
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(385, 500)
	container.stretch = true
	right.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(385, 500)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(viewport)
	preview_world = Node3D.new()
	viewport.add_child(preview_world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b3044")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4dce9")
	environment.ambient_light_energy = 0.8
	env.environment = environment
	preview_world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	preview_world.add_child(light)
	var camera := Camera3D.new()
	preview_world.add_child(camera)
	camera.position = Vector3(0, 1.2, 3.8)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.fov = 42
	right.add_child(lab.hud.label("One body, used in preview and on court.\nHeight and wingspan change reach.\nAppearance does not assign your position.", 14))
	refresh_choices()

func row(parent: Node, caption: String, control: Control) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var text: Label = lab.hud.label(caption, 13)
	text.custom_minimum_size.x = 110
	line.add_child(text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.y = 32
	line.add_child(control)
	parent.add_child(line)
	return line

func refresh_choices() -> void:
	var produce := Bodies.chosen_produce(42, draft.appearance)
	shape_row.visible = draft.body_type == "Vegi"
	shape_picker.select(maxi(0, Bodies.PRODUCE.find(produce)))
	var key := Bodies.palette_key(draft.body_type, produce)
	palette_picker.clear()
	for index in range(Bodies.palette_count(key)):
		palette_picker.add_item("Colorway %d" % (index + 1))
	palette_picker.select(clampi(int(draft.appearance.get("palette_index", 0)), 0, maxi(0, palette_picker.item_count - 1)))
	marking_picker.clear()
	var options := Bodies.marking_options(key)
	for marking in options:
		marking_picker.add_item(marking)
	marking_picker.select(maxi(0, options.find(str(draft.appearance.get("marking", "none")))))

func refresh_preview() -> void:
	if not is_instance_valid(preview_world):
		return
	if is_instance_valid(preview_actor):
		preview_actor.get_parent().remove_child(preview_actor)
		preview_actor.queue_free()
	preview_actor = Visual.build(lab, preview_world, draft.body_type, draft.appearance, draft).body
	preview_actor.rotation.y = PI + 0.3

func refresh_budget() -> void:
	budget_label.text = "%d / %d STARTING AP REMAINING" % [AP_BUDGET - ap_spent(), AP_BUDGET]
	for index in range(stat_labels.size()):
		stat_labels[index].text = str(int(draft[ATTRIBUTES[index]]))

func _proportion_slider(slider_name: String, which: String) -> HSlider:
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = Store.PROPORTION_MIN
	slider.max_value = Store.PROPORTION_MAX
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(180, 24)
	slider.value_changed.connect(func(_value: float):
		Store.set_proportions(draft, wingspan_slider.value, stride_slider.value)
		_show_proportions()
		refresh_preview())
	return slider

func _proportion_row(slider: HSlider, value_label: Label) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(slider)
	box.add_child(value_label)
	return box

func _show_proportions() -> void:
	if wingspan_slider == null or stride_slider == null:
		return
	wingspan_slider.set_value_no_signal(Store.wingspan_ratio(draft))
	stride_slider.set_value_no_signal(Store.stride_ratio(draft))
	wingspan_label.text = "%.2f  (%d cm)" % [Store.wingspan_ratio(draft), roundi(float(draft.span) * 100.0)]
	stride_label.text = "%.2f  (%.2f m)" % [Store.stride_ratio(draft), Store.stride_metres(draft)]

func apply() -> void:
	if ap_spent() > AP_BUDGET:
		return
	preload("res://scripts/athlete_store.gd").sync_statistics(draft)
	lab.apply_created_athlete(draft)
	close()

func _process(_dt: float) -> void:
	if visible and is_instance_valid(preview_actor):
		preview_actor.rotation.y = PI + sin(Time.get_ticks_msec() / 1200.0) * 0.35
