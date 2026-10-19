extends Node3D

# The map's geometry, built from scripts/map_layout.gd: floor, bases, lanes, Nets and courts, pits, walls, jungle sectors and markers.
# Used by the lab-hosted graybox (scripts/map_lab.gd) and by the plain traversal scene (scripts/map_traversal.gd).
#
# options (all optional):
#   "floor": bool            build the floor (default true; the lab already has one)
#   "skip_nets": Array       Net ids not to build, because the host has its own there (the lab keeps its Net at the origin)
#   "skip_sectors": Array    jungle sector indexes to leave empty, because a real Drill goes there
#   "skip_markers": Array    marker names not to build, because a real Drill goes there
const Layout := preload("res://scripts/map_layout.gd")
const TEAL := Color("54ead0")
const GOLD := Color("ffce73")
const ORANGE := Color("ffb46e")
const WALL_COLOR := Color("5b6f7a")
const LANE_COLOR := Color("27474f")
const STEP_HEIGHTS := [0.7, 1.2, 1.7]

var options := {}
var solids: Array[Node3D] = []

func build() -> void:
	_build_environment()
	if options.get("floor", true):
		_build_floor()
	_build_central_line()
	_build_bases()
	_build_lanes()
	_build_nets()
	_build_pits()
	_build_lane_walls()
	var sectors := Layout.sectors()
	for i in range(sectors.size()):
		if not (options.get("skip_sectors", []) as Array).has(i):
			_build_sector(sectors[i])
	_build_markers()

# --- Building blocks ---------------------------------------------------------------------------------

func _material(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.9
	return material

# A box at `xform` (its centre). Solid ones get a collider; the rest are floor decals.
func _box(size: Vector3, xform: Transform3D, color: Color, solid: bool = false, alpha: float = 1.0) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _material(color, alpha)
	if not solid:
		mesh.transform = xform
		add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.transform = xform
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	add_child(body)
	solids.append(body)
	return body

func _at(position_in_world: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), position_in_world)

func _label(text: String, position_in_world: Vector3, size: int = 36, color: Color = GOLD) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position_in_world
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

func _decal(size: Vector2, position_in_world: Vector3, color: Color, yaw: float = 0.0, alpha: float = 1.0) -> Node3D:
	return _box(Vector3(size.x, 0.04, size.y), _at(position_in_world + Vector3(0.0, 0.02, 0.0), yaw), color, false, alpha)

func _segment_yaw(a: Vector2, b: Vector2) -> float:
	return atan2(b.x - a.x, b.y - a.y)

# --- The world -----------------------------------------------------------------------------------------

func _build_environment() -> void:
	if not options.get("floor", true):
		return   # the host has its own sky and sun
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0e1928")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5d2e4")
	environment.ambient_light_energy = 0.7
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_floor() -> void:
	_box(Vector3(Layout.HALF * 2.0, 0.2, Layout.HALF * 2.0), _at(Vector3(0.0, -0.1, 0.0)), Color("1a2d3d"), true)

func _build_central_line() -> void:
	_decal(Vector2(Layout.HALF * 1.7, 0.2), Vector3.ZERO, GOLD, 0.0, 0.7)
	_label("CENTRAL LINE", Vector3(-62.0, 0.4, 0.0), 30, GOLD)

func _build_bases() -> void:
	for team_name in ["blue", "red"]:
		var sign_z := 1.0 if team_name == "blue" else -1.0
		var tint := Color("3a6ea5") if team_name == "blue" else Color("a53a3a")
		_decal(Layout.BASE_SIZE, Vector3(0.0, 0.0, sign_z * Layout.BASE_Z), tint, 0.0, 0.85)
		_label("%s BASE" % team_name.to_upper(), Vector3(0.0, 2.4, sign_z * (Layout.BASE_Z + 7.0)), 44, tint.lightened(0.4))
		for spawn in Layout.spawns(team_name):
			var marker := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 0.06
			marker.mesh = cylinder
			marker.material_override = _material(tint.lightened(0.35))
			marker.position = Vector3(spawn.x, 0.06, spawn.z)
			add_child(marker)

