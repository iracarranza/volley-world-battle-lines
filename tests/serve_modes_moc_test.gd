extends SceneTree
const Clock = preload("res://scripts/moment_of_contact.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func step_serve(lab: Node3D, seconds: float) -> void:
	for frame in range(ceili(seconds * 120)):
		if lab.serve.state == lab.serve.State.FLIGHT or not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.moc.enabled = false
	await physics_frame
	for x in [-2.2, 0.0, 2.2]:
		for yaw in [-1.0, 0.0, 1.0, PI]:
			lab._reset()
			lab.player.position = Vector3(x, 0, lab.court_half_depth + 0.4)
			lab.facing_yaw = yaw
			lab.view_yaw = yaw
			lab._update_aim()
			lab._update_pose()
			lab.serve.input_press()
			step_serve(lab, 0.3)
			check(lab.serve.channeling() and lab.serve.evidence.is_empty(), "Holding E begins standing channel without premature strike")
			step_serve(lab, 0.8)
			var shot: Dictionary = lab.serve.evidence
			check(not shot.is_empty() and shot.mode == "held" and lab.serve.state == lab.serve.State.FLIGHT, "Completed hold serves automatically")
			var origin: Vector3 = shot.point
			var velocity: Vector3 = shot.outgoing_velocity
			var arrival: Vector3 = origin + velocity * shot.duration + Vector3.DOWN * lab.GRAVITY * shot.duration * shot.duration * 0.5
			check(arrival.distance_to(shot.target) < 0.001 and absf(arrival.x) < lab.court_half_width and arrival.z < 0 and arrival.z > -lab.court_half_depth, "Basic serve lands in opposing court")
			check(shot.net_height >= 2.43 + lab.Geometry.BALL_RADIUS + 0.19, "Basic serve clears net including ball radius")
			lab.serve.release()
			check(lab.serve.state == lab.serve.State.FLIGHT, "Key release after channel cannot cancel outgoing serve")
	lab._reset()
	lab.serve.input_press()
	step_serve(lab, 0.3)
	lab.serve.release()
	check(not lab.ball_active and lab.serve.state == lab.serve.State.IDLE, "Incomplete held channel cancels cleanly")
	lab._reset()
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	lab._unhandled_input(key)
	step_serve(lab, 0.05)
	key.pressed = false
	lab._input(key)
	check(lab.serve.state == lab.serve.State.TOSS and not lab.serve.input_held, "Short E press selects manual toss mode")
	step_serve(lab, 0.1)
	key.pressed = true
	lab._unhandled_input(key)
	step_serve(lab, 0.4)
	check(not lab.serve.evidence.is_empty() and lab.serve.evidence.mode == "tap", "Second tap hits through physical hand sweep")
	lab._reset()
	var drill = lab.station
	lab.player.position = drill.START
	drill.start()
	drill.serve()
	check(drill.state == drill.State.TOSS and lab.ball_velocity.y > 0 and lab.ball_shot.is_empty(), "Drill visibly tosses before publishing serve")
	var initial_height: float = lab.ball.position.y
	for frame in range(30):
		drill.tick(1.0 / 120)
		lab._tick_ball(1.0 / 120)
	check(drill.state == drill.State.TOSS and lab.ball.position.y > initial_height and drill.serves_sent == 0, "Telegraph lasts while toss rises")
	for frame in range(60):
		if drill.state == drill.State.SERVING:
			break
		drill.tick(1.0 / 120)
		lab._tick_ball(1.0 / 120)
	check(drill.state == drill.State.SERVING and lab.ball_shot.kind == "serve" and lab.ball_velocity.z > 20, "Overhead strike starts driven serve")
	check(drill.striker.position.y >= lab.ball.position.y, "Feeder strikes from above toss")
	for action in [0,2,3,4]:
		var base := Clock.duration_for(action, Vector3(0,-5,10), Vector3(0,6,-10))
		check(absf(Clock.duration_for(action, Vector3(0,-5,10), Vector3(0,6,-10), true) - base - Clock.SWEET_BONUS) < 0.00001, "Sweet MoC adds to velocity MoC for every contact type")
	check(Clock.duration_for(3, Vector3.ZERO, Vector3.ZERO, true) == Clock.SWEET_BONUS+Clock.DURATION_EXTENSION, "Sweet contact alone starts MoC")
	lab.moc.enabled = true
	lab.moc.clear()
	var event := {"id": "additive-a", "action": 2, "physical_hit": true, "sweet": true, "incoming_velocity": Vector3(0,0,1), "outgoing_velocity": Vector3(0,0,-1)}
	lab.moc.begin(event)
	var end_before: int = lab.moc._end_usec
	var duration: float = lab.moc.last_event.duration_seconds
	var repeated := event.duplicate()
	repeated.id = "additive-b"
	lab.moc.begin(repeated)
	check(lab.moc._end_usec == mini(end_before+int(duration*1000000),lab.moc._chain_start_usec+int(Clock.CHAIN_LIMIT*1000000)), "Distinct MoCs add remaining real-time duration")
	var doubled_end: int = lab.moc._end_usec
	lab.moc.begin(repeated)
	check(lab.moc._end_usec == doubled_end, "Duplicate contact cannot add twice")
	for index in range(8):
		repeated = event.duplicate()
		repeated.id = "additive-%d" % index
		lab.moc.begin(repeated)
	check(lab.moc._end_usec <= lab.moc._chain_start_usec + int(Clock.CHAIN_LIMIT * 1000000), "Additive chain remains capped")
	lab.moc.clear()
	print("SERVE MODES / TELEGRAPH / ADDITIVE MOC: %d / %d passed" % [checks-failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
