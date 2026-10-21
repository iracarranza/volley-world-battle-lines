extends Node3D
## Swept ball-versus-ring response, sharing the net tape's normal/tangent damping.
const Tape := preload("res://scripts/net_response.gd")
const BALL_RADIUS := preload("res://scripts/contact_geometry.gd").BALL_RADIUS
const RADIUS := 0.85
const TUBE_RADIUS := 0.055
const MAX_ENTRY_ANGLE := 60.0
var normal := Vector3.UP
var rim: MeshInstance3D

func build(color: Color) -> void:
	rim = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = RADIUS-TUBE_RADIUS
	mesh.outer_radius = RADIUS+TUBE_RADIUS
	mesh.rings = 48
	mesh.ring_segments = 10
	rim.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim.material_override = material
	add_child(rim)
	var net := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(16):
		var angle := TAU*i/16.0
		var direction := Vector3(cos(angle),0,sin(angle))
		lines.surface_add_vertex(direction*RADIUS)
		lines.surface_add_vertex(direction*0.45-Vector3.UP*0.65)
		lines.surface_add_vertex(direction*0.45-Vector3.UP*0.65)
		var next := Vector3(cos(angle+TAU/16),0,sin(angle+TAU/16))
		lines.surface_add_vertex(next*0.45-Vector3.UP*0.65)
	lines.surface_end()
	net.mesh = lines
	var thread := StandardMaterial3D.new()
	thread.albedo_color = Color("b7e5ec")
	thread.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net.material_override = thread
	add_child(net)

func place(center: Vector3,face: Vector3) -> void:
	position = center
	normal = face.normalized()
	basis = Basis(Quaternion(Vector3.UP,normal))

func rim_distance(point: Vector3,center: Vector3) -> float:
	var relative := point-center
	var axial := relative.dot(normal)
	var radial := (relative-normal*axial).length()
	return Vector2(radial-RADIUS,axial).length()-TUBE_RADIUS-BALL_RADIUS

func rim_fraction(previous: Vector3,endpoint: Vector3,center: Vector3) -> float:
	var length := previous.distance_to(endpoint)
	var fraction := 0.0
	# The torus signed distance bounds each safe advance, avoiding tunneling at high speed.
	for iteration in range(96):
		var distance := rim_distance(previous.lerp(endpoint,fraction),center)
		if distance <= 0.00001: return fraction
		if length <= 0.000001: return -1
		fraction += maxf(distance*0.9/length,0.000001)
		if fraction > 1: return -1
	return -1

func entry_fraction(previous: Vector3,endpoint: Vector3,velocity: Vector3,center: Vector3) -> float:
	var front := (previous-center).dot(normal)
	var back := (endpoint-center).dot(normal)
	if front > 0 and back <= 0:
		var entry := front/(front-back)
		var crossing := previous.lerp(endpoint,entry)-center
		var alignment := -velocity.normalized().dot(normal) if velocity.length_squared()>0.00001 else 0.0
		if crossing.length() > RADIUS-TUBE_RADIUS-BALL_RADIUS or velocity.y >= 0 or alignment < cos(deg_to_rad(MAX_ENTRY_ANGLE)):
			return -1
		return entry
	return -1

func step(previous: Vector3,endpoint: Vector3,velocity: Vector3,dt: float) -> Dictionary:
	var center := global_position
	var result := {"position":endpoint,"velocity":velocity,"contact":false,"scored":false}
	var hit := rim_fraction(previous,endpoint,center)
	var entry := entry_fraction(previous,endpoint,velocity,center)
	if entry >= 0 and (hit < 0 or entry < hit):
		result.scored = true
		result.position = previous.lerp(endpoint,entry)
		return result
	if hit < 0: return result
	var point := previous.lerp(endpoint,hit)
	var local := point-center
	var radial := local-normal*local.dot(normal)
	var nearest := center+radial.normalized()*RADIUS
	var bounce_normal := (point-nearest).normalized()
	if bounce_normal.length_squared() < 0.01: bounce_normal = normal
	result.velocity = Tape.tape_velocity(velocity,bounce_normal)
	var separated := nearest+bounce_normal*(BALL_RADIUS+TUBE_RADIUS+0.002)
	result.position = separated+Vector3(result.velocity)*dt*(1-hit)
	result.contact = velocity.dot(bounce_normal)<0
	# A soft inner-rim touch may drop in during the remainder of this same frame.
	var after_entry := entry_fraction(separated,result.position,result.velocity,center)
	if after_entry >= 0:
		var after_hit := rim_fraction(separated,result.position,center)
		if after_hit < 0 or after_entry < after_hit:
			result.scored = true
			result.position = separated.lerp(result.position,after_entry)
	return result
