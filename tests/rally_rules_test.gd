extends "res://tests/support/test_case.gd"
const Rules := preload("res://scripts/rally_rules.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rules := Rules.new()
	rules.begin(0)
	check(rules.landing(Vector3(0,0,-4),Vector3.ZERO,4.5,9,0.105).winner == 0,"Ball down in Away court awards Home")
	check(rules.landing(Vector3(0,0,4),Vector3.ZERO,4.5,9,0.105).winner == 1,"Ball down in Home court awards Away")
	check(rules.landing(Vector3(4.6,0,-4),Vector3.ZERO,4.5,9,0.105).winner == 0,"Boundary contact is in")
	check(rules.landing(Vector3(4.7,0,-4),Vector3.ZERO,4.5,9,0.105).winner == 1,"Untouched Home shot out awards Away")
	rules.touch(1)
	check(rules.out().winner == 0,"Away block touch then out awards Home")
	check(rules.fault(0,"NET FAULT").winner == 1,"Fault awards opposing side")
	check(rules.landing(Vector3(20,0,-4),Vector3(20,0,0),4.5,9,0.105).winner == 0,"Court origin supports other map nets")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	await physics_frame
	lab._feed()
	lab.ball.position = Vector3(0,0.15,4)
	lab.ball_velocity = Vector3(0,-4,0)
	lab._tick_ball(0.05)
	check(not lab.ball_active and "AWAY POINT" in lab.feedback,"Contact lab feed landing reports scoring side")
	lab.rally_rules.begin(0)
	lab.ball_active = true
	lab.ball.position = Vector3(0,0.15,-4)
	lab.ball_velocity = Vector3(0,-4,0)
	lab._tick_ball(0.05)
	check("HOME POINT" in lab.feedback,"Home winner works independently of outgoing flag")
	lab.rally_rules.touch(1)
	lab._finish_landing(Vector3(8,0,3),"OUT")
	check("HOME POINT" in lab.feedback,"Last bot touch controls out-ball attribution")
	lab._finish_fault("NET FAULT",0)
	check("AWAY POINT" in lab.feedback,"Net fault reports opponent point")
	lab.ball_active = true
	lab.contacts = 3
	lab.side_contacts[0] = 3
	lab.locked_action = 1
	lab.ball.position = Vector3(0,2,3)
	lab._contact()
	check("AWAY POINT" in lab.feedback and "Three-contact" in lab.feedback,"Fourth touch awards opponent")
	lab._reset()
	lab.ball_active = true
	lab.rally_rules.begin(0)
	lab.ball.position = Vector3(lab.net_response.web_half_width+1,3,0.2)
	lab.ball_velocity = Vector3(0,0,-20)
	lab._tick_ball(0.02)
	check("OUTSIDE-ANTENNA" in lab.feedback and "AWAY POINT" in lab.feedback,"Crossing outside antennas faults the last touching side")
	lab._reset()
	lab.ball_active = true
	for hit in range(2):
		lab.locked_action = 1
		lab.armed = true
		var shape: Dictionary = lab._raw_hurtbox_definition(1)
		lab.ball.position = lab.player.position+Vector3(shape.center)+Vector3.UP*float(shape.radius)*0.5
		lab._confirm_action()
		lab._contact()
	check(lab.ball_active and lab.side_contacts[0] == 2,"Same athlete may make consecutive team contacts")
	lab._finish("Manually stopped")
	check(not "POINT" in lab.feedback,"Manual stop does not invent a point")
	lab.queue_free()
	await process_frame
	print("RALLY RULES: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