func _build_lanes() -> void:
	for lane in Layout.lane_ids():
		var blue := Layout.lane_points(lane)
		for line in [blue, Layout.mirrored(blue)]:
			for i in range(line.size() - 1):
				var a: Vector2 = line[i]
				var b: Vector2 = line[i + 1]
				var middle := (a + b) * 0.5
				var length := a.distance_to(b) + Layout.LANE_WIDTH * 0.35
				_decal(Vector2(Layout.LANE_WIDTH, length), Vector3(middle.x, 0.0, middle.y), LANE_COLOR.lightened(0.05 * i), _segment_yaw(a, b))
		var mid_net := Layout.net_by_id(lane)
		_label("%s LANE" % lane.to_upper(), Vector3(float(mid_net.position.x) * 0.55 - (3.0 if lane == "top" else (-3.0 if lane == "bottom" else 0.0)), 0.5, 36.0), 30, TEAL)
		_label("%s LANE" % lane.to_upper(), Vector3(float(mid_net.position.x) * 0.55 - (3.0 if lane == "top" else (-3.0 if lane == "bottom" else 0.0)), 0.5, -36.0), 30, TEAL)

func _build_nets() -> void:
	for net in Layout.nets():
		if (options.get("skip_nets", []) as Array).has(net.id):
			continue
		var center: Vector3 = net.position
		var width: float = net.width
		var depth: float = net.depth
		var tint := TEAL if net.kind == "lane" else ORANGE
		_decal(Vector2(width, depth), center, tint.darkened(0.55), 0.0, 0.55)
		for edge in [-depth * 0.5, depth * 0.5]:
			_decal(Vector2(width, 0.12), center + Vector3(0.0, 0.0, edge), tint)
		for edge in [-width * 0.5, width * 0.5]:
			_decal(Vector2(0.12, depth), center + Vector3(edge, 0.0, 0.0), tint)
		var height: float = net.height
		var span := width + 0.5
		# The Net itself is a wall: you walk around its ends or through the jungle, not across it.
		_box(Vector3(span, height, 0.1), _at(center + Vector3(0.0, height * 0.5, 0.0)), Color("d9e6ec"), true, 0.55)
		for end in [-span * 0.5, span * 0.5]:
			_box(Vector3(0.12, height + 0.2, 0.12), _at(center + Vector3(end, (height + 0.2) * 0.5, 0.0)), GOLD, true)
		_label("%s  %.2f m" % [String(net.label), height], center + Vector3(0.0, height + 1.2, 0.0), 32, tint.lightened(0.3))

func _build_pits() -> void:
	for side in [-1.0, 1.0]:
		var center := Vector3(side * Layout.PIT_X, 0.0, 0.0)
		var radius := Layout.PIT_RING_RADIUS
		var length := 2.0 * radius * tan(PI / 8.0) + 0.3
		for k in range(8):
			var angle := float(k) * PI / 4.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			if absf(direction.z) > 0.9:
				continue   # the north and south openings, where the teams come in
			var tangent := Vector3(-sin(angle), 0.0, cos(angle))
			_box(Vector3(0.8, 2.4, length), _at(center + direction * radius + Vector3(0.0, 1.2, 0.0), atan2(tangent.x, tangent.z)), WALL_COLOR.darkened(0.1), true)
		_label("PIT", center + Vector3(0.0, 4.2, 5.0), 44, ORANGE)

# Low walls beside each lane, with gaps: alternately a wall you can jump and one you have to go around.
func _build_lane_walls() -> void:
	for lane in Layout.lane_ids():
		var blue := Layout.lane_points(lane)
		for line in [blue, Layout.mirrored(blue)]:
			var piece := 0
			for i in range(line.size() - 1):
				var a: Vector2 = line[i]
				var b: Vector2 = line[i + 1]
				var direction := (b - a).normalized()
				var normal := Vector2(-direction.y, direction.x)
				var run := a.distance_to(b)
				var along := 6.0
				while along + 8.0 <= run:
					var middle := a + direction * (along + 4.0)
					if absf(middle.y) < 50.0 and absf(middle.y) > 13.0:
						var height := 1.0 if piece % 2 == 0 else 2.2
						for side in [-1.0, 1.0]:
							var spot: Vector2 = middle + normal * side * (Layout.LANE_WIDTH * 0.5 + 0.9)
							_box(Vector3(0.6, height, 8.0), _at(Vector3(spot.x, height * 0.5, spot.y), _segment_yaw(a, b)), WALL_COLOR, true)
						piece += 1
					along += 14.0

