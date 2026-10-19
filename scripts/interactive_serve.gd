extends Node3D

enum State { IDLE, TOSS, SWING, FLIGHT, CHANNEL }
const HOLD_THRESHOLD := 0.18
const CHANNEL_SECONDS := 1.0
var input_held := false
var held_time := 0.0
var lab: Node3D
var state := State.IDLE
var toss_time := 0.0
var swing_time := 0.0
var follow_time := 0.0
var last_hand := Vector3.ZERO
var evidence: Dictionary = {}
var main_court := false
var hand_volume: MeshInstance3D
const HAND_RADIUS := 0.28
const SWING_DURATION := 0.24

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	hand_volume = lab.sphere(self, HAND_RADIUS, Vector3.ZERO, Color("ffb46e"))
	hand_volume.material_override = lab.debug_material(Color("ffb46e"), 0.15)
	hand_volume.hide()

func tossing() -> bool:
	return state in [State.TOSS, State.SWING, State.CHANNEL]

func clear() -> void:
	state = State.IDLE
	input_held = false
	held_time = 0
	follow_time = 0
	hand_volume.hide()

func input_press() -> void:
	var starting: bool = state in [State.IDLE, State.FLIGHT] and not lab.ball_active
	press()
	input_held = starting and state == State.TOSS
	held_time = 0.0

func release() -> void:
	input_held = false
	if state == State.CHANNEL:
		clear()
		lab.ball_active = false
		lab._message("Serve channel cancelled / hold E to complete, or tap E to toss")

func channeling() -> bool:
	return state == State.CHANNEL

func press() -> void:
	if lab.athlete.exhausted or lab.is_benched():
		lab._message("Cannot serve while Exhausted or Benched")
		return
	if lab.paused or lab.station.running() or lab.drills.running() or lab.pepper.active():
		return
	if state == State.TOSS:
		state = State.SWING
		swing_time = 0
		apply_pose()
		last_hand = hand_position()
		lab._message("SERVE / swing / meet the toss with your striking hand")
		return
	if lab.ball_active or lab.jumped or lab.jump_charge >= 0:
		return
	lab._update_aim()
	lab._update_pose()
	lab.ball_shot = {}
	state = State.TOSS
	toss_time = 0
	evidence = {}
	main_court = absf(lab.player.position.x) <= 6 and lab.player.position.z > 0.35 and lab.player.position.z <= 15
	lab.armed = false
	lab.charging = false
	lab.contacts = 0
	lab.side_contacts.fill(0)
	lab.training_bots.active_action = -1
	lab.training_bots.incoming_action = -1
	lab.training_bots.last_was_block = false
	lab.trail_points.clear()
	lab.contact_memory.fill(0.0)
	var sign := -1.0 if lab.dominant_hand == "Left" else 1.0
	var shoulder: Vector3 = lab.arms[0 if sign < 0 else 1].position * (float(lab.athlete.build.height) / lab.visual_rig_height)
	var local := Vector3(shoulder.x, float(lab.athlete.build.height) * 0.68, -0.55)
	lab.ball.position = lab.player.position + local.rotated(Vector3.UP, lab.facing_yaw)
	lab.ball_velocity = Vector3.UP * 5.2 + Vector3.FORWARD.rotated(Vector3.UP, lab.facing_yaw) * 0.18
	lab.ball_active = true
	lab.outgoing = false
	lab._message("TOSS / E again to strike / early rising contact lofts higher; late contact drives flatter")

func hand_position() -> Vector3:
	var arm: Node3D = lab.arms[0 if lab.dominant_hand == "Left" else 1]
	return arm.get_node("Elbow/Wrist/ContactAnchor").global_position

