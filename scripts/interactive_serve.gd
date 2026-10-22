extends Node3D

enum State { IDLE, TOSS, SWING, FLIGHT, CHANNEL, TOSS_CHARGE }
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
# With the ball economy on: holding E charges the toss for this long; release tosses between the two speeds.
# The serve now meets the toss on its way down through the hurtbox, so the launch angle is measured from how fast that fall normally is: a ball
# struck earlier in its fall, or still rising, leaves higher, one struck later leaves lower.
const TYPICAL_FALL_SPEED := -3.7
const TOSS_FORWARD_SPEED := 1.6 # the toss travels forward, toward where the serve is going, not straight up
const TOSS_CHARGE_SECONDS := 1.0
const TOSS_SPEED_MIN := 5.2
const TOSS_SPEED_MAX := 8.6
var toss_charge := 0.0
# R during a serve: the float serve (needs the Float Serve Trait). Chosen before the strike, used up by it.
var float_mode := false
const FLOAT_SWEET_SCALE := 1.25 # the float's sweetspot is slightly larger; it grades how centred the contact is, not its timing
const FLOAT_PACE := 0.80        # the float's pace cost, eased back by how true the contact is (provisional)
const FLOAT_PACE_RECOVERY := 0.15
# Jump serve: a toss high enough to be worth jumping for turns the jump into an approach run. The strike is then a jump-serve:
# its pace is JUMP_SERVE_PACE of an equivalent clean spike (same charge, attributes and resources, before action-specific modifiers) and it leaves
# higher. Serve Velocity adds effective charge before that 65%, which is why its nodes grant more than Spike Velocity's.
const JUMP_SERVE_PACE := 0.65
const JUMP_SERVE_ANGLE_BONUS := 10.0
const JUMP_SERVE_CLEARANCE := 0.5  # the toss must peak this far above the athlete's standing reach
const JUMP_SERVE_MIN_TIME := 0.9   # and stay above that reach-plus-clearance long enough to run up and jump
# The serve's swing runs on the shared swing clock: the arm reaches its extension at Swing.PEAK and the swing is live until the late window closes.
const Swing := preload("res://scripts/swing_clock.gd")
const SWING_DURATION := Swing.PEAK + Swing.POWER_HALF_WINDOW
# Zone and timing scale the serve's pace: a clean strike inside the power window is full pace, a scraped or badly timed one is not.
const ZONE_FACTOR := {"SWEET SPOT": 1.0, "FAIR": 1.0, "WEAK": 0.82, "SOUR SPOT": 0.51}
const FORM_FACTOR := {"roll": 0.75, "power": 1.0, "push": 0.65}
# The serving hurtbox: a ball-sized region centred where the striking arm is at its forward-and-up-most extension (the spiking hurtbox's
# sweetspot), tilted with the aim like every hurtbox. It is most effective at the centre and radially less effective outward.
const SERVE_SWEET_RADIUS := 0.16
const SERVE_FAIR_RADIUS := 0.34
const SERVE_WEAK_RADIUS := 0.50
const SERVE_BOX_RADIUS := 0.60

func serve_center(shape: Dictionary) -> Vector3:
	return shape.center + lab.Geometry.sector_point(shape, 0.74, 67.5, 0)

# Predicted from the live ball: how high the toss will peak, and how long it stays above the height worth jumping for.
func toss_prediction() -> Dictionary:
	var target: float = lab.player.position.y + lab.athlete.reach() + JUMP_SERVE_CLEARANCE
	var g: float = lab.GRAVITY
	var y0: float = lab.ball.position.y
	var vy: float = lab.ball_velocity.y
	var apex := y0 + (vy * vy / (2.0 * g) if vy > 0.0 else 0.0)
	var discriminant := vy * vy - 2.0 * g * (target - y0)
	var time_above := 0.0
	if discriminant > 0.0:
		var root := sqrt(discriminant)
		time_above = maxf(0.0, (vy + root) / g - maxf((vy - root) / g, 0.0))
	return {"apex": apex, "target": target, "time_above": time_above}

