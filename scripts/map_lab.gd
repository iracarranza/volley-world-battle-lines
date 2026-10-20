extends "res://scripts/contact_lab.gd"

# The map graybox: the Contact Lab itself, hosted on the planned map. Everything the lab has stays live -- the athlete, creator and builds,
# movement, jumps and approaches, actions, the Moment of Contact, bots, Peppers, Serves, Drills, Bench, HUD -- and only the world under
# it changes: the lab's blockout lanes and bases are replaced by the map (scripts/map_world.gd), the lab's court and Net at the origin
# is the Middle Net, and the three Drills sit on the map.
#
# Primary Nets 1–3 host the shared live rally. Pit Nets remain traversal blockout only.
const Layout := preload("res://scripts/map_layout.gd")
const World := preload("res://scripts/map_world.gd")
# Where each lab Drill sits, as the offset from the coordinates it is written in. The tower comes out at (-46, 22) beside the top
# lane, the Spike Trainer in the open floor outside the bottom lane, and the Serve Receive station in the east Blue jungle sector.
const BOX_ANCHOR := Vector3(-10.0, 0.0, 18.0)
const SPIKE_ANCHOR := Vector3(63.0, 0.0, 16.0)
const STATION_ANCHOR := Vector3(2.0, 0.0, 23.0)
const EAST_BLUE_SECTOR := 1

var map_world: Node3D
var overview_camera: Camera3D
var overview := false
var zone_label: Label

# Map play retains one live ball/rally, with an explicit primary-court context.
var primary_nets: Array = [Layout.net_by_id("top"),Layout.net_by_id("middle"),Layout.net_by_id("bottom")]
var primary_bodies: Array[StaticBody3D] = []

var primary_responses: Array = []

func _init() -> void:
	start_position = Vector3(0.0, 0.03, Layout.BASE_Z)
	box_origin = BOX_ANCHOR
	spike_origin = SPIKE_ANCHOR
	station_origin = STATION_ANCHOR

func _ready() -> void:
	super._ready()
	select_net(1)
	# The overview camera was added first, so Godot made it current; the athlete's camera is the one to start on.
	overview_camera.current = false
	camera.current = true

func _build_lanes_and_bases() -> void:
	map_world = World.new()
	map_world.options = {
		"floor": false,
		"hosted": true,
		"skip_nets": ["top","middle","bottom"],
		"skip_sectors": [EAST_BLUE_SECTOR],
		"skip_markers": ["box_jump_blue", "transition_set_blue"],
	}
	add_child(map_world)
	map_world.build()
	overview_camera = Camera3D.new()
	overview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview_camera.size = Layout.HALF * 2.15
	overview_camera.position = Vector3(0.0, 120.0, 0.0)
	overview_camera.far = 400.0
	add_child(overview_camera)
	overview_camera.look_at(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))

func _build_ui() -> void:
	super._build_ui()
	var layer := CanvasLayer.new()
	add_child(layer)
	zone_label = Label.new()
	zone_label.position = Vector2(18.0, 126.0)
	zone_label.add_theme_font_size_override("font_size", 16)
	zone_label.add_theme_color_override("font_color", TEAL)
	layer.add_child(zone_label)

func _process(dt: float) -> void:
	super._process(dt)
	if zone_label != null and player != null:
		var p: Vector3 = player.global_position
		zone_label.visible = hud.ui.visible
		zone_label.text = "MAP / NET %d · %s   x %.0f  z %.0f%s" % [current_net+1,Layout.zone_at(p), p.x, p.z, "   (N: back to the athlete)" if overview else "   (N: overview)"]
		var nearby := nearby_bot()
		if nearby >= 0:
			zone_label.text += "   [I] BOT #%d SETTINGS" % (nearby+1)

func _physics_process(dt: float) -> void:
	if not ball_active and not station.running() and not drills.running():
		select_net(nearest_primary_net())
	super._physics_process(dt)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		overview = not overview
		overview_camera.current = overview
		if not overview and camera != null:
			camera.current = true
		return
	super._unhandled_input(event)

func bot_courts() -> Dictionary:
	var result := {}
	for index in range(primary_nets.size()): result[index] = primary_nets[index]
	return result

