class_name AthleteMotor
extends RefCounted

## Owns motion state. LabSession schedules updates and composes peers.
const SpikeStage := preload("res://scripts/spike_stage.gd")
const Approach = preload("res://scripts/approach_run.gd")
const Flight = preload("res://vendor/vwm/ball_flight_model.gd")
const GRAVITY = Flight.DEFAULT_GRAVITY_MPS2
const SPIKE_LATERAL_RETENTION := 0.02
const SPIKE_MOMENTUM_CONVERSION := 0.495
const QUICK_STEP_COOLDOWN_EXPLORE := 5.0
const QUICK_STEP_COOLDOWN_RALLY := 8.0
const DOUBLE_TAP_WINDOW := 0.28
const QUICK_STEP_TIME := 0.18

var lab: LabSession
var attack_energy_conversion := true
var generic_jump := false
var gait_cycle := 0.0
var approach_bound := false
var approach_bound_started := false
var approach_release_pending := false
var approach_release_progress := 0.0
var approach_plant_speed := 0.0
var approach_distance := 0.0
var approach_action := -1
var approach_direction := Vector3.ZERO
var approach_phase_name := ""
var jump_charge := -1.0
var jumped := false
var airborne_action := 0
var airborne_aim := Vector3.FORWARD
var last_jump_height := 0.0
var quick_step_cooldown := 0.0
var tap_times: Dictionary = {}
var quick_step_time := 0.0
var quick_step_velocity := Vector3.ZERO