# Seconds until the live ball next passes through the serving hurtbox's centre height on its way down; the swing needs Swing.PEAK of that to arrive.
func time_to_center() -> float:
	var center: Vector3 = lab.hurtbox_center_local(serve_center(lab._raw_hurtbox_definition(2)))
	var g: float = lab.GRAVITY
	var vy: float = lab.ball_velocity.y
	var drop: float = lab.ball.position.y - (lab.player.position.y + center.y)
	var discriminant := vy * vy + 2.0 * g * drop
	return (vy + sqrt(maxf(discriminant, 0.0))) / g

func jump_serve_ready() -> bool:
	if state != State.TOSS or not lab.ball_active or lab.motion.jumped:
		return false
	var prediction := toss_prediction()
	return float(prediction.apex) >= float(prediction.target) and float(prediction.time_above) >= JUMP_SERVE_MIN_TIME

func toggle_float() -> void:
	if not lab.athlete.has_access(lab.FLOAT_SERVE_TRAIT):
		lab._message("Float Serve needs the Float Serve Trait")
		return
	float_mode = not float_mode
	lab._message("FLOAT SERVE / a centred contact floats" if float_mode else "TOPSPIN SERVE")

static func serve_zone(distance: float, sweet_scale: float = 1.0) -> String:
	if distance <= SERVE_SWEET_RADIUS * sweet_scale: return "SWEET SPOT"
	if distance <= SERVE_FAIR_RADIUS: return "FAIR"
	if distance <= SERVE_WEAK_RADIUS: return "WEAK"
	return "SOUR SPOT" if distance <= SERVE_BOX_RADIUS else "MISS"

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	hand_volume = lab.world_builder.sphere(self, HAND_RADIUS, Vector3.ZERO, Color("ffb46e"))
	hand_volume.material_override = lab.world_builder.debug_material(Color("ffb46e"), 0.15)
	hand_volume.hide()

func tossing() -> bool:
	return state in [State.TOSS, State.SWING, State.CHANNEL]

func clear() -> void:
	float_mode = false
	state = State.IDLE
	input_held = false
	held_time = 0
	follow_time = 0
	hand_volume.hide()

func input_press() -> void:
	if lab.inventory.enabled and state in [State.IDLE, State.FLIGHT] and not lab.ball_active:
		_start_toss_charge()
		return
	var starting: bool = state in [State.IDLE, State.FLIGHT] and not lab.ball_active
	press()
	input_held = starting and state == State.TOSS
	held_time = 0.0

func release() -> void:
	if state == State.TOSS_CHARGE:
		input_held = false
		var charge := clampf(toss_charge / TOSS_CHARGE_SECONDS, 0.0, 1.0)
		toss_charge = 0.0
		state = State.IDLE
		if lab.inventory.consume():
			_begin_toss(lerpf(TOSS_SPEED_MIN, TOSS_SPEED_MAX, charge))
		return
	input_held = false
	if state == State.CHANNEL:
		clear()
		lab.ball_active = false
		lab._message("Serve channel cancelled / hold E to complete, or tap E to toss")

func channeling() -> bool:
	return state == State.CHANNEL

# A toss can begin: the same conditions press() uses, without starting anything.
func _can_begin() -> bool:
	if lab.athlete.exhausted or lab.is_benched():
		lab._message("Cannot serve while Exhausted or Benched")
		return false
	if lab.paused or lab.station.running() or lab.drills.running() or lab.pepper.active():
		return false
	if lab.ball_active or lab.motion.jumped or lab.motion.jump_charge >= 0:
		return false
	return true

# Ball economy: E starts charging the toss, but only with a ball in hand.
func _start_toss_charge() -> void:
	if not _can_begin():
		return
	if not lab.inventory.held:
		lab._message("No ball / pick one up (I) at a cart or from the ground")
		return
	state = State.TOSS_CHARGE
	toss_charge = 0.0
	input_held = true
	lab._message("TOSS / hold E to charge / release to toss")

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
	if lab.ball_active or lab.motion.jumped or lab.motion.jump_charge >= 0:
		return
	if lab.inventory.enabled:
		# Without a charge step (a direct press) the economy still needs the ball and tosses at the base speed.
		if not lab.inventory.consume():
			lab._message("No ball / pick one up (I) at a cart or from the ground")
			return
	_begin_toss(TOSS_SPEED_MIN)

