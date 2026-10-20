extends RefCounted

# A spine for the voli. The rig builds the torso as one rigid mesh with the head, shoulders,
# neck and garments as separate siblings, so a lean could only tilt that one block. This
# keeps those nodes where they are and poses a chain of virtual joints over them:
#
#   hips (hinge) -> lumbar -> thoracic -> neck
#
# Each joint has flexion, lateral bend and twist. The torso, singlet and neck meshes are
# skinned to the chain in script (vertices blended between neighbouring joints by height),
# so the body curves instead of folding at a seam. Everything else rides on a joint rigidly.
#
# hip_yaw turns the whole pelvis about the vertical: the legs, their sockets, the tail and everything above the hips, which the
# twist joints then counter-rotate to keep the chest and head where the caller wants them.
#
# Angles are degrees; hip_shift is centimetres, positive forward. Flexion is positive forward, bend is positive to the character's
# left, twist is positive turning left.
const MESH_SPINE := ["Torso", "Singlet"]
const MESH_NECK := ["Neck"]
# Tails grow from the pelvis: Avi's TailFeathers, and the Tail that Feli and Cani have.
const ON_PELVIS := ["TailFeathers", "Tail"]
const ON_THORAX := ["LeftArm", "RightArm", "Collar"]
const NOT_SPINE := ["LeftLeg", "RightLeg"]
# Fractions of the way up from the hips to the shoulders.
const LUMBAR_AT := 0.30
const THORACIC_AT := 0.72
const BLEND_BAND := 0.10

const ZERO := {
	"hip_yaw": 0.0, "hip_shift": 0.0, "hip_hinge": 0.0, "lumbar_flexion": 0.0, "lumbar_bend": 0.0, "lumbar_twist": 0.0,
	"thoracic_flexion": 0.0, "thoracic_bend": 0.0, "thoracic_twist": 0.0,
	"neck_flexion": 0.0, "neck_bend": 0.0, "neck_twist": 0.0,
}

static func _about(pivot: Vector3, basis: Basis) -> Transform3D:
	return Transform3D(basis, pivot - basis * pivot)

static func _joint(flexion: float, bend: float, twist: float) -> Basis:
	return Basis.from_euler(Vector3(-deg_to_rad(flexion), deg_to_rad(twist), deg_to_rad(bend)), EULER_ORDER_XZY)

static func _mix(a: Transform3D, b: Transform3D, t: float) -> Transform3D:
	return Transform3D(Basis(a.basis.x.lerp(b.basis.x, t), a.basis.y.lerp(b.basis.y, t), a.basis.z.lerp(b.basis.z, t)), a.origin.lerp(b.origin, t))

# Remember how the rig was built. Called once, before the first pose.
static func capture(body: Node3D) -> void:
	if body.has_meta("spine_rest"):
		return
	var left_leg := body.get_node_or_null("LeftLeg") as Node3D
	var left_arm := body.get_node_or_null("LeftArm") as Node3D
	var neck := body.get_node_or_null("Neck") as MeshInstance3D
	if left_leg == null or left_arm == null:
		return
	var hip := Vector3(0.0, left_leg.position.y, left_leg.position.z)
	var shoulder_y := left_arm.position.y
	var span := shoulder_y - hip.y
	var rest := {"nodes": {}, "meshes": {}, "anchors": {
		"hip": hip,
		"lumbar": Vector3(0.0, hip.y + span * LUMBAR_AT, hip.z),
		"thoracic": Vector3(0.0, hip.y + span * THORACIC_AT, hip.z),
		"band": span * BLEND_BAND,
		"neck": Vector3(0.0, shoulder_y, hip.z),
		"neck_top": Vector3(0.0, shoulder_y, hip.z),
	}}
	if neck != null and neck.mesh != null:
		var box := neck.mesh.get_aabb()
		rest.anchors.neck = Vector3(neck.position.x, neck.position.y + box.position.y, neck.position.z)
		rest.anchors.neck_top = Vector3(neck.position.x, neck.position.y + box.end.y, neck.position.z)
	rest["legs_z"] = {}
	rest["legs_x"] = {}
	for side in ["LeftLeg", "RightLeg"]:
		var leg := body.get_node_or_null(side) as Node3D
		if leg != null:
			rest.legs_z[side] = leg.position.z
			rest.legs_x[side] = leg.position.x
	for child in body.get_children():
		if child is Node3D and not NOT_SPINE.has(String(child.name)):
			rest.nodes[String(child.name)] = {"position": child.position, "basis": child.basis}
	for path in MESH_SPINE + MESH_NECK:
		var node := body.get_node_or_null(path) as MeshInstance3D
		if node != null and node.mesh != null:
			rest.meshes[path] = _capture_mesh(node, node.mesh)
			var ink := node.get_node_or_null("Ink") as MeshInstance3D
			if ink != null and ink.mesh != null:
				rest.meshes[path + "/Ink"] = _capture_mesh(ink, ink.mesh)
	body.set_meta("spine_rest", rest)