func tick(dt: float, motion_scale: float) -> void:
	lab.action_endlag = maxf(0,lab.action_endlag-dt*lab.athlete.transition_rate())
	var jump_gravity := lab.athlete.jump_gravity(GRAVITY,lab.player.velocity.y > 0) if jumped else (GRAVITY*pow(lab.athlete.explosiveness_rate(),2) if approach_bound else GRAVITY)
	lab.animation.receive_pose_remaining = maxf(0, lab.animation.receive_pose_remaining - dt*lab.athlete.transition_rate())
	lab.feedback_time = maxf(0.0, lab.feedback_time - dt)
	lab.animation.roll_lock = maxf(0.0, lab.animation.roll_lock - dt*lab.athlete.transition_rate())
	lab.animation.dive_air_time = lab.animation.dive_air_time + dt if jumped and airborne_action == 0 else 0.0
	lab.animation.tick_dive_recovery(dt)
	lab.animation.tick_floor_recovery(dt)
	lab.animation.spike_air_time = lab.animation.spike_air_time + dt if jumped and airborne_action == 2 else 0.0
	if jumped and airborne_action == 2 and lab.animation.spike_swing_time >= 0.0:
		lab.animation.spike_swing_time += dt*(lab.athlete.transition_rate() if lab.animation.spike_hit_time >= 0 else 1.0)
		# The swing waits at contact for the ball; if the window closes without a hit it carries on regardless.
		if lab.animation.spike_hit_time < 0.0 and lab.animation.spike_swing_time > SpikeStage.STRIKE_SECONDS and lab.confirm_window <= 0.0:
			lab.animation.spike_hit_time = lab.animation.spike_swing_time
	lab.animation.set_air_time = lab.animation.set_air_time + dt if jumped and airborne_action == 1 else 0.0
	if not (jumped and airborne_action == 2):
		lab.animation.spike_swing_time = -1.0
		lab.animation.spike_hit_time = -1.0
		lab.animation.spike_contacted = false
		lab.animation.spike_swing_yaw = 0.0
	quick_step_time = maxf(0.0, quick_step_time - dt)
	quick_step_cooldown = maxf(0.0, quick_step_cooldown - dt)
	var local_move := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	if lab.animation.roll_lock > 0.0 or lab.animation.dive_input_locked() or lab.animation.floor_input_locked():
		local_move = Vector3.ZERO
	var move := lab.camera_rig.movement_direction(local_move)
	lab.directional_input.sample(move, dt / motion_scale)
	var contact_locked := lab.ground_contact_locked()
	var locomotion := Vector3.ZERO if contact_locked else move
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT) and locomotion.length() > 0 and lab.athlete.stamina > 0 and jump_charge < 0
	var facing_right := Vector3.RIGHT.rotated(Vector3.UP,lab._contact_yaw())
	var strafe := absf(locomotion.dot(facing_right))
	var desired := locomotion * lab.athlete.speed() * lerpf(1.0,lab.athlete.strafe_factor(),strafe) * (1.32 if sprint else 1.0)
	if lab.animation.dive_recovery_time >= 0.0:
		desired *= 0.55
	var acceleration := lab.athlete.acceleration()
	if contact_locked:
		lab.player.velocity.x = 0.0
		lab.player.velocity.z = 0.0
	elif generic_jump and jump_charge >= 0 and not jumped:
		jump_charge = minf(1.0, jump_charge + dt / 0.8)
		approach_direction = move
		approach_phase_name = "TRAVEL JUMP / CHARGING"
		lab.player.velocity.x = move_toward(lab.player.velocity.x, desired.x * 0.45, dt * acceleration)
		lab.player.velocity.z = move_toward(lab.player.velocity.z, desired.z * 0.45, dt * acceleration)
	elif jump_charge >= 0 and not jumped:
		jump_charge = minf(1.0, jump_charge + dt * lab.athlete.explosiveness_rate() / Approach.DURATION)
		if move.length_squared() > 0.01 and not approach_bound:
			approach_direction = approach_direction.lerp(move, minf(1.0, dt * 7.0)).normalized()
		approach_phase_name = Approach.STEP_NAMES[Approach.step_index(jump_charge)]
		if approach_bound:
			# The long first step has a real flight phase: momentum carries it
			# until landing instead of continuously sliding a planted foot.
			lab.player.velocity.y -= jump_gravity * dt
		elif lab.player.is_on_floor():
			var step_velocity := approach_direction * lab.athlete.speed() * Approach.speed_scale(jump_charge) * lab.athlete.explosiveness_rate()
			lab.player.velocity.x = step_velocity.x
			lab.player.velocity.z = step_velocity.z
			if not approach_bound_started and jump_charge >= 0.11 and jump_charge < 0.40 and approach_direction.length_squared() > 0.01:
				approach_bound = true
				approach_bound_started = true
				lab.player.velocity.y = sqrt(2.0 * GRAVITY * pow(lab.athlete.explosiveness_rate(),2) * 0.15)
				lab.player.velocity.x = approach_direction.x * lab.athlete.speed() * 1.10 * lab.athlete.explosiveness_rate()
				lab.player.velocity.z = approach_direction.z * lab.athlete.speed() * 1.10 * lab.athlete.explosiveness_rate()
				lab.athlete.spend(3.0)
		else:
			lab.player.velocity.y -= jump_gravity * dt
	elif lab.animation.floor_input_locked() and lab.player.is_on_floor():
		var floor_slide := Vector2(lab.player.velocity.x, lab.player.velocity.z).move_toward(Vector2.ZERO, lab.animation.floor_slide_decel * dt)
		lab.player.velocity.x = floor_slide.x
		lab.player.velocity.z = floor_slide.y
	elif lab.animation.dive_input_locked() and lab.player.is_on_floor():
		var slide := Vector2(lab.player.velocity.x, lab.player.velocity.z).move_toward(Vector2.ZERO, lab.animation.dive_slide_decel * dt)
		lab.player.velocity.x = slide.x
		lab.player.velocity.z = slide.y
	elif quick_step_time > 0.0 and lab.player.is_on_floor() and not jumped:
		lab.player.velocity.x = quick_step_velocity.x
		lab.player.velocity.z = quick_step_velocity.z
	elif lab.player.is_on_floor() and not jumped:
		lab.player.velocity.x = move_toward(lab.player.velocity.x, desired.x, dt * acceleration)
		lab.player.velocity.z = move_toward(lab.player.velocity.z, desired.z, dt * acceleration)
	else:
		lab.player.velocity.y -= jump_gravity * dt
	var before_move := lab.player.position
	lab.drills.update_one_way()
	var knock_travel: Vector3 = lab.contact_flow.displacement("player",dt)
	lab.player.velocity *= motion_scale
	lab.player.move_and_slide()
	lab.player.velocity /= motion_scale
	if knock_travel.length_squared() > 0:
		lab.player.move_and_collide(knock_travel)
	if not jumped and not approach_bound:
		var walked := Vector2(lab.player.position.x - before_move.x, lab.player.position.z - before_move.z).length()
		gait_cycle += walked / maxf(lab.athlete.stride() * 2.0, 0.1)
	if jump_charge >= 0:
		approach_distance += Vector2(lab.player.position.x - before_move.x, lab.player.position.z - before_move.z).length()
		if Approach.step_index(jump_charge) == 2:
			approach_plant_speed = maxf(approach_plant_speed, Vector2(lab.player.velocity.x, lab.player.velocity.z).length())
	lab.player.position.x = clampf(lab.player.position.x, -78, 78)
	lab.player.position.z = clampf(lab.player.position.z, -78, 78)
	if lab.player.is_on_floor() and jumped:
		lab.action_endlag = maxf(lab.action_endlag,0.12)
		jumped = false
		lab.animation.begin_dive_recovery()
	if approach_bound and lab.player.is_on_floor():
		approach_bound = false
		if approach_release_pending:
			jump_charge = approach_release_progress
			approach_release_pending = false
			takeoff()
	if sprint:
		lab.athlete.spend(dt * (10.0 if lab.ball_active or lab.station.running() else 3.0))
	lab.athlete.recover(dt, move.length() < 0.1 and lab.player.is_on_floor() and jump_charge < 0)
	if jump_charge >= 0:
		lab.athlete.spend(dt * 3.0)
		if jump_charge >= (1.0 if generic_jump else Approach.LAUNCH_START):
			takeoff()
	if lab.charging:
		lab.charge = minf(1.0, lab.charge + dt / 0.85)

