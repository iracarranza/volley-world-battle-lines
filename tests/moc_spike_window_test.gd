extends "res://tests/support/test_case.gd"
const Clock := preload("res://scripts/moment_of_contact.gd")
func _initialize() -> void:
	var clock := Clock.new()
	root.add_child(clock)
	clock.set_mode(Clock.Mode.TUNED_SLOWDOWN)
	var time := {"usec":1000000}
	clock.clock = func(): return time.usec
	check(clock.actor_scale("player") == 1 and clock.simulation_scale() == 1,"Preparation runs at normal speed")
	var spike := {"id":"spike","action":2,"actor":"player","physical_hit":false}
	clock.begin(spike)
	check(not clock.active,"Confirmation without physical contact does not start MoC")
	spike.physical_hit = true
	clock.begin(spike)
	check(clock.actor_scale("player") == 0.15 and clock.simulation_scale() == 0.15 and clock.actor_scale("other") == 1 and Engine.time_scale == 1,"Only ball and acting athlete slow on contact")
	time.usec += 399999
	clock.begin(spike)
	check(clock.simulation_scale() == 0.15,"Duplicate contact does not interrupt the 400ms window")
	time.usec += 1
	check(clock.simulation_scale() == 1 and clock.actor_scale("player") == 1,"Exactly 400ms restores normal motion without extending for duplicate events")
	for action in [0,1,3,4]:
		spike.id = "spike-%d" % action
		clock.begin(spike)
		check(clock.active,"New spike starts immediately without chain cooldown")
		clock.begin({"action":action,"physical_hit":true})
		check(not clock.active and clock.simulation_scale() == 1,"Non-spike contact immediately launches at normal speed")
	clock.queue_free()
	print("MOC SPIKE WINDOW: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