static func _capture_mesh(node: MeshInstance3D, mesh: Mesh) -> Dictionary:
	var surfaces: Array = []
	for index in range(mesh.get_surface_count()):
		surfaces.append(mesh.surface_get_arrays(index))
	return {"mesh": mesh, "surfaces": surfaces, "local": node.transform}

# Put every spine rider and skinned mesh back as the rig built it.
static func release(body: Node3D) -> void:
	if not body.has_meta("spine_rest") or not body.has_meta("spine_key"):
		return
	var rest: Dictionary = body.get_meta("spine_rest")
	# Take the pelvis turn off the legs before anything reads their angles.
	var yaw: float = deg_to_rad(float(body.get_meta("spine_angles", {}).get("hip_yaw", 0.0)))
	if not is_zero_approx(yaw):
		for side in rest.legs_z:
			var leg := body.get_node(side) as Node3D
			leg.basis = Basis(Vector3.UP, -yaw) * leg.basis
	for path in rest.nodes:
		var node := body.get_node_or_null(path) as Node3D
		if node != null:
			node.position = rest.nodes[path].position
			if path != "Torso" and not ["LeftArm", "RightArm"].has(path):
				node.basis = rest.nodes[path].basis
	for path in rest.meshes:
		var node := body.get_node_or_null(path) as MeshInstance3D
		if node != null:
			node.mesh = rest.meshes[path].mesh
	for side in rest.legs_z:
		(body.get_node(side) as Node3D).position.z = rest.legs_z[side]
		(body.get_node(side) as Node3D).position.x = rest.legs_x.get(side, (body.get_node(side) as Node3D).position.x)
	body.remove_meta("spine_key")
	body.remove_meta("spine_xf")
	body.remove_meta("spine_angles")
	body.remove_meta("pre_ik")

# The chain's transforms for these angles, in the body's local space.
static func chain(rest: Dictionary, angles: Dictionary) -> Dictionary:
	var anchors: Dictionary = rest.anchors
	var shift := Transform3D(Basis(), Vector3(0.0, 0.0, -0.01 * float(angles.get("hip_shift", 0.0))))
	var turn := _about(anchors.hip, Basis(Vector3.UP, deg_to_rad(float(angles.get("hip_yaw", 0.0)))))
	var hinge := shift * turn * _about(anchors.hip, Basis(Vector3.RIGHT, -deg_to_rad(float(angles.get("hip_hinge", 0.0)))))
	var lumbar := hinge * _about(anchors.lumbar, _joint(float(angles.get("lumbar_flexion", 0.0)), float(angles.get("lumbar_bend", 0.0)), float(angles.get("lumbar_twist", 0.0))))
	var thorax := lumbar * _about(anchors.thoracic, _joint(float(angles.get("thoracic_flexion", 0.0)), float(angles.get("thoracic_bend", 0.0)), float(angles.get("thoracic_twist", 0.0))))
	var head := thorax * _about(anchors.neck, _joint(float(angles.get("neck_flexion", 0.0)), float(angles.get("neck_bend", 0.0)), float(angles.get("neck_twist", 0.0))))
	return {"hinge": hinge, "lumbar": lumbar, "thorax": thorax, "head": head}

# Joint positions as posed, in the body's local space, for editor handles.
static func joint_positions(body: Node3D) -> Dictionary:
	if not body.has_meta("spine_rest"):
		return {}
	var rest: Dictionary = body.get_meta("spine_rest")
	var xf: Dictionary = body.get_meta("spine_xf", chain(rest, ZERO))
	var a: Dictionary = rest.anchors
	return {
		"pelvis": xf.hinge * a.hip,
		"lumbar": xf.hinge * a.lumbar,
		"thoracic": xf.lumbar * a.thoracic,
		"neck": xf.thorax * a.neck,
	}

