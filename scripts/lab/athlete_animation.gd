class_name AthleteAnimation
extends RefCounted

## Owns animation state. LabSession schedules updates and composes peers.
const ContactResponse := preload("res://scripts/contact_response_pose.gd")
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
const Locomotion := preload("res://scripts/lab/athlete_locomotion.gd")
const SpineRig := preload("res://scripts/spine_rig.gd")
const Approach = preload("res://scripts/approach_run.gd")
const ViewMode = LabCamera.ViewMode
const ROLL_TIME := 0.9

var lab: LabSession
var contact_age := -1.0
var contact_action := -1
var contact_evidence := {}
var receive_posture := "planted"
var receive_pose_remaining := 0.0
var receive_pose_contact := Vector3.ZERO
var roll_lock := 0.0
var dive_air_time := 0.0
var dive_applied_yaw := 0.0
var spike_air_time := 0.0
var spike_flight_time := 0.5
# How far a running setter's hands relax from the gather toward their sides.
const SET_RUN_RELAX := 0.7
# The block's coil: the hands up in front of the chest (a bit over 70 degrees forward) with the elbows bent, where the thrust over the net starts.
const BLOCK_COIL_PITCH := -1.25
const BLOCK_COIL_ELBOW := 105.0
var jump_air_time := 0.0        # seconds since takeoff, for any jump
var spike_swing_time := -1.0   # seconds since the click started the strike; -1 while only loaded
var spike_hit_time := -1.0     # swing-clock time of the hit, or of the window closing
var spike_contacted := false
var set_air_time := 0.0
var set_flight_time := 0.5
var spike_swing_yaw := 0.0
var spike_impact_world := Vector3.ZERO
var spike_impact_latched := false
var carry := preload("res://scripts/ball_carry_animation.gd").new()
var pose_smoother := PoseSmoother.new()
var pose_smoothing := true
var pose_frame_dt := 0.0
# Hips and legs follow the direction of travel while the head keeps to the cursor (see athlete_locomotion.gd).
var locomotion := Locomotion.new()
var locomotion_state := {}
var locomotion_frame := -1
var locomotion_enabled := true
var locomotion_hips := {"left": 0.0, "right": 0.0}
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
var floor_recovery_lateral := 1.0   # how far off the middle the contact was: 0 gives the symmetric version of a sided recovery
var floor_recovery_root := Vector2.ZERO
var floor_recovery_flat := {}
var floor_slide_decel := 0.0
var rolling := false

# Called once per physics step with the actor-local delta, before pose composition.
func tick_action_clocks(dt: float) -> void:
	if contact_age >= 0.0:
		contact_age += dt*lab.athlete.transition_rate()
	receive_pose_remaining = maxf(0, receive_pose_remaining - dt*lab.athlete.transition_rate())
	roll_lock = maxf(0.0, roll_lock - dt*lab.athlete.transition_rate())
	dive_air_time = dive_air_time + dt if lab.motion.jumped and lab.motion.airborne_action == 0 else 0.0
	tick_dive_recovery(dt)
	tick_floor_recovery(dt)
	spike_air_time = spike_air_time + dt if lab.motion.jumped and lab.motion.airborne_action == 2 else 0.0
	if lab.motion.jumped and lab.motion.airborne_action == 2 and spike_swing_time >= 0.0:
		spike_swing_time += dt*(lab.athlete.transition_rate() if spike_hit_time >= 0 else 1.0)
		# The swing waits at contact for the ball; if the window closes without a hit it carries on regardless.
		if spike_hit_time < 0.0 and spike_swing_time > SpikeStage.STRIKE_SECONDS and lab.confirm_window <= 0.0:
			spike_hit_time = spike_swing_time
	set_air_time = set_air_time + dt if lab.motion.jumped and lab.motion.airborne_action == 1 else 0.0
	jump_air_time = jump_air_time + dt if lab.motion.jumped else 0.0
	if not (lab.motion.jumped and lab.motion.airborne_action == 2):
		spike_swing_time = -1.0
		spike_hit_time = -1.0
		spike_contacted = false
		spike_swing_yaw = 0.0

