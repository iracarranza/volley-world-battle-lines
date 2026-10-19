extends RefCounted
const Execution := preload("res://scripts/contact_execution.gd")
const ReceiveCharge := preload("res://scripts/receive_charge.gd")
const CHARGE_SECONDS := 0.85
const DEFAULT_CHARGE := 0.65
var states: Dictionary = {}

func reset() -> void:
	states.clear()

func state_for(key: int) -> Dictionary:
	if not states.has(key):
		states[key] = {"phase": "preparing", "charge": 0.0, "target": DEFAULT_CHARGE, "locked_charge": 0.0, "elapsed": 0.0, "release_at": INF, "confirmation_age": -1.0, "planned": false}
	return states[key]

func begin(key: int, action: int, shot: Dictionary, time: float, accuracy: float, random: RandomNumberGenerator, cushioning: float = 0.0, available_output: float = 1.0) -> void:
	var state := state_for(key)
	var match_result := ReceiveCharge.match_charge(shot, 0)
	var target := clampf((float(match_result.minimum) + ReceiveCharge.ABOVE_LEEWAY * 0.5-cushioning)/maxf(available_output,0.01),0,1) if action == 0 and match_result.required else DEFAULT_CHARGE
	if accuracy < 100:
		target = clampf(target + random.randf_range(-0.35, 0.35) * (1.0 - clampf(accuracy, 0, 100) / 100.0), 0, 1)
	if float(state.charge) > target:
		state.charge = 0.0 # Cancel and recharge rather than silently subtracting charge.
	state.merge({"target": target, "phase": "charging", "elapsed": 0.0, "release_at": maxf(0, time - Execution.SWEET_DELAY), "confirmation_age": -1.0, "planned": true}, true)

func tick(key: int, dt: float) -> void:
	var state := state_for(key)
	if not state.planned:
		state.charge = move_toward(float(state.charge), DEFAULT_CHARGE, dt / CHARGE_SECONDS)
		state.phase = "ready" if state.charge >= DEFAULT_CHARGE else "charging"
		return
	var remaining := dt
	if state.phase != "confirmed":
		var until_release := maxf(0, float(state.release_at) - float(state.elapsed))
		var charging_time := minf(dt, until_release)
		state.charge = move_toward(float(state.charge), float(state.target), charging_time / CHARGE_SECONDS)
		state.elapsed += charging_time
		remaining -= charging_time
		state.phase = "ready" if state.charge >= state.target else "charging"
		if state.elapsed >= state.release_at:
			state.phase = "confirmed"
			state.locked_charge = float(state.charge)
			state.confirmation_age = 0.0
	if state.phase == "confirmed":
		state.confirmation_age += remaining
		state.elapsed += remaining

func finish(key: int) -> void:
	states[key] = {"phase": "preparing", "charge": 0.0, "target": DEFAULT_CHARGE, "locked_charge": 0.0, "elapsed": 0.0, "release_at": INF, "confirmation_age": -1.0, "planned": false}

func evidence(key: int) -> Dictionary:
	var result := state_for(key).duplicate(true)
	result.make_read_only()
	return result

static func output_factor(charge: float) -> float:
	return (0.55 + 0.45 * maxf(charge, 0)) / (0.55 + 0.45 * DEFAULT_CHARGE)
