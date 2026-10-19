class_name AthleteAnimation
extends RefCounted

## Owns animation state. LabSession schedules updates and composes peers.
const ReceivePose := preload("res://scripts/receive_pose.gd")
const ReceivePlatform := preload("res://scripts/receive_platform.gd")
const SpikeDirection := preload("res://scripts/spike_direction.gd")
const Geometry = preload("res://scripts/contact_geometry.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const DiveStage := preload("res://scripts/dive_stage.gd")
const DiveRecovery := preload("res://scripts/dive_recovery.gd")
const FloorRecovery := preload("res://scripts/floor_recovery.gd")
const PoseLibrary := preload("res://scripts/pose_library.gd")
const PoseSmoother := preload("res://scripts/pose_smoother.gd")
const SpikeStage := preload("res://scripts/spike_stage.gd")
const SetStage := preload("res://scripts/set_stage.gd")
const WingPose := preload("res://scripts/wing_pose.gd")
const Approach = preload("res://scripts/approach_run.gd")
const ViewMode = LabCamera.ViewMode
const ROLL_TIME := 0.9

var lab: LabSession
var receive_posture := "planted"
var receive_pose_remaining := 0.0
var receive_pose_contact := Vector3.ZERO
var roll_lock := 0.0
var dive_air_time := 0.0
var dive_applied_yaw := 0.0
var spike_air_time := 0.0
var spike_flight_time := 0.5
var spike_swing_time := -1.0   # seconds since the click started the strike; -1 while only loaded
var spike_hit_time := -1.0     # swing-clock time of the hit, or of the window closing
var spike_contacted := false
var set_air_time := 0.0
var set_flight_time := 0.5
var spike_swing_yaw := 0.0
var pose_smoother := PoseSmoother.new()
var pose_smoothing := true
var pose_frame_dt := 0.0
var pose_last_frame := -1
var dive_flight_time := 0.5
var dive_world_direction := Vector3.ZERO
var dive_launched := false
var dive_quality_value := 0.5
var dive_recovery_time := -1.0
var dive_recovery_dir := Vector2(0, 1)
var dive_recovery_root := Vector2.ZERO
var dive_recovery_flat := {}
var dive_turn_total := 0.0
var dive_turn_spine := 0.0
var dive_turn_neck := 0.0
var dive_base_yaw := 0.0
var dive_slide_decel := 0.0
var floor_recovery_name := ""
var floor_recovery_time := -1.0
var floor_recovery_scale := 1.0     # DI penalty factor: 0.65 helped to 1.35 contrary, stretches or shortens the animation
var floor_recovery_lock := 0.0
var floor_recovery_side := 1.0
var floor_recovery_root := Vector2.ZERO
var floor_recovery_flat := {}
var floor_slide_decel := 0.0
var rolling := false

func update() -> void:
	if lab.is_benched():
		lab.bench.apply_pose()
		return
	# The dive layer adds yaw/roll on top of the body; take it off first so it never accumulates between frames.
	lab.body.rotation.y -= dive_applied_yaw
	dive_applied_yaw = 0.0
	lab.body.rotation.z = 0.0
	lab.body.scale = Vector3.ONE * float(lab.athlete.build.height) / lab.visual_rig_height
	var direction := lab.aim - lab.player.position
	if direction.length_squared() > 0.1:
		lab.body.rotation.y = lab.camera_rig.facing_yaw if lab.camera_rig.camera_mode == ViewMode.BALL and lab.ball_active else atan2(-direction.x, -direction.z)
	dive_base_yaw = lab.body.rotation.y
	dive_applied_yaw = dive_turn_offset()
	lab.body.rotation.y += dive_applied_yaw
	pivot_dive_turn()
	var speed := Vector2(lab.player.velocity.x, lab.player.velocity.z).length()
	var receive_ready := not lab.motion.jumped and lab.motion.jump_charge < 0 and ((lab.armed and lab.locked_action == 0) or (lab.charging and lab.selected == 0))
	var travel_heading := wrapf(atan2(-lab.player.velocity.x, -lab.player.velocity.z) - lab.camera_rig.facing_yaw, -PI, PI) if speed > 0.1 else 0.0
	var follow_receive := receive_pose_remaining > 0 and not lab.motion.jumped
	var receive_weight := 1.0 if receive_ready else smoothstep(0, 0.18, receive_pose_remaining)
	var gait := Pose.base(lab.body, lab.motion.gait_cycle, speed if not lab.motion.jumped and lab.motion.jump_charge < 0 else 0.0, travel_heading, receive_ready or follow_receive, receive_weight)
	lab.body.get_node("Torso").rotation.y = 0
	lab.body.get_node("Head").rotation.y = 0
	for i in range(2):
		lab.legs[i].position.x = -lab.visual_hip_x if i == 0 else lab.visual_hip_x
		if lab.motion.jumped:
			lab.legs[i].rotation.x = -0.25
			lab.legs[i].get_node("Knee").rotation_degrees.x = -20.0
		if not lab.motion.generic_jump and lab.selected != 0 and (lab.armed or lab.motion.jumped):
			lab.arms[i].rotation.x = -2.7
		elif lab.armed:
			lab.arms[i].rotation.x = -0.8

	if lab.motion.jump_charge < 0 and ((lab.armed and lab.locked_action == 2) or (lab.motion.jumped and lab.motion.airborne_action == 2)):
		var dominant := 0 if lab.dominant_hand == "Left" else 1
		lab.arms[dominant].rotation.x = -2.95
		lab.arms[dominant].rotation.z = 0.35 if lab.dominant_hand == "Left" else -0.35
		lab.arms[1 - dominant].rotation.x = -1.3
	lab.body.position.y = 0.0
	if lab.motion.generic_jump and lab.motion.jump_charge >= 0:
		lab.body.position.y = -0.22 * lab.motion.jump_charge
		for leg in lab.legs:
			leg.rotation.x = 0.35 * lab.motion.jump_charge
			leg.get_node("Knee").rotation.x = -0.8 * lab.motion.jump_charge
	elif lab.motion.jump_charge >= 0 and lab.motion.approach_action != 0:
		# A dive charges as its crouching step (DiveStage prep), not as a jump approach.
		var step := Approach.step_index(lab.motion.jump_charge)
		var phase := Approach.step_phase(lab.motion.jump_charge)
		var lead := Approach.lead_foot(step)
		var swing: float = [1.05, 0.65, 0.48, 0.0][step]
		lab.legs[lead].rotation.x = -sin(phase * PI) * swing
		lab.legs[1 - lead].rotation.x = sin(phase * PI) * swing * 0.55
		lab.body.position.y = -0.14 * sin(phase * PI)
		if step == 0 and lab.motion.approach_bound:
			lab.body.position.y = 0.0
			lab.legs[lead].rotation.x = -0.85
			lab.legs[1 - lead].rotation.x = 0.55
		if step == 2:
			var closing := smoothstep(0.15, 1.0, phase)
			lab.legs[lead].position.x = lerpf(lab.visual_hip_x, Approach.foot_lateral(2), closing)
			lab.legs[lead].rotation.y = Approach.foot_turn(2) * closing
			lab.body.position.y = -0.16 * closing
			if lab.motion.approach_direction.length_squared() > 0.01:
				var plant_yaw := atan2(-lab.motion.approach_direction.x, -lab.motion.approach_direction.z)
				var correction := clampf(wrapf(plant_yaw - lab.body.rotation.y, -PI, PI), -0.25, 0.25)
				lab.body.rotation.y += correction * closing
		for arm in lab.arms:
			arm.rotation.x = 0.55 if step < 2 else -0.7
	lab.body.rotation.x = 0.0
	if roll_lock > 0.0:
		var roll_progress := 1.0 - roll_lock / ROLL_TIME
		lab.body.rotation.x = -TAU * roll_progress
		lab.body.position.y = 0.45 * sin(roll_progress * PI)
	lab.body.get_node("Torso").rotation.x = float(gait.torso_pitch_radians)
	if (receive_ready or follow_receive or (lab.motion.jumped and lab.motion.airborne_action == 0)) and roll_lock <= 0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0:
		if receive_pose_remaining <= 0:
			var shape := lab._hurtbox_definition(0)
			receive_pose_contact = Vector3(shape.center)
			if lab.ball_active and Geometry.contains(shape, lab._local_contact_position()):
				receive_pose_contact = lab._local_contact_position()
			receive_posture = ReceivePlatform.posture(shape, receive_pose_contact, speed)
		ReceivePose.apply(lab.body, receive_posture, receive_pose_contact, 1.0 if receive_ready or lab.motion.jumped else receive_weight)
	var diving_now := lab.motion.jumped and lab.motion.airborne_action == 0
	var preparing_dive := not lab.motion.jumped and lab.motion.jump_charge >= 0 and lab.motion.approach_action == 0
	if (diving_now or preparing_dive) and roll_lock <= 0:
		var dive_dir := dive_world_direction if diving_now else (lab.motion.approach_direction if lab.motion.approach_direction.length_squared() > 0.01 else Vector3(-sin(lab.camera_rig.facing_yaw), 0, -cos(lab.camera_rig.facing_yaw)))
		var dive_phase := DiveStage.phase_for(lab.motion.jump_charge, dive_air_time, dive_flight_time, diving_now)
		var dive_stage := DiveStage.resolve(dive_phase, DiveStage.local_direction(dive_dir, lab.body.rotation.y), dive_pivot_foot())
		dive_stage["turn_spine"] = dive_turn_spine
		dive_stage["turn_neck"] = dive_turn_neck
		dive_applied_yaw += DiveStage.apply(lab.body, dive_stage)
	if lab.motion.jumped and lab.motion.airborne_action == 2 and roll_lock <= 0.0:
		var swing_yaw := spike_swing_yaw
		if not spike_contacted and lab.ball_active:
			var preview_assessment := lab._contact_assessment(2)
			if preview_assessment.hit:
				var forward := Vector3(-sin(lab._contact_yaw()), 0, -cos(lab._contact_yaw()))
				var preview := SpikeDirection.resolve(lab._shot_velocity(lab.ball.position, 2, lab.locked_charge), preview_assessment, lab.directional_input.value(), forward)
				swing_yaw = preview.shot_yaw_radians
		var aim_context := {"shot_yaw": swing_yaw}
		if lab.ball_active:
			aim_context["ball_local"] = lab.body.global_transform.affine_inverse() * lab.ball.position
		SpikeStage.apply(lab.body, SpikeStage.phase_for(spike_air_time, spike_flight_time, spike_swing_time, spike_hit_time), -1.0 if lab.dominant_hand == "Left" else 1.0, lab.locked_charge, "Power swing", aim_context)
	if dive_recovery_time >= 0.0 and roll_lock <= 0.0:
		apply_dive_recovery()
	elif floor_recovery_time >= 0.0 and roll_lock <= 0.0:
		apply_floor_recovery()
	var set_phase := set_phase()
	if set_phase > -1.5 and roll_lock <= 0.0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0 and not (diving_now or preparing_dive):
		SetStage.apply_data(lab.body, set_phase, lab.motion.jumped and lab.motion.airborne_action == 1, -1.0 if lab.dominant_hand == "Left" else 1.0)
	smooth_pose(pose_source(diving_now, preparing_dive, receive_ready or follow_receive))
	var wing_pose := "tucked"
	var wing_weight := 0.0
	if diving_now or preparing_dive:
		wing_pose = "balance"
		wing_weight = 1.0 if diving_now else 0.35
	elif lab.motion.jumped and lab.motion.airborne_action == 3:
		wing_pose = "block"
		wing_weight = 1.0
	WingPose.apply(lab.body, "tucked", wing_pose, wing_weight)
	if dive_recovery_time >= 0.0 or (floor_recovery_time >= 0.0 and floor_recovery_name != "shrug"):
		DiveRecovery.rest_on_floor(lab.body, lab.player.global_position.y)
	elif not lab.motion.jumped and not lab.motion.approach_bound:
		Pose.ground_feet(lab.body)
	if lab.rescue_swing_remaining > 0:
		var dominant := 0 if lab.dominant_hand == "Left" else 1
		var progress := 1.0 - lab.rescue_swing_remaining / 0.28
		lab.arms[dominant].rotation.x = lerpf(-1.0, -1.65, sin(progress * PI))
		lab.arms[dominant].get_node("Elbow").rotation.x = -0.25
	if is_instance_valid(lab.serve):
		lab.serve.apply_pose()

# Where the set is: -2 when the body is not setting. Hands up and ready while a set is armed, the push and
# extension after contact, and through the air for a jump set (contact at the top).
func set_phase() -> float:
	if lab.motion.jumped and lab.motion.airborne_action == 1:
		var f := clampf(set_air_time / maxf(set_flight_time, 0.001), 0.0, 1.0)
		return lerpf(-0.30, 0.04, f / 0.5) if f < 0.5 else lerpf(0.04, 0.45, (f - 0.5) / 0.5)
	if lab.motion.jumped or lab.motion.jump_charge >= 0.0:
		return -2.0
	var since := (lab.elapsed - lab.last_contact)*lab.athlete.transition_rate()
	if since >= 0.0 and since < 0.5 and int(lab.last_contact_result.get("action", -1)) == 1:
		return SetStage.follow_phase(since)
	if lab.armed and lab.locked_action == 1:
		return -0.16
	return -2.0

# Which animation is driving the body right now. A change in this is what gets smoothed.
func pose_source(diving_now: bool, preparing_dive: bool, receiving: bool) -> String:
	if roll_lock > 0.0:
		return "roll"
	if floor_recovery_time >= 0.0:
		return "floor:%s" % floor_recovery_name
	if set_phase() > -1.5 and dive_recovery_time < 0.0 and not (diving_now or preparing_dive):
		return "set"
	if dive_recovery_time >= 0.0 or diving_now or preparing_dive:
		# The crouching step, the dive, the landing and the getting up are one animation. It is
		# continuous inside itself, so only its edges are smoothed.
		return "dive"
	if lab.motion.jumped:
		if lab.motion.airborne_action == 2 and spike_contacted:
			return "air:2:hit"
		return "air:%d" % lab.motion.airborne_action
	if lab.motion.jump_charge >= 0.0:
		return "approach:%d" % lab.motion.approach_action
	if receiving:
		return "receive:%s" % receive_posture
	if lab.armed:
		return "armed:%d" % lab.locked_action
	return "locomotion"

# Read the pose the code just built, and draw it with the seam from the previous source removed.
# Outside a running frame (tests, screenshots) there is no time to smooth over, so the pose stands.
func smooth_pose(source: String) -> void:
	if not pose_smoothing or pose_frame_dt <= 0.0:
		pose_smoother.reset()
		return
	var frame := Engine.get_process_frames()
	var step := pose_frame_dt if frame != pose_last_frame else 0.0
	pose_last_frame = frame
	var shown := pose_smoother.update(PoseLibrary.read_rig(lab.body), source, step)
	PoseLibrary.apply(lab.body, PoseLibrary.from_flat(shown, false), 1.0)

func dive_input_locked() -> bool:
	return dive_recovery_time >= 0.0 and dive_recovery_time < DiveRecovery.lock_seconds(dive_quality_value)

# How far the hips have turned toward a backward dive at this moment, in radians. The upper body turns ahead of
# them (dive_turn_spine, dive_turn_neck in degrees), so the torso leads and the hips and feet follow.
func dive_turn_offset() -> float:
	var prepping := not lab.motion.jumped and lab.motion.jump_charge >= 0.0 and lab.motion.approach_action == 0
	var airborne := lab.motion.jumped and lab.motion.airborne_action == 0
	dive_turn_spine = 0.0
	dive_turn_neck = 0.0
	if not (prepping or airborne or dive_recovery_time >= 0.0):
		dive_turn_total = 0.0
		return 0.0
	if dive_recovery_time >= 0.0 and not prepping and not airborne:
		return dive_turn_total * (1.0 - DiveRecovery.facing_release(dive_recovery_time, dive_quality_value))
	var phase := 0.0
	if prepping:
		var dir := lab.motion.approach_direction if lab.motion.approach_direction.length_squared() > 0.01 else Vector3(-sin(lab.camera_rig.facing_yaw), 0, -cos(lab.camera_rig.facing_yaw))
		dive_turn_total = dive_turn_for(dir, dive_base_yaw)
		phase = DiveStage.phase_for(lab.motion.jump_charge, 0.0, dive_flight_time, false)
	else:
		phase = DiveStage.phase_for(lab.motion.jump_charge, dive_air_time, dive_flight_time, true)
	var hips := dive_turn_total * smoothstep(-0.52, -0.08, phase)
	var upper := dive_turn_total * smoothstep(-0.64, -0.30, phase)
	var lead := rad_to_deg(upper - hips)
	dive_turn_spine = clampf(lead, -55.0, 55.0)
	dive_turn_neck = clampf(lead - dive_turn_spine, -70.0, 70.0)
	return hips

# The turn pivots on the trailing foot: the body rotates about that foot, so it stays where it was put.
func pivot_dive_turn() -> void:
	lab.body.position.x = 0.0
	lab.body.position.z = 0.0
	if absf(dive_applied_yaw) < 0.0001 or dive_turn_total == 0.0:
		return
	var foot := Basis(Vector3.UP, dive_base_yaw) * Vector3((lab.visual_hip_x if dive_turn_total < 0.0 else -lab.visual_hip_x) * lab.body.scale.x, 0.0, 0.0)
	var shift := foot - Basis(Vector3.UP, dive_applied_yaw) * foot
	lab.body.position.x = shift.x
	lab.body.position.z = shift.z

# The foot a backward dive pivots on, as DiveStage names its trailing foot (1 right, 0 left); -1 when nothing turns.
func dive_pivot_foot() -> int:
	if absf(dive_turn_total) < 0.01:
		return -1
	return 1 if dive_turn_total < 0.0 else 0

# The turn a dive toward `dir` needs from facing `base_yaw`: none to the front or side, all of it behind.
func dive_turn_for(dir: Vector3, base_yaw: float) -> float:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return 0.0
	var ahead := DiveStage.local_direction(dir, base_yaw).y
	var weight := smoothstep(-0.15, -0.55, ahead)
	if weight <= 0.0:
		return 0.0
	var delta := wrapf(atan2(-dir.x, -dir.z) - base_yaw, -PI, PI)
	if absf(delta) > PI - 0.05:
		delta = -PI if lab.dominant_hand == "Right" else PI
	return delta * weight

func begin_dive_recovery() -> void:
	if not dive_launched:
		return
	dive_launched = false
	if roll_lock > 0.0:
		return
	dive_recovery_dir = DiveStage.local_direction(dive_world_direction, lab.body.rotation.y)
	dive_recovery_root = Vector2(lab.body.rotation.x, lab.body.rotation.z)
	dive_recovery_flat = PoseLibrary.read_rig(lab.body)
	dive_recovery_time = 0.0
	var slide: Dictionary = DiveRecovery.plan().slide_metres
	var metres := lerpf(float(slide.forward), float(slide.lateral), absf(dive_recovery_dir.x)) * lerpf(0.75, 1.15, dive_quality_value)
	metres = maxf(metres, float(slide.floor))
	var speed := Vector2(lab.player.velocity.x, lab.player.velocity.z).length()
	dive_slide_decel = speed * speed / (2.0 * metres)

func tick_dive_recovery(dt: float) -> void:
	dt *= lab.athlete.transition_rate()*lab.athlete.recovery_rate()
	if dive_recovery_time < 0.0:
		return
	# Starting any new action ends the recovery where it is.
	if lab.motion.jumped or lab.motion.jump_charge >= 0.0 or lab.motion.approach_bound:
		end_dive_recovery()
		return
	var step := dt
	if not dive_input_locked() and (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D)):
		step *= 1.6
	dive_recovery_time += step
	if dive_recovery_time >= DiveRecovery.duration(dive_quality_value):
		end_dive_recovery()