func update() -> void:
	if lab.is_benched():
		carry.hide_visual()
		lab.bench.apply_pose()
		return
	# The dive layer adds yaw/roll on top of the body; take it off first so it never accumulates between frames.
	lab.body.rotation.y -= dive_applied_yaw
	dive_applied_yaw = 0.0
	lab.body.rotation.z = 0.0
	lab.body.scale = Vector3.ONE * float(lab.athlete.body_height()) / lab.visual_rig_height
	var direction := lab.aim - lab.player.position
	if direction.length_squared() > 0.1:
		lab.body.rotation.y = lab.camera_rig.facing_yaw if lab.camera_rig.camera_mode == ViewMode.BALL and lab.ball_active else atan2(-direction.x, -direction.z)
	dive_base_yaw = lab.body.rotation.y
	dive_applied_yaw = dive_turn_offset()
	lab.body.rotation.y += dive_applied_yaw
	pivot_dive_turn()
	var speed := Vector2(lab.player.velocity.x, lab.player.velocity.z).length()
	var receive_mobile := lab.motion.approach_action == 0 and lab.motion.jump_charge >= 0 and not lab.motion.approach_bound
	var receive_ready := not lab.motion.jumped and (lab.motion.jump_charge < 0 or receive_mobile) and ((lab.armed and lab.locked_action == 0) or (lab.charging and lab.selected == 0))
	var travel_heading := wrapf(atan2(-lab.player.velocity.x, -lab.player.velocity.z) - lab.camera_rig.facing_yaw, -PI, PI) if speed > 0.1 else 0.0
	var follow_receive := receive_pose_remaining > 0 and not lab.motion.jumped
	# A prepared receive does not run with the platform out: it comes up as the athlete slows, or as the ball gets close.
	var run_weight := 0.0 if lab.motion.jumped else smoothstep(0.55, 0.85, speed / maxf(lab.athlete.speed(), 0.1))
	var near_ball := 0.0
	if lab.ball_active:
		near_ball = smoothstep(3.6, 2.2, Vector2(lab.ball.position.x - lab.player.position.x, lab.ball.position.z - lab.player.position.z).length())
	var platform_factor := 1.0 - run_weight * (1.0 - near_ball)
	var receive_weight := (1.0 if receive_ready else smoothstep(0, 0.18, receive_pose_remaining)) * platform_factor
	var loco_on := locomotion_enabled and not lab.motion.jumped and lab.motion.jump_charge < 0 and not ((receive_ready or follow_receive) and platform_factor > 0.5) and roll_lock <= 0.0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0 and self.set_phase() <= -1.5
	locomotion_state = step_locomotion(loco_on)
	var loco_weight := float(locomotion_state.weight)
	var gait_heading := lerp_angle(travel_heading, float(locomotion_state.heading), loco_weight) if loco_weight > 0.0 else travel_heading
	# Charging a set or block jump keeps the footwork going: the steps get smaller as the jump loads.
	var loading_jump: bool = lab.motion.jump_charge >= 0 and lab.motion.approach_action in [1, 3] and not lab.motion.generic_jump and not lab.motion.jumped
	var gait_speed := speed * lerpf(1.0, 0.6, lab.motion.jump_charge) if loading_jump else speed
	var gait := Pose.base(lab.body, lab.motion.gait_cycle, gait_speed if not lab.motion.jumped and (lab.motion.jump_charge < 0 or receive_mobile or loading_jump) else 0.0, gait_heading, receive_ready or follow_receive, receive_weight)
	locomotion_hips = {"left": float(gait.left_hip_degrees), "right": float(gait.right_hip_degrees)}
	var gait_arms := _read_arms()
	if loco_on and loco_weight > 0.0:
		Locomotion.apply_legs(lab.legs, locomotion_state.legs)
	lab.body.get_node("Torso").rotation.y = 0
	lab.body.get_node("Head").rotation.y = 0
	# 0 standing, 1 travelling. In the air the raised pose always holds.
	var travel_weight := 0.0 if lab.motion.jumped else smoothstep(0.35, 1.4, speed)
	_apply_prepared_pose(travel_weight)
	_apply_block_jump_pose()
	_apply_takeoff_and_roll_pose()
	lab.body.get_node("Torso").rotation.x = float(gait.torso_pitch_radians)
	_apply_receive_pose(receive_ready or follow_receive, speed, receive_weight)
	if (receive_ready or follow_receive) and not lab.motion.jumped and not follow_receive:
		# Moving with a receive prepared, the arms stay in the stride; the platform comes out as the athlete slows, or as the ball gets close.
		_blend_arms(gait_arms, smoothstep(0.28, 0.5, speed / maxf(lab.athlete.speed(), 0.1)) * (1.0 - near_ball))
	var diving_now := lab.motion.jumped and lab.motion.airborne_action == 0
	var preparing_dive := not lab.motion.jumped and lab.motion.jump_charge >= 0 and lab.motion.approach_action == 0 and lab.motion.approach_bound
	_apply_dive_pose(diving_now, preparing_dive)
	_apply_spike_pose()
	if dive_recovery_time >= 0.0 and roll_lock <= 0.0:
		apply_dive_recovery()
	elif floor_recovery_time >= 0.0 and roll_lock <= 0.0:
		apply_floor_recovery()
	_apply_set_pose(travel_weight, diving_now, preparing_dive)
	if loco_on and loco_weight > 0.001:
		apply_locomotion_spine(locomotion_state)
	_apply_contact_response(diving_now, preparing_dive)
	smooth_pose(pose_source(diving_now, preparing_dive, receive_ready or follow_receive))
	_finish_pose(diving_now, preparing_dive)