func note_direction_tap(event: InputEventKey) -> void:
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var directions := {KEY_W: Vector3(0, 0, -1), KEY_S: Vector3(0, 0, 1), KEY_A: Vector3(-1, 0, 0), KEY_D: Vector3(1, 0, 0)}
	if not directions.has(code):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if tap_times.has(code) and now - float(tap_times[code]) <= DOUBLE_TAP_WINDOW:
		tap_times.erase(code)
		quick_step(directions[code])
	else:
		tap_times[code] = now

func quick_step(tapped: Vector3 = Vector3(0, 0, -1)) -> void:
	if lab.ground_contact_locked() or lab.paused or not lab.athlete.has_trait("speed_quick_step") or not (lab.armed or lab.charging) or jumped or jump_charge >= 0.0 or not lab.player.is_on_floor() or lab.animation.roll_lock > 0.0:
		return
	if quick_step_cooldown > 0.0:
		lab._message("Quick Step ready in %.1fs" % quick_step_cooldown)
		return
	var cost := lab.athlete.quick_step_stamina_cost()
	if lab.athlete.exhausted or lab.athlete.stamina < cost:
		lab._message("Quick Step needs more Stamina.")
		return
	# Combine the tapped key with any other held direction, snapped to eight compass directions.
	var local := tapped + Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))) * 0.5
	var snapped := roundf(atan2(local.x, local.z) / (PI / 4.0)) * (PI / 4.0)
	var direction := lab.camera_rig.movement_direction(Vector3(sin(snapped), 0, cos(snapped)))
	quick_step_velocity = direction.normalized() * maxf(lab.athlete.speed() * 2.2, 7.0)
	quick_step_time = QUICK_STEP_TIME
	var in_rally: bool = lab.ball_active or lab.station.running() or lab.drills.running()
	quick_step_cooldown = QUICK_STEP_COOLDOWN_RALLY if in_rally else QUICK_STEP_COOLDOWN_EXPLORE
	lab.athlete.spend(cost, LabAthlete.QUICK_STEP_HP)
	lab._message("QUICK STEP / cooldown %ds" % int(quick_step_cooldown))

