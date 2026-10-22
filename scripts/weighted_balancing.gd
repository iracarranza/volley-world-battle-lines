extends "res://scripts/workout_drill.gd"
## Weighted Balancing (Stability): walk a narrow beam while a load drags you sideways. Stability sets how hard the drag is.
const BEAM_TOP := 0.4
const BEAM_LENGTH := 10.0
const BEAM_WIDTH := 0.7
var on_beam := false
var sway_time := 0.0
var sway := 0.0
var lean := 0.0
var lean_speed := 0.0
var gust := 0.0
var gust_clock := 0.0
var rng := RandomNumberGenerator.new()
var weights: Array[MeshInstance3D] = []

func _init() -> void:
	title = "WEIGHTED BALANCING"
	subattribute = "stability"
	time_limit = 35.0
	xp_reward = 20
	hp_reward = 10.0
	zone = Rect2(-4, -13, 8, 17)

func _build_course() -> void:
	rng.randomize()
	for i in range(2):
		var weight: MeshInstance3D = lab.world_builder.box(self, Vector3(0.22, 0.32, 0.22), anchor, Color("3b414c"))
		weight.visible = false
		weights.append(weight)
	lab.world_builder.box(self, Vector3(8, 0.03, 17), anchor + Vector3(0, -0.015, -4.5), Color("3b3a45"))
	one_way.append(_add_deck(self, anchor + Vector3(0, BEAM_TOP, -2.0 - BEAM_LENGTH * 0.5), Vector2(BEAM_WIDTH, BEAM_LENGTH), Color("77708a")))
	lab.world_builder.world_label("WALK THE BEAM TO THE FAR END / STABILITY", anchor + Vector3(0, 0.15, 3.2), 22, Color("c9b8ff"))

# Peak sideways drag in m/s: strong for a 50, mild for a 99.
func drag_amplitude() -> float:
	var rating: float = preload("res://scripts/stat_tuning.gd").rating(lab.athlete.build, "stability")
	return lerpf(1.6, 0.5, clampf((rating - 50.0) / 49.0, 0.0, 1.0))

func beam_center_z() -> float:
	return anchor.z - 2.0 - BEAM_LENGTH * 0.5

func _begin_run() -> void:
	on_beam = false
	steps_done = 0
	sway_time = rng.randf_range(0, TAU)
	lean = 0.0
	lean_speed = 0.0
	detail = "WEIGHTED BALANCING / step onto the beam and walk to the far end, %.0f s" % time_limit

func _reset_run() -> void:
	on_beam = false
	steps_done = 0
	lean = 0.0
	lean_speed = 0.0
	for weight in weights: weight.visible = false

func _tick_active(dt: float) -> void:
	var p: Vector3 = lab.player.position
	var on_top: bool = absf(p.y - BEAM_TOP) < 0.16 and absf(p.x - anchor.x) <= BEAM_WIDTH * 0.5 + 0.1 and absf(p.z - beam_center_z()) <= BEAM_LENGTH * 0.5
	if on_top and lab.player.is_on_floor():
		on_beam = true
		sway_time += dt
		gust_clock -= dt
		if gust_clock <= 0.0:
			gust = rng.randf_range(-1.0, 1.0)
			gust_clock = rng.randf_range(0.35, 1.1)
		sway = drag_amplitude() * (sin(sway_time * 1.9) * 0.5 + gust)
		var counter: float = lab.directional_input.value().x
		lean_speed += (sway + lean * 1.4 + counter * 3.5 - lean_speed * 1.8) * dt
		lean += lean_speed * dt
		lab.player.position.x += lean * dt
		if absf(lean) > 0.65:
			lab.player.position.x = anchor.x + signf(lean) * (BEAM_WIDTH + 0.3)
			detail = "Lost balance / step back onto the beam"
			on_beam = false
			lean = 0.0
			lean_speed = 0.0
			return
		lab.athlete.spend_resolved(float(lab.athlete.stamina_quote("drill_step").total) * dt * 0.5)
		if p.z <= anchor.z - 2.0 - BEAM_LENGTH + 0.8:
			_complete()
	elif on_beam and p.y < 0.2:
		on_beam = false
		sway_time = 0.0
		lean = 0.0
		lean_speed = 0.0
		detail = "Fell off the beam / step back on"
		lab._message(detail)

func apply_drill_pose() -> void:
	var active := running() and on_beam
	for weight in weights: weight.visible = active
	if not active: return
	lab.body.rotation.z = -lean
	for i in range(lab.arms.size()):
		var arm: Node3D = lab.arms[i]
		arm.rotation = Vector3(0, 0, PI / 2 * (-1 if i == 0 else 1))
		arm.get_node("Elbow").rotation.x = -0.08
		var elbow: Node3D = arm.get_node("Elbow")
		weights[i].global_position = elbow.get_node("Wrist").global_position
		weights[i].global_rotation = Vector3(0, 0, -lean * 0.4)

# On the beam lateral input chiefly shifts the load; small foot corrections remain.
func terrain_motion(_dt: float, _move: Vector3, _sprint: bool) -> void:
	if running() and on_beam:
		lab.player.velocity.x *= 0.15

func hud_text() -> String:
	return "%s\nLEAN %.0f%% / A-D COUNTERBALANCE" % [super.hud_text(), absf(lean) / 0.65 * 100]