func _read_arms() -> Array:
	var arms := []
	for arm in lab.arms:
		arms.append({"rotation": arm.rotation, "elbow": (arm.get_node("Elbow") as Node3D).rotation})
	return arms

func _blend_arms(target: Array, weight: float) -> void:
	for index in range(lab.arms.size()):
		lab.arms[index].rotation = (lab.arms[index].rotation as Vector3).lerp(target[index].rotation, weight)
		var elbow := lab.arms[index].get_node("Elbow") as Node3D
		elbow.rotation = elbow.rotation.lerp(target[index].elbow, weight)

# A block jump: the hands go up from the guard to full reach over the net, spread a little, as the legs tuck on the way up, stretch at the top and
# bend again to land. (The set jump's legs and hands come from its pose files.)
func _apply_block_jump_pose() -> void:
	if roll_lock > 0.0:
		return
	# Loading a block jump, the hands coil up in front of the chest, elbows bent, rather than hanging or swinging at the sides.
	if lab.motion.approach_action == 3 and not lab.motion.generic_jump and lab.motion.jump_charge >= 0 and not lab.motion.jumped:
		var coil := smoothstep(0.0, 0.5, lab.motion.jump_charge)
		for index in range(2):
			var outward := 1.0 if index == 0 else -1.0
			lab.arms[index].rotation = (lab.arms[index].rotation as Vector3).lerp(Vector3(BLOCK_COIL_PITCH, 0.0, outward * 0.1), coil)
			var elbow := lab.arms[index].get_node("Elbow") as Node3D
			elbow.rotation_degrees.x = lerpf(elbow.rotation_degrees.x, BLOCK_COIL_ELBOW, coil)
		return
	if not (lab.motion.jumped and lab.motion.airborne_action == 3):
		return
	var flight: float = lab.athlete.jump_flight_time(lab.motion.last_jump_height, lab.GRAVITY)
	var f := clampf(jump_air_time / maxf(flight, 0.001), 0.0, 1.0)
	var reach := smoothstep(0.0, 0.45, f)
	var landing := smoothstep(0.6, 1.0, f)
	for index in range(2):
		var outward := 1.0 if index == 0 else -1.0
		lab.arms[index].rotation.x = lerpf(BLOCK_COIL_PITCH, -2.95, reach)
		lab.arms[index].rotation.z = outward * lerpf(0.1, 0.2, reach)
		lab.arms[index].get_node("Elbow").rotation_degrees.x = lerpf(BLOCK_COIL_ELBOW, 0.0, reach)
		lab.legs[index].rotation.x = lerpf(-0.42, -0.06, reach) - 0.3 * landing
		lab.legs[index].get_node("Knee").rotation_degrees.x = lerpf(-52.0, -10.0, reach) - 28.0 * landing