func begin_jump() -> void:
	if lab.is_benched():
		return
	if lab.ground_contact_locked():
		return
	if lab.charging:
		lab.locked_action = lab.selected
		lab.locked_charge = lab.charge if lab.charge > 0.13 else lab._default_charge()
		lab.charging = false
		lab.armed = true
	if lab.armed or lab.ball_active or lab.station.running() or lab.drills.running():
		begin_approach()
	else:
		generic_jump = true
		jump_charge = 0.0
		approach_bound = false
		approach_action = -1
		approach_direction = Vector3.ZERO

func travel_takeoff() -> void:
	if not lab.player.is_on_floor():
		jump_charge = -1
		generic_jump = false
		return
	var power := clampf(jump_charge, 0, 1)
	last_jump_height = lerpf(0.6, maxf(0.6, lab.athlete.explore_jump_max()), power)
	var flight_time := lab.athlete.jump_flight_time(last_jump_height,GRAVITY)
	var distance := lerpf(1.5, 5.5, power)
	var input_direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := lab.camera_rig.movement_direction(input_direction)
	lab.player.velocity = direction * distance / flight_time + Vector3.UP * lab.athlete.jump_velocity(last_jump_height,GRAVITY)
	jump_charge = -1
	airborne_action = -1
	airborne_aim = Vector3(-sin(lab.camera_rig.facing_yaw), 0, -cos(lab.camera_rig.facing_yaw))
	jumped = true
	lab.armed = false
	lab.charging = false
	lab.contact_flow.consume_jump("player")
	lab.athlete.spend(5.0)
	lab._message("TRAVEL JUMP / %.1fm high / %.1fm distance" % [last_jump_height, distance if direction.length_squared() > 0 else 0.0])

func begin_approach() -> void:
	generic_jump = false
	jump_charge = 0.0
	approach_action = lab.locked_action if lab.armed else lab.selected
	approach_distance = 0.0
	approach_plant_speed = 0.0
	approach_bound = false
	approach_bound_started = false
	approach_release_pending = false
	var input_direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	approach_direction = lab.camera_rig.movement_direction(input_direction)
	approach_phase_name = Approach.STEP_NAMES[0]

