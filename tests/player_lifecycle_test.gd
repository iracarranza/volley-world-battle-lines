extends "res://tests/support/test_case.gd"
## MS-10: the lifecycle table, the derived phase, the operations that write `armed` and `confirm_window`, the read-only locks facade.
const Life := preload("res://scripts/player_lifecycle.gd")
const Locks := preload("res://scripts/player_locks.gd")
func _initialize() -> void: call_deferred("run")

func run() -> void:
	for phase in Life.PHASES: check(Life.TABLE.has(phase), "The table has a row for %s" % phase)
	check(Life.legal(Life.IDLE, Life.CHARGING) and Life.legal(Life.CHARGING, Life.PREPARED) and Life.legal(Life.PREPARED, Life.CONFIRMED) and Life.legal(Life.CONFIRMED, Life.CONTACTED), "The ordinary path charge, prepare, confirm, contact is legal")
	check(Life.legal(Life.IDLE, Life.PREPARED) and Life.legal(Life.IDLE, Life.CONFIRMED), "Dive and passive Block arm from IDLE; the swept Block confirms from IDLE (FC-04)")
	check(not Life.legal(Life.CONTACTED, Life.CONFIRMED) and not Life.legal(Life.CHARGING, Life.CONFIRMED) and not Life.legal(Life.MISSED, Life.PREPARED) and not Life.legal(Life.IDLE, Life.CONTACTED), "Illegal moves are illegal (no confirm from a charge, no contact without a window)")
	for phase in Life.PHASES: if phase != Life.IDLE: check(Life.legal(phase, Life.IDLE), "%s can be cancelled to IDLE" % phase)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	check(Life.phase(lab) == Life.IDLE, "A fresh lab is IDLE")
	lab.charging = true
	check(Life.phase(lab) == Life.CHARGING, "Charging is CHARGING")
	Life.arm(lab)
	check(lab.armed and Life.phase(lab) == Life.PREPARED, "arm writes the legacy flag and the phase is PREPARED")
	Life.set_window(lab, 0.4)
	check(lab.confirm_window == 0.4 and Life.phase(lab) == Life.CONFIRMED, "set_window writes the legacy field and the phase is CONFIRMED")
	Life.set_window(lab, 0)
	Life.disarm(lab)
	lab.charging = false
	check(not lab.armed and Life.phase(lab) == Life.IDLE, "disarm and a closed window return to IDLE")
	lab.animation.roll_lock = 0.2
	check(Locks.recovering(lab) and Locks.input_locked(lab) and Life.phase(lab) == Life.RECOVERY, "A roll lock is RECOVERY and locks input through the facade")
	check(Locks.recovery(lab).roll == 0.2, "The facade reports the roll lock")
	lab.animation.roll_lock = 0.0
	check(not Locks.input_locked(lab), "The lock clears")
	# PRB-15: the cancel set equals the Bench entry's old hand-written reset, field for field.
	dirty(lab)
	old_bench_reset(lab)
	var from_old := snapshot(lab)
	dirty(lab)
	Life.cancel(lab)
	var from_cancel := snapshot(lab)
	check(from_old == from_cancel, "cancel() leaves exactly the fields the old Bench reset left (%s vs %s)" % [from_old, from_cancel])
	check(not from_cancel.armed and not from_cancel.charging and from_cancel.window == 0.0 and Life.phase(lab) == Life.IDLE, "cancel() ends IDLE")
	# Every exit path clears the documented set (armed and the confirm window): Bench, rally end, a lab reset.
	for path in ["bench", "finish", "reset"]:
		lab.armed = true
		lab.confirm_window = 0.3
		match path:
			"bench": lab.bench.enter()
			"finish": lab._finish("probe")
			"reset": lab._reset()
		check(not lab.armed and lab.confirm_window == 0.0, "Exit path %s clears armed and the confirm window" % path)
		lab.bench.clear()
	# Writers: only the lifecycle operations write the two fields (the lint half of the ratchet).
	var pattern := RegEx.new()
	pattern.compile("(?<![_\\w])(armed|confirm_window)\\s*(=|\\+=|-=)[^=]")
	var offenders := []
	for path in _scripts("res://scripts"):
		if path.ends_with("/player_lifecycle.gd"): continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].strip_edges()
			if code.begins_with("#") or code.begins_with("var "): continue
			if pattern.search(code) != null: offenders.append("%s:%d" % [path, i + 1])
	check(offenders.is_empty(), "No writer of armed or confirm_window outside the lifecycle operations (%s)" % [offenders])
	lab.queue_free()
	await process_frame
	print("PLAYER LIFECYCLE: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

static func _scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"): out.append(dir + "/" + file)
	for sub in DirAccess.get_directories_at(dir): out.append_array(_scripts(dir + "/" + sub))
	return out

static func dirty(lab) -> void:
	lab.armed = true
	lab.charging = true
	lab.confirm_window = 0.3
	lab.confirm_duration = 0.4
	lab.committed_intent = {"x": 1}
	lab.contact_memory.assign([1.0, 2.0, 3.0, 4.0])
	lab.motion.jump_charge = 0.5
	lab.motion.jumped = true
	lab.motion.airborne_action = 2
	lab.motion.generic_jump = true
	lab.motion.approach_bound = true
	lab.motion.approach_release_pending = true
	lab.motion.quick_step_time = 0.2
	lab.animation.roll_lock = 0.3
	lab.animation.dive_recovery_time = 0.2
	lab.animation.dive_launched = true
	lab.animation.receive_pose_remaining = 0.4
	lab.rescue_swing_remaining = 0.3
	lab.hurtbox_linger = 0.5
	lab.hurtbox_root.show()
	lab.landing_marker.show()
	lab.aim_marker.show()
	lab.reach_ring.show()

static func snapshot(lab) -> Dictionary:
	return {"armed": lab.armed, "charging": lab.charging, "window": lab.confirm_window, "duration": lab.confirm_duration, "intent": lab.committed_intent,
		"memory": lab.contact_memory, "jump_charge": lab.motion.jump_charge, "jumped": lab.motion.jumped, "airborne": lab.motion.airborne_action,
		"generic": lab.motion.generic_jump, "bound": lab.motion.approach_bound, "release": lab.motion.approach_release_pending, "quick": lab.motion.quick_step_time,
		"roll": lab.animation.roll_lock, "dive": lab.animation.dive_recovery_time, "launched": lab.animation.dive_launched, "pose": lab.animation.receive_pose_remaining,
		"rescue": lab.rescue_swing_remaining, "linger": lab.hurtbox_linger, "hurtbox": lab.hurtbox_root.visible, "landing": lab.landing_marker.visible,
		"aim": lab.aim_marker.visible, "reach": lab.reach_ring.visible, "preview": lab.preview.mesh, "phase": Life.phase(lab)}

## The Bench entry's hand-written reset exactly as it was before MS-10d (PRB-15 reference). `cancel` must leave the same fields.
static func old_bench_reset(lab) -> void:
	lab.armed = false
	lab.charging = false
	lab.confirm_window = 0
	lab.confirm_duration = 0
	lab.committed_intent = {}
	lab.contact_memory.fill(0.0)
	lab.directional_input.clear()
	lab.motion.jump_charge = -1
	lab.motion.jumped = false
	lab.motion.airborne_action = -1
	lab.motion.generic_jump = false
	lab.motion.approach_bound = false
	lab.motion.approach_release_pending = false
	lab.motion.quick_step_time = 0
	lab.animation.roll_lock = 0
	lab.animation.dive_recovery_time = -1
	lab.animation.dive_launched = false
	lab.animation.receive_pose_remaining = 0
	lab.rescue_swing_remaining = 0
	lab.hurtbox_linger = 0
	lab.hurtbox_root.hide()
	lab.preview.mesh = null
	lab.landing_marker.hide()
	lab.aim_marker.hide()
	lab.reach_ring.hide()
	lab.serve.clear()
	lab.moc.clear()
