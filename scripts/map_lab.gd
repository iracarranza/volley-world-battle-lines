extends "res://scripts/contact_lab.gd"

# The map graybox: the Contact Lab itself, hosted on the planned map. Everything the lab has stays live -- the athlete, creator and builds,
# movement, jumps and approaches, actions, the Moment of Contact, bots, Peppers, Serves, Drills, Bench, HUD -- and only the world under
# it changes: the lab's blockout lanes and bases are replaced by the map (scripts/map_world.gd), the lab's court and Net at the origin
# is the Middle Net, and the three Drills sit on the map.
#
# Not live yet: Rallies and Serves work only at the Middle Net, because the lab's rules are still written around one Net at the origin.
# The top, bottom and Pit Nets are real walls with their own court sizes and heights, but nothing happens at them.
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

func _init() -> void:
	start_position = Vector3(0.0, 0.03, Layout.BASE_Z)
	box_origin = BOX_ANCHOR
	spike_origin = SPIKE_ANCHOR
	station_origin = STATION_ANCHOR

func _ready() -> void:
	super._ready()
	# The overview camera was added first, so Godot made it current; the athlete's camera is the one to start on.
	overview_camera.current = false
	camera.current = true

func _build_lanes_and_bases() -> void:
	map_world = World.new()
	map_world.options = {
		"floor": false,
		"hosted": true,
		"skip_nets": ["middle"],
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
		zone_label.text = "MAP  %s   x %.0f  z %.0f%s" % [Layout.zone_at(p), p.x, p.z, "   (N: back to the athlete)" if overview else "   (N: overview)"]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		overview = not overview
		overview_camera.current = overview
		if not overview and camera != null:
			camera.current = true
		return
	super._unhandled_input(event)