# Pose layers execute in update() order; later layers intentionally override earlier ones.
func _apply_prepared_pose(travel_weight: float) -> void:
	var raise_weight := 1.0 - travel_weight
	for i in range(2):
		lab.legs[i].position.x = -lab.visual_hip_x if i == 0 else lab.visual_hip_x
		if lab.motion.jumped:
			lab.legs[i].rotation.x = -0.25
			lab.legs[i].get_node("Knee").rotation_degrees.x = -20.0
		if not lab.motion.generic_jump and lab.selected != 0 and (lab.armed or lab.motion.jumped):
			# Hands go up for a prepared action but come back down into the walk swing while the athlete is travelling,
			# and a raised arm is straight: the walk's elbow bend belongs to a swinging arm only.
			lab.arms[i].rotation.x = lerpf(lab.arms[i].rotation.x, -2.7, raise_weight)
			lab.arms[i].get_node("Elbow").rotation_degrees.x = lerpf(lab.arms[i].get_node("Elbow").rotation_degrees.x, 0.0, raise_weight)
		elif lab.armed:
			lab.arms[i].rotation.x = -0.8

	if lab.motion.jump_charge < 0 and ((lab.armed and lab.locked_action == 2) or (lab.motion.jumped and lab.motion.airborne_action == 2)):
		var dominant := 0 if lab.dominant_hand == "Left" else 1
		lab.arms[dominant].rotation.x = lerpf(lab.arms[dominant].rotation.x, -2.95, raise_weight)
		lab.arms[dominant].rotation.z = lerpf(lab.arms[dominant].rotation.z, 0.35 if lab.dominant_hand == "Left" else -0.35, raise_weight)
		lab.arms[1 - dominant].rotation.x = lerpf(lab.arms[1 - dominant].rotation.x, -1.3, raise_weight)
		for arm in lab.arms:
			arm.get_node("Elbow").rotation_degrees.x = lerpf(arm.get_node("Elbow").rotation_degrees.x, 0.0, raise_weight)


func _apply_takeoff_and_roll_pose() -> void:
	lab.body.position.y = 0.0
	if (lab.motion.generic_jump or lab.motion.approach_action in [1,3]) and lab.motion.jump_charge >= 0:
		lab.body.position.y = -0.22 * lab.motion.jump_charge
		for leg in lab.legs:
			if lab.motion.generic_jump:
				leg.rotation.x = 0.35 * lab.motion.jump_charge
				leg.get_node("Knee").rotation.x = -0.8 * lab.motion.jump_charge
			else:
				# The load is a crouch on top of the stride, not a replacement for it.
				leg.rotation.x += 0.28 * lab.motion.jump_charge
				leg.get_node("Knee").rotation.x += -0.65 * lab.motion.jump_charge
	elif lab.motion.jump_charge >= 0 and lab.motion.approach_action == 2:
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


func _apply_receive_pose(receiving: bool, speed: float, receive_weight: float) -> void:
	if (receiving or (lab.motion.jumped and lab.motion.airborne_action == 0)) and roll_lock <= 0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0:
		if receive_pose_remaining <= 0:
			var shape := lab._hurtbox_definition(0)
			receive_pose_contact = Vector3(shape.center)
			if lab.ball_active and Geometry.contains(shape, lab._local_contact_position()):
				receive_pose_contact = lab._local_contact_position()
			receive_posture = ReceivePlatform.posture(shape, receive_pose_contact, speed)
		ReceivePose.apply(lab.body, receive_posture, receive_pose_contact, 1.0 if lab.motion.jumped else receive_weight)


func _apply_dive_pose(diving_now: bool, preparing_dive: bool) -> void:
	if (diving_now or (preparing_dive and lab.motion.approach_bound)) and roll_lock <= 0:
		var dive_dir := dive_world_direction if diving_now else (lab.motion.approach_direction if lab.motion.approach_direction.length_squared() > 0.01 else Vector3(-sin(lab.camera_rig.facing_yaw), 0, -cos(lab.camera_rig.facing_yaw)))
		var dive_phase := DiveStage.phase_for(lab.motion.jump_charge, dive_air_time, dive_flight_time, diving_now)
		var dive_stage := DiveStage.resolve(dive_phase, DiveStage.local_direction(dive_dir, lab.body.rotation.y), dive_pivot_foot())
		dive_stage["turn_spine"] = dive_turn_spine
		dive_stage["turn_neck"] = dive_turn_neck
		dive_applied_yaw += DiveStage.apply(lab.body, dive_stage)
		if preparing_dive:
			# A compact version of the attack's opening bound, before mobile receiving.
			lab.body.position.y = 0.0
			lab.legs[Approach.LEAD_FOOT].rotation.x = -0.45
			lab.legs[1-Approach.LEAD_FOOT].rotation.x = 0.30


