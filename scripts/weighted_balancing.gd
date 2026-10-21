extends "res://scripts/workout_drill.gd"
## Weighted Balancing (Stability): walk a narrow beam while a load drags you sideways. Stability sets how hard the drag is.
const BEAM_TOP := 0.4
const BEAM_LENGTH := 10.0
const BEAM_WIDTH := 0.7
var on_beam := false
var sway_time := 0.0
var sway := 0.0

func _init() -> void:
	title = "WEIGHTED BALANCING"
	subattribute = "stability"
	time_limit = 35.0
	xp_reward = 20
	hp_reward = 10.0
	zone = Rect2(-4, -13, 8, 17)

func _build_course() -> void:
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
	sway_time = 0.0
	detail = "WEIGHTED BALANCING / step onto the beam and walk to the far end, %.0f s" % time_limit

func _reset_run() -> void:
	on_beam = false
	steps_done = 0

func _tick_active(dt: float) -> void:
	var p: Vector3 = lab.player.position
	var on_top: bool = absf(p.y - BEAM_TOP) < 0.16 and absf(p.x - anchor.x) <= BEAM_WIDTH * 0.5 + 0.1 and absf(p.z - beam_center_z()) <= BEAM_LENGTH * 0.5
	if on_top and lab.player.is_on_floor():
		on_beam = true
		sway_time += dt
		sway = drag_amplitude() * sin(sway_time * 1.9) + drag_amplitude() * 0.5 * sin(sway_time * 4.3 + 1.0)
		lab.player.position.x += sway * dt
		lab.athlete.spend_resolved(float(lab.athlete.stamina_quote("drill_step").total) * dt * 0.5)
		if p.z <= anchor.z - 2.0 - BEAM_LENGTH + 0.8:
			_complete()
	elif on_beam and p.y < 0.2:
		on_beam = false
		sway_time = 0.0
		detail = "Fell off the beam / step back on"
		lab._message(detail)
