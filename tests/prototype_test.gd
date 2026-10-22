extends "res://tests/support/test_case.gd"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var lab = packed.instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(lab.player != null and lab.camera != null, "Scene must contain a live athlete and camera")
	var a = lab.athlete
	var body_default: float = preload("res://scripts/voli_visual.gd").model_height(1.86)
	check(absf(a.reach() - (1.215 * body_default + 0.32 * 0.04 * body_default / 1.86)) < 0.0001, "VWM reach formula must retain wingspan contribution, on the trimmed body height")
	var balanced_reach: float = a.reach()
	lab._cycle_build()
	check(a.reach() > balanced_reach, "Middle build should have more reach")
	lab._reset()
	a.spend(150)
	check(a.winded and not a.exhausted, "First depletion enters Winded")
	a.recover(1, true)
	a.spend(100)
	check(a.exhausted, "Second depletion while Winded enters Exhaustion")
	a.recover(7, true)
	check(not a.exhausted and a.winded, "Seven seconds returns Exhaustion to Winded")
	lab._reset()
	lab._feed()
	check(lab.ball_active and lab.attempts == 1, "Feed must create an active incoming ball")
	# Keep this flight fixture on a full-depth court; mini-court feeds can land out.
	lab.court_half_depth = 9.0
	var landed := false
	for i in range(240):
		if not lab.ball_active:
			landed = true
			break
		lab._tick_ball(1.0 / 60.0)
	check(landed and lab.feedback.begins_with("Ball down"), "Unplayed feed must clear the Net and land on the athlete side")
	lab._reset()
	lab.locked_action = 0
	lab.ball.position = lab.player.position + Vector3(0, 1.0, 0)
	check(lab._can_contact(), "Low ball should be receivable")
	lab.ball.position.x += 2
	check(not lab._can_contact(), "Distant ball must not be teleported into contact")
	lab.locked_action = 2
	lab.ball.position = lab.player.position + Vector3.UP * (a.reach() - 0.2)
	lab.armed = true
	lab._confirm_action()
	# The strike sweeps through the envelope; the ball is attackable when the sweep reaches it.
	var overhead_age := -1.0
	for step in range(41):
		var age: float = lab.Execution.SPIKE_WINDUP + step * 0.005
		lab.confirm_window = lab.confirm_duration - age
		if lab._can_contact():
			overhead_age = age
			break
	check(overhead_age > 0.0, "Overhead ball must be attackable")
	lab.ball.position.y += 2
	check(not lab._can_contact(), "Ball above reach must not be contactable")
	lab._reset()
	lab.camera_rig.view_pitch = 0.56 # Deliberate loft clears the net from a grounded driven attack.
	lab.rotate_hurtboxes = false # the ball is placed in the level box; tilting is covered by hurtbox_tilt_test
	lab.court_half_width = 4.5
	lab.court_half_depth = 9.0
	lab.aim = Vector3(0, 0, -6)
	lab.locked_action = 2
	lab.locked_charge = 0.15
	var attack_shape: Dictionary = lab._hurtbox_definition(2)
	lab.ball.position = lab.player.position + attack_shape.center + lab.Geometry.sector_point(attack_shape, 0.74, 67.5, 0)
	lab.ball_active = true
	lab.armed = true
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration - lab.Execution.SPIKE_PEAK
	lab._contact()
	check(lab.contacts == 1 and not lab.armed and lab.ball_velocity.z < 0, "Confirm must launch a real outgoing ball")
	check(a.hp == 100 and a.stamina < a.max_stamina(), "Ordinary contact consumes stamina without spending HP")
	for i in range(1500): # a sweet contact starts the local slowdown, so the flight takes longer
		if not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120.0)
	check(lab.returns == 1, "A well-aimed attack must clear the Net and score in bounds")
	lab._reset()
	lab.ball_active = true
	lab.outgoing = true
	lab.ball.position = Vector3(0, 1, 0.1)
	lab.ball_velocity = Vector3(0, 0, -12)
	lab._tick_ball(0.02)
	check(not lab.ball_active and lab.feedback.begins_with("UNDER-NET FAULT"), "Swept crossing catches a ball passing beneath the webbing")
	lab._reset()
	lab.contacts = 3
	lab.ball_active = true
	lab._contact()
	check(not lab.ball_active and lab.feedback.begins_with("Three-contact"), "Fourth contact must fault")
	lab._reset()
	for i in range(8):
		lab._physics_process(1.0 / 60.0)
		await physics_frame
	lab.motion.jump_charge = 0.8
	lab.motion.takeoff()
	check(lab.motion.jumped and lab.player.velocity.y > 0, "Charged jump must launch athlete")
	check(a.stamina < 100, "Jump must consume stamina")
	lab._reset()
	lab.selected = 0
	lab._unhandled_input(mouse_button(MOUSE_BUTTON_LEFT, true))
	check(lab.charging and not lab.armed, "First press must start charge without contacting")
	lab._unhandled_input(mouse_button(MOUSE_BUTTON_LEFT, false))
	check(lab.armed and not lab.charging and lab.locked_charge > 0, "First release must arm the stat-based tap power")
	lab.ball_active = true
	lab.ball.position = lab.player.position + Vector3(0, 1.0, 0)
	lab.ball_velocity = Vector3(0, -2, 0)
	lab._unhandled_input(mouse_button(MOUSE_BUTTON_LEFT, true))
	check(lab.confirm_window > 0, "Second press must buffer confirmation")
	lab._physics_process(1.0 / 60.0)
	check(lab.contacts == 1 and not lab.armed, "Two-stage user input must produce an actual contact")
	lab._reset()
	lab.armed = true
	lab._unhandled_input(mouse_button(MOUSE_BUTTON_RIGHT, true))
	check(not lab.armed, "Grounded right click must cancel the armed action")
	check(a.contact_cost(2, 3).y == 0 and a.contact_cost(2, 1).y == 0, "Ordinary repeated contacts never spend HP")
	lab._reset()
	lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
	lab.camera_rig.update(1.0)
	check(absf(lab.camera.position.x - lab.player.position.x) < 0.02, "Athlete View must follow horizontally")
	lab._reset()
	lab.ball_active = true
	lab.outgoing = true
	lab.ball.position = Vector3(5.0, 0.11, -5)
	lab.ball_velocity = Vector3(0, -1, 0)
	lab._tick_ball(0.03)
	check(lab.returns == 0 and lab.feedback.begins_with("OUT"), "Ball outside the sideline must not score")
	lab._reset()
	lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
	lab.camera_rig.view_yaw = 0.0
	lab.camera_rig.update(2.0)
	var old_camera: Vector3 = lab.camera.position
	lab.player.position.x += 2.0
	lab.camera_rig.update(2.0)
	check(absf(lab.camera.position.x - old_camera.x - 2.0) < 0.01, "Athlete View must translate with athlete movement")
	var before_orbit: Vector3 = lab.camera.position
	lab.camera_rig.rotate_view(Vector2(180, -50))
	lab.camera_rig.update_aim()
	check(absf(lab.aim.x - lab.player.position.x) > 1.0, "Mouse look in Athlete View must steer grounded facing")
	lab.camera_rig.update(2.0)
	check(lab.camera.position.distance_to(before_orbit) > 0.5, "Athlete camera must orbit with view yaw")
	lab.ball_active = true
	lab.ball.position = Vector3(2, 5, 3)
	lab.camera_rig.set_mode(lab.ViewMode.BALL)
	lab.camera_rig.update_aim()
	check(is_equal_approx(lab.camera_rig.facing_yaw, lab.camera_rig.view_yaw), "Entering Ball View preserves athlete facing")
	lab.camera_rig.update(2.0)
	var first_ball_rotation: Quaternion = lab.camera.quaternion
	var first_ball_camera: Vector3 = lab.camera.position
	lab.ball.position = Vector3(-3, 7, 1)
	lab.camera_rig.update(2.0)
	check(lab.camera.unproject_position(lab.camera_rig.ball_frame_pivot).distance_to(lab.get_viewport().get_visible_rect().size * Vector2(0.5, lab.camera_rig.ball_frame_screen_y)) < 0.1, "Ball View frames athlete at bottom center")
	check(first_ball_rotation.angle_to(lab.camera.quaternion) > 0.05, "Ball View must rotate to track ball movement")
	lab.camera_rig.update_aim()
	var facing_before: float = lab.camera_rig.facing_yaw
	lab.camera_rig.rotate_view(Vector2(150, 20))
	lab.camera_rig.update_aim()
	check(absf(lab.camera_rig.facing_yaw - facing_before + 150 * lab.camera_tuning.mouse_sensitivity) < 0.0001, "Ball View mouse turns athlete independently")
	lab.motion.jumped = true
	lab.motion.airborne_aim = Vector3.FORWARD
	lab.camera_rig.set_mode(lab.ViewMode.ATHLETE)
	lab.camera_rig.rotate_view(Vector2(800, 0))
	lab.camera_rig.update_aim()
	check((lab.aim - Vector3(lab.player.position.x, 0, lab.player.position.z)).normalized().is_equal_approx(Vector3.FORWARD), "Airborne look must preserve committed attack direction")
	check(absf(lab.camera_rig.view_yaw) <= 0.651, "Airborne Athlete View must limit looking independently of body aim")
	lab.motion.jumped = false
	lab.camera_rig.view_yaw = PI * 0.5
	lab.camera_rig.update(2.0)
	var forward_move: Vector3 = lab.camera_rig.movement_direction(Vector3.FORWARD)
	check(forward_move.x < -0.9 and absf(forward_move.y) < 0.001, "Forward movement must follow camera heading without vertical drift")
	lab.ball_active = false
	lab.camera_rig.set_mode(lab.ViewMode.BALL)
	lab.camera_rig.update(2.0)
	var inactive_position: Vector3 = lab.camera.position
	lab.ball.position = Vector3(30, 20, 30)
	lab.camera_rig.update(2.0)
	check(lab.camera.position.distance_to(inactive_position) < 0.01, "Inactive ball must not pull camera to stale off-court position")
	lab._reset()
	lab.camera_rig.set_mode(lab.ViewMode.ATHLETE)
	lab.camera_rig.update(2.0)
	var grounded_camera_y: float = lab.camera.position.y
	lab.player.position.y += 0.8
	lab.camera_rig.update(2.0)
	check(absf(lab.camera.position.y - grounded_camera_y - 0.8) < 0.001, "Athlete camera must follow the full jump elevation")
	var airborne_camera_y: float = lab.camera.position.y
	lab.player.position.y += 1.0
	lab.camera_rig.update(1.0 / 60.0)
	check(lab.camera.position.y > airborne_camera_y and lab.camera.position.y < airborne_camera_y + 1.0, "Vertical follow must move smoothly toward rising athlete")
	lab.player.position.y = 8.0
	lab.camera_rig.update(2.0)
	check(absf(lab.camera_rig.camera_anchor.y - (8.0 + float(a.body_height()) * 0.55)) < 0.001, "Raised box landing must retain full world elevation in camera anchor")
	var raised_camera_y: float = lab.camera.position.y
	lab.camera_rig.update(2.0)
	check(absf(lab.camera.position.y - raised_camera_y) < 0.001, "Camera must remain stable while standing on elevated platform")
	lab.player.position.y = 0.03
	lab.camera_rig.update(2.0)
	check(absf(lab.camera.position.y - grounded_camera_y) < 0.001, "Descending back to ground must restore original camera height")
	lab._reset()
	lab.camera_rig.update(2.0)
	lab.camera_rig.rotate_view(Vector2(100, 0))
	check(absf(lab.camera_rig.facing_yaw + 100.0 * lab.camera_tuning.mouse_sensitivity) < 0.00001, "Facing must apply exact mouse delta immediately")
	lab.camera_rig.update(1.0 / 144.0)
	var camera_forward: Vector3 = -lab.camera.global_basis.z
	camera_forward.y = 0
	var aim_forward: Vector3 = lab.aim - Vector3(lab.player.position.x, 0, lab.player.position.z)
	check(camera_forward.normalized().dot(aim_forward.normalized()) > 0.9999, "Camera heading and athlete facing must agree without orbit lag")
	lab.camera_rig.rotate_view(Vector2(-100, 0))
	check(absf(lab.camera_rig.facing_yaw) < 0.00001, "Equal opposite mouse motion must return precisely to original facing")
	lab.camera_rig.rotate_view(Vector2(0, 80))
	check(absf(lab.camera_rig.facing_yaw) < 0.00001, "Vertical mouse look must not introduce yaw drift")
	lab._reset()
	lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
	lab.camera_rig.update(2.0)
	var initial_orbit_position: Vector3 = lab.camera.position
	for pitch in [-0.5, 0.0, 0.25, 0.60]:
		lab.camera_rig.view_pitch = pitch
		lab.camera_rig.update(2.0)
		var centered: Vector2 = lab.camera.unproject_position(lab.camera_rig.camera_anchor)
		var screen_center: Vector2 = lab.get_viewport().get_visible_rect().size * 0.5
		if pitch <= 0.27 + asin((lab.camera_rig.camera_anchor.y - 0.4) / lab.camera_tuning.distance):
			check(centered.distance_to(screen_center) < 0.1, "Athlete pivot stays centered until the camera reaches floor for pitch %s" % pitch)
		else:
			check(absf(lab.camera.position.y - 0.4) < 0.01, "Beyond floor limit camera tilts from fixed ground clearance")
	check(lab.camera.position.distance_to(initial_orbit_position) > 0.5, "Looking up must orbit camera position rather than tilt away from athlete")
	lab._reset()
	for build in a.BUILDS:
		a.build = build.duplicate()
		var neutral_jump: float = 2.25*(0.20+65.0*0.007)
		var effective_height: float = neutral_jump*lerpf(0.55,1.0,a.effective_jump_charge(1.0))
		a.stamina = a.max_stamina()
		check(absf(a.leap(1.0,1.0)-effective_height) < 0.001,"Build jump height uses neutral baseline and tiered Jump Power charge")
	for height in [0.3, 1.0, 1.6]:
		for power in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var legacy := {"range_meters": preload("res://scripts/receive_pass.gd").matched_distance(lab.receive_net_distance())} # the matched pass depends on the net, not the charge
			var velocity: Vector3 = lab._shot_velocity(Vector3(0, height, 5), 0, power)
			var flight_time: float = (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * lab.GRAVITY * (height - 0.105))) / lab.GRAVITY
			var horizontal_speed := Vector2(velocity.x, velocity.z).length()
			check(absf(horizontal_speed * flight_time - float(legacy.range_meters)) < 0.001, "Matched receive range must be charge independent at height %s, charge %s" % [height, power])
			var old_rise: float = pow((5.0 + power * 5.5) * sin(deg_to_rad(60.0)), 2) / (2.0 * lab.GRAVITY)
			check(height + velocity.y * velocity.y / (2.0 * lab.GRAVITY) <= lab._bump_ceiling(height) + 0.001, "No bump charge may exceed the former tapped-bump ceiling")
	lab._reset()
	var bot = lab.training_bots
	for action in range(4):
		bot.toggle(action, action == 3)
		lab._feed()
		if action > 0:
			check(bot.active_action == -1, "Setter, attacker and blocker must not steal an opening receive")
			lab.ball.position = Vector3(0, 5.0, 5.0)
			lab.ball_velocity = Vector3(0, -1, 0)
			lab.side_contacts[0] = action
			if action == 3:
				bot.incoming_action = 2 # Block responds to an attack, not a serve.
				lab.ball_shot = lab.ReceiveCharge.shot("attack",0.65,"player")
				lab.ball.position = Vector3(0, 3.6, 2)
				lab.ball_velocity = Vector3(0, 0, -6)
				lab.side_contacts[0] = 0
				lab.side_contacts[1] = 0
			bot.replan()
		check(bot.active_action == action and bot.actors[action + (4 if action == 3 else 0)].visible, "Each action bot must intercept only its eligible touch")
		for frame in range(240):
			if not lab.ball_active or bot.total_contacts > 0:
				break
			lab._tick_ball(1.0 / 120.0)
		check(bot.total_contacts > 0 and bot.last_action == action, "Each enabled action bot must make a real ball contact")
		bot.toggle(action, action == 3)
		check(not bot.actors[action + (4 if action == 3 else 0)].visible and bot.active_action == -1, "Disabled bot must disappear and relinquish intercept")
		lab._reset()
	bot.toggle(3)
	check(bot.settings[3].enabled, "Home blocker can now be enabled")
	bot.toggle(3)
	bot.toggle(0, true)
	check(bot.settings[(0) + 4].enabled and not bot.settings[0].enabled, "Away receiver toggles independently")
	bot.toggle(0, true)
	lab.player.position = Vector3(2, 0, 4)
	var debug_key := InputEventKey.new()
	debug_key.pressed = true
	debug_key.keycode = KEY_F5
	lab._unhandled_input(debug_key)
	lab.player.position = Vector3(-2, 0, 7)
	lab._feed()
	var feed_time := 2.0
	var landing: Vector3 = lab.ball.position + lab.ball_velocity * feed_time + Vector3.DOWN * lab.GRAVITY * feed_time * feed_time * 0.5
	check(landing.distance_to(Vector3(2, 0.95, 4)) < 0.001, "F5 feed location persists when player moves")
	debug_key.keycode = KEY_F6
	lab._unhandled_input(debug_key)
	check(bot.set_target.distance_to(Vector3(-2, 3.8, 7)) < 0.001, "F6 explicitly designates set destination")
	debug_key.keycode = KEY_F7
	lab._unhandled_input(debug_key)
	check(not lab.debug_feed_locked, "F7 restores player-tracking feed")
	bot.toggle_all()
	lab._feed()
	var bot_actions_seen: Array[int] = []
	for frame in range(3600):
		if not lab.ball_active:
			lab._feed()
		lab._tick_ball(1.0 / 120.0)
		if bot.last_action >= 0 and not bot.last_action in bot_actions_seen:
			bot_actions_seen.append(bot.last_action)
	check(bot_actions_seen.has(0) and bot_actions_seen.has(1) and bot_actions_seen.has(2), "Receive/set/attack sustain practice; block reach is tested separately")
	check(bot.total_contacts > 12, "Enabled bots must sustain repeated camera-test contacts")
	bot.toggle_all()
	check(not bot.any_enabled() and bot.active_action == -1, "Toggle all off must release the ball to normal play")
	lab._reset()
	bot.toggle(1)
	bot.toggle(2)
	lab._feed()
	check(bot.active_action == -1, "Missing receive bot must leave first contact for player")
	lab.ball.position = lab.player.position + Vector3(0, 1.0, 0)
	lab.ball_velocity = Vector3(0, -1, 0)
	lab.locked_action = 0
	lab.locked_charge = 0.65
	lab.aim = Vector3(lab.player.position.x, 0, 3.5)
	lab._contact()
	check(lab.side_contacts[0] == 1, "Player receive must advance shared side count")
	check(bot.active_action == 1, "Setter bot must take second touch after player receive")
	for frame in range(400):
		if bot.last_action == 1 or not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120.0)
	check(bot.last_action == 1 and lab.side_contacts[0] == 2, "Bot set must advance the same counter as player contact")
	check(bot.active_action == 2, "Attack bot must wait for third touch")
	bot.toggle(2)
	check(bot.active_action == -1, "Disabled attacker must leave third touch for player")
	lab.ball.position = lab.player.position + Vector3.UP * (a.reach() - 0.2)
	lab.locked_action = 2
	lab._contact()
	check(lab.side_contacts[0] == 3, "Player may fill third contact after bot setter")
	check(bot.active_action == -1, "Setter cannot steal a fourth touch")
	lab._reset()
	lab.camera_rig.camera_mode = lab.ViewMode.BALL
	lab.ball_active = true
	lab.ball.position = lab.player.position + Vector3(3, 2, 1)
	lab.camera_rig.update_aim()
	lab.animation.update()
	check(absf(wrapf(lab.body.rotation.y - lab.camera_rig.facing_yaw, -PI, PI)) < 0.0001 and lab.camera_rig.facing_yaw == 0, "Ball View preserves deliberate facing despite ball behind athlete")
	lab.motion.jumped = true
	lab.motion.airborne_aim = Vector3.FORWARD
	lab.ball.position = lab.player.position + Vector3(-3, 3, -2)
	lab.camera_rig.update_aim()
	lab.animation.update()
	check(absf(wrapf(lab.body.rotation.y - lab.camera_rig.facing_yaw, -PI, PI)) < 0.0001 and lab.camera_rig.facing_yaw == 0, "Ball View airborne facing is not overwritten by ball tracking")
	check((lab.aim - Vector3(lab.player.position.x, 0, lab.player.position.z)).normalized().is_equal_approx(Vector3.FORWARD), "Airborne ball-facing must preserve committed shot aim")
	lab._reset()
	lab.ball_active = true
	lab.locked_action = 0
	lab.ball.position = lab.player.position + Vector3(0.98, 1.0, 0)
	check(lab._can_contact(), "Expanded hitbox must accept a slightly wider receive")
	lab._remember_contacts(0.0)
	lab.ball.position.x += 0.6
	check(lab._can_contact(), "Contact grace must persist briefly after leaving the volume")
	lab._remember_contacts(0.11)
	check(not lab._can_contact(), "Contact grace must expire instead of allowing remote contacts indefinitely")
	check(lab._hurtbox_definition(0).size.x > 0 and lab._hurtbox_definition(3).size.y > 0, "Each action must define an authoritative confirmation hurtbox")
	print("PROTOTYPE CHECKS: %d passed / %d total" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)

func mouse_button(which: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = pressed
	return event
