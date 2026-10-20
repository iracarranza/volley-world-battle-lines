extends "res://tests/support/test_case.gd"
const Net := preload("res://scripts/net_response.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var net := Net.new()
	var tape := net.step(Vector3(0,2.43,1),Vector3(0,2.43,-1),Vector3(0,0,-20),0.1,0.7)
	check(tape.contact == "tape" and tape.velocity.z > 0,"Tape arrests and rebounds a direct strike without ending play")
	net.clear()
	var dribble := net.step(Vector3(0,2.8,0.03),Vector3(0,2.4,-0.03),Vector3(0,-4,-0.6),0.1,0.1)
	check(dribble.contact == "tape" and dribble.velocity.y > 0 and dribble.velocity.z < 0,"Top-tape contact can bounce upward and dribble across")
	for side in [-1.0,1.0]:
		for speed in [2.0,30.0]:
			net.clear()
			var point := Vector3(0,2.0,side*0.3)
			var velocity := Vector3(0,0,-side*speed)
			var deepest := 0.0
			var result := {}
			var touched := false
			for frame in range(130):
				var next := point+velocity/240.0
				result = net.step(point,next,velocity,1.0/240,0.1 if speed < 5 else 1.0)
				touched = touched or result.contact == "webbing"
				point = result.position
				velocity = result.velocity
				deepest = maxf(deepest,-point.z*side)
				check(not result.crossed,"A stretched pocket is not a legal court crossing")
				if touched and not net.pocket: break
			check(not net.pocket and point.z*side > 0,"Webbing releases toward the original side on both court orientations")
			if speed < 5:
				check(absf(velocity.z) < 1,"Soft webbing contact absorbs normal speed for a drop")
			else:
				check(deepest > 0.1 and velocity.z*side > 2,"Hard contact stretches through the net plane then rebounds")
	check(Net.body_touches(Vector3(0,0,0.5),Vector3(0,0,-0.5)),"Swept athlete body crossing the webbing is a fault")
	check(not Net.body_touches(Vector3(0,-0.4,0.1),Vector3(0,-0.4,0.1)),"Body entirely below webbing does not touch the net")
	check(not Net.body_touches(Vector3(6,0,0.1),Vector3(6,0,0.1)),"Athlete outside net width does not fault")
	check(not Net.body_touches(Vector3(0,0,0.2),Vector3(0,0,0.2)),"A shoulder or arm brushing the net (body beside it) is not a fault")
	check(not Net.body_touches(Vector3(1,0,0.15),Vector3(1,0,0.15)),"Standing close to the net is not a fault")
	check(Net.body_touches(Vector3(0,0,0.0),Vector3(0,0,0.0)),"The body's vertical midline in the net is a fault")
	check(Net.body_touches(Vector3(0,0,0.04),Vector3(0,0,-0.04)),"Crossing the midline through the net is a fault")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	lab.ball_active = true
	lab.ball.position = Vector3(0,2.1,0.4)
	lab.ball_velocity = Vector3(0,0,-12)
	lab._tick_ball(0.04)
	check(lab.ball_active and lab.net_response.pocket,"Actual webbing contact keeps rally alive")
	lab.player.position = Vector3(0,0,0.3)
	lab.player.velocity = Vector3(0,0,-3)
	lab._physics_process(1.0/60)
	check(lab.ball_active,"Brushing the net with the side of the body (midline 0.25 m away) is not a fault")
	lab.player.position = Vector3(0,0,0.08)
	lab.player.velocity = Vector3(0,0,-3)
	lab._physics_process(1.0/60)
	check(not lab.ball_active and lab.feedback.contains("NET FAULT"),"Actual athlete body contact ends rally with net fault")
	# Out of a rally the net still stops the body's midline, but the body can press into it up to the shoulders
	lab._reset()
	lab.player.position = Vector3(0,0.03,1.0)
	for frame in range(120):
		lab.player.velocity = Vector3(0,0,-5)
		lab._physics_process(1.0/60)
	check(lab.player.position.z > 0.04 and lab.player.position.z < 0.1,"Out of a rally the athlete's midline stops at the net, a shoulder's width into it (%.3f)" % lab.player.position.z)
	check(not lab.ball_active,"Walking into the net with no rally is not a fault")
	lab._reset()
	lab.ball_active = true
	lab.ball.position = Vector3(0,0.8,0.4)
	lab.ball_velocity = Vector3(0,0,-12)
	lab._tick_ball(0.06)
	check(not lab.ball_active and lab.feedback.contains("UNDER-NET"),"Ball crossing completely beneath the webbing is an under-net fault")
	lab.queue_free()
	await process_frame
	print("NET RESPONSE: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