# One jungle sector: the Serve Receive Drill pad, dividers, a stair of ledges, a ramp and platform, and a ledge too high to reach.
func _build_sector(center: Vector2) -> void:
	var mx := -signf(center.x)
	var mz := signf(center.y)
	var pad := Layout.sector_point(center, 0.0, 0.0)
	_decal(Vector2(6.0, 6.0), pad, Color("5f6b3f"), 0.0, 0.9)
	_label("SERVE RECEIVE" + (" (marker)" if options.get("hosted", false) else ""), pad + Vector3(0.0, 1.2, 0.0), 28, GOLD)
	for local_x in [-6.0, 6.0]:
		var yaw := deg_to_rad(15.0) * mx * mz * (1.0 if local_x < 0.0 else -1.0)
		_box(Vector3(8.0, 2.0, 0.6), _at(Layout.sector_point(center, local_x, -6.0) + Vector3(0.0, 1.0, 0.0), yaw), WALL_COLOR, true)
	for i in range(STEP_HEIGHTS.size()):
		var height: float = STEP_HEIGHTS[i]
		var spot := Layout.sector_point(center, -9.0 + 3.2 * float(i), 4.0)
		_box(Vector3(3.0, height, 4.0), _at(spot + Vector3(0.0, height * 0.5, 0.0)), Color("6d7f88").lightened(0.06 * i), true)
	_label("LEDGES %.1f / %.1f / %.1f m" % [STEP_HEIGHTS[0], STEP_HEIGHTS[1], STEP_HEIGHTS[2]], Layout.sector_point(center, -5.8, 4.0) + Vector3(0.0, 3.2, 0.0), 22, TEAL)
	var low := Layout.sector_point(center, 9.0, -2.0)
	var high := Layout.sector_point(center, 9.0, 3.0) + Vector3(0.0, 1.0, 0.0)
	var slope := high - low
	var ramp_center := (low + high) * 0.5 - Vector3(0.0, 0.2, 0.0)
	_box(Vector3(3.0, 0.4, slope.length()), Transform3D(Basis.looking_at(slope.normalized(), Vector3.UP), ramp_center), Color("7a8d96"), true)
	var platform := Layout.sector_point(center, 9.0, 5.0)
	_box(Vector3(3.0, 1.0, 4.0), _at(platform + Vector3(0.0, 0.5, 0.0)), Color("6d7f88"), true)
	_label("RAMP + 1.0 m", platform + Vector3(0.0, 2.2, 0.0), 22, TEAL)
	var block := Layout.sector_point(center, -10.0, -9.0)
	_box(Vector3(3.0, 2.2, 3.0), _at(block + Vector3(0.0, 1.1, 0.0)), Color("8a6a5a"), true)
	_label("HIGH LEDGE 2.2 m (needs mobility, G)", block + Vector3(0.0, 3.6, 0.0), 22, ORANGE)

# Drill and Energy Drink positions: markers only.
func _build_markers() -> void:
	var skipped: Array = options.get("skip_markers", [])
	var tag := " (marker)" if options.get("hosted", false) else ""
	for sign_z in [-1.0, 1.0]:
		var half := "blue" if sign_z > 0.0 else "red"
		if not skipped.has("box_jump_" + half):
			_decal(Vector2(8.0, 8.0), Vector3(-46.0, 0.0, sign_z * 22.0), Color("7a6a3a"), 0.0, 0.9)
			_label("BOX JUMP" + tag, Vector3(-46.0, 1.4, sign_z * 22.0), 28, GOLD)
		if not skipped.has("transition_set_" + half):
			_decal(Vector2(8.0, 8.0), Vector3(46.0, 0.0, sign_z * 22.0), Color("3a6a7a"), 0.0, 0.9)
			_label("TRANSITION SET" + tag, Vector3(46.0, 1.4, sign_z * 22.0), 28, GOLD)
	var sectors := Layout.sectors()
	for i in range(sectors.size()):
		if skipped.has("spike_%d" % i) or (options.get("skip_sectors", []) as Array).has(i):
			continue
		var spike := Layout.sector_point(sectors[i], 3.0, -9.0)
		_decal(Vector2(4.0, 4.0), spike, Color("7a4a3a"), 0.0, 0.9)
		_label("SPIKE TRAINER" + tag, spike + Vector3(0.0, 1.2, 0.0), 24, ORANGE)
	var drink_spots: Array[Vector3] = []
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			drink_spots.append(Vector3(sign_x * Layout.PIT_X, 0.0, sign_z * 13.8))
			drink_spots.append(Vector3(sign_x * 8.0, 0.0, sign_z * 52.0))
	for spot in drink_spots:
		var drink := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1.1
		drink.mesh = cylinder
		drink.material_override = _material(Color("5fe08a"))
		drink.position = spot + Vector3(0.0, 0.55, 0.0)
		add_child(drink)
		_label("ENERGY DRINK", spot + Vector3(0.0, 1.8, 0.0), 22, Color("5fe08a"))

