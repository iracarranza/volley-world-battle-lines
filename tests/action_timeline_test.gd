extends "res://tests/support/test_case.gd"
const Timeline := preload("res://scripts/action_timeline.gd")
const Execution := preload("res://scripts/contact_execution.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(is_equal_approx(Execution.SPIKE_WINDUP, 0.25), "Default spike windup is 250 ms")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var view = lab.hud.athlete_hud.timeline
	view.set_process(false)
	var bar_position: Vector2 = lab.hud.athlete_hud.resources.position
	for action in range(4):
		lab._reset()
		lab.selected = action
		lab.locked_action = action
		lab.charging = true
		lab.charge = 0.5
		view.advance(0)
		check(view.visible and view.phase == "CHARGING 50%" and view.age == 0, "Charging reveals a parked timeline")
		lab.charging = false
		lab.armed = true
		view.advance(0)
		check(view.phase.begins_with("PREPARED") and view.age == 0, "Release parks the tick until confirmation")
		lab._confirm_action()
		var time := Execution.ideal_age(action)
		lab.confirm_window = lab.confirm_duration - time
		view.advance(0.01)
		check(is_equal_approx(view.age, time), "Tick follows actual contact clock, not UI elapsed time")
		if action != 3:
			check(view.phase == "SWEET TIMING", "Green region matches resolver sweet timing")
		view.contact({"actor":"bot:0","action":action,"confirmation_age":0.1})
		check(view.running, "Bot contact cannot overwrite player timeline")
		view.contact({"actor":"player","action":action,"confirmation_age":time,"zone":"FAIR"})
		view.advance(0.1)
		check(not view.running and is_equal_approx(view.contact_age,time) and view.phase == "CONTACT · FAIR", "Contact marker freezes at actual impact and reports geometry result")
		lab.armed = false
		view.advance(1.0)
		check(not view.visible, "Result expires after its hold and fade")
	lab.locked_action = 2
	lab._confirm_action()
	lab.confirm_window = 0
	view.advance(0)
	check(view.phase == "MISSED" and view.age == view.duration, "Whiff reaches end of the timeline")
	lab._reset()
	check(not view.visible and view.action == -1, "Reset clears timeline state")
	lab.locked_action = 3
	lab.armed = true
	lab.block_state.start()
	view.advance(0)
	check(view.phase == "PASSIVE BLOCK", "Unconfirmed airborne block is passive")
	lab._confirm_action()
	lab.block_state.confirmation_age = 0.2
	view.advance(0)
	check(view.phase == "WEAKENING PRESS" and is_equal_approx(view.age,0.2), "Block reads its own press clock")
	lab.block_state.confirmation_age = 0.6
	view.advance(0)
	check(view.phase == "PASSIVE BLOCK", "Expired press remains a valid passive block")
	lab._reset()
	Execution.spike_windup_seconds = 0.7
	view.configure(2)
	check(is_equal_approx(view.duration,0.9) and is_equal_approx(view.segments[0].end,0.7), "Timeline reflects edited windup")
	Execution.spike_windup_enabled = false
	view.configure(2)
	check(is_equal_approx(view.duration,0.2) and view.segments[0].label != "WINDUP", "Disabled windup removes its region")
	Execution.spike_windup_seconds = 0.25
	Execution.spike_windup_enabled = true
	check(lab.hud.athlete_hud.resources.position == bar_position, "Showing timelines never shifts resource bars")
	lab.queue_free()
	await process_frame
	print("ACTION TIMELINE: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
