extends RefCounted

# Shared action presentation for court helpers and Pepper partners. Uses the same
# authored files/stages as the athlete; never moves the actor or changes collision.
const ContactResponse := preload("res://scripts/contact_response_pose.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const Library := preload("res://scripts/pose_library.gd")
const Smoother := preload("res://scripts/pose_smoother.gd")
const Receive := preload("res://scripts/receive_pose.gd")
const Platform := preload("res://scripts/receive_platform.gd")
const SetStage := preload("res://scripts/set_stage.gd")
const SpikeStage := preload("res://scripts/spike_stage.gd")
const Wing := preload("res://scripts/wing_pose.gd")
const Dive := preload("res://scripts/dive_stage.gd")
const Recovery := preload("res://scripts/dive_recovery.gd")
var states: Dictionary = {}

func reset() -> void:
	for key in states:
		var body := instance_from_id(key) as Node3D
		if is_instance_valid(body):
			body.rotation.y -= float(states[key].dive_yaw)
			body.rotation.x = 0.0
			body.rotation.z = 0.0
	states.clear()

func state_for(body: Node3D) -> Dictionary:
	var key := body.get_instance_id()
	if not states.has(key):
		states[key] = {"since": 100.0, "action": -1, "point": Vector3.ZERO, "posture": "planted", "swing_yaw": 0.0, "rescue": false, "smoother": Smoother.new(), "source": "locomotion", "phase": -2.0, "dive_yaw": 0.0}
	return states[key]

func contact(rig: Dictionary, action: int, point: Vector3, posture: String = "planted", swing_yaw: float = 0.0, rescue: bool = false, evidence: Dictionary = {}) -> void:
	var state := state_for(rig.body)
	state.merge({"since": 0.0, "action": action, "point": point, "posture": posture, "swing_yaw": swing_yaw, "rescue": rescue, "contact_evidence": {"charge_match": evidence.get("charge_match", {}).duplicate(true), "block_response": evidence.get("block_response", {}).duplicate(true)}}, true)

func update(rig: Dictionary, dt: float, context: Dictionary = {}) -> void:
	var body: Node3D = rig.body
	var state := state_for(body)
	state.since += dt*float(context.get("transition_rate",1.0))
	body.rotation.y -= float(state.dive_yaw)
	state.dive_yaw = 0.0
	body.rotation.x = 0.0
	body.rotation.z = 0.0
	var action := int(context.get("action", -1))
	var planned := bool(context.get("planned", false))
	var airborne := bool(context.get("airborne", false))
	var speed := float(context.get("speed", 0.0))
	var remaining := float(context.get("remaining", 1.0))
	var hand := float(context.get("hand", 1.0))
	var source := "locomotion"
	var phase := -2.0
	if not context.get("preserve_base", false):
		Pose.base(body, float(context.get("cycle", 0.0)), speed, float(context.get("heading", 0.0)), planned and action == 0)
	var follow := float(state.since) < (0.75 if int(state.action) == 2 else (SetStage.FOLLOW_SECONDS if int(state.action) == 1 else 0.50)) and (not planned or action == int(state.action))
	var shown_action := int(state.action) if follow else (action if planned else -1)
	if shown_action == 0:
		var point: Vector3 = state.point if follow else context.get("contact_point", Vector3(0, 0.95, -0.65))
		var posture: String = state.posture if follow else str(context.get("posture", "moving" if speed > 0.45 else "planted"))
		Receive.apply(body, posture, point, 1.0)
		source = "receive:" + posture
	elif shown_action == 1:
		phase = SetStage.follow_phase(float(state.since)) if follow else lerpf(-0.72, -0.16, 1.0 - clampf(remaining / 0.45, 0, 1))
		SetStage.apply_data(body, phase, airborne, hand)
		source = "set"
	elif shown_action == 2 and (airborne or follow):
		phase = lerpf(0.0, 0.72, clampf(float(state.since) / 0.65, 0, 1)) if follow else lerpf(-0.62, 0.0, 1.0 - clampf(remaining / maxf(float(context.get("rise", 0.4)), 0.01), 0, 1))
		if not follow and float(context.get("swing_age", -1.0)) >= 0.0:
			phase = SpikeStage.swing_phase(float(context.swing_age))
		var swing_yaw := float(state.swing_yaw) if follow else float(context.get("swing_yaw", 0.0))
		var ball_local: Vector3 = state.point if follow else context.get("contact_point",Vector3(0,2.3,-0.4))
		SpikeStage.apply(body,phase,hand,float(context.get("charge",0.65)),"Power swing",{"ball_local":ball_local,"shot_yaw":swing_yaw})
		if follow and state.rescue:
			body.get_node("LeftArm" if hand < 0 else "RightArm").rotation.x = lerpf(-1.0, -1.65, sin(clampf(float(state.since) / 0.28, 0, 1) * PI))
		source = "air:2"
	elif shown_action == 3 and airborne:
		for arm in rig.arms:
			arm.rotation.x = -2.9
			arm.get_node("Elbow").rotation.x = 0.0
		source = "air:3"
	# These hooks use the same dive/recovery stages whenever a bot behavior
	# actually supplies a dive state; ordinary reaching receives stay standing.
	if context.has("dive_phase"):
		var dive := Dive.resolve(float(context.dive_phase), context.get("dive_direction", Vector2(0, 1)))
		state.dive_yaw = Dive.apply(body, dive)
		source = "dive"
	elif context.has("dive_recovery_time"):
		Recovery.apply(body, Recovery.at(float(context.dive_recovery_time), context.get("dive_direction", Vector2(0, 1)), float(context.get("dive_quality", 0.7)), context.get("dive_root", Vector2.ZERO)))
		source = "dive"
	if source != "dive":
		ContactResponse.apply(body, ContactResponse.offsets(shown_action, float(state.since) if follow else -1.0, state.get("contact_evidence", {}), float(context.get("block_age", -1.0)) if airborne else -1.0))
	var smoothed: Dictionary = state.smoother.update(Library.read_rig(body), source, dt)
	Library.apply(body, Library.from_flat(smoothed, false), 1.0)
	Wing.apply(body, "tucked", "block" if shown_action == 3 and airborne else ("balance" if source == "dive" else "tucked"), 1.0)
	if context.has("dive_recovery_time"):
		Recovery.rest_on_floor(body, float(context.get("floor_y", 0)))
	else:
		Pose.ground_feet(body)
	state.source = source
	state.phase = phase
