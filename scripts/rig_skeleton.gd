extends Node
## Skeleton rig (prototype). The animation code keeps posing the same joint nodes it always has; this adds a render-side Skeleton3D that mirrors them. Every
## rigid mesh in the rig (limb segments, joint balls, sleeves, shoes, the head and its ears, muzzle, nose, collar, tail) is baked once into a single skinned mesh,
## each vertex weighted wholly to the frame that carries it, and the ink outlines into a second. Each rendered frame the bones are set to the joints' transforms.
## What is left as its own node: the parts the spine rig re-skins on the CPU (torso, singlet, neck) and the face, whose parts the expression system moves.
const Merge := preload("res://scripts/rig_merge.gd")
const SPINE_MESHES := ["Torso", "Singlet", "Neck"]
const RIDER_NAMES := ["Shoe"]

static var sync_enabled := true # measuring: with it off the bones stay at rest
static var sync_microseconds := 0
var root: Node3D
var skeleton: Skeleton3D
var owners: Array[Node3D] = []

# Builds the skeleton mesh for a rig and returns the stats, or an empty dictionary when there was nothing to do. The returned node (a child of the rig) mirrors
# the joints every frame.
static func build(rig_root: Node3D) -> Dictionary:
	var self_node := preload("res://scripts/rig_skeleton.gd").new()
	var stats: Dictionary = self_node._bake(rig_root)
	if stats.is_empty():
		self_node.free()
		return {}
	rig_root.add_child(self_node)
	stats["node"] = self_node
	return stats

static func _is_rider(node: Node3D, rig_root: Node3D) -> bool:
	return node is MeshInstance3D and (node.get_parent() == rig_root or RIDER_NAMES.has(String(node.name)))

static func _excluded(mesh_node: MeshInstance3D, rig_root: Node3D) -> bool:
	var node: Node = mesh_node
	while node != null and node != rig_root:
		if SPINE_MESHES.has(String(node.name)) or String(node.name) == "Face":
			return true
		node = node.get_parent()
	return false

func _bake(rig_root: Node3D) -> Dictionary:
	root = rig_root
	var parts: Array[Dictionary] = []   # solids: {"mesh", "owner", "relative", "color"}
	var inks: Array[Dictionary] = []
	var template_solid: Material = null
	var template_ink: Material = null
	var template_node: MeshInstance3D = null
	var before := Merge.count_meshes(root)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or not mesh_node.visible or _excluded(mesh_node, root) or Merge.arrays_of(mesh_node.mesh).is_empty():
			continue
		var material := mesh_node.get_active_material(0)
		if not (material is StandardMaterial3D) or (material as StandardMaterial3D).albedo_texture != null:
			continue
		var is_ink := String(mesh_node.name) == "Ink"
		if is_ink:
			if template_ink == null:
				template_ink = material
			if not Merge.compatible(template_ink, material) or (material as StandardMaterial3D).albedo_color != (template_ink as StandardMaterial3D).albedo_color:
				continue
		else:
			if template_solid == null:
				template_solid = material
				template_node = mesh_node
			if not Merge.compatible(template_solid, material):
				continue
		var carrier := _carrier(mesh_node)
		if carrier == null:
			continue
		var relative: Transform3D = carrier.global_transform.affine_inverse() * mesh_node.global_transform
		var entry := {"mesh": mesh_node, "owner": carrier, "relative": relative, "color": (material as StandardMaterial3D).albedo_color}
		if is_ink:
			inks.append(entry)
		else:
			parts.append(entry)
	if parts.size() < 4:
		return {}
	skeleton = Skeleton3D.new()
	skeleton.name = "RigSkeleton"
	var bone_of := {}
	var skin := Skin.new()
	var root_inverse := root.global_transform.affine_inverse()
	for entry in parts + inks:
		var carrier: Node3D = entry.owner
		if bone_of.has(carrier):
			continue
		var bone := skeleton.get_bone_count()
		skeleton.add_bone("bone_%d_%s" % [bone, String(carrier.name)])
		var rest: Transform3D = root_inverse * carrier.global_transform
		skeleton.set_bone_rest(bone, rest)
		skeleton.set_bone_pose_position(bone, rest.origin)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, rest.basis.get_scale())
		skin.add_bind(bone, rest.affine_inverse())
		bone_of[carrier] = bone
		owners.append(carrier)
	root.add_child(skeleton)
	for group in [["RigSolid", parts, template_solid, true, template_node], ["RigInk", inks, template_ink, false, null]]:
		var entries: Array = group[1]
		if entries.is_empty():
			continue
		var instance := _skinned_instance(group[0], entries, group[2], group[3], bone_of, root_inverse, skin, group[4] if group[4] != null else (entries[0].mesh as MeshInstance3D))
		skeleton.add_child(instance)
		instance.skeleton = NodePath("..")
	# The originals stop drawing but stay where they are: the animation code reaches them by path, and the face hangs off the head.
	for entry in parts + inks:
		var mesh_node: MeshInstance3D = entry.mesh
		if String(mesh_node.name) == "Shoe" or RIDER_NAMES.has(String(mesh_node.name)):
			mesh_node.set_meta("rig_bounds", mesh_node.get_aabb())
		mesh_node.mesh = null
	return {"before": before, "after": Merge.count_meshes(root), "bones": skeleton.get_bone_count()}