func _begin_toss(up_speed: float) -> void:
	if lab.inventory.enabled:
		lab.inventory.free_ball = true
		lab.inventory.pending_origin = lab.inventory.release_origin()
		lab.inventory.pending_opposing = lab.inventory.pending_origin >= 0 and is_instance_valid(lab.ball_carts) and lab.ball_carts.carts[lab.inventory.pending_origin].team != lab.player_team()
	lab.prepare_serve_context()
	if not lab.training_bots.ready_to_serve():
		if lab.inventory.enabled:
			lab.inventory.give() # the toss did not start: the ball stays in hand
			lab.inventory.origin_cart = lab.inventory.pending_origin
		lab._message("Wait for bots to clear the net")
		return
	lab.refresh_bot_rally()
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab.ball_shot = {}
	state = State.TOSS
	toss_time = 0
	evidence = {}
	main_court = absf(lab.player.position.x-lab.court_center.x) <= lab.court_half_width+1.5 and absf(lab.player.position.z) > 0.35 and absf(lab.player.position.z) <= lab.court_half_depth+6
	lab.armed = false
	lab.auto_preparation.clear()
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
	# The toss travels forward as well as up, and is released far enough behind the serving hurtbox's centre that the falling ball comes down
	# through it.
	var center: Vector3 = lab.hurtbox_center_local(serve_center(lab._raw_hurtbox_definition(2)))
	var release_height: float = float(lab.athlete.build.height) * 0.68
	var gravity: float = lab.GRAVITY
	var discriminant := up_speed * up_speed - 2.0 * gravity * (center.y - release_height)
	var fall_time := (up_speed + sqrt(maxf(discriminant, 0.0))) / gravity if discriminant > 0.0 else up_speed / gravity
	var local := Vector3(center.x, release_height, center.z + TOSS_FORWARD_SPEED * fall_time)
	lab.ball.position = lab.player.position + local.rotated(Vector3.UP, lab.camera_rig.facing_yaw)
	lab.ball_velocity = Vector3.UP * up_speed + Vector3.FORWARD.rotated(Vector3.UP, lab.camera_rig.facing_yaw) * TOSS_FORWARD_SPEED
	lab.ball_active = true
	lab.outgoing = false
	lab._message("TOSS / E again to strike / early rising contact lofts higher; late contact drives flatter")

func hand_position() -> Vector3:
	var arm: Node3D = lab.arms[0 if lab.dominant_hand == "Left" else 1]
	return arm.get_node("Elbow/Wrist/ContactAnchor").global_position

func apply_pose() -> void:
	if not tossing() and (lab.armed or lab.motion.jumped or lab.motion.jump_charge >= 0):
		follow_time = 0
	if not tossing() and follow_time <= 0:
		return
	var dominant := 0 if lab.dominant_hand == "Left" else 1
	var arm: Node3D = lab.arms[dominant]
	var phase := clampf(swing_time / SWING_DURATION, 0, 1) if state == State.SWING else (1.0 if follow_time > 0 else 0.0)
	arm.rotation = Vector3(lerpf(3.45, 1.65, Swing.extension_at(phase * SWING_DURATION) if state == State.SWING else phase), 0, 0)
	arm.get_node("Elbow").rotation = Vector3.ZERO
	lab.arms[1 - dominant].rotation.x = 1.15 if state == State.TOSS else 0.5

# The toss charge builds every frame the key is held (the ball is not in the air yet, so the ball tick does not run).
func tick_toss_charge(dt: float) -> void:
	if state != State.TOSS_CHARGE:
		return
	if lab.athlete.exhausted or lab.is_benched() or lab.paused:
		state = State.IDLE
		input_held = false
		toss_charge = 0.0
		lab._message("Toss cancelled")
		return
	toss_charge = minf(toss_charge + dt, TOSS_CHARGE_SECONDS)
	lab._message("TOSS / %d%% / release to toss" % roundi(toss_charge / TOSS_CHARGE_SECONDS * 100.0))