func end_dive_recovery() -> void:
	dive_recovery_time = -1.0
	dive_slide_decel = 0.0

func apply_dive_recovery() -> void:
	var state := DiveRecovery.at(dive_recovery_time, dive_recovery_dir, dive_quality_value, dive_recovery_root, dive_recovery_flat)
	DiveRecovery.apply(lab.body, state)

# --- Floor recovery after a poorly handled receive ------------------------------------------------
# Codex's receive_resolved event is authoritative for which recovery, its DI penalty and the contact side.
# Not for dives (they have their own floor recovery), jumps or rolling receives.
func on_receive_resolved(event: Dictionary) -> void:
	if String(event.get("actor", "")) != "player":
		return
	var recovery := FloorRecovery.resolve(String(event.get("recovery", "")))
	if recovery.is_empty() or not FloorRecovery.names().has(recovery):
		return
	if lab.motion.jumped or dive_launched or dive_recovery_time >= 0.0 or roll_lock > 0.0 or floor_recovery_time >= 0.0:
		return
	var outcome: Dictionary = event.get("receive_outcome", {})
	var coord: Vector3 = outcome.get("platform_coord", Vector3.ZERO)
	floor_recovery_name = recovery
	floor_recovery_side = FloorRecovery.side_of(coord.x, lab.dominant_hand)
	floor_recovery_scale = clampf(float(outcome.get("penalty_factor", 1.0)), 0.65, 1.35)
	floor_recovery_root = Vector2(lab.body.rotation.x, lab.body.rotation.z)
	floor_recovery_flat = PoseLibrary.read_rig(lab.body)
	floor_recovery_time = 0.0
	var total := floor_recovery_total()
	# Input comes back at the rise (the penalty budget for a shrug, whose gameplay budget is shorter than its animation).
	floor_recovery_lock = float(event.get("recovery_penalty_seconds", total)) if recovery == "shrug" else FloorRecovery.lock_seconds(recovery) * floor_recovery_scale
	var plan := FloorRecovery.plan(recovery)
	var forward := Vector3(-sin(lab.camera_rig.facing_yaw), 0, -cos(lab.camera_rig.facing_yaw))
	var right := Vector3(cos(lab.camera_rig.facing_yaw), 0, -sin(lab.camera_rig.facing_yaw))
	var direction := forward
	match recovery:
		"knocked_away":
			# Back, and a little away from the side the ball hit.
			direction = (-forward - right * floor_recovery_side * 0.35).normalized()
		"collapse":
			# In the direction of the contact: forward, leaning toward the side it landed on.
			direction = (forward + right * clampf(coord.x, -1.0, 1.0)).normalized()
		"blown_away", "shrug":
			direction = -forward
	var metres := float(plan.get("travel", 0.0))
	floor_slide_decel = 2.0 * metres / maxf(floor_recovery_lock * floor_recovery_lock, 0.01)
	var launch := floor_slide_decel * floor_recovery_lock
	lab.player.velocity.x = direction.x * launch
	lab.player.velocity.z = direction.z * launch

func floor_recovery_total() -> float:
	return FloorRecovery.duration(floor_recovery_name) * floor_recovery_scale

func floor_input_locked() -> bool:
	return floor_recovery_time >= 0.0 and floor_recovery_time < floor_recovery_lock

func tick_floor_recovery(dt: float) -> void:
	dt *= lab.athlete.transition_rate()*lab.athlete.recovery_rate()
	if floor_recovery_time < 0.0:
		return
	var step := dt
	if not floor_input_locked() and (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D)):
		step *= 1.6
	floor_recovery_time += step
	if floor_recovery_time >= floor_recovery_total():
		floor_recovery_time = -1.0
		floor_recovery_name = ""
		floor_slide_decel = 0.0

func apply_floor_recovery() -> void:
	var seconds := floor_recovery_time / floor_recovery_scale
	var state := FloorRecovery.at(floor_recovery_name, seconds, floor_recovery_side, floor_recovery_root, floor_recovery_flat)
	FloorRecovery.apply(lab.body, state)


func _init(session: LabSession) -> void:
	lab = session
