extends SceneTree
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func hand_x(body: Node3D, hand: float, phase: float, yaw: float) -> float:
	var Spike = load("res://scripts/spike_stage.gd")
	Spike.apply(body, phase, hand, 0.8, "Power swing", {"shot_yaw": yaw, "ball_local": Vector3(0.0, 2.3, -0.5)})
	var wrist := body.get_node(("RightArm" if hand > 0.0 else "LeftArm") + "/Elbow/Wrist") as Node3D
	return body.to_local(wrist.global_position).x
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var body: Node3D = lab.body
	body.rotation = Vector3.ZERO
	var Spike = load("res://scripts/spike_stage.gd")
	# A shot to the left carries the hand left and a shot to the right carries it right, for either hand.
	for hand in [1.0, -1.0]:
		for phase in [0.0, 0.2, 0.4]:
			var left := hand_x(body, hand, phase, 0.6)
			var straight := hand_x(body, hand, phase, 0.0)
			var right := hand_x(body, hand, phase, -0.6)
			check(left < straight and straight < right, "A shot to the left draws the hand left of a straight one, a shot to the right further right (hand %d, phase %.1f: %.2f %.2f %.2f)" % [int(hand), phase, left, straight, right])
	# Cross-court is across the body: for a right-hander the hand ends nearer the body's middle than for the line shot
	check(absf(hand_x(body, 1.0, 0.4, 0.6)) < absf(hand_x(body, 1.0, 0.4, -0.6)), "A right-hander's cross-body shot finishes nearer the body than the outward one")
	# A ball struck early no longer snaps the arm to contact
	var previous: float = Spike.phase_for(1.0, 1.0, 0.0, 0.0)
	check(is_equal_approx(previous, Spike.LOADED), "Struck at the click, the swing still starts from the loaded pose")
	var biggest := 0.0
	var monotonic := true
	for i in range(1, 60):
		var phase: float = Spike.phase_for(1.0, 1.0, float(i) / 60.0, 0.0)
		biggest = maxf(biggest, absf(phase - previous))
		monotonic = monotonic and phase >= previous - 0.0001
		previous = phase
	check(biggest < 0.09, "The arm passes through contact over several frames instead of one (largest step %.3f)" % biggest)
	check(monotonic, "The swing only ever moves forward")
	check(Spike.phase_for(1.0, 1.0, 0.05, 0.0) > Spike.LOADED and Spike.phase_for(1.0, 1.0, 0.05, 0.0) < -0.05, "It is still part way to contact a few frames after the ball is struck")
	check(is_equal_approx(Spike.phase_for(1.0, 1.0, 0.09, 0.0), 0.0), "It reaches contact after the catch-up")
	var late: float = Spike.phase_for(1.0, 1.0, 0.14, 0.14)
	check(is_equal_approx(late, 0.0), "A ball struck at the end of the strike behaves as before")
	# The set gathers as the ball comes in
	lab._reset()
	lab.selected = 1
	lab.locked_action = 1
	lab.armed = true
	lab.ball_active = false
	check(is_equal_approx(lab.animation.set_phase(), -0.16), "With no ball coming the set holds its gather")
	lab.ball_active = true
	var head: Vector3 = lab.player.position + Vector3.UP * lab.athlete.reach()
	var phases := []
	for distance in [8.0, 4.0, 2.0, 1.0, 0.4]:
		lab.ball.position = head + Vector3(0, 0, -distance)
		lab.ball_velocity = Vector3(0, 0, 6)
		phases.append(lab.animation.set_phase())
	check(phases[0] <= phases[1] and phases[1] < phases[2] and phases[2] <= phases[3] and phases[3] <= phases[4], "The hands gather progressively as the ball approaches (%s)" % str(phases))
	check(phases[0] < -0.6 and phases[4] > -0.2, "From nearly ready to gathered at the forehead")
	lab.ball_velocity = Vector3(0, 0, -6)
	check(is_equal_approx(lab.animation.set_phase(), -0.16), "A ball moving away does not draw the hands in")
	print("swing_lead_in: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
