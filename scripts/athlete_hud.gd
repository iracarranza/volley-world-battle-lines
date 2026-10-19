extends Control

const Visual := preload("res://scripts/voli_visual.gd")
const HP_COLOR := Color("8fd8f5")
const STAMINA_COLOR := Color("f0cb55")
var lab: Node3D
var portrait: TextureRect
var portrait_viewport: SubViewport
var portrait_world: Node3D
var portrait_actor: Node3D
var portrait_camera: Camera3D
var name_label: Label
var role_label: Label
var level_label: Label
var xp_label: Label
var flow_bar: ProgressBar
var flow_value: Label
var hp_bar: ProgressBar
var sta_bar: ProgressBar
var hp_value: Label
var sta_value: Label
var resources: VBoxContainer
var xp_fraction := 0.0

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_viewport = SubViewport.new()
	portrait_viewport.size = Vector2i(256, 256)
	portrait_viewport.transparent_bg = true
	portrait_viewport.own_world_3d = true
	add_child(portrait_viewport)
	portrait_world = Node3D.new()
	portrait_viewport.add_child(portrait_world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("172936")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d8eaf4")
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	portrait_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -30, 0)
	portrait_world.add_child(light)
	portrait_camera = Camera3D.new()
	portrait_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	portrait_world.add_child(portrait_camera)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(128, 128)
	portrait.texture = portrait_viewport.get_texture()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec2 p = UV - vec2(0.5); float mask = 1.0 - smoothstep(0.485, 0.5, length(p)); vec4 c = texture(TEXTURE, UV); COLOR = vec4(c.rgb, c.a * mask); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	portrait.material = material
	add_child(portrait)
	name_label = _label(22, Color("eaf5fb"))
	name_label.size = Vector2(300, 30)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_label = _label(12, Color("9bb5c6"))
	xp_label = _label(11, Color("dfc581"))
	level_label = _label(20, Color("ffe6a4"))
	level_label.size = Vector2(40, 40)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.z_index = 3
	resources = VBoxContainer.new()
	resources.add_theme_constant_override("separation", 7)
	resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(resources)
	flow_bar = _bar(Color("68e6c2"))
	flow_bar.custom_minimum_size = Vector2(440,14)
	resources.add_child(flow_bar)
	flow_value = _bar_label(flow_bar)
	flow_value.add_theme_font_size_override("font_size",10)
	sta_bar = _bar(STAMINA_COLOR)
	resources.add_child(sta_bar)
	sta_value = _bar_label(sta_bar)
	hp_bar = _bar(HP_COLOR)
	resources.add_child(hp_bar)
	hp_value = _bar_label(hp_bar)
	resized.connect(_layout)
	_layout()
	refresh_portrait()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(440, 24)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("122330")
	track.border_color = Color("557185")
	track.set_border_width_all(1)
	track.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _bar_label(bar: ProgressBar) -> Label:
	var text := Label.new()
	bar.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 12)
	text.add_theme_color_override("font_color", Color("eff7fb"))
	text.add_theme_color_override("font_outline_color", Color("0c202c"))
	text.add_theme_constant_override("outline_size", 3)
	text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	text.add_theme_constant_override("shadow_offset_x", 0)
	text.add_theme_constant_override("shadow_offset_y", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return text

func _layout() -> void:
	if not is_instance_valid(portrait):
		return
	var origin := Vector2(24, size.y - 234)
	name_label.position = origin
	role_label.position = origin + Vector2(0, 32)
	portrait.position = origin + Vector2(12, 62)
	level_label.position = origin + Vector2(112, 166)
	xp_label.position = origin + Vector2(4, 211)
	resources.position = Vector2(size.x * 0.5 - 220, size.y - 101)
	resources.size = Vector2(440, 76)
	queue_redraw()

func refresh_portrait() -> void:
	if not is_instance_valid(portrait_world):
		return
	if is_instance_valid(portrait_actor):
		portrait_actor.get_parent().remove_child(portrait_actor)
		portrait_actor.queue_free()
	portrait_actor = Visual.build(lab, portrait_world, lab.body_type, lab.appearance, lab.athlete.build).body
	portrait_actor.rotation.y = PI + 0.10
	var head_height: float = portrait_actor.get_node("Head").global_position.y
	portrait_camera.size = 0.72 * float(lab.athlete.build.height) / 1.86
	portrait_camera.position = Vector3(0, head_height, 3)
	portrait_camera.look_at(Vector3(0, head_height, 0))
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_values() -> void:
	name_label.text = lab.athlete_name
	role_label.text = lab.position_role + "  /  " + lab.body_type.to_upper()
	level_label.text = str(lab.athlete_level)
	var xp: int = lab.station.earned_xp + lab.drills.earned_xp
	var next_xp := clampf(float(xp) / 100.0, 0, 1)
	if next_xp != xp_fraction:
		xp_fraction = next_xp
		queue_redraw()
	xp_label.text = "%d LAB XP" % xp
	flow_bar.value = lab.athlete.flow
	flow_value.text = "FLOW   %d / 100" % roundi(lab.athlete.flow)
	sta_bar.max_value = lab.athlete.max_stamina()
	sta_bar.value = lab.athlete.stamina
	hp_bar.value = lab.athlete.hp
	sta_value.text = "STAMINA   %d / %d" % [roundi(lab.athlete.stamina),roundi(lab.athlete.max_stamina())]
	if lab.athlete.exhausted or lab.athlete.winded:
		sta_value.text += "   ·   " + lab.athlete.fatigue_text()
	hp_value.text = "HP   %d / 100" % roundi(lab.athlete.hp)

func _draw() -> void:
	var center := Vector2(100, size.y - 108)
	draw_circle(center, 78, Color(0.02, 0.05, 0.08, 0.8))
	draw_circle(center, 65, Color("1c3545"))
	draw_arc(center, 67, 0, TAU, 96, Color("628193"), 2, true)
	draw_arc(center, 73, PI * 0.75, PI * 2.25, 96, Color("4b4938"), 8, true)
	if xp_fraction > 0:
		draw_arc(center, 73, PI * 0.75, PI * (0.75 + 1.5 * xp_fraction), 96, Color("e2c772"), 5, true)
	# Level badge sits outside the portrait cutout, with its number on top.
	var badge := Vector2(156, size.y - 48)
	draw_circle(badge, 23, Color("101d29"))
	draw_arc(badge, 21, 0, TAU, 48, Color("c5aa68"), 2, true)
