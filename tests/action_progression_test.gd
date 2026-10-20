extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	lab._reset()
	for slot in range(8):
		bots.settings[slot].enabled = false
	lab.player.position = Vector3(0, 0, 4)
	lab.locked_action = 0
	lab.selected = 0
	lab._advance_action_after_contact()
	check(lab.selected == 1, "Alone on the court, the wheel moves on from receive to set")
	lab.locked_action = 3
	lab._advance_action_after_contact()
	check(lab.selected == 0, "...and wraps from block back to receive")
	# A teammate on the player's side stops it
	bots.settings[1].enabled = true
	lab.locked_action = 0
	lab.selected = 0
	check(bots.has_teammates(0) and not bots.has_teammates(1), "A home helper is a teammate for a home player")
	lab._advance_action_after_contact()
	check(lab.selected == 0, "With a teammate on your court the action stays where you put it")
	# The other side's helpers do not count
	bots.settings[1].enabled = false
	bots.settings[5].enabled = true
	lab.selected = 0
	lab._advance_action_after_contact()
	check(lab.selected == 1, "Helpers on the other side of the net do not stop it")
	# Away court
	lab.player.position = Vector3(0, 0, -4)
	lab.selected = 0
	lab._advance_action_after_contact()
	check(lab.selected == 0 and bots.has_teammates(1), "On the away court its own helpers count")
	print("ACTION PROGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