# Pose the spine. `angles` uses the keys in ZERO; missing keys are zero.
# Each arm keeps the rotation the caller gave it; the thorax rotation is applied on top.
static func pose(body: Node3D, angles: Dictionary) -> void:
	capture(body)
	if not body.has_meta("spine_rest"):
		return
	release(body)
	var rest: Dictionary = body.get_meta("spine_rest")
	var xf := chain(rest, angles)
	var anchors: Dictionary = rest.anchors
	# The hips carry the legs' sockets with them. Foot planting is the caller's job.
	var yaw := deg_to_rad(float(angles.get("hip_yaw", 0.0)))
	for side in rest.legs_z:
		var leg := body.get_node(side) as Node3D
		var socket := Vector3(rest.legs_x.get(side, leg.position.x), leg.position.y, rest.legs_z[side] - 0.01 * float(angles.get("hip_shift", 0.0)))
		if not is_zero_approx(yaw):
			socket = anchors.hip + Basis(Vector3.UP, yaw) * (socket - anchors.hip)
			leg.basis = Basis(Vector3.UP, yaw) * leg.basis
		leg.position = socket
	for path in rest.nodes:
		var node := body.get_node_or_null(path) as Node3D
		if node == null or MESH_SPINE.has(path) or MESH_NECK.has(path):
			continue
		var group: Transform3D = xf.head
		if ON_PELVIS.has(path) or path.begins_with("Tail"):
			group = xf.hinge
		elif ON_THORAX.has(path):
			group = xf.thorax
		node.position = group * rest.nodes[path].position
		node.basis = group.basis * node.basis
	var key := []
	for joint in ZERO:
		key.append(snappedf(float(angles.get(joint, 0.0)), 0.01))
	body.set_meta("spine_key", key)
	body.set_meta("spine_xf", xf)
	body.set_meta("spine_angles", angles.duplicate())
	# Skinning rebuilds meshes, so keep the last result: a held pose costs nothing per frame.
	var cache: Dictionary = body.get_meta("spine_cache", {})
	if cache.get("key", []) != key:
		cache = {"key": key, "meshes": {}}
		for path in rest.meshes:
			var node_path: String = path.get_slice("/", 0)
			var host_rest: Dictionary = rest.nodes.get(node_path, {})
			if host_rest.is_empty():
				continue
			var host_xf := Transform3D(host_rest.basis, host_rest.position)
			var to_body: Transform3D = host_xf
			if path.contains("/"):
				to_body = host_xf * (rest.meshes[path].local as Transform3D)
			cache.meshes[path] = _skin(rest.meshes[path], to_body, xf, anchors, MESH_NECK.has(node_path))
		body.set_meta("spine_cache", cache)
	for path in cache.meshes:
		var node := body.get_node_or_null(path) as MeshInstance3D
		if node != null:
			node.mesh = cache.meshes[path]
			if not path.contains("/"):
				node.position = rest.nodes[path].position
				node.basis = rest.nodes[path].basis

static func _skin(source: Dictionary, to_body: Transform3D, xf: Dictionary, anchors: Dictionary, neck: bool) -> ArrayMesh:
	var inverse := to_body.affine_inverse()
	var band: float = anchors.band
	var lumbar_y: float = anchors.lumbar.y
	var thoracic_y: float = anchors.thoracic.y
	var neck_low: float = anchors.neck.y
	var neck_high: float = maxf(anchors.neck_top.y, neck_low + 0.001)
	var mesh := ArrayMesh.new()
	for arrays in source.surfaces:
		var out: Array = arrays.duplicate()
		var vertices: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		var normals: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		for i in range(vertices.size()):
			var p: Vector3 = to_body * vertices[i]
			var blend: Transform3D
			if neck:
				blend = _mix(xf.thorax, xf.head, smoothstep(neck_low, neck_high, p.y))
			else:
				var t1 := smoothstep(lumbar_y - band, lumbar_y + band, p.y)
				var t2 := smoothstep(thoracic_y - band, thoracic_y + band, p.y)
				blend = _mix(xf.hinge, _mix(xf.lumbar, xf.thorax, t2), t1)
			vertices[i] = inverse * (blend * p)
			if i < normals.size():
				normals[i] = (inverse.basis * (blend.basis * (to_body.basis * normals[i]))).normalized()
		out[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			out[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh
