extends RefCounted
## Dead balls retain visible bounce/roll after the point has been scored once.
const RADIUS := 0.105
const MAX_BALLS := 3
var balls: Array[Dictionary] = []
var last_pickup_point := Vector3.ZERO
var last_origin := -1 # the cart the most recently taken ball came from

func clear() -> void:
	for entry in balls:
		entry.mesh.queue_free()
		entry.shadow.queue_free()
	balls.clear()

func land(lab: Node3D,point: Vector3,incoming: Vector3,shot: Dictionary) -> void:
	if balls.size() >= MAX_BALLS:
		var oldest: Dictionary = balls.pop_front()
		oldest.mesh.queue_free()
		oldest.shadow.queue_free()
	var mesh := MeshInstance3D.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.mesh = lab.ball.mesh
	mesh.material_override = lab.ball.material_override
	lab.add_child(mesh)
	mesh.global_position = point+Vector3.UP*RADIUS
	mesh.rotation = lab.ball.rotation
	var shade := MeshInstance3D.new()
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.mesh = lab.shadow.mesh
	shade.material_override = lab.shadow.material_override
	lab.add_child(shade)
	shade.global_position = point+Vector3.UP*0.025
	var velocity := Vector3(incoming.x*0.78,absf(incoming.y)*0.42,incoming.z*0.78)
	# With the ball economy on, a free ball (tossed, never served) can be picked up by anyone until it despawns.
	var pickable: bool = lab.inventory.enabled and lab.inventory.landed_free
	lab.inventory.landed_free = false
	balls.append({"mesh":mesh,"shadow":shade,"velocity":velocity,"floor":point.y,"age":0.0,"pickable":pickable,"origin":lab.inventory.pending_origin if pickable else -1,"opposing":lab.inventory.pending_opposing if pickable else false})
	lab.moc.clear()
	lab.moc.begin({"id":"ground:%d"%Time.get_ticks_usec(),"actor":"ground","action":5,"physical_hit":true,"point":mesh.global_position,"incoming_velocity":incoming,"outgoing_velocity":velocity,"incoming_shot":shot})
	lab.ball.visible = lab.ball_active
	lab.shadow.visible = lab.ball_active

func tick(lab: Node3D,dt: float) -> void:
	var step: float = dt*lab.moc.simulation_scale()
	for index in range(balls.size()-1,-1,-1):
		var entry: Dictionary = balls[index]
		entry.age += dt
		var mesh: MeshInstance3D = entry.mesh
		var velocity: Vector3 = entry.velocity
		if float(entry.floor) > 0.01:
			var at := mesh.global_position
			var query := PhysicsRayQueryParameters3D.create(Vector3(at.x,float(entry.floor)+0.25,at.z),Vector3(at.x,-1,at.z))
			query.exclude = [lab.player.get_rid()]
			var support: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(query)
			entry.floor = float(support.position.y) if not support.is_empty() and Vector3(support.normal).y > 0.65 else 0.0
		var floor_y: float = float(entry.floor)+RADIUS
		if mesh.global_position.y > floor_y+0.0001 or velocity.y > 0:
			mesh.global_position += velocity*step+Vector3.DOWN*lab.GRAVITY*step*step*0.5
			velocity.y -= lab.GRAVITY*step
			if mesh.global_position.y <= floor_y:
				mesh.global_position.y = floor_y
				velocity.y = absf(velocity.y)*0.42 if absf(velocity.y) > 0.8 else 0.0
				velocity.x *= 0.82
				velocity.z *= 0.82
		else:
			var lateral := Vector3(velocity.x,0,velocity.z).move_toward(Vector3.ZERO,2.8*step)
			mesh.global_position += lateral*step
			velocity = lateral
		var axis := Vector3.UP.cross(Vector3(velocity.x,0,velocity.z))
		if axis.length_squared() > 0.00001: mesh.rotate(axis.normalized(),axis.length()*step/RADIUS)
		entry.shadow.global_position = Vector3(mesh.global_position.x,float(entry.floor)+0.025,mesh.global_position.z)
		entry.velocity = velocity
		if entry.age > (lab.inventory.DESPAWN_SECONDS if entry.get("pickable", false) else 7.0):
			# A ball an opposing player tossed from a team's cart and let go to waste returns to that cart instead of being lost.
			if entry.get("pickable", false) and bool(entry.get("opposing", false)) and int(entry.get("origin", -1)) >= 0 and is_instance_valid(lab.ball_carts):
				lab.ball_carts.give_back(int(entry.origin))
			mesh.queue_free()
			entry.shadow.queue_free()
			balls.remove_at(index)

# Removes and returns true for the nearest pickable ball within `radius` of `point` (horizontal distance).
func take_near(point: Vector3, radius: float) -> bool:
	var best := -1
	var best_distance := radius
	for index in range(balls.size()):
		var entry: Dictionary = balls[index]
		if not entry.get("pickable", false):
			continue
		var at: Vector3 = entry.mesh.global_position
		var distance := Vector2(at.x - point.x, at.z - point.z).length()
		if distance <= best_distance:
			best = index
			best_distance = distance
	if best < 0:
		return false
	var taken: Dictionary = balls[best]
	last_origin = int(taken.get("origin", -1))
	last_pickup_point = taken.mesh.global_position
	taken.mesh.queue_free()
	taken.shadow.queue_free()
	balls.remove_at(best)
	return true

func pickable_count() -> int:
	var count := 0
	for entry in balls:
		if entry.get("pickable", false):
			count += 1
	return count