# Contact actions may play a tossed ball (not mid-swing or channel) when the ball economy is on; only a Serve starts a rally.
func contacts_allowed() -> bool:
	return not tossing() or (lab.inventory.enabled and state == State.TOSS)

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
			lab.ball.position = lab.player.position + Vector3(0, float(lab.athlete.build.height) * 0.72, -0.45).rotated(Vector3.UP, lab.camera_rig.facing_yaw)
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
		# The ball is struck when it is in the serving hurtbox (the spiking half-pipe, tilted with the aim). The path since the last frame is
		# swept, so a fast ball cannot skip through it. What it is graded on is where in the box, and when on the swing clock.
		var shape: Dictionary = lab._raw_hurtbox_definition(2)
		var struck := false
		for step in range(1, 5):
			var sample: Vector3 = previous_ball.lerp(lab.ball.position, float(step) / 4.0)
			var local: Vector3 = lab.local_contact_position_at(sample)
			if local.distance_to(serve_center(shape)) <= SERVE_BOX_RADIUS:
				# The arm has to have swept round to where the ball is; the ball's place in the box decides when that happens.
				var offset: Vector3 = local - shape.center
				var ball_angle := rad_to_deg(atan2(maxf(offset.y, 0.0), offset.x * float(shape.dominant_sign)))
				if Swing.arm_angle_at(swing_time) <= ball_angle:
					strike(hand, shape, local, sample)
					struck = true
					break
		if not struck and swing_time > SWING_DURATION:
			state = State.TOSS
			lab._message("Serve swing missed / reposition and E again before the toss falls")
	last_hand = hand

func strike(hand: Vector3, shape: Dictionary, local: Vector3, point: Vector3) -> void:
	if lab.athlete.exhausted or lab.is_benched():
		return
	var incoming: Vector3 = lab.ball_velocity
	var camera_forward: Vector3 = -lab.camera.global_basis.z
	if lab.camera_rig.camera_mode == lab.ViewMode.BALL:
		var intentional_pitch: float = lab.camera_rig.view_pitch - 0.27
		camera_forward = Vector3(-sin(lab.camera_rig.facing_yaw) * cos(intentional_pitch), sin(intentional_pitch), -cos(lab.camera_rig.facing_yaw) * cos(intentional_pitch))
	var horizontal := Vector3(camera_forward.x, 0, camera_forward.z).normalized()
	if horizontal.length_squared() < 0.001:
		horizontal = Vector3.FORWARD.rotated(Vector3.UP, lab.camera_rig.facing_yaw)
	var camera_pitch := atan2(camera_forward.y, Vector2(camera_forward.x, camera_forward.z).length())
	var height_ratio: float = clampf((lab.ball.position.y - lab.player.position.y - float(lab.athlete.build.height) * 0.68) / 1.4, 0, 1)
	# At identical aim, a rising high toss leaves a higher trajectory than a falling one.
	var angle := clampf(22.0 + rad_to_deg(camera_pitch) * 0.7 + (incoming.y - TYPICAL_FALL_SPEED) * 3.5 + height_ratio * 5.0, -12, 72)
	var offset := local.distance_to(serve_center(shape))
	var zone := serve_zone(offset, FLOAT_SWEET_SCALE if float_mode else 1.0)
	var floated: bool = float_mode and zone == "SWEET SPOT"
	var true_distance := offset / (SERVE_SWEET_RADIUS * FLOAT_SWEET_SCALE) # 0 at the centre, 1 at the edge of the float's sweetspot
	var form: String = Swing.form_at(swing_time)
	var sweet: bool = zone == "SWEET SPOT" and (floated or lab.Execution.sweet_active(2, swing_time))
	var contact_factor: float = float(ZONE_FACTOR.get(zone, 0.51)) * (1.0 if floated else float(FORM_FACTOR[form]))
	if floated:
		contact_factor *= FLOAT_PACE + FLOAT_PACE_RECOVERY * (1.0 - clampf(true_distance, 0.0, 1.0))
	var speed: float = (9.0 + 65.0 * 0.035) * lab.athlete.serve_speed_factor(lab._default_charge())*(1.0+0.12*lab.athlete.flow/100.0) * contact_factor
	var jumping: bool = lab.motion.jumped
	var spike_reference := 0.0
	if jumping:
		# 65% of the spike an equivalent clean contact would be: the spike's own pace formula at this charge, before spike-only modifiers.
		var hp_factor := lerpf(0.7, 1.0, lab.athlete.hp / 100.0)
		spike_reference = (6.0 + lab.athlete.effective_serve_charge(lab._default_charge()) * 7.0 + 65.0 * 0.02) * hp_factor * lab.ATTACK_DRIVE_FACTOR * lab.SPIKE_SPEED_MULTIPLIER
		speed = spike_reference * JUMP_SERVE_PACE * (1.0+0.12*lab.athlete.flow/100.0) * contact_factor
		angle = clampf(angle + JUMP_SERVE_ANGLE_BONUS, -12, 75)
	lab.ball_velocity = horizontal * cos(deg_to_rad(angle)) * speed + Vector3.UP * sin(deg_to_rad(angle)) * speed
	lab.ball_shot = lab.ReceiveCharge.shot("serve", lab.athlete.effective_serve_charge(lab._default_charge()), "player")
	lab.ball_shot = lab.contact_flow.decorate_serve(lab.ball_shot,"player")
	evidence = {"mode": "tap", "sweet": sweet, "zone": zone, "form": form, "contact_factor": contact_factor, "float": floated, "wobble": clampf(true_distance, 0.0, 1.0) if floated else 0.0, "charge": lab.athlete.effective_serve_charge(lab._default_charge()), "hand": hand, "point": lab.ball.position, "incoming_velocity": incoming, "outgoing_velocity": lab.ball_velocity, "angle_degrees": angle, "jump": jumping, "spike_reference_speed": spike_reference, "toss_time": toss_time, "swing_time": swing_time}
	evidence.make_read_only()
	_finish_strike(incoming, sweet)