func apply_pose() -> void:
	if not tossing() and (lab.armed or lab.jumped or lab.jump_charge >= 0):
		follow_time = 0
	if not tossing() and follow_time <= 0:
		return
	var dominant := 0 if lab.dominant_hand == "Left" else 1
	var arm: Node3D = lab.arms[dominant]
	var phase := clampf(swing_time / SWING_DURATION, 0, 1) if state == State.SWING else (1.0 if follow_time > 0 else 0.0)
	arm.rotation = Vector3(lerpf(3.45, 1.65, phase), 0, 0)
	arm.get_node("Elbow").rotation = Vector3.ZERO
	lab.arms[1 - dominant].rotation.x = 1.15 if state == State.TOSS else 0.5

func tick(dt: float, previous_ball: Vector3) -> void:
	if tossing() and (lab.athlete.exhausted or lab.is_benched()):
		clear()
		lab.ball_active = false
		lab._message("Serve cancelled / Exhausted or Benched")
		return
	follow_time = maxf(0, follow_time - dt*lab.athlete.transition_rate())
	if input_held and state in [State.TOSS, State.CHANNEL]:
		held_time += dt
		if held_time >= HOLD_THRESHOLD:
			state = State.CHANNEL
			lab.ball.position = lab.player.position + Vector3(0, float(lab.athlete.build.height) * 0.72, -0.45).rotated(Vector3.UP, lab.facing_yaw)
			lab.ball_velocity = Vector3.ZERO
			lab._message("STANDING SERVE / hold E / %d%%" % roundi(clampf(held_time / CHANNEL_SECONDS, 0, 1) * 100))
			if held_time >= CHANNEL_SECONDS:
				basic_strike()
			return
	if not tossing():
		hand_volume.hide()
		return
	toss_time += dt
	if state == State.SWING:
		swing_time += dt
	apply_pose()
	var hand := hand_position()
	hand_volume.position = hand
	hand_volume.visible = lab.debug_volumes_visible
	if state == State.SWING:
		# Relative swept hand/ball motion, so a fast swing cannot tunnel through a toss.
		var a := previous_ball - last_hand
		var b: Vector3 = lab.ball.position - hand
		var delta := b - a
		var t := clampf(-a.dot(delta) / maxf(delta.length_squared(), 0.000001), 0, 1)
		if swing_time >= 0.025 and (a + delta * t).length() <= HAND_RADIUS + lab.Geometry.BALL_RADIUS:
			strike(hand)
		elif swing_time > SWING_DURATION:
			state = State.TOSS
			lab._message("Serve swing missed / reposition and E again before the toss falls")
	last_hand = hand

func strike(hand: Vector3) -> void:
	if lab.athlete.exhausted or lab.is_benched():
		return
	var incoming: Vector3 = lab.ball_velocity
	var camera_forward: Vector3 = -lab.camera.global_basis.z
	if lab.camera_mode == lab.ViewMode.BALL:
		var intentional_pitch: float = lab.view_pitch - 0.27
		camera_forward = Vector3(-sin(lab.facing_yaw) * cos(intentional_pitch), sin(intentional_pitch), -cos(lab.facing_yaw) * cos(intentional_pitch))
	var horizontal := Vector3(camera_forward.x, 0, camera_forward.z).normalized()
	if horizontal.length_squared() < 0.001:
		horizontal = Vector3.FORWARD.rotated(Vector3.UP, lab.facing_yaw)
	var camera_pitch := atan2(camera_forward.y, Vector2(camera_forward.x, camera_forward.z).length())
	var height_ratio: float = clampf((lab.ball.position.y - lab.player.position.y - float(lab.athlete.build.height) * 0.68) / 1.4, 0, 1)
	# At identical aim, a rising high toss leaves a higher trajectory than a falling one.
	var angle := clampf(22.0 + rad_to_deg(camera_pitch) * 0.7 + incoming.y * 3.5 + height_ratio * 5.0, -12, 72)
	var speed: float = (9.0 + 65.0 * 0.035) * lab.athlete.serve_speed_factor(lab._default_charge())*(1.0+0.12*lab.athlete.flow/100.0)
	lab.ball_velocity = horizontal * cos(deg_to_rad(angle)) * speed + Vector3.UP * sin(deg_to_rad(angle)) * speed
	lab.ball_shot = lab.ReceiveCharge.shot("serve", lab.athlete.effective_serve_charge(lab._default_charge()), "player")
	var sweet: bool = hand.distance_to(lab.ball.position) <= HAND_RADIUS * 0.60 + lab.Geometry.BALL_RADIUS
	evidence = {"mode": "tap", "sweet": sweet, "charge": lab.athlete.effective_serve_charge(lab._default_charge()), "hand": hand, "point": lab.ball.position, "incoming_velocity": incoming, "outgoing_velocity": lab.ball_velocity, "angle_degrees": angle, "toss_time": toss_time, "swing_time": swing_time}
	evidence.make_read_only()
	_finish_strike(incoming, sweet)

