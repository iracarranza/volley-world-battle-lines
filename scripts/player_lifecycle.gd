extends RefCounted
## MS-10 player lifecycle record (SADR-06). Documentation of where the player's action is (docs/architecture-migration/player-lifecycle.md), the
## transition table recording TODAY'S legality, a derived phase, and the named operations that write `armed` and `confirm_window`. The fields stay on
## the lab (accessor stage: legacy readers and tests read `lab.armed` and `lab.confirm_window` unchanged); storage is not moved in this stage.
const PlayerLocks := preload("res://scripts/player_locks.gd")
const IDLE := "IDLE"
const CHARGING := "CHARGING"
const PREPARED := "PREPARED"
const CONFIRMED := "CONFIRMED"
const CONTACTED := "CONTACTED"
const MISSED := "MISSED"
const RECOVERY := "RECOVERY"
const PHASES := [IDLE, CHARGING, PREPARED, CONFIRMED, CONTACTED, MISSED, RECOVERY]

## CURRENT legality, row = from, value = the phases reachable in one step. Facts recorded, not designed (G-06, G-07):
## - IDLE -> PREPARED directly: dive and the passive Block arm without a charge; a grounded Attack is legal by age (FC-14, a named rescue spike).
## - IDLE -> CONFIRMED directly: the swept Block bypasses `_can_contact` (FC-04).
## - Any phase -> IDLE through cancel (right click, rally end, Bench, scene exit); CONTACTED and MISSED are resolved inside the confirm step, so they
##   are never observed between ticks (`phase()` does not return them).
## - RECOVERY is reached from CONTACTED, MISSED or a dive/floor/roll lock; the plant is two things (0.85 s timeline vs a movement lock of at most the 0.55 s window, FC-13).
const TABLE := {
	IDLE: [CHARGING, PREPARED, CONFIRMED, RECOVERY],
	CHARGING: [IDLE, PREPARED, RECOVERY],
	PREPARED: [IDLE, CONFIRMED, RECOVERY],
	CONFIRMED: [IDLE, CONTACTED, MISSED],
	CONTACTED: [IDLE, RECOVERY],
	MISSED: [IDLE, RECOVERY],
	RECOVERY: [IDLE, CHARGING, PREPARED],
}

static func legal(from: String, to: String) -> bool:
	return TABLE.get(from, []).has(to)

## The phase derived from the legacy flags, in the order the lab consults them: an open confirm window wins, then a prepared (armed) action, then a
## charge in progress, then a lock or end lag.
static func phase(lab) -> String:
	if lab.confirm_window > 0.0: return CONFIRMED
	if lab.armed: return PREPARED
	if lab.charging: return CHARGING
	if PlayerLocks.recovering(lab): return RECOVERY
	return IDLE

# --- Operations: the only writers of `armed` and `confirm_window` ----------------------------------------------------------------------------------
static func arm(lab) -> void:
	lab.armed = true

static func disarm(lab) -> void:
	lab.armed = false

static func set_window(lab, seconds) -> void:
	lab.confirm_window = seconds

## The cancel set (PRB-15): every field the Bench entry used to reset by hand, in the same order. Bench is the widest exit path; rally end, the
## right-click cancel and the station resets clear subsets of it (docs/architecture-migration/player-lifecycle.md lists which). The two lifecycle
## fields go through the operations above.
static func cancel(lab) -> void:
	disarm(lab)
	lab.charging = false
	set_window(lab, 0)
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
