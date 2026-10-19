extends Node3D

# The plain traversal scene: the map's geometry and a bare walking body, nothing else and nothing shared with the Contact Lab.
# The primary graybox is the lab-hosted one (map_graybox.tscn, scripts/map_lab.gd); this one stays for quick geometry checks and tests.
const Layout := preload("res://scripts/map_layout.gd")
const World := preload("res://scripts/map_world.gd")
const Player := preload("res://scripts/graybox_player.gd")
const TEAL := Color("54ead0")
const GOLD := Color("ffce73")

var world: Node3D
var player: CharacterBody3D
var overview_camera: Camera3D
var overview := false
var team := "blue"
var spawn_index := 2
var hud: Label
var help: Label

func _ready() -> void:
	world = World.new()
	add_child(world)
	world.build()
	_build_player()
	_build_ui()
	respawn()

# --- Player, camera and HUD -----------------------------------------------------------------------------

func _build_player() -> void:
	player = Player.new()
	add_child(player)
	overview_camera = Camera3D.new()
	overview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	overview_camera.size = Layout.HALF * 2.15
	overview_camera.position = Vector3(0.0, 120.0, 0.0)
	overview_camera.far = 400.0
	add_child(overview_camera)
	overview_camera.look_at(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16.0, 12.0)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", TEAL)
	layer.add_child(hud)
	help = Label.new()
	help.position = Vector2(16.0, 84.0)
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", GOLD)
	help.text = "WASD move   Shift sprint   hold Space to charge, release to jump   mouse look (click to capture, Esc to release)\nV overview   R respawn   1 Blue base   2 Red base   G mobility jump   H hide this"
	layer.add_child(help)

func respawn() -> void:
	var spots := Layout.spawns(team)
	player.place(spots[spawn_index], 0.0 if team == "blue" else PI)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_V:
			overview = not overview
			overview_camera.current = overview
			player.camera.current = not overview
		KEY_R:
			respawn()
		KEY_1:
			team = "blue"
			respawn()
		KEY_2:
			team = "red"
			respawn()
		KEY_H:
			help.visible = not help.visible

func _process(_delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var state := "AIR" if not player.is_on_floor() else ("CHARGING %.0f%%" % (100.0 * minf(1.0, player.charge / player.CHARGE_TIME)) if player.charge >= 0.0 else ("SPRINT" if player.sprinting else "ON FOOT"))
	hud.text = "%s\nx %.1f   y %.2f   z %.1f   speed %.1f m/s   %s   mobility jump: %s" % [Layout.zone_at(player.global_position), player.global_position.x, player.global_position.y, player.global_position.z, speed, state, "ON" if player.mobility else "off"]