func basic_strike() -> void:
	if lab.athlete.exhausted or lab.is_benched():
		return
	var incoming: Vector3 = lab.ball_velocity
	input_held = false
	# A completed basic channel chooses a legal target, while preserving lateral aim.
	if main_court and not lab.training_bots.away_enabled[0]:
		lab.training_bots.toggle(0, true)
	lab._resize_court()
	state = State.SWING
	swing_time = SWING_DURATION
	apply_pose()
	lab.ball.position = hand_position()
	var origin: Vector3 = lab.ball.position
	var side := 1.0 if lab.player.position.z >= 0 else -1.0
	var forward := Vector3.FORWARD.rotated(Vector3.UP, lab.facing_yaw)
	var depth: float = lab.court_half_depth
	var width: float = lab.court_half_width
	var depth_fraction := clampf(0.65+0.4*(lab.athlete.effective_serve_charge(lab._default_charge())-lab._default_charge())+0.08*lab.athlete.flow/100.0,0.4,0.9)
	var target := Vector3(clampf(origin.x + forward.x / maxf(0.15, -forward.z * side) * (absf(origin.z) + depth * depth_fraction), -width + 0.4, width - 0.4), 0.105, -side * depth * depth_fraction)
	var apex := maxf(4.3, origin.y + 1.5)
	var duration := 0.0
	var velocity := Vector3.ZERO
	var net_height := 0.0
	for attempt in range(20):
		var up := sqrt(2.0 * lab.GRAVITY * (apex - origin.y))
		duration = (up + sqrt(up * up + 2 * lab.GRAVITY * (origin.y - target.y))) / lab.GRAVITY
		velocity = (target - origin) / duration + Vector3.UP * lab.GRAVITY * duration * 0.5
		var fraction := clampf(origin.z / (origin.z - target.z), 0, 1)
		var crossing_time := duration * fraction
		net_height = origin.y + velocity.y * crossing_time - lab.GRAVITY * crossing_time * crossing_time * 0.5
		if net_height >= 2.43 + lab.Geometry.BALL_RADIUS + 0.2:
			break
		apex += 0.5
	lab.ball_velocity = velocity
	lab.ball_shot = lab.ReceiveCharge.shot("serve", lab.athlete.effective_serve_charge(lab._default_charge()), "player")
	evidence = {"mode": "held", "sweet": false, "charge": lab.athlete.effective_serve_charge(lab._default_charge()), "hand": origin, "point": origin, "target": target, "duration": duration, "net_height": net_height, "incoming_velocity": incoming, "outgoing_velocity": velocity, "channel_seconds": held_time}
	evidence.make_read_only()
	_finish_strike(incoming, false)
	lab._message("STANDING SERVE / safe arc into the opposing court")

func _finish_strike(incoming: Vector3, sweet: bool) -> void:
	state = State.FLIGHT
	follow_time = 0.22
	lab.outgoing = true
	lab.attempts += 1
	lab.athlete.spend(4)
	if main_court:
		if not lab.training_bots.away_enabled[0]:
			lab.training_bots.toggle(0, true)
		lab._resize_court()
		lab.training_bots.replan()
	lab._emit_external_impact("player_serve", 4, incoming, {"hit": true, "sweet": sweet})
	if evidence.get("mode", "") == "tap":
		lab._message("SERVE / physical hand contact / %.0f° launch / aim at a Pepper opponent" % evidence.angle_degrees)
