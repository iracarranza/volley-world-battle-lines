extends "res://scripts/map_activities.gd"
## The Drill Lab's drills in one row, every Workout and Setup: the lab drives them exactly as the map does (MapActivities), only the placement differs.
## West to east: Inclined Obstacles, Salmon Ladder, Box Parkour, Weighted Balancing | Spike Trainer, Serve Machine, Balance Ball Setting, Transition Set.
const InclinedObstacles := preload("res://scripts/inclined_obstacles.gd")
const SalmonLadder := preload("res://scripts/salmon_ladder.gd")
const WeightedBalancing := preload("res://scripts/weighted_balancing.gd")
const BalanceBall := preload("res://scripts/balance_ball_setting.gd")
const SPACING := 20.0
const LINE_Z := 40.0
const NAMES := ["inclined_obstacles", "salmon_ladder", "box_parkour", "weighted_balancing", "spike_trainer", "serve_machine", "balance_ball_setting", "transition_set"]
var by_name := {}

static func slot_x(index: int) -> float:
	return (float(index) - float(NAMES.size() - 1) * 0.5) * SPACING

func setup(host: Node3D) -> void:
	lab = host
	for index in range(NAMES.size()):
		_place(index, slot_x(index))
	lab.drills = by_name["box_parkour"] # any course will do until the player walks up to one
	lab.station = by_name["serve_machine"]
	lab.station_origin = lab.station.origin
	lab.box_origin = by_name["box_parkour"].box_anchor
	lab.spike_origin = by_name["spike_trainer"].spike_anchor
	for index in range(NAMES.size()):
		var label: Label3D = lab.world_builder.world_label("%d  %s" % [index + 1, String(NAMES[index]).replace("_", " ").to_upper()], Vector3(slot_x(index), 0.05, LINE_Z + 6.5), 34, lab.GOLD)
		label.rotation_degrees.x = -90
	tick(0.0)

func _workout(drill: Node3D, key: String, x: float) -> void:
	drill.anchor = Vector3(x, 0.0, LINE_Z)
	add_child(drill)
	drill.setup(lab)
	_register(key, drill, "workout", drill.anchor)

func _register(key: String, node: Node3D, type: String, at: Vector3) -> void:
	by_name[key] = node
	if node is Node3D and node.has_method("tick_setup") and type != "receive":
		courses.append(node)
	locations.append({"node": node, "position": at, "type": type})

func _place(index: int, x: float) -> void:
	match String(NAMES[index]):
		"inclined_obstacles": _workout(InclinedObstacles.new(), "inclined_obstacles", x)
		"salmon_ladder": _workout(SalmonLadder.new(), "salmon_ladder", x)
		"weighted_balancing": _workout(WeightedBalancing.new(), "weighted_balancing", x)
		"box_parkour":
			var drill := Drills.new()
			drill.spike_enabled = false
			add_child(drill)
			drill.setup(lab, {"box": Vector3(x - Drills.TOWER_X, 0.0, LINE_Z - 16.0), "spike": Vector3.ZERO})
			_register("box_parkour", drill, "box", Vector3(x, 0.0, LINE_Z - 8.0))
		"spike_trainer":
			var drill := Drills.new()
			drill.box_enabled = false
			add_child(drill)
			drill.setup(lab, {"box": Vector3.ZERO, "spike": Vector3(x, 0.0, LINE_Z - 3.5) - Drills.SPIKE_REFERENCE})
			_register("spike_trainer", drill, "spike", Vector3(x, 0.0, LINE_Z))
		"serve_machine":
			var station := Station.new()
			add_child(station)
			station.setup(lab, Vector3(x - 16.0, 0.0, LINE_Z - 6.5))
			stations.append(station)
			by_name["serve_machine"] = station
			locations.append({"node": station, "position": Vector3(x, 0.0, LINE_Z), "type": "receive"})
		"balance_ball_setting":
			var drill := BalanceBall.new()
			drill.anchor = Vector3(x, 0.0, LINE_Z - 4.0)
			add_child(drill)
			drill.setup(lab)
			_register("balance_ball_setting", drill, "setup", drill.anchor)
		"transition_set":
			var drill := Transition.new()
			drill.anchor = Vector3(x, 0.0, LINE_Z - 4.0)
			add_child(drill)
			drill.setup(lab)
			_register("transition_set", drill, "setup", drill.anchor)

func bin_spots() -> Array:
	var spots: Array = []
	for index in [4, 6, 7]:
		spots.append(Vector3(slot_x(index) - 4.5, 0.0, LINE_Z + 2.0))
	spots.append(Vector3(slot_x(5) - 4.5, 0.0, LINE_Z + 2.0))
	return spots

func reset() -> void:
	for course in courses:
		course.reset()
		if course.box_enabled: course._build_attack_decks()
	for station in stations: station.reset()
