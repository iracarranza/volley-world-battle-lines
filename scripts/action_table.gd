extends RefCounted
## Read-only mirror of each contact action's timing, for consumers that draw or plan with it (timeline, previews, bots).
## It mirrors what the resolver does, not the first function that computes a window: a Block has no age window, only the press
## pulse of BlockResponse, so its sweet fields are -1. Windows are read live (the Attack windup is a session setting), in seconds of
## confirmation age. tests/action_table_test.gd compares every row with ContactResolver.assess.
const Execution := preload("res://scripts/contact_execution.gd")
const BlockResponse := preload("res://scripts/contact/block_response.gd")
const Action := preload("res://scripts/contact/action.gd").Type

static func row(action: int) -> Dictionary:
	if action == Action.BLOCK:
		return {"action": action, "kind": "pulse", "windup": 0.0, "live_start": 0.0, "live_end": Execution.contact_seconds(action),
			"sweet_start": -1.0, "sweet_end": -1.0, "ideal": Execution.ideal_age(action), "pulse_seconds": BlockResponse.PRESS_SECONDS}
	var attack := action == Action.ATTACK
	return {"action": action, "kind": "age", "windup": Execution.SPIKE_WINDUP if attack else 0.0,
		"live_start": Execution.SPIKE_WINDUP if attack else 0.0, "live_end": Execution.contact_seconds(action),
		"sweet_start": Execution.sweet_start(action), "sweet_end": Execution.sweet_end(action), "ideal": Execution.ideal_age(action),
		"power_start": Execution.SPIKE_POWER_START if attack else -1.0, "rescue_start": Execution.SPIKE_RESCUE_SECONDS if attack else -1.0}