func basic_strike() -> void:
	if lab.athlete.exhausted or lab.is_benched():
		return
	var incoming: Vector3 = lab.ball_velocity
	input_held = false
	# A completed basic channel chooses a legal target, while preserving lateral aim.
	if main_court and not lab.training_bots.is_enabled(0,-lab.player.position.z):
		lab.training_bots.ensure_receiver(lab.player.position.z < 0)
	lab._resize_court()
	state = State.SWING
	swing_time = SWING_DURATION
	apply_pose()
	lab.ball.position = hand_position()
	var origin: Vector3 = lab.ball.position
	var side := 1.0 if lab.player.position.z >= 0 else -1.0
	var forward := Vector3.FORWARD.rotated(Vector3.UP, lab.camera_rig.facing_yaw)
	var depth: float = lab.court_half_depth
	var width: float = lab.court_half_width
	var depth_fraction := clampf(0.65+0.4*(lab.athlete.effective_serve_charge(lab._default_charge())-lab._default_charge())+0.08*lab.athlete.flow/100.0,0.4,0.9)
	var target := Vector3(clampf(origin.x + forward.x / maxf(0.15, -forward.z * side) * (absf(origin.z) + depth * depth_fraction), lab.court_center.x-width+0.4, lab.court_center.x+width-0.4), 0.105, -side * depth * depth_fraction)
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
		if net_height >= lab.net_height + lab.Geometry.BALL_RADIUS + 0.2:
			break
		apex += 0.5
	lab.ball_velocity = velocity
	lab.ball_shot = lab.ReceiveCharge.shot("serve", lab.athlete.effective_serve_charge(lab._default_charge()), "player")
	lab.ball_shot = lab.contact_flow.decorate_serve(lab.ball_shot,"player")
	evidence = {"mode": "held", "sweet": false, "charge": lab.athlete.effective_serve_charge(lab._default_charge()), "hand": origin, "point": origin, "target": target, "duration": duration, "net_height": net_height, "incoming_velocity": incoming, "outgoing_velocity": velocity, "channel_seconds": held_time}
	evidence.make_read_only()
	_finish_strike(incoming, false)
	lab._message("STANDING SERVE / safe arc into the opposing court")

func _finish_strike(incoming: Vector3, sweet: bool) -> void:
	float_mode = false
	lab.inventory.free_ball = false # a Serve: now the ball starts a Pepper or Rally
	state = State.FLIGHT
	follow_time = 0.22
	lab.outgoing = true
	lab.attempts += 1
	lab.athlete.spend_resolved(float(lab.athlete.stamina_quote("serve").total))
	if main_court:
		if not lab.training_bots.is_enabled(0,-lab.player.position.z):
			lab.training_bots.ensure_receiver(lab.player.position.z < 0)
		lab._resize_court()
		lab.training_bots.replan()
	lab._emit_external_impact("player_serve", 4, incoming, {"hit": true, "sweet": sweet})
	if evidence.get("mode", "") == "tap":
		lab._message("SERVE / physical hand contact / %.0f° launch / aim at a Pepper opponent" % evidence.angle_degrees)
