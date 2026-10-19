extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await physics_frame
	var bots = lab.training_bots
	bots.toggle_all()
	lab.view_pitch = 0.27
	lab._update_camera(2)
	lab._serve()
	for frame in range(18):
		lab._tick_ball(1.0 / 120)
	lab._serve()
	for frame in range(40):
		if lab.serve.state == lab.serve.State.FLIGHT:
			break
		lab._tick_ball(1.0 / 120)
	check(bots.active_action == 0 and bots.intercept.z < 0, "Serve goes to away receiver rather than blocker")
	var away_actions: Array[int] = []
	var previous := 0
	var approach_seen := false
	var jump_seen := false
	for frame in range(1000):
		if not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120)
		if bots.motion.plans.has(6):
			var plan: Dictionary = bots.motion.plans[6]
			approach_seen = approach_seen or plan.phase == "approach"
			jump_seen = jump_seen or (plan.phase == "jump" and bots.actors[6].position.y > 0.4)
		if bots.total_contacts > previous:
			previous = bots.total_contacts
			if lab.ball.position.z < 0 and not bots.last_action in away_actions:
				away_actions.append(bots.last_action)
	check(away_actions.has(0) and away_actions.has(1) and away_actions.has(2), "Away receive, set and attack all make real contacts")
	check(approach_seen and jump_seen, "Away attacker approaches and jumps before hitting")
	for frame in range(180):
		bots.tick_motion(1.0 / 120)
	check(bots.actors[6].position.y < 0.001, "Attacker lands after contact")
	lab._reset()
	# A reachable attacking flight must trigger the away block jump.
	lab.ball_active = true
	lab.ball.position = Vector3(0, 3.6, 2)
	lab.ball_velocity = Vector3(0, 0, -6)
	bots.incoming_action = 2
	bots.replan()
	check(bots.active_action == 3 and bots.motion.plans.has(7), "Attack schedules away block jump")
	check(bots.actors[7].position.y == 0, "Blocker begins on floor")
	var blocked := false
	var block_air := false
	var hands_up := false
	for frame in range(120):
		lab._tick_ball(1.0 / 120)
		block_air = block_air or bots.actors[7].position.y > 0.2
		hands_up = hands_up or bots.rigs[7].arms[0].rotation.x < -2.5
		if bots.last_action == 3:
			blocked = true
			break
	check(blocked and block_air and hands_up, "Blocker jumps with both hands raised and physically blocks")
	for frame in range(180):
		bots.tick_motion(1.0 / 120)
	check(bots.actors[7].position.y < 0.001, "Blocker lands after contact")
	# Static attack keeps its ground position but can still jump to contact.
	lab._reset()
	bots.place_at_player(6)
	var fixed: Vector3 = bots.fixed_positions[6]
	lab.ball_active = true
	lab.ball.position = fixed + bots.contact_anchor(6).rotated(Vector3.UP, PI) + Vector3.UP * 2.0
	lab.ball_velocity = Vector3(0, -1, 0)
	lab.side_contacts[1] = 2
	bots.replan()
	check(bots.active_action == 2 and bots.intercept.z < 0, "Static away attacker plans a reachable jump")
	for frame in range(240):
		if bots.last_action == 2 or not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120)
	check(bots.last_action == 2 and Vector2(bots.actors[6].position.x - fixed.x, bots.actors[6].position.z - fixed.z).length() < 0.001, "Static attacker hits without drifting its base position")
	if "--render" in OS.get_cmdline_user_args():
		bots._plan(2, Vector3(0, 3.8, 3), 1.7)
		bots.tick_motion(1.65)
		bots._plan(3, Vector3(0, 3.3, -0.5), 0.7)
		bots.tick_motion(0.66)
		lab._update_camera(2)
		lab._update_ui()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rally-bot-motion.png")
	print("BOT RALLY / MOTION: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
