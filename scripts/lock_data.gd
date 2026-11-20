extends RefCounted
## MS-12 (G-09, G-10, G-20): locks and recovery durations as tunable gameplay data. Animation reads these; it no longer owns the numbers.
## Every value is today's value (defaults). Pose clocks stay in the animation controller.
const FloorRecovery := preload("res://scripts/floor_recovery.gd")
const DiveRecovery := preload("res://scripts/dive_recovery.gd")

## Seconds the rolling receive locks the player (also the roll pose length).
const ROLL_TIME := 0.9
## G-10 (deferred part): `action_endlag` literals stay in contact_lab.gd and athlete_motor.gd because scenario S-11 records their source text;
## moving them is a recorded difference, so it waits for a decision record. They gate nothing today.
## Recovery clocks run this much faster while the player steers after the lock ends.
const RELEASE_SPEEDUP := 1.6

## Seconds into a dive recovery at which input returns.
static func dive_lock_seconds(quality: float) -> float:
	return DiveRecovery.lock_seconds(quality)

## Seconds into a floor recovery at which input returns. The shrug budget (G-20) governs over its longer animation.
static func floor_lock_seconds(recovery: String, scale: float, event: Dictionary, total: float) -> float:
	if recovery == "shrug":
		return float(event.get("recovery_penalty_seconds", total))
	return FloorRecovery.lock_seconds(recovery) * scale

## The lock predicates (pure): input is locked from the start of a recovery until its lock second. Animation and PlayerLocks both ask here.
static func dive_locked(recovery_time: float, quality: float) -> bool:
	return recovery_time >= 0.0 and recovery_time < dive_lock_seconds(quality)

static func floor_locked(recovery_time: float, lock: float) -> bool:
	return recovery_time >= 0.0 and recovery_time < lock
