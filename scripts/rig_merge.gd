extends RefCounted
## Rig mesh merging (prototype). The built rig is dozens of separate meshes, each a node and a draw call, and each with an "Ink" outline twin. The pieces that
## ride rigidly on one limb joint (a limb's segment, its joint ball, its sleeve or shorts) never move relative to it, so they can be one mesh: one for the solid
## parts (each part's colour baked into the vertices) and one for the ink. The joint nodes, and everything the animation code reaches by path, stay as they
## are; only the leaf meshes under the limb joints are replaced. Parts that move on their own (shoes, the face, hands) are left alone.
const JOINTS := ["LeftArm", "RightArm", "LeftArm/Elbow", "RightArm/Elbow", "LeftLeg", "RightLeg", "LeftLeg/Knee", "RightLeg/Knee"]
const KEEP := ["Shoe", "Palm", "Face"]

# Merges every limb joint's rigid meshes. Returns {"before": meshes, "after": meshes}.
static func merge(root: Node3D) -> Dictionary:
	var before := count_meshes(root)
	for path in JOINTS:
		var joint := root.get_node_or_null(path) as Node3D
		if joint != null:
			_merge_joint(joint)
	return {"before": before, "after": count_meshes(root)}

static func count_meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
	for child in node.get_children():
		total += count_meshes(child)
	return total

static func arrays_of(mesh: Mesh) -> Array:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_arrays(0)
	if mesh is PrimitiveMesh:
		return (mesh as PrimitiveMesh).get_mesh_arrays()
	return []

# Whether two materials look the same apart from the colour: those can share one merged material.
static func compatible(a: Material, b: Material) -> bool:
	if not (a is StandardMaterial3D and b is StandardMaterial3D):
		return false
	var x := a as StandardMaterial3D
	var y := b as StandardMaterial3D
	return x.albedo_texture == null and y.albedo_texture == null and x.roughness == y.roughness and x.metallic == y.metallic and x.shading_mode == y.shading_mode and x.transparency == y.transparency and x.cull_mode == y.cull_mode and x.emission_enabled == y.emission_enabled and x.vertex_color_use_as_albedo == y.vertex_color_use_as_albedo and x.no_depth_test == y.no_depth_test

static func _merge_joint(joint: Node3D) -> void:
	var solids: Array[MeshInstance3D] = []
	var inks: Array[Dictionary] = [] # {"mesh": MeshInstance3D, "transform": Transform3D relative to the joint}
	for child in joint.get_children():
		if not (child is MeshInstance3D) or KEEP.has(String(child.name)) or (child as MeshInstance3D).mesh == null:
			continue
		var part := child as MeshInstance3D
		if arrays_of(part.mesh).is_empty() or part.get_active_material(0) == null:
			continue
		if not solids.is_empty() and not compatible(solids[0].get_active_material(0), part.get_active_material(0)):
			continue
		solids.append(part)
	if solids.size() < 2:
		return
	var ink_template: Material = null
	for part in solids:
		for grandchild in part.get_children():
			if grandchild is MeshInstance3D and (grandchild as MeshInstance3D).mesh != null and not arrays_of((grandchild as MeshInstance3D).mesh).is_empty():
				var ink := grandchild as MeshInstance3D
				if ink_template == null:
					ink_template = ink.get_active_material(0)
				if compatible(ink_template, ink.get_active_material(0)) and ink.get_active_material(0).get("albedo_color") == ink_template.get("albedo_color"):
					inks.append({"mesh": ink, "transform": part.transform * ink.transform})
	var template := solids[0]
	var solid_parts: Array[Dictionary] = []
	for part in solids:
		var material := part.get_active_material(0) as StandardMaterial3D
		solid_parts.append({"mesh": part, "transform": part.transform, "color": material.albedo_color})
	var merged_solid := _merged_instance(joint, "MergedSolid", solid_parts, template.get_active_material(0), true, template)
	joint.add_child(merged_solid)
	if not inks.is_empty():
		var merged_ink := _merged_instance(joint, "MergedInk", inks, ink_template, false, inks[0].mesh)
		joint.add_child(merged_ink)
	for part in solids:
		joint.remove_child(part)
		part.queue_free()

static func _merged_instance(joint: Node3D, node_name: String, parts: Array, template_material: Material, bake_colors: bool, template: MeshInstance3D) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for entry in parts:
		var arrays := arrays_of((entry.mesh as MeshInstance3D).mesh)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var xf: Transform3D = entry.transform
		var normal_basis := xf.basis.inverse().transposed()
		var offset := vertices.size()
		var tint: Color = entry.get("color", Color.WHITE)
		for index in range(source_vertices.size()):
			vertices.append(xf * source_vertices[index])
			normals.append((normal_basis * source_normals[index]).normalized() if index < source_normals.size() else Vector3.UP)
			colors.append(tint)
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
	instance.cast_shadow = template.cast_shadow
	instance.layers = template.layers
	instance.gi_mode = template.gi_mode
	return instance
