extends Node3D
## Owns map activity locations; the lab keeps its existing single-ball contact pipeline.
const Layout := preload("res://scripts/map_layout.gd")
const Drills := preload("res://scripts/map_drills.gd")
const Station := preload("res://scripts/serve_receive_station.gd")
const Transition := preload("res://scripts/transition_set_drill.gd")
const DRINK_STAMINA := 40.0
const DRINK_RESPAWN := 30.0
const DRINK_REACH := 1.8
var lab: Node3D
var courses: Array[Node3D] = []
var stations: Array[Node3D] = []
var drinks: Array = []
var locations: Array = []

func setup(host: Node3D) -> void:
	lab = host
	# Keep the first box/spike pair together for the lab's common drill interface.
	var first := Drills.new()
	add_child(first)
	first.setup(lab)
	courses.append(first)
	lab.drills = first
	for marker in Layout.drill_markers():
		match marker.type:
			"receive":
				var station := Station.new()
				add_child(station)
				station.setup(lab,marker.position-Vector3(16,0,Station.HALF))
				stations.append(station)
				locations.append({"node":station,"position":marker.position,"type":marker.type})
			"box", "spike":
				if marker.id in ["box_jump_blue","spike_0"]:
					locations.append({"node":first,"position":marker.position,"type":marker.type})
					continue
				var drill := Drills.new()
				drill.box_enabled = marker.type == "box"
				drill.spike_enabled = marker.type == "spike"
				add_child(drill)
				drill.setup(lab,{"box":marker.position-Vector3(Drills.TOWER_X,0,Drills.TOWER_Z),"spike":marker.position-Vector3(-16,0,1.5)})
				courses.append(drill)
				locations.append({"node":drill,"position":marker.position,"type":marker.type})
			"transition":
				var drill := Transition.new()
				drill.anchor = marker.position
				add_child(drill)
				drill.setup(lab)
				courses.append(drill)
				locations.append({"node":drill,"position":marker.position,"type":marker.type})
	lab.station = stations[1] # Blue east station, as before.
	lab.station_origin = lab.station.origin
	lab.box_origin = first.box_anchor
	lab.spike_origin = first.spike_anchor
	for spot in Layout.drink_positions():
		var root := Node3D.new()
		root.position = spot
		add_child(root)
		var can := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.5
		mesh.bottom_radius = 0.5
		mesh.height = 1.1
		can.mesh = mesh
		can.position.y = 0.55
		can.material_override = lab.world_builder.material(Color("5fe08a"),true)
		root.add_child(can)
		var label := Label3D.new()
		label.position.y = 1.8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 26
		label.pixel_size = 0.008
		root.add_child(label)
		drinks.append({"root":root,"can":can,"label":label,"remaining":0.0})
	tick(0)

func select_nearby() -> void:
	if lab.ball_active or lab.station.running() or lab.drills.running(): return
	# Let an active tower record failure before switching away from it.
	if lab.drills.box_state == Drills.State.ACTIVE: return
	for course in courses: course.interaction_enabled = true
	var closest: Dictionary = {}
	var distance := INF
	for location in locations:
		var candidate: Node3D = location.node
		var inside: bool = candidate.in_zone()
		if location.type == "box": inside = candidate.in_box_zone()
		if location.type == "spike": inside = candidate.in_spike_zone()
		var next: float = lab.player.position.distance_squared_to(location.position)
		if inside and next < distance:
			closest = location
			distance = next
	if closest.is_empty(): return
	for course in courses: course.interaction_enabled = closest.type != "receive" and course == closest.node
	if closest.type == "receive": lab.station = closest.node
	else: lab.drills = closest.node

func nearby_drink() -> int:
	var best := -1
	var distance := DRINK_REACH
	for i in range(drinks.size()):
		var delta: float = lab.player.position.distance_to(drinks[i].root.position)
		if delta < distance:
			distance = delta
			best = i
	return best

func consume_nearby() -> bool:
	var index := nearby_drink()
	if index < 0: return false
	var drink: Dictionary = drinks[index]
	if drink.remaining > 0:
		lab._message("Energy Drink replenishes in %ds"%ceili(drink.remaining))
	elif lab.athlete.exhausted:
		lab._message("Exhausted / Stamina recovery resumes when the lock ends; drink remains available")
	elif lab.athlete.stamina >= lab.athlete.max_stamina():
		lab._message("Stamina full / Energy Drink remains available")
	else:
		var restored: float = minf(DRINK_STAMINA,lab.athlete.max_stamina()-lab.athlete.stamina)
		lab.athlete.stamina += restored
		drink.remaining = DRINK_RESPAWN
		lab._message("Energy Drink / +%.0f Stamina"%restored)
	return true

func tick(dt: float) -> void:
	for course in courses:
		if course.has_method("tick_setup"): course.tick_setup(dt)
	for drink in drinks:
		drink.remaining = maxf(0,drink.remaining-dt)
		drink.can.visible = drink.remaining <= 0
		var text := "ENERGY DRINK / I / +40 STA" if drink.remaining <= 0 else "ENERGY DRINK / %ds"%ceili(drink.remaining)
		if drink.label.text != text: drink.label.text = text

func reset() -> void:
	for course in courses:
		course.reset()
		if course.box_enabled: course._build_attack_decks()
	for station in stations: station.reset()
	if is_instance_valid(lab.pepper):
		lab.pepper.move_home(0,courses[0].course_top_world(2))
