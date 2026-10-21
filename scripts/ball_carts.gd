extends Node3D
## Net ball carts: two per team per lane Net, one beside each antenna on that team's side, 12 in all. Each holds up to five balls and is refilled
## on a fixed clock that ignores whether it was emptied; the hovering ring fills as the next refill approaches. Players take one ball per use
## (anyone may take from any cart) and cannot put balls back. A team whose carts at a Net are both empty leaves that Net open to be scored on.
const Layout := preload("res://scripts/map_layout.gd")
const CAPACITY := 5
const REFILL_SECONDS := 180.0
const REACH := 2.2
const SIDE_OFFSET := 1.1 # metres outside the antenna
const ENDS_Z := 1.6      # metres from the Net line, on the team's own side
var lab: Node3D
var carts: Array[Dictionary] = []
var clock := 0.0
var _redraw := 0.0

func setup(host: Node3D) -> void:
	lab = host
	for lane in Layout.lane_ids():
		var net: Dictionary = Layout.net_by_id(lane)
		for team in ["blue", "red"]:
			var z := ENDS_Z if team == "blue" else -ENDS_Z
			for side in [-1.0, 1.0]:
				var x: float = float(net.position.x) + side * (float(net.width) * 0.5 + SIDE_OFFSET)
				_add(lane, team, Vector3(x, 0.0, z))
	tick(0.0)

func _add(lane: String, team: String, at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var colour := Color("5fa8ff") if team == "blue" else Color("ff7a6e")
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.5, 0.8)
	body.mesh = box
	body.position.y = 0.45
	body.material_override = lab.world_builder.material(colour, true)
	root.add_child(body)
	var balls_root := Node3D.new()
	root.add_child(balls_root)
	for slot in range(CAPACITY):
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		ball.mesh = sphere
		ball.position = Vector3(-0.42 + 0.21 * slot, 0.84, 0.0)
		ball.material_override = lab.world_builder.material(Color("f5f0dc"), true)
		balls_root.add_child(ball)
	var ring := MeshInstance3D.new()
	ring.mesh = ImmediateMesh.new()
	ring.position.y = 1.7
	ring.material_override = lab.world_builder.material(colour, true)
	root.add_child(ring)
	var label := Label3D.new()
	label.position.y = 2.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.pixel_size = 0.008
	root.add_child(label)
	carts.append({"root": root, "lane": lane, "team": team, "balls": CAPACITY, "ball_nodes": balls_root, "ring": ring, "label": label})

func tick(dt: float) -> void:
	clock += dt
	if clock >= REFILL_SECONDS:
		clock = fmod(clock, REFILL_SECONDS)
		for cart in carts:
			cart.balls = CAPACITY # refilled even when some balls remain: the clock ignores emptying
	_redraw -= dt
	if _redraw <= 0.0:
		_redraw = 0.2
		_refresh_visuals()

func fill_fraction() -> float:
	return clampf(clock / REFILL_SECONDS, 0.0, 1.0)

func _refresh_visuals() -> void:
	var fraction := fill_fraction()
	for cart in carts:
		var nodes: Node3D = cart.ball_nodes
		for slot in range(nodes.get_child_count()):
			nodes.get_child(slot).visible = slot < int(cart.balls)
		var label: Label3D = cart.label
		var text := "BALLS %d/%d  /  I" % [int(cart.balls), CAPACITY] if int(cart.balls) > 0 else "EMPTY"
		if label.text != text:
			label.text = text
		_draw_ring(cart.ring.mesh, fraction)

# A filling ring: an arc from the top, clockwise, covering `fraction` of the circle.
func _draw_ring(mesh: ImmediateMesh, fraction: float) -> void:
	mesh.clear_surfaces()
	var steps := maxi(2, int(ceil(48.0 * fraction)))
	if fraction <= 0.0:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for step in range(steps + 1):
		var angle := TAU * fraction * float(step) / float(steps)
		var direction := Vector3(sin(angle), 0.0, -cos(angle))
		mesh.surface_add_vertex(direction * 0.34)
		mesh.surface_add_vertex(direction * 0.46)
	mesh.surface_end()

# The nearest cart with a ball within reach of `point`, or -1.
func nearest_with_ball(point: Vector3) -> int:
	var best := -1
	var best_distance := REACH
	for index in range(carts.size()):
		if int(carts[index].balls) <= 0:
			continue
		var distance: float = Vector2(point.x - carts[index].root.global_position.x, point.z - carts[index].root.global_position.z).length()
		if distance <= best_distance:
			best = index
			best_distance = distance
	return best

# One ball per use. The cart is remembered on the inventory, so a ball an opponent wastes can return to it.
func take_nearby(point: Vector3) -> bool:
	var index := nearest_with_ball(point)
	if index < 0:
		return false
	carts[index].balls = int(carts[index].balls) - 1
	lab.inventory.origin_cart = index
	_refresh_visuals()
	return true

func give_back(index: int) -> void:
	if index >= 0 and index < carts.size():
		carts[index].balls = mini(CAPACITY, int(carts[index].balls) + 1)
		_refresh_visuals()

func team_empty(lane: String, team: String) -> bool:
	var found := false
	for cart in carts:
		if cart.lane == lane and cart.team == team:
			found = true
			if int(cart.balls) > 0:
				return false
	return found

func total_balls() -> int:
	var total := 0
	for cart in carts:
		total += int(cart.balls)
	return total