# The frame that carries a mesh: the nearest joint (plain Node3D) above it, or the mesh's own node when it is a rider (a top-level piece the spine moves, or a shoe).
func _carrier(mesh_node: MeshInstance3D) -> Node3D:
	var node: Node = mesh_node
	if String(mesh_node.name) == "Ink":
		node = mesh_node.get_parent()
	while node != null and node != root:
		var as_node := node as Node3D
		if as_node != null:
			if not (node is MeshInstance3D):
				return as_node
			if _is_rider(as_node, root):
				return as_node
		node = node.get_parent()
	return null

func _skinned_instance(node_name: String, entries: Array, template_material: Material, bake_colors: bool, bone_of: Dictionary, root_inverse: Transform3D, skin: Skin, template: MeshInstance3D) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for entry in entries:
		var arrays := Merge.arrays_of((entry.mesh as MeshInstance3D).mesh)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var carrier: Node3D = entry.owner
		# Into the skeleton's rest space: the carrier's own rest frame, then the mesh's place within it.
		var to_rest: Transform3D = root_inverse * carrier.global_transform * (entry.relative as Transform3D)
		var normal_basis := to_rest.basis.inverse().transposed()
		var bone: int = bone_of[carrier]
		var offset := vertices.size()
		for index in range(source_vertices.size()):
			vertices.append(to_rest * source_vertices[index])
			normals.append((normal_basis * source_normals[index]).normalized() if index < source_normals.size() else Vector3.UP)
			colors.append(entry.color)
			bones.append_array([bone, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
		if source_indices.is_empty():
			for index in range(source_vertices.size()):
				indices.append(offset + index)
		else:
			for index in source_indices:
				indices.append(offset + index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if bake_colors:
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := template_material.duplicate() as StandardMaterial3D
	if bake_colors:
		material.albedo_color = Color.WHITE
		material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.skin = skin
	instance.cast_shadow = template.cast_shadow
	instance.layers = template.layers
	instance.gi_mode = template.gi_mode
	# Skinning moves the mesh outside its bind-pose box, so give it a generous one in rig space.
	instance.custom_aabb = AABB(Vector3(-1.6, -0.6, -1.6), Vector3(3.2, 4.2, 3.2))
	return instance

# Each rendered frame the bones follow the joints.
func _process(_delta: float) -> void:
	if skeleton == null or not sync_enabled or not root.is_visible_in_tree():
		return
	var started := Time.get_ticks_usec()
	var root_inverse := root.global_transform.affine_inverse()
	for bone in range(owners.size()):
		var pose := root_inverse * owners[bone].global_transform
		skeleton.set_bone_pose_position(bone, pose.origin)
		skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, pose.basis.get_scale())
	sync_microseconds += Time.get_ticks_usec() - started
