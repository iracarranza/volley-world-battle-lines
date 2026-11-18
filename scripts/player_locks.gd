extends RefCounted
## MS-10 read-only locks facade (T-LK, interim: G-09 relocation is MS-12). Lock state still lives in the animation controller; readers ask here, so the
## move later changes one file. Nothing here writes.
static func input_locked(lab) -> bool:
	return lab.animation.roll_lock > 0.0 or lab.animation.dive_input_locked() or lab.animation.floor_input_locked()

static func recovering(lab) -> bool:
	return lab.animation.roll_lock > 0.0 or lab.animation.dive_recovery_time >= 0.0 or lab.animation.floor_recovery_time >= 0.0

static func recovery(lab) -> Dictionary:
	return {"roll": lab.animation.roll_lock, "dive": lab.animation.dive_recovery_time, "floor": lab.animation.floor_recovery_time,
		"input_locked": input_locked(lab)}
