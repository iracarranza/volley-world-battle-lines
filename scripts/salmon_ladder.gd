extends "res://scripts/workout_drill.gd"
## Salmon Ladder (Work Rate): a tall zig-zag of rungs; every jump costs Stamina, so pace decides whether the top is reached.
const RISE := 0.5
const RUNGS := 6

func _init() -> void:
	title = "SALMON LADDER"
	subattribute = "work_rate"
	time_limit = 40.0
	xp_reward = 25
	hp_reward = 12.0
	zone = Rect2(-4, -16, 8, 20)

func _build_course() -> void:
	lab.world_builder.box(self, Vector3(8, 0.03, 20), anchor + Vector3(0, -0.015, -6), Color("343b45"))
	for i in range(RUNGS):
		var side: float = -1.1 if i % 2 == 0 else 1.1
		_add_step(anchor + Vector3(side, RISE * (i + 1), -2.0 - 2.3 * i), Vector2(1.7, 1.7), Color("4d6075"))
	lab.world_builder.world_label("CLIMB RUNGS 1-%d, ALTERNATING SIDES / WORK RATE" % RUNGS, anchor + Vector3(0, 0.15, 3.2), 22, Color("9bc4ff"))

func _begin_run() -> void:
	steps_done = 0
	detail = "SALMON LADDER / climb %d rungs, %.0f s, every jump costs Stamina" % [RUNGS, time_limit]

func _tick_active(_dt: float) -> void:
	if _step_tick(title):
		_complete()
