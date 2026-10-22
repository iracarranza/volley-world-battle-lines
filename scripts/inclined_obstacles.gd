extends "res://scripts/workout_drill.gd"
## Steep physical ramp, narrow traction routes, and level footholds for recovery.
const SLOPE := 0.85
const LENGTH := 10.0
const PATH_WIDTH := 0.48
var footholds: Array[Vector3] = []

func _init() -> void:
	title = "INCLINED OBSTACLES"
	subattribute = "explosiveness"
	time_limit = 60.0
	xp_reward = 20
	hp_reward = 10.0
	zone = Rect2(-4, -13.5, 8, 17)

func _build_course() -> void:
	footholds.append(anchor + Vector3(0, 0.08, -2))
	for i in range(1, 6):
		var top := anchor + Vector3(-0.85 if i % 2 else 0.85, i * 2 * SLOPE + 0.08, -2 - i * 2)
		footholds.append(top)
		_add_step(top, Vector2(1.0, 0.65), Color("b89c72"))
	_build_ridged_surface()
	lab.world_builder.world_label("SPRINT THE RIDGED SURFACE / SMOOTH ROCK HAS NO FOOTING", anchor + Vector3(0, 0.2, 2), 22, Color("ffb46e"))

# The colored ridges are vertices of the ramp itself, including its collision mesh.
# No overlay strips or bridge geometry sits above the surface.
func _build_ridged_surface() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const CELL := 0.1
	for x in range(60):
		for z in range(100):
			var corners: Array[Vector3] = []
			for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var point := Vector3(-3 + (x + offset.x) * CELL, 0, -2 - (z + offset.y) * CELL)
				corners.append(point)
			for index in [0, 2, 1, 0, 3, 2]:
				var point := corners[index]
				var route := route_at(anchor + point)
				var weight := 1.0 - smoothstep(PATH_WIDTH - 0.12, PATH_WIDTH, float(route.distance))
				var ridge := pow(0.5 + 0.5 * cos(float(route.along) * TAU / 0.32), 3.0)
				point.y = - (point.z + 2) * SLOPE + weight * ridge * 0.055
				# Flatten the rock into the resting pockets, with a short beveled edge.
				for top in footholds:
					var local := top - anchor
					var blend := (1.0 - smoothstep(0.38, 0.53, absf(point.x - local.x))) * (1.0 - smoothstep(0.23, 0.38, absf(point.z - local.z)))
					point.y = lerpf(point.y, local.y, blend)
				surface.set_color(Color("6b5a44").lerp(Color("c3a359").lerp(Color("f5d78b"), ridge), weight))
				surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	var ramp := StaticBody3D.new()
	ramp.name = "RidgedRamp"
	ramp.position = anchor
	add_child(ramp)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	visual.material_override = material
	ramp.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	ramp.add_child(collision)

func route_at(p: Vector3) -> Dictionary:
	var best := {"distance": INF, "direction": Vector3.FORWARD, "along": 0.0}
	for i in range(footholds.size() - 1):
		var a := Vector2(footholds[i].x, footholds[i].z)
		var b := Vector2(footholds[i + 1].x, footholds[i + 1].z)
		var point := Vector2(p.x, p.z)
		var t := clampf((point - a).dot(b - a) / a.distance_squared_to(b), 0, 1)
		var distance := point.distance_to(a.lerp(b, t))
		if distance < float(best.distance):
			var direction := (b - a).normalized()
			best = {"distance": distance, "direction": Vector3(direction.x, 0, direction.y), "along": t * a.distance_to(b)}
	return best

func path_distance(p: Vector3) -> float:
	return float(route_at(p).distance)

func resting_at(p: Vector3) -> bool:
	for top in footholds:
		if absf(p.x - top.x) < 0.43 and absf(p.z - top.z) < 0.27 and absf(p.y - top.y) < 0.18:
			return true
	return false

func terrain_motion(_dt: float, move: Vector3, sprint: bool) -> void:
	if not in_zone(): return
	var p: Vector3 = lab.player.position - anchor
	if p.z > -2 or p.z < -12 or absf(p.x) > 3: return
	var height := (-p.z - 2) * SLOPE
	if p.y < height - 0.35 or p.y > height + 0.4: return
	var uphill: bool = move.z < -0.05 or lab.player.velocity.z < -0.1
	if uphill: lab.athlete.terrain_stamina_multiplier = 5.0
	if resting_at(lab.player.position): return
	# Airborne jumps retain their flight; touching rock cannot supply a new step.
	if (lab.motion.jumped or lab.motion.approach_bound) and lab.player.velocity.y > 0.0: return
	var route := route_at(lab.player.position)
	var direction: Vector3 = route.direction
	var power := (preload("res://scripts/stat_tuning.gd").rating(lab.athlete.build, "explosiveness") - 50.0) / 49.0
	var on_ridges := float(route.distance) <= PATH_WIDTH - 0.06
	var gripping: bool = sprint and on_ridges and move.dot(direction) > 0.55 and lab.athlete.stamina > 0.0
	if gripping:
		# Small ridge faces are steeper than the underlying ramp. They become
		# support only while actively gripping; the motor restores its floor angle.
		lab.player.floor_max_angle = deg_to_rad(65.0)
		# The ridge supplies limited uphill traction, never ordinary running speed.
		var speed := lerpf(1.4, 2.2, power)
		var correction := move - direction * move.dot(direction)
		var velocity := direction * speed + correction * 0.35
		lab.player.velocity.x = velocity.x
		lab.player.velocity.z = velocity.z
		lab.player.velocity.y = minf(lab.player.velocity.y, -0.5)
	else:
		# Replace the motor's ground drive: additive drag loses to its acceleration
		# every frame and permits walking straight up smooth rock.
		lab.player.velocity.x = move.x * (0.35 if on_ridges else 0.18)
		lab.player.velocity.z = (0.55 if on_ridges else 2.8) + maxf(0.0, move.z) * 0.5
		lab.player.velocity.y = -lab.player.velocity.z * SLOPE - 0.3

func _begin_run() -> void:
	steps_done = 0
	detail = "Follow the gold route uphill / recover on each foothold before the next burst"

func _tick_active(_dt: float) -> void:
	if _step_tick(title): _complete()