func _apply_spike_pose() -> void:
	if not lab.motion.jumped or lab.motion.airborne_action != 2 or not spike_contacted:
		spike_impact_latched = false
	if lab.motion.jumped and lab.motion.airborne_action == 2 and roll_lock <= 0.0:
		if spike_contacted and not spike_impact_latched:
			spike_impact_world = lab.last_contact_result.get("point",lab.ball.position)
			spike_impact_latched = true
		var swing_yaw := spike_swing_yaw
		if not spike_contacted and lab.ball_active:
			var preview_assessment := lab._contact_assessment(2)
			if preview_assessment.hit:
				var forward := Vector3(-sin(lab._contact_yaw()), 0, -cos(lab._contact_yaw()))
				var preview := SpikeDirection.resolve(lab._shot_velocity(lab.ball.position, 2, lab.locked_charge), preview_assessment, lab.directional_input.value(), forward)
				swing_yaw = preview.shot_yaw_radians
		var aim_context := {"shot_yaw": swing_yaw}
		if spike_impact_latched:
			aim_context["ball_local"] = lab.body.global_transform.affine_inverse()*spike_impact_world
		elif lab.ball_active:
			aim_context["ball_local"] = lab.body.global_transform.affine_inverse() * lab.ball.position
		SpikeStage.apply(lab.body, SpikeStage.phase_for(spike_air_time, spike_flight_time, spike_swing_time, spike_hit_time), -1.0 if lab.dominant_hand == "Left" else 1.0, lab.locked_charge, "Roll shot" if spike_contacted and str(lab.last_contact_result.get("spike_form", "")) == "roll" else "Power swing", aim_context)


func _apply_set_pose(travel_weight: float, diving_now: bool, preparing_dive: bool) -> void:
	var set_phase := set_phase()
	if set_phase > -1.5 and roll_lock <= 0.0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0 and not (diving_now or preparing_dive):
		var set_jump: bool = lab.motion.jumped and lab.motion.airborne_action == 1
		var set_flat := SetStage.data_pose(set_phase, set_jump, -1.0 if lab.dominant_hand == "Left" else 1.0)
		if travel_weight > 0.0:
			# A ground set keeps its hands (shoulders, elbows, forearms); everything else stays with the walk cycle.
			var walk: Dictionary = PoseLibrary.read_rig(lab.body)
			for key in set_flat:
				if walk.has(key) and not (key.begins_with("shoulder_") or key.begins_with("elbow") or key.begins_with("forearm_")):
					set_flat[key] = lerpf(float(set_flat[key]), float(walk[key]), travel_weight)
		# Running with a set ready, the hands relax down and out a little but stay in front, ready to come up to the forehead.
		if travel_weight > 0.0 and not set_jump and lab.armed and lab.locked_action == 1 and set_phase <= SetStage.GATHER_PHASE + 0.01:
			for side in PoseLibrary.SIDES:
				var relax := travel_weight * SET_RUN_RELAX
				set_flat["shoulder_pitch:%s" % side] = lerpf(float(set_flat["shoulder_pitch:%s" % side]), 62.0, relax)
				set_flat["shoulder_roll:%s" % side] = lerpf(float(set_flat["shoulder_roll:%s" % side]), 34.0, relax)
				set_flat["elbow:%s" % side] = lerpf(float(set_flat["elbow:%s" % side]), 76.0, relax)
		PoseLibrary.apply(lab.body, PoseLibrary.from_flat(set_flat, false), 1.0)


func _apply_contact_response(diving_now: bool, preparing_dive: bool) -> void:
	if not (diving_now or preparing_dive) and roll_lock <= 0.0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0:
		var action: int = lab.motion.airborne_action if lab.motion.jumped else lab.selected
		var age := contact_age if action == contact_action else -1.0
		var press: float = lab.block_state.confirmation_age if lab.block_state.active and action == 3 else -1.0
		ContactResponse.apply(lab.body, ContactResponse.offsets(action, age, contact_evidence, press))


