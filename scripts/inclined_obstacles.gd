extends "res://scripts/workout_drill.gd"
## Inclined Obstacles (Explosiveness): a rising run of platforms, each higher than the last, taken in order under a timer.
const HEIGHTS := [0.35, 0.55, 0.75, 0.95]

func _init() -> void:
	title = "INCLINED OBSTACLES"
	subattribute = "explosiveness"
	time_limit = 25.0
	xp_reward = 20
	hp_reward = 10.0
	zone = Rect2(-4, -13.5, 8, 17)

func _build_course() -> void:
	lab.world_builder.box(self, Vector3(8, 0.03, 17), anchor + Vector3(0, -0.015, -5), Color("3d3a34"))
	for i in range(HEIGHTS.size()):
		_add_step(anchor + Vector3(0, HEIGHTS[i], -2.2 - 2.9 * i), Vector2(3.0, 2.0), Color("6b5a44"))
	lab.world_builder.world_label("JUMP ONTO 1-4 IN ORDER / EXPLOSIVENESS", anchor + Vector3(0, 0.15, 3.2), 22, Color("ffb46e"))

func _begin_run() -> void:
	steps_done = 0
	detail = "INCLINED OBSTACLES / land on 1 to 4 in order, %.0f s" % time_limit

func _tick_active(_dt: float) -> void:
	if _step_tick(title):
		_complete()
