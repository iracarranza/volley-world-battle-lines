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