func _create_training_bots() -> Node3D:
	return preload("res://scripts/map_bot_roster.gd").new()

func build_net_visuals() -> void:
	for index in range(primary_nets.size()):
		primary_nets[index]["index"] = index
		var response := NetResponse.new()
		response.origin = primary_nets[index].position
		response.height_offset = float(primary_nets[index].height)-2.43
		response.web_half_width = float(primary_nets[index].width)/2
		response.tape_half_width = response.web_half_width+0.25
		primary_responses.append(response)
		primary_bodies.append(preload("res://scripts/primary_net_world.gd").build(self,primary_nets[index]))
	net_body = primary_bodies[1]
	net_response = primary_responses[1]

func build_net_colliders() -> void:
	pass # Built together with the corresponding visible map net.

func net_collision_rids() -> Array[RID]:
	var result: Array[RID] = []
	for body in primary_bodies: result.append(body.get_rid())
	return result

func nearest_primary_net() -> int:
	var best := 1
	var distance := INF
	for index in range(primary_nets.size()):
		var next: float = player.position.distance_squared_to(primary_nets[index].position)
		if next < distance:
			distance = next
			best = index
	return best

func select_net(index: int) -> void:
	if index == current_net and court_center == primary_nets[index].position and is_equal_approx(net_height,float(primary_nets[index].height)):
		return
	current_net = index
	var net: Dictionary = primary_nets[index]
	court_center = net.position
	net_height = net.height
	court_half_width = float(net.width)/2
	court_half_depth = float(net.depth)/2
	net_body = primary_bodies[index]
	clear_net_responses()
	net_response = primary_responses[index]
	training_bots.current_net = index
	training_bots.reset()
	training_bots.set_target = training_bots.set_targets.get(index,court_center+Vector3(0,3.8,1.7))
	training_bots.set_target_locked = training_bots.set_targets.has(index)
	_resize_court()

func prepare_serve_context() -> void:
	if not ball_active: select_net(nearest_primary_net())

func _resize_court() -> void:
	var net: Dictionary = primary_nets[current_net]
	court_half_width = float(net.width)/2
	court_half_depth = float(net.depth)/2
	var x: float = net.position.x
	_draw_line(court_outline,[Vector3(x-court_half_width,0.045,-court_half_depth),Vector3(x+court_half_width,0.045,-court_half_depth),Vector3(x+court_half_width,0.045,court_half_depth),Vector3(x-court_half_width,0.045,court_half_depth),Vector3(x-court_half_width,0.045,-court_half_depth)])

func open_bot_menu() -> bool:
	if bot_menu == null:
		bot_menu = preload("res://scripts/map_bot_menu.gd").new(hud)
	bot_menu.toggle()
	return true

func nearby_bot() -> int:
	var closest := -1
	var distance := 2.2
	for slot in range(training_bots.actors.size()):
		if not training_bots.settings[slot].enabled: continue
		var next: float = player.position.distance_to(training_bots.actors[slot].position)
		if next < distance:
			distance = next
			closest = slot
	return closest

func interact_nearby_bot() -> bool:
	var closest := nearby_bot()
	if closest < 0: return false
	if bot_menu == null: bot_menu = preload("res://scripts/map_bot_menu.gd").new(hud)
	bot_menu.open_bot(closest)
	return true

func uses_legacy_bot_pads() -> bool:
	return false

func clear_net_responses() -> void:
	for response in primary_responses: response.clear()

func resolve_ball_net(previous: Vector3,dt: float) -> Dictionary:
	for response in primary_responses:
		var left: float = response.origin.x-response.tape_half_width-NetResponse.RADIUS
		var right: float = response.origin.x+response.tape_half_width+NetResponse.RADIUS
		if response.pocket or (minf(previous.x,ball.position.x) <= right and maxf(previous.x,ball.position.x) >= left):
			return response.step(previous,ball.position,ball_velocity,dt,float(ball_shot.get("charge",0)))
	return super.resolve_ball_net(previous,dt)

func athlete_touches_net(from: Vector3,to: Vector3,height: float = 1.7,radius: float = NetResponse.MIDLINE_RADIUS) -> bool:
	for response in primary_responses:
		if response.touches_body(from,to,height,radius): return true
	return false
