class_name LabHurtboxView
extends RefCounted
## Cache one presentation subtree per exact geometry. Cleared on athlete rebuild.
const Geometry := preload("res://scripts/contact_geometry.gd")
const ReceivePlatform := preload("res://scripts/receive_platform.gd")
const Actions := preload("res://scripts/contact/action.gd")
const ACTIONS := Actions.LABELS
const TEAL := Color("54ead0")
const GOLD := Color("ffce73")
var world_builder: LabWorldBuilder
var root: Node3D
var groups: Dictionary = {}
var active: Node3D

func _init(parent: Node3D, builder: LabWorldBuilder) -> void:
	root = parent
	world_builder = builder

func clear() -> void:
	for entry in groups.values():
		root.remove_child(entry.group)
		entry.group.queue_free()
	groups.clear()
	active = null

func present(shape: Dictionary, action: int) -> Dictionary:
	# Full serialized geometry avoids hash collisions and includes physique/traits.
	var key := var_to_str(shape)
	if is_instance_valid(active):
		active.hide()
	if not groups.has(key):
		# Bound unusual debug/creator sessions that produce many shapes.
		if groups.size() >= 16:
			clear()
		groups[key] = _build(shape.get("base_geometry",shape), action,shape)
		groups[key].group.scale = shape.get("geometry_scale",Vector3.ONE)
	var entry: Dictionary = groups[key]
	active = entry.group
	active.show()
	return entry

func _build(shape: Dictionary, action: int, grading_shape: Dictionary = {}) -> Dictionary:
	var group := Node3D.new()
	root.add_child(group)
	var mesh_instance: MeshInstance3D
	var label: Label3D
	var color: Color = [TEAL, Color("ac9df2"), GOLD, Color("8bbdf4")][action]
	mesh_instance = MeshInstance3D.new()
	group.add_child(mesh_instance)
	if shape.shape == "sector":
		mesh_instance.mesh = Geometry.zone_mesh(shape,false,grading_shape)
		var m := world_builder.debug_material(Color.WHITE, 1.0)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.material_override = m
		var wire := MeshInstance3D.new()
		wire.mesh = Geometry.zone_mesh(shape, true,grading_shape)
		wire.material_override = m
		group.add_child(wire)
		var sweet_point := Geometry.sector_point(shape, 0.74, 67.5, 0.0)
		if not grading_shape.is_empty():
			sweet_point = (Vector3(shape.center)+sweet_point-Vector3(grading_shape.center))/Vector3(grading_shape.get("geometry_scale",Vector3.ONE))
		world_builder.sphere(group, 0.045, sweet_point, Color("67f3a3"))
	elif shape.shape == "set_sector":
		mesh_instance.mesh = Geometry.SetHurtbox.mesh(shape)
		var m := world_builder.debug_material(Color.WHITE, 1.0)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.material_override = m
		var wire := MeshInstance3D.new()
		wire.mesh = Geometry.SetHurtbox.mesh(shape, true)
		wire.material_override = m
		group.add_child(wire)
	elif shape.get("receive_platform", false):
		mesh_instance.mesh = ReceivePlatform.mesh(shape)
		var m := world_builder.debug_material(Color.WHITE, 1.0)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.material_override = m
		var wire := MeshInstance3D.new()
		wire.mesh = ReceivePlatform.mesh(shape, true)
		wire.material_override = m
		group.add_child(wire)
	elif shape.shape == "ellipsoid":
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 32
		mesh.rings = 16
		mesh_instance.mesh = mesh
		mesh_instance.scale = shape.size * 0.5
		mesh_instance.material_override = world_builder.debug_material(color, 0.12)
		var wire := MeshInstance3D.new()
		var lines := ImmediateMesh.new()
		lines.surface_begin(Mesh.PRIMITIVE_LINES)
		for axis in range(3):
			for i in range(48):
				var a := TAU * i / 48.0
				var b := TAU * (i + 1) / 48.0
				var first := Vector3.ZERO
				var second := Vector3.ZERO
				first[(axis + 1) % 3] = cos(a) * shape.size[(axis + 1) % 3] * 0.5
				first[(axis + 2) % 3] = sin(a) * shape.size[(axis + 2) % 3] * 0.5
				second[(axis + 1) % 3] = cos(b) * shape.size[(axis + 1) % 3] * 0.5
				second[(axis + 2) % 3] = sin(b) * shape.size[(axis + 2) % 3] * 0.5
				lines.surface_add_vertex(first)
				lines.surface_add_vertex(second)
		lines.surface_end()
		wire.mesh = lines
		wire.material_override = world_builder.debug_material(color, 0.85)
		group.add_child(wire)
		if shape.has("edge_zone"):
			for side in [-1.0, 1.0]:
				world_builder.sphere(group, 0.07, Vector3(side * (shape.size.x * 0.5 + Geometry.BALL_RADIUS) * float(shape.edge_zone), 0, 0), Color("ee617b"))
	elif shape.shape == "block_triangle":
		mesh_instance.mesh = Geometry.block_mesh(shape)
		var material := world_builder.debug_material(Color.WHITE, 1.0)
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.material_override = material
		for side in [-1.0,1.0]:
			world_builder.sphere(group,0.065,Vector3(side*float(shape.hand_x),float(shape.palm)-float(shape.center.y),0),Color("67f3a3"))
	else:
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = world_builder.debug_material(color, 0.14)
		world_builder.wire_box(group, shape.size, color)
	label = Label3D.new()
	label.text = ACTIONS[action] + " HURTBOX"
	label.font_size = 29
	label.pixel_size = 0.005
	label.position.y = (float(shape.radius) if shape.shape == "sector" else (float(shape.radius) if shape.shape == "set_sector" else shape.size.y * 0.5)) + 0.18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	group.add_child(label)
	return {"group": group, "mesh": mesh_instance, "label": label}

var phase_materials: Dictionary = {}
func phase_material(phase: String) -> StandardMaterial3D:
	if not phase_materials.has(phase):
		phase_materials[phase] = world_builder.debug_material(
			Color("8faabb") if phase == "windup" else Color("f69c69"), 0.22
		)
	return phase_materials[phase]