func takeoff() -> void:
	if generic_jump:
		travel_takeoff()
		return
	var action := approach_action if approach_action >= 0 else (lab.locked_action if lab.armed else lab.selected)
	if not lab.player.is_on_floor() and not (approach_bound and action == 0):
		if approach_bound:
			# A Set/Block/Spike release during the bound buffers its plant.
			approach_release_pending = true
			approach_release_progress = jump_charge
			return
		jump_charge = -1
		approach_action = -1
		return
	approach_bound = false
	approach_release_pending = false
	lab.camera_rig.update_aim()
	var progress := clampf(jump_charge, 0, 1)
	airborne_action = approach_action if approach_action >= 0 else (lab.locked_action if lab.armed else lab.selected)
	var base_jump := lab.athlete.leap(1.0, 1.0)
	var jump_factor := Approach.jump_factor(airborne_action, progress)
	var run_quality := clampf(approach_distance / (lab.athlete.stride() * 2.0), 0.0, 1.0)
	if airborne_action == 2:
		jump_factor = lerpf(0.60, jump_factor, run_quality)
	last_jump_height = base_jump * jump_factor
	airborne_aim = (lab.aim - lab.player.position).normalized()
	airborne_aim.y = 0
	airborne_aim = airborne_aim.normalized()
	lab.player.velocity.y = sqrt(2.0 * GRAVITY * last_jump_height)
	if airborne_action == 0:
		var quality := Approach.dive_quality(progress)
		var dive_direction := approach_direction
		if dive_direction.length_squared() < 0.01:
			dive_direction = Vector3(lab.player.velocity.x, 0, lab.player.velocity.z).normalized()
		if dive_direction.length_squared() < 0.01:
			dive_direction = airborne_aim
		last_jump_height = lerpf(0.16, 0.32, quality)
		lab.player.velocity.y = sqrt(2.0 * GRAVITY * last_jump_height)
		lab.animation.dive_flight_time = 2.0 * lab.player.velocity.y / GRAVITY
		lab.animation.dive_world_direction = dive_direction
		lab.animation.dive_turn_total = lab.animation.dive_turn_for(dive_direction, lab.animation.dive_base_yaw)
		lab.animation.dive_launched = true
		lab.animation.dive_quality_value = quality
		var dive_speed := lab.athlete.speed() * lerpf(1.05, 1.85, quality) * lab.athlete.explosiveness_rate() * lab.athlete.low_stamina_factor()
		lab.player.velocity.x = dive_direction.x * dive_speed
		lab.player.velocity.z = dive_direction.z * dive_speed
		if not lab.armed:
			lab.locked_charge = 0.35 + 65.0 / 250.0
		lab.armed = true
		lab.locked_action = 0
		lab._message("DIVE / " + ("TIMED FIRST STEP" if quality > 0.7 else "EARLY / LATE RELEASE"))
	elif airborne_action == 2:
		# Redirect the run into the plant, including momentum already arrested
		# during the closing step. Only the Attack takeoff uses this transfer.
		var horizontal_speed := Vector2(lab.player.velocity.x, lab.player.velocity.z).length()
		var transfer_speed := minf(maxf(horizontal_speed, approach_plant_speed)/lab.athlete.explosiveness_rate(), lab.athlete.speed() * 1.4)
		var converted_energy := transfer_speed * transfer_speed * (1.0 - SPIKE_LATERAL_RETENTION * SPIKE_LATERAL_RETENTION) * SPIKE_MOMENTUM_CONVERSION
		if attack_energy_conversion:
			lab.player.velocity.y = sqrt(lab.player.velocity.y * lab.player.velocity.y + converted_energy)
			last_jump_height = lab.player.velocity.y * lab.player.velocity.y / (2.0 * GRAVITY)
		lab.player.velocity.x *= SPIKE_LATERAL_RETENTION
		lab.player.velocity.z *= SPIKE_LATERAL_RETENTION
		lab.animation.spike_flight_time = 2.0 * lab.player.velocity.y / GRAVITY
		lab.animation.spike_swing_time = -1.0
		lab.animation.spike_hit_time = -1.0
		lab.animation.spike_contacted = false
		lab.animation.spike_swing_yaw = 0.0
	else:
		# Jump Set and Block Jump retain their existing lateral carry.
		lab.player.velocity.x *= 0.38
		lab.player.velocity.z *= 0.38
		if airborne_action == 1:
			lab.animation.set_flight_time = 2.0 * lab.player.velocity.y / GRAVITY
	# Explosiveness changes ascent time without changing the resolved jump height.
	lab.player.velocity.y = lab.athlete.jump_velocity(last_jump_height,GRAVITY)
	if airborne_action == 0:
		lab.animation.dive_flight_time = lab.athlete.jump_flight_time(last_jump_height,GRAVITY)
	elif airborne_action == 1:
		lab.animation.set_flight_time = lab.athlete.jump_flight_time(last_jump_height,GRAVITY)
	elif airborne_action == 2:
		lab.animation.spike_flight_time = lab.athlete.jump_flight_time(last_jump_height,GRAVITY)
	if airborne_action != 0:
		lab.contact_flow.consume_jump("player")
	lab.athlete.spend(lab.athlete.jump_stamina_cost())
	jump_charge = -1
	approach_action = -1
	jumped = true
	approach_phase_name = Approach.STEP_NAMES[3]
	if airborne_action == 0:
		lab._confirm_action(0.65)


func _init(session: LabSession) -> void:
	lab = session
