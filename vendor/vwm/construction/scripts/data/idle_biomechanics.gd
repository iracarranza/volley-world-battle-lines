class_name IdleBiomechanics
extends RefCounted

## Deterministic low-amplitude life layered under stance and action poses.

## Visual vocabulary semantics
##
## Breathing and sway are settled non-contact micro-movement, not fatigue or a
## rally outcome. Blink and pupil motion communicate ordinary attention; contact
## concentration may suppress a blink without changing gaze ownership. These
## overlays fade beneath locomotion and preparation so the same living body can
## transition continuously into ready stance or action.

const BREATH_SECONDS: float = 4.2
const SWAY_SECONDS: float = 6.8
const BLINK_CLOSE_SECONDS: float = 0.07
const BLINK_HOLD_SECONDS: float = 0.035
const BLINK_OPEN_SECONDS: float = 0.11


static func phase_offset(player_id: int) -> float:
	return float(absi(hash("idle-phase:%d" % player_id)) % 10000) / 10000.0


static func resolve(time_seconds: float, player_id: int, stance: String) -> Dictionary:
	var offset := phase_offset(player_id)
	var breath_phase := TAU * (time_seconds / BREATH_SECONDS + offset)
	var sway_phase := TAU * (time_seconds / SWAY_SECONDS + offset * 0.61)
	var stance_scale := 1.0 if stance == "watching" else 0.55
	return {
		"rise_metres": sin(breath_phase) * 0.006 * stance_scale,
		"torso_scale_y": 1.0 + sin(breath_phase) * 0.012 * stance_scale,
		"lateral_metres": sin(sway_phase) * 0.012 * stance_scale,
		"torso_roll_degrees": -sin(sway_phase) * 1.15 * stance_scale,
		"knee_degrees": -1.8 * (0.5 + 0.5 * sin(sway_phase)) * stance_scale,
		"arm_lag_degrees": cos(sway_phase) * 1.4 * stance_scale,
	}


static func blink_interval_seconds(player_id: int) -> float:
	return 3.2 + float(absi(hash("blink-rate:%d" % player_id)) % 2200) / 1000.0


static func blink_weight(
	time_seconds: float, player_id: int, suppress: bool = false
) -> float:
	if suppress:
		return 0.0
	var interval := blink_interval_seconds(player_id)
	var offset := phase_offset(player_id) * interval
	var local := fposmod(time_seconds + offset, interval)
	var duration := BLINK_CLOSE_SECONDS + BLINK_HOLD_SECONDS + BLINK_OPEN_SECONDS
	if local >= duration:
		return 0.0
	if local < BLINK_CLOSE_SECONDS:
		return smoothstep(0.0, BLINK_CLOSE_SECONDS, local)
	if local < BLINK_CLOSE_SECONDS + BLINK_HOLD_SECONDS:
		return 1.0
	return 1.0 - smoothstep(
		BLINK_CLOSE_SECONDS + BLINK_HOLD_SECONDS, duration, local
	)


static func pupil_offset(time_seconds: float, player_id: int) -> Vector2:
	var offset := phase_offset(player_id)
	return Vector2(
		sin(time_seconds * 0.73 + offset * TAU) * 0.035,
		cos(time_seconds * 0.51 + offset * TAU) * 0.018,
	)
