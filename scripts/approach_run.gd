class_name ApproachRun
extends RefCounted

const DURATION := 1.08
# A deliberate long stride, a quick short stride, a sharper inward closing
# stride, then the launch. The last phase has no forward ground travel.
const STEP_ENDS := [0.50, 0.72, 0.91, 1.0]
const LAUNCH_START := 0.91
const STEP_NAMES := ["1 / LONG RIGHT BOUND", "2 / SHORT LEFT STEP", "3 / SHORT INWARD RIGHT PLANT", "4 / UPWARD LAUNCH"]
const LEAD_FOOT := 1 # Right foot for now; handedness inversion is deferred.

static func step_index(progress: float) -> int:
	for step in range(4):
		if progress < STEP_ENDS[step]:
			return step
	return 3

static func step_phase(progress: float) -> float:
	var step := step_index(progress)
	var start: float = 0.0 if step == 0 else STEP_ENDS[step - 1]
	return clampf((progress - start) / (float(STEP_ENDS[step]) - start), 0.0, 1.0)

static func lead_foot(step: int) -> int:
	return LEAD_FOOT if step % 2 == 0 else 1 - LEAD_FOOT

static func foot_lateral(step: int) -> float:
	return [0.14, -0.14, 0.055, 0.0][step]

static func foot_turn(step: int) -> float:
	return deg_to_rad(14.0) if step == 2 else 0.0

static func speed_scale(progress: float) -> float:
	var step := step_index(progress)
	if step == 3:
		return 0.0
	var phase := step_phase(progress)
	var load: float = [0.22, 0.08, 0.03][step]
	var idle: float = [0.05, 0.03, 0.02][step]
	if phase < load:
		return idle
	var pulse := maxf(0.0, sin((phase - load) / (1.0 - load) * PI))
	var shape: float = [0.80, 1.0, 1.4][step]
	return idle + pow(pulse, shape) * [1.18, 0.88, 0.72][step]

static func dive_quality(progress: float) -> float:
	return clampf(1.0 - absf(progress - 0.16) / 0.20, 0.0, 1.0)

static func jump_factor(action: int, progress: float) -> float:
	if action == 2:
		return lerpf(0.60, 1.20, smoothstep(0.35, LAUNCH_START, progress))
	return 0.88
