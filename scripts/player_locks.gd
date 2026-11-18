extends RefCounted
const LockData := preload("res://scripts/lock_data.gd")
## Locks facade (T-LK). MS-12: durations and predicates are `lock_data.gd` (tunable data); the countdown clocks stay with the pose clocks in the animation
## controller (tests and traces read them there). Readers ask here. Nothing here writes.
static func input_locked(lab) -> bool:
	return lab.animation.roll_lock > 0.0 or LockData.dive_locked(lab.animation.dive_recovery_time, lab.animation.dive_quality_value) or LockData.floor_locked(lab.animation.floor_recovery_time, lab.animation.floor_recovery_lock)

static func recovering(lab) -> bool:
	return lab.animation.roll_lock > 0.0 or lab.animation.dive_recovery_time >= 0.0 or lab.animation.floor_recovery_time >= 0.0

static func recovery(lab) -> Dictionary:
	return {"roll": lab.animation.roll_lock, "dive": lab.animation.dive_recovery_time, "floor": lab.animation.floor_recovery_time,
		"input_locked": input_locked(lab)}
