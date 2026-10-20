class_name LabWorldBuilder
extends RefCounted

## Owns world builder state. LabSession schedules updates and composes peers.
const TEAL = Color("54ead0")
const GOLD = Color("ffce73")

var lab: LabSession

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	return n

func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	return n

func ring(radius: float, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.025
	mesh.outer_radius = radius + 0.025
	mesh.rings = 32
	mesh.ring_segments = 8
	n.mesh = mesh
	n.material_override = material(color, true)
	lab.add_child(n)
	return n

func world_label(text: String, pos: Vector3, size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.007
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.add_child(label)

# Open exploration blockout: three lanes and traversable jungle space. A scene that hosts the lab on a different map replaces this
# (see scripts/map_lab.gd) and keeps everything else, including the court and Net at the origin.
func build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0e1928")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b5d2e4")
	e.ambient_light_energy = 0.65
	env.environment = e
	lab.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	lab.add_child(light)
	box(lab, Vector3(160, 0.2, 160), Vector3(0, -0.22, 0), Color("142333"))
	lab._build_lanes_and_bases()
	lab.court_outline = MeshInstance3D.new()
	lab.court_outline.material_override = material(GOLD, true)
	lab.add_child(lab.court_outline)
	box(lab, Vector3(9, 0.12, 18), Vector3(0, -0.08, 0), Color("255b66"))
	box(lab, Vector3(8.8, 0.015, 8.8), Vector3(0, -0.008, 4.5), Color("30727a"))
	lab.build_net_visuals()
	# Physical floor and net; the ball uses swept intersection against these same dimensions.
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(160, 0.2, 160)
	shape.shape = floor_shape
	shape.position.y = -0.1
	floor_body.add_child(shape)
	lab.add_child(floor_body)
	lab.build_net_colliders()
	lab.ball = sphere(lab, 0.105, Vector3.ZERO, GOLD)
	lab.shadow = ring(0.19, Color("0d2536"))
	lab.landing_marker = ring(0.32, Color("a9d4df"))
	lab.aim_marker = ring(0.28, GOLD)
	lab.facing_arrow = MeshInstance3D.new()
	var arrow_mesh := ImmediateMesh.new()
	arrow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrow_points := [Vector3(0, 0, -1.9), Vector3(-0.23, 0, -1.42), Vector3(0.23, 0, -1.42), Vector3(-0.055, 0, -0.5), Vector3(-0.055, 0, -1.5), Vector3(0.055, 0, -1.5), Vector3(-0.055, 0, -0.5), Vector3(0.055, 0, -1.5), Vector3(0.055, 0, -0.5)]
	for point in arrow_points:
		arrow_mesh.surface_add_vertex(point)
	arrow_mesh.surface_end()
	lab.facing_arrow.mesh = arrow_mesh
	lab.facing_arrow.material_override = debug_material(GOLD, 0.85)
	lab.facing_arrow.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	lab.add_child(lab.facing_arrow)
	lab.facing_arrow.hide()
	lab.reach_ring = ring(0.72, TEAL)
	lab.preview = MeshInstance3D.new()
	lab.preview.material_override = debug_material(Color.WHITE, 1.0)
	lab.preview.material_override.no_depth_test = true
	lab.preview.material_override.vertex_color_use_as_albedo = true
	lab.preview.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	lab.add_child(lab.preview)
	for step in range(4):
		var footprint: MeshInstance3D
		if step < 3:
			footprint = box(lab, Vector3(0.18, 0.025, 0.38), Vector3.ZERO, GOLD)
		else:
			footprint = MeshInstance3D.new()
			lab.add_child(footprint)
			lab._draw_line(footprint, [Vector3.ZERO, Vector3.UP * 0.9, Vector3(0.13, 0.68, 0), Vector3.UP * 0.9, Vector3(-0.13, 0.68, 0)])
		footprint.material_override = debug_material(GOLD, 0.85)
		footprint.hide()
		lab.approach_footprints.append(footprint)
	lab.approach_preview = MeshInstance3D.new()
	lab.approach_preview.material_override = debug_material(GOLD, 0.80)
	lab.add_child(lab.approach_preview)
	lab.trail = MeshInstance3D.new()
	lab.trail.material_override = material(GOLD, true)
	lab.add_child(lab.trail)
	lab.camera = Camera3D.new()
	lab.camera.position = Vector3(0, 4.2, 10.5)
	lab.camera.fov = 65
	lab.add_child(lab.camera)
	lab.camera.look_at(Vector3(0, 0, 0.8))
	world_label("CONTACT LAB", Vector3(0, 0.1, -10.3), 66, TEAL)
	world_label("01   /   TRAINING COURT", Vector3(-6.5, 0.1, 0), 28, Color("90a9ba"))
	for x in [-3, 0, 3]:
		var target := ring(0.6, Color("477b86"))
		target.position = Vector3(x, 0.025, -6)

func debug_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := material(Color(color, alpha), true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	return m

func wire_box(parent: Node3D, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for axis in range(3):
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				var start := Vector3.ZERO
				start[axis] = -size[axis] * 0.5
				start[(axis + 1) % 3] = a * size[(axis + 1) % 3] * 0.5
				start[(axis + 2) % 3] = b * size[(axis + 2) % 3] * 0.5
				var finish := start
				finish[axis] *= -1
				mesh.surface_add_vertex(start)
				mesh.surface_add_vertex(finish)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = debug_material(color, 0.8)
	parent.add_child(instance)
	return instance


func _init(session: LabSession) -> void:
	lab = session

func box_batch(parent: Node3D, transforms: Array[Transform3D], color: Color) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance

func build_net_visuals() -> void:
	for x in [-4.8, 4.8]:
		box(lab, Vector3(0.10, 2.6, 0.10), Vector3(x, 1.3, 0), GOLD)
	var strings: Array[Transform3D] = []
	for i in range(33):
		strings.append(Transform3D(Basis.from_scale(Vector3(0.012, 0.88, 0.012)), Vector3(-4.5 + i * 9.0 / 32, 1.98, 0)))
	for i in range(6):
		strings.append(Transform3D(Basis.from_scale(Vector3(9, 0.012, 0.012)), Vector3(0, 1.54 + i * 0.176, 0)))
	box_batch(lab, strings, Color("829dab"))
	box(lab, Vector3(9.5, 0.055, 0.06), Vector3(0, 2.43, 0), Color("f0e6ce"))

func build_net_colliders() -> void:
	var net_body := StaticBody3D.new()
	lab.net_body = net_body
	# The athlete does not collide with the net: a shoulder or an arm can press into it. Only the body's midline matters (see
	# contact_lab._hold_midline_off_net and NetResponse.body_touches). The layer is kept for rays.
	net_body.collision_layer = 2
	net_body.collision_mask = 0
	for band in [[9.0,lab.NetResponse.BOTTOM,lab.NetResponse.TAPE_BOTTOM],[9.5,lab.NetResponse.TAPE_BOTTOM,lab.NetResponse.TOP]]:
		var net_shape := CollisionShape3D.new()
		var net_box := BoxShape3D.new()
		net_box.size = Vector3(float(band[0]),float(band[2])-float(band[1]),0.08)
		net_shape.shape = net_box
		net_shape.position.y = (float(band[1])+float(band[2]))*0.5
		net_body.add_child(net_shape)
	lab.add_child(net_body)
