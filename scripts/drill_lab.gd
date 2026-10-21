extends "res://scripts/contact_lab.gd"
## The Drill Lab: every Workout and Setup lined up in one row, with ball bins beside the Setups. It is the Contact Lab underneath (athlete,
## builds, movement, actions, Stamina), with the ball economy on so the Setups behave as they do on the map.
const Row := preload("res://scripts/drill_row.gd")
var activities: Node3D

func _init() -> void:
	start_position = Vector3(0.0, 0.03, Row.LINE_Z + 5.0)

func world_half_extent() -> float:
	return 110.0

func bench_home() -> Vector3:
	return Vector3(0, 0.03, Row.LINE_Z + 12.0)

func pepper_spots() -> Array:
	return [Vector3(0, 0, 8), Vector3(10, 0, 8), Vector3(-10, 0, 8)]

func _build_lanes_and_bases() -> void:
	world_builder.box(self, Vector3(Row.SPACING * Row.NAMES.size() + 8.0, 0.015, 26.0), Vector3(0, -0.015, Row.LINE_Z - 4.0), Color("223c45"))
	world_builder.world_label("DRILL LAB / WORKOUTS 1-4 / SETUPS 5-8", Vector3(0, 0.03, Row.LINE_Z + 11.0), 44, GOLD)

func _build_activities() -> void:
	activities = Row.new()
	add_child(activities)
	activities.setup(self)
	ball_carts = preload("res://scripts/ball_bin.gd").new()
	ball_carts.spots = activities.bin_spots()
	add_child(ball_carts)
	ball_carts.setup(self)
	inventory.enabled = true
	inventory.give()

func _physics_process(dt: float) -> void:
	if is_instance_valid(activities) and not paused:
		activities.select_nearby()
		activities.tick(dt)
	if is_instance_valid(ball_carts) and not paused:
		ball_carts.tick(dt)
	super._physics_process(dt)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I and not paused:
		activities.select_nearby()
		if activities.consume_nearby(): return
	super._unhandled_input(event)

func _reset() -> void:
	super._reset()
	if is_instance_valid(activities): activities.reset()