func _finish_pose(diving_now: bool, preparing_dive: bool) -> void:
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
	carry.update(lab,pose_frame_dt)
	if lab.drills.has_method("apply_drill_pose"):
		lab.drills.apply_drill_pose()

# Only presentation consumes this finalized snapshot; floor recoveries retain priority.
func on_contact(event: Dictionary) -> void:
	if str(event.get("actor", "")) != "player" or not bool(event.get("physical_hit", false)):
		return
	contact_action = int(event.get("action", -1))
	contact_age = 0.0
	contact_evidence = {"charge_match": event.get("charge_match", {}).duplicate(true), "block_response": event.get("block_response", {}).duplicate(true)}

func reset_contact() -> void:
	contact_age = -1.0
	contact_action = -1
	contact_evidence.clear()

# Steps the locomotion layer once per rendered frame, however many times the pose is rebuilt in it.
func step_locomotion(enabled: bool) -> Dictionary:
	var frame := Engine.get_process_frames()
	var dt := pose_frame_dt if frame != locomotion_frame else 0.0
	locomotion_frame = frame
	return locomotion.update(dt, {"facing_yaw": dive_base_yaw, "velocity": lab.player.velocity, "wish": lab.directional_input.value(), "enabled": enabled, "hips": locomotion_hips})

# The spine for a turned pelvis: hips turned to the direction of travel, lumbar, chest and neck turned back so the head faces the cursor.
func apply_locomotion_spine(state: Dictionary) -> void:
	var torso := lab.body.get_node("Torso") as Node3D
	SpineRig.pose(lab.body, {"hip_hinge": -rad_to_deg(torso.rotation.x) + float(state.lean), "hip_yaw": float(state.hip_yaw), "lumbar_twist": float(state.lumbar_twist), "thoracic_twist": float(state.thoracic_twist), "neck_twist": float(state.neck_twist)})
	torso.rotation = Vector3.ZERO
	lab.body.get_node("Head").rotation.y = 0.0

# The hands gather as the ball comes in, so there is motion to watch before the set instead of a pose that was simply there: from the ready
# stance when the ball is far to gathered at the forehead as it arrives. With no ball coming, the gather holds.
func anticipated_gather() -> float:
	if not lab.ball_active:
		return SetStage.GATHER_PHASE
	var to_athlete: Vector3 = lab.player.position + Vector3.UP * lab.athlete.reach() - lab.ball.position
	var closing: float = lab.ball_velocity.dot(to_athlete.normalized())
	if closing <= 0.5:
		return SetStage.GATHER_PHASE
	var arrives_in: float = to_athlete.length() / closing
	return lerpf(-0.72, SetStage.GATHER_PHASE, smoothstep(1.0, 0.12, arrives_in))

# Hands gather while armed, extend after contact, and follow the jump-set flight.
# Returns -2 when no set layer is active.
func set_phase() -> float:
	if lab.motion.jumped and lab.motion.airborne_action == 1:
		var f := clampf(set_air_time / maxf(set_flight_time, 0.001), 0.0, 1.0)
		return lerpf(-0.30, 0.04, f / 0.5) if f < 0.5 else lerpf(0.04, 0.45, (f - 0.5) / 0.5)
	if lab.motion.jumped or lab.motion.jump_charge >= 0.0:
		return -2.0
	var since := (lab.elapsed - lab.last_contact)*lab.athlete.transition_rate()
	if since >= 0.0 and since < SetStage.FOLLOW_SECONDS and int(lab.last_contact_result.get("action", -1)) == 1:
		return SetStage.follow_phase(since)
	if lab.armed and lab.locked_action == 1:
		return anticipated_gather()
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
	var prepping := not lab.motion.jumped and lab.motion.jump_charge >= 0.0 and lab.motion.approach_action == 0 and lab.motion.approach_bound
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
	floor_recovery_lateral = clampf(absf(coord.x) / FloorRecovery.LATERAL_FULL, 0.0, 1.0)
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
	var state := FloorRecovery.at(floor_recovery_name, seconds, floor_recovery_side, floor_recovery_root, floor_recovery_flat, floor_recovery_lateral)
	FloorRecovery.apply(lab.body, state)


func _init(session: LabSession) -> void:
	lab = session
