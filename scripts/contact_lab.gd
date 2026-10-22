class_name LabSession
extends Node3D

@export var camera_tuning: LabCameraTuning = preload("res://resources/lab_camera.tres")

signal receive_resolved(event: Dictionary)
const ContactEvent := preload("res://scripts/contact/contact_event.gd")
const ContactRequest := preload("res://scripts/contact/contact_request.gd")
const ContactResolver := preload("res://scripts/contact/contact_resolver.gd")
const Action := preload("res://scripts/contact/action.gd").Type


const ReceiveCharge := preload("res://scripts/receive_charge.gd")
var ball_shot: Dictionary = {}
var last_receive_match: Dictionary = {}
const ReceivePlatform := preload("res://scripts/receive_platform.gd")
const ContactIntent := preload("res://scripts/contact_intent.gd")
const DirectionalInfluence := preload("res://scripts/directional_influence.gd")
var directional_input := DirectionalInfluence.new()
var last_directional_influence: Dictionary = {}
const MoC := preload("res://scripts/moment_of_contact.gd")
const NetResponse := preload("res://scripts/net_response.gd")
var net_response := NetResponse.new()
var net_bounce_pending := false
var net_body: StaticBody3D
var moc: Node
var committed_intent: Dictionary = {}
var last_contact_result: Dictionary = {}
var _contact_event_serial := 0

const Athlete = preload("res://scripts/athlete.gd")
const ReceivePass := preload("res://scripts/receive_pass.gd")
const Execution = preload("res://scripts/contact_execution.gd")
const Geometry = preload("res://scripts/contact_geometry.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const DiveRecovery := preload("res://scripts/dive_recovery.gd")
const VoliVisual = preload("res://scripts/voli_visual.gd")
const Approach = preload("res://scripts/approach_run.gd")
const Flight = preload("res://vendor/vwm/ball_flight_model.gd")
const GRAVITY = Flight.DEFAULT_GRAVITY_MPS2
const SPIKE_SPEED_MULTIPLIER := 1.50
const ATTACK_DRIVE_FACTOR := 1.40
# The launch angle the bump's range is measured at, in degrees. The calibrated height ceiling stays where it was, so a higher angle is a steeper
# bump that lands shorter rather than a higher one: the arc's angle follows from its height over its range.
const BUMP_ANGLE := 68.0
# A jumping attack's base launch angle before charge and the view add to it (negative is downward).
const SPIKE_BASE_ANGLE := -9.0
const SET_RISE_FACTOR := 0.80
const SET_RANGE_FACTOR := 1.40
const GROUND_SET_RANGE_FACTOR := 1.65
const GROUND_SET_RISE_FACTOR := 0.80
var start_position := Vector3(0, 0.03, 5.0)
var station_origin := Vector3.ZERO
var box_origin := Vector3.ZERO
var spike_origin := Vector3.ZERO
const ACTIONS = preload("res://scripts/contact/action.gd").CONTACT_LABELS
const TEAL = Color("54ead0")
const GOLD = Color("ffce73")
var serve: Node3D
var pepper: Node3D
var debug_volumes_visible := true
# Hurtboxes tilt with the aimed angle (the half-pipe faces where the athlete is aiming), about the shoulder. A setting, on by default.
var rotate_hurtboxes := true
# R toggles the modified action: Back Set (with the Back Set Trait) when setting, Float Serve (with the Float Serve Trait) when serving.
var back_set := false
var perf_meter: CanvasLayer # F3
const BACK_SET_TRAIT := "accuracy_back_set"
const FLOAT_SERVE_TRAIT := "acc_float_serve"
const NEUTRAL_VIEW_PITCH := -0.12 # the resting view: boxes tilt by how far the aim has moved from it
const MAX_HURTBOX_PITCH := 0.6
const BallFraming := preload("res://scripts/ball_camera_framing.gd")
var facing_arrow: MeshInstance3D
var drills: Node3D
var bot_pads: Node3D
var court_center := Vector3.ZERO
var net_height := 2.43
var court_half_width := 4.5
var court_half_depth := 9.0
var court_outline: MeshInstance3D
var debug_feed_target := Vector3.ZERO
var debug_feed_locked := false
var creator: CanvasLayer
var dominant_hand := "Right"
var body_type := "Feli"
var appearance := {"palette_index": 0, "marking": "none"}
var athlete_name := "Rookie"
var position_role := "OH"
var visual_rig_height := 1.86
var visual_hip_x := 0.13
var athlete: LabAthlete = Athlete.new()
var player: CharacterBody3D
var body: Node3D
var camera: Camera3D
var ball: MeshInstance3D
var shadow: MeshInstance3D
var landing_marker: MeshInstance3D
var aim_marker: MeshInstance3D
var reach_ring: MeshInstance3D
const TrajectoryPreview := preload("res://scripts/trajectory_preview.gd")
var last_trajectory_preview: Dictionary = {}
var block_state := preload("res://scripts/block_state.gd").new()
var ground_balls := preload("res://scripts/ground_ball.gd").new()
var inventory := preload("res://scripts/ball_inventory.gd").new()
var ball_carts: Node3D # the map's net carts (null in the practice lab)

# The player's team by court side: Blue plays the z > 0 half of the map.
func player_team() -> String:
	return "blue" if player.position.z >= 0.0 else "red"
var _preview_mesh := ImmediateMesh.new()
var preview: MeshInstance3D
var approach_footprints: Array[MeshInstance3D] = []
var approach_preview: MeshInstance3D
var trail: MeshInstance3D
var athlete_level := 1
var contact_flow: Node3D
var impact_visual: Node3D
var bench: Node3D
var station: Node3D
var hurtbox_view: LabHurtboxView
var hurtbox_root: Node3D
var hurtbox_mesh: MeshInstance3D
var hurtbox_label: Label3D
var confirmed_geometry: Dictionary = {}
var hurtbox_action := -1
var hurtbox_linger := 0.0
var training_bots: Node3D
var feedback := "Move under the ball. 1 / 2 / 3 / 4 select a contact."
var feedback_time := 0.0
var selected := 0
var locked_action := 0
var charging := false
var armed := false
const AutoCharge := preload("res://scripts/auto_charge.gd")
var auto_preparation := AutoCharge.new()
var charge := 0.0
var locked_charge := 0.0
var confirm_window := 0.0
var confirm_duration := 0.0
var sweet_visual_expired := false
var sweet_visual_phase := ""
var rescue_swing_remaining := 0.0
var aim := Vector3(0, 0, -6)
var ball_velocity := Vector3.ZERO
var ball_active := false
var outgoing := false
var feed_timer := 2.5
var auto_feed := false
var paused := false
var side_contacts: Array[int] = [0, 0]
var rally_rules := preload("res://scripts/rally_rules.gd").new()
var contacts := 0
var attempts := 0
var returns := 0
var build_index := 0
var last_quality := "—"
var last_contact := -10.0
var elapsed := 0.0
var trail_points: Array[Vector3] = []
const ViewMode = LabCamera.ViewMode
var cursor_release_click := false
var action_endlag := 0.0
const ROLL_TIME := 0.9
var contact_memory: Array[float] = [0.0, 0.0, 0.0, 0.0]
var body_collision_view: MeshInstance3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []


var camera_rig: LabCamera = LabCamera.new(self)
var motion: AthleteMotor = AthleteMotor.new(self)
var animation: AthleteAnimation = AthleteAnimation.new(self)
var hud: LabHud = LabHud.new(self)
var world_builder: LabWorldBuilder = LabWorldBuilder.new(self)

func build_net_visuals() -> void:
	world_builder.build_net_visuals()

func build_net_colliders() -> void:
	world_builder.build_net_colliders()

func clear_net_responses() -> void:
	net_response.clear()

func resolve_ball_net(previous: Vector3,dt: float) -> Dictionary:
	return net_response.step(previous,ball.position,ball_velocity,dt,float(ball_shot.get("charge",0)))

func athlete_touches_net(from: Vector3,to: Vector3,height: float = 1.7,radius: float = NetResponse.MIDLINE_RADIUS) -> bool:
	return net_response.touches_body(from,to,height,radius)

func net_collision_rids() -> Array[RID]:
	return [net_body.get_rid()]

var current_net := 1
var bot_menu: RefCounted

func bot_courts() -> Dictionary:
	return {1:{"position":court_center,"width":court_half_width*2,"depth":court_half_depth*2,"height":net_height}}

func interact_nearby_bot() -> bool:
	var best := -1
	var distance := 2.2
	for slot in range(training_bots.actors.size()):
		if not training_bots.actors[slot].visible: continue
		var next: float = player.position.distance_to(training_bots.actors[slot].position)
		if next < distance:
			distance = next
			best = slot
	if best < 0: return false
	if bot_menu == null: bot_menu = preload("res://scripts/map_bot_menu.gd").new(hud)
	bot_menu.open_bot(best)
	return true

func uses_legacy_bot_pads() -> bool:
	return true

func _create_training_bots() -> Node3D:
	return preload("res://scripts/map_bot_roster.gd").new()

func open_bot_menu() -> bool:
	if bot_menu == null: bot_menu = preload("res://scripts/map_bot_menu.gd").new(hud)
	bot_menu.toggle()
	return true

func refresh_bot_rally() -> void:
	if is_instance_valid(moc) and moc.acting_actor == "ground": moc.clear()
	if is_instance_valid(contact_flow): contact_flow.start_rally()
	training_bots.refresh_for_rally()
	pepper.refresh_for_rally()

func prepare_serve_context() -> void:
	pass

func _ready() -> void:
	receive_resolved.connect(animation.on_receive_resolved)
	moc = MoC.new()
	moc.owner_lab = self
	add_child(moc)
	world_builder.build()
	_build_player()
	training_bots = _create_training_bots()
	add_child(training_bots)
	training_bots.setup(self)
	_build_activities()
	if uses_legacy_bot_pads():
		bot_pads = preload("res://scripts/bot_pads.gd").new()
		add_child(bot_pads)
		bot_pads.setup(self)
	serve = preload("res://scripts/interactive_serve.gd").new()
	add_child(serve)
	serve.setup(self)
	pepper = preload("res://scripts/pepper_partners.gd").new()
	add_child(pepper)
	pepper.setup(self)
	_build_hurtbox()
	_build_ui()
	bench = preload("res://scripts/bench_status.gd").new()
	add_child(bench)
	bench.setup(self)
	impact_visual = preload("res://scripts/impact_visual.gd").new()
	add_child(impact_visual)
	impact_visual.setup(self)
	contact_flow = preload("res://scripts/contact_flow.gd").new()
	add_child(contact_flow)
	contact_flow.setup(self)
	creator = preload("res://scripts/athlete_creator.gd").new()
	add_child(creator)
	creator.setup(self)
	var chosen: Dictionary = preload("res://scripts/athlete_store.gd").selected_config()
	if not chosen.is_empty():
		apply_created_athlete(chosen)
	_reset()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.use_accumulated_input = false
	var presets := preload("res://scripts/bot_roster_presets.gd")
	if get_tree().get_meta(presets.STARTUP_META,false):
		get_tree().remove_meta(presets.STARTUP_META)
		presets.apply_net_2.call_deferred(training_bots)

func bench_home() -> Vector3:
	return Vector3(0,0.03,48)

func pepper_spots() -> Array:
	return preload("res://scripts/pepper_partners.gd").SPOTS.duplicate()

func movement_in_rally() -> bool:
	return pepper.active() or (ball_active and not station.running() and not drills.running())

func world_half_extent() -> float:
	return 80.0

func _build_activities() -> void:
	station = preload("res://scripts/serve_receive_station.gd").new()
	add_child(station)
	station.setup(self)
	drills = preload("res://scripts/map_drills.gd").new()
	add_child(drills)
	drills.setup(self)

func _process(dt: float) -> void:
	animation.pose_frame_dt = dt * moc.actor_scale("player")
	var now := Time.get_ticks_usec()
	var real_dt := minf(float(now - camera_rig._camera_frame_usec) / 1000000.0, 0.1) if camera_rig._camera_frame_usec > 0 else dt
	camera_rig._camera_frame_usec = now
	if paused:
		moc.clear()
	if not paused:
		camera_rig.update_aim()
		moc.steer(real_dt,directional_input.value())
		animation.update()
		camera_rig.update(real_dt)
		_update_contact_preview()
		_update_hurtbox_visual(dt)
		impact_visual.tick(real_dt)
		contact_flow.tick_visuals()

func _build_lanes_and_bases() -> void:
	for lane_x in [-36.0, 0.0, 36.0]:
		world_builder.box(self, Vector3(5, 0.015, 120), Vector3(lane_x, -0.015, 0), Color("223c45"))
		world_builder.world_label("%s LANE" % ("MIDDLE" if lane_x == 0 else ("WEST" if lane_x < 0 else "EAST")), Vector3(lane_x, 0.03, -25), 40, TEAL)
	for z in [-48.0, 48.0]:
		world_builder.box(self, Vector3(77, 0.015, 6), Vector3(0, -0.015, z), Color("29434b"))
		world_builder.world_label("AWAY BASE" if z < 0 else "HOME BASE", Vector3(0, 0.03, z), 48, GOLD)
	world_builder.world_label("OPEN JUNGLE / DRILL SPACE", Vector3(-18, 0.03, 14), 30, TEAL)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Athlete"
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.7
	col.shape = capsule
	col.position.y = 0.85
	player.add_child(col)
	add_child(player)
	_rebuild_visual()
	body_collision_view = MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = capsule.radius
	capsule_mesh.height = capsule.height
	body_collision_view.mesh = capsule_mesh
	body_collision_view.position.y = 0.85
	body_collision_view.material_override = world_builder.debug_material(Color("ffffff"), 0.045)
	player.add_child(body_collision_view)

func _rebuild_visual() -> void:
	if hurtbox_view != null:
		hurtbox_view.clear()
		hurtbox_action = -1
	if is_instance_valid(body):
		body.get_parent().remove_child(body)
		body.queue_free()
	var rig := VoliVisual.build(self, player, body_type, appearance, athlete.build)
	body = rig.body
	arms = rig.arms
	legs = rig.legs
	visual_rig_height = rig.rig_height
	visual_hip_x = rig.hip_x
	if is_instance_valid(hud.athlete_hud):
		hud.athlete_hud.refresh_portrait()

func apply_created_athlete(config: Dictionary) -> void:
	config = preload("res://scripts/athlete_store.gd").migrate(config)
	body_type = str(config.body_type)
	appearance = config.appearance.duplicate(true)
	athlete_name = str(config.name).strip_edges()
	if athlete_name.is_empty():
		athlete_name = "Rookie"
	athlete_level = int(config.get("level", 1))
	position_role = str(config.role)
	dominant_hand = str(config.get("dominant_hand", "Right"))
	var build := {"name": athlete_name.to_upper() + " / " + position_role, "height": float(config.height), "span": float(config.span), "wingspan_ratio": preload("res://scripts/athlete_store.gd").wingspan_ratio(config), "stride_ratio": preload("res://scripts/athlete_store.gd").stride_ratio(config)}
	for attribute in ["power", "speed", "accuracy", "endurance"]:
		build[attribute] = float(config[attribute])
	build["offsets"] = config.get("offsets", {}).duplicate(true)
	build["statistics"] = config.get("statistics",{}).duplicate(true)
	build["stat_version"] = config.get("stat_version",2)
	if config.has("picks"):
		build["picks"] = config.picks.duplicate()
	build["stat_names"] = config.get("stat_names",preload("res://scripts/athlete_store.gd").STATS).duplicate(true)
	athlete.build = build
	athlete.trait_ids = preload("res://scripts/athlete_store.gd").owned_trait_ids(config)
	athlete.trait_via = config.get("via", {}).duplicate()
	_rebuild_visual()
	_reset()
	_message(athlete_name + " / " + body_type + " / ready to train" + ((" / traits: " + ", ".join(athlete.trait_ids)) if not athlete.trait_ids.is_empty() else ""))

func _hurtbox_definition(action: int) -> Dictionary:
	if confirm_window > 0 and action == hurtbox_action and not confirmed_geometry.is_empty():
		return confirmed_geometry
	return _raw_hurtbox_definition(action)

func _raw_hurtbox_definition(action: int) -> Dictionary:
	var height: float = athlete.build.height
	var scale_to_world: float = preload("res://scripts/voli_visual.gd").model_height(height) / visual_rig_height
	var shoulder := arms[1].position.y * scale_to_world if arms.size() > 1 else height * 0.815
	var shoulder_x := absf(arms[1].position.x) * scale_to_world if arms.size() > 1 else height * 0.17
	var shape := Geometry.definition(action, height, athlete.reach(), motion.jumped and motion.airborne_action == 0, -1.0 if dominant_hand == "Left" else 1.0, shoulder, shoulder_x, athlete.ball_control(), Geometry.arm_length(arms[0 if dominant_hand == "Left" else 1], scale_to_world),athlete.build)
	if action == 0:
		shape["platform_quality"] = athlete.trait_effect("platform_quality")
	if is_instance_valid(contact_flow):
		var effects: Dictionary = contact_flow.shape_effects("player",action)
		if action == 0: shape["platform_quality"] = effects.get("platform_quality",0)
		shape = Geometry.with_effects(shape,effects)
	return shape

func _contact_yaw() -> float:
	var facing := motion.airborne_aim if motion.jumped else Vector3(-sin(camera_rig.facing_yaw), 0, -cos(camera_rig.facing_yaw))
	return atan2(-facing.x, -facing.z)

func _build_hurtbox() -> void:
	hurtbox_root = Node3D.new()
	add_child(hurtbox_root)
	hurtbox_root.hide()
	hurtbox_view = LabHurtboxView.new(hurtbox_root, world_builder)

func _confirm_action(window: float = -1.0) -> void:
	if block_state.active and locked_action == 3 and not block_state.confirm(): return
	if _check_bench():
		return
	if locked_action == 0:
		motion.cancel_receive_preparation()
	# The click is what starts the strike. Until then the spiker only loads.
	if motion.jumped and motion.airborne_action == 2 and locked_action == 2 and animation.spike_swing_time < 0.0:
		animation.spike_swing_time = 0.0
	_capture_contact_intent()
	confirmed_geometry = {}
	confirm_window = minf(window, Execution.contact_seconds(locked_action)) if window > 0 else Execution.contact_seconds(locked_action)
	confirm_duration = confirm_window
	sweet_visual_expired = false
	sweet_visual_phase = ""
	hurtbox_action = locked_action
	hurtbox_linger = confirm_window + 0.35
	var shape := _hurtbox_definition(locked_action)
	confirmed_geometry = shape.duplicate(true)
	var presentation := hurtbox_view.present(shape, locked_action)
	hurtbox_mesh = presentation.mesh
	hurtbox_label = presentation.label
	hurtbox_root.show()
	_update_hurtbox_visual(0.0)

func _update_hurtbox_visual(dt: float) -> void:
	if hurtbox_action < 0 or not is_instance_valid(hurtbox_root):
		return
	rescue_swing_remaining = maxf(0, rescue_swing_remaining - dt*athlete.transition_rate())
	hurtbox_linger = maxf(0.0, hurtbox_linger - dt)
	if confirm_window > 0 or (block_state.active and hurtbox_action == 3):
		if block_state.active: hurtbox_linger = 1
		var definition := _hurtbox_definition(hurtbox_action)
		hurtbox_root.rotation = Vector3(hurtbox_pitch(), _contact_yaw(), 0.0)
		hurtbox_root.position = player.position + hurtbox_center_local(definition.center as Vector3).rotated(Vector3.UP, _contact_yaw())
	var age := block_state.confirmation_age if block_state.active and hurtbox_action == 3 else confirm_duration - maxf(confirm_window, 0)
	sweet_visual_expired = age > Execution.sweet_end(hurtbox_action)
	var phase := "sweet" if (age >= 0 and age < 0.5 if hurtbox_action == 3 else Execution.sweet_active(hurtbox_action, age)) else ("windup" if age < Execution.sweet_start(hurtbox_action) else "rescue")
	if phase != sweet_visual_phase:
		for child in hurtbox_view.active.get_children():
			if child is MeshInstance3D and child.name != "ActiveSweep":
				if not child.has_meta("sweet_material"):
					child.set_meta("sweet_material", child.material_override)
				child.material_override = child.get_meta("sweet_material") if phase == "sweet" or hurtbox_action == 3 else hurtbox_view.phase_material(phase)
		sweet_visual_phase = phase
	if is_instance_valid(hurtbox_label):
		hurtbox_label.text = ACTIONS[hurtbox_action] + (" / WINDUP" if phase == "windup" else (" / SWEET ACTIVE" if phase == "sweet" else " / RESCUE"))
		if block_state.active and hurtbox_action == 3: hurtbox_label.text = "BLOCK / PRESS %.0f%%" % (100*pow(clampf(1-age/0.5,0,1),3)) if age >= 0 and age < 0.5 else "BLOCK / PASSIVE"
		if hurtbox_action == 2 and phase == "rescue" and age < Execution.SPIKE_RESCUE_SECONDS:
			hurtbox_label.text = "ATTACK / ROLL SHOT" if age < Execution.SPIKE_POWER_START else "ATTACK / FORGIVING SPIKE"
	if hurtbox_action == 2:
		hurtbox_view.update_spike_sweep(_hurtbox_definition(2), age)
		if is_instance_valid(hurtbox_label):
			hurtbox_label.text = "ATTACK / WINDUP %.2f" % maxf(0.0, Execution.SPIKE_WINDUP - age) if age < Execution.SPIKE_WINDUP else ("ATTACK / " + ("ROLL" if age < Execution.SPIKE_POWER_START else ("POWER" if age < Execution.SPIKE_RESCUE_SECONDS else "PUSH")))
	if hurtbox_action == 0 and is_instance_valid(hurtbox_label):
		hurtbox_label.text += " / " + animation.receive_posture.to_upper()
	hurtbox_root.visible = debug_volumes_visible and hurtbox_linger > 0

# The tilt of every hurtbox from its neutral orientation: how far the aim is raised (positive) or lowered from the neutral view.
func hurtbox_pitch() -> float:
	if not rotate_hurtboxes or camera_rig == null:
		return 0.0
	return clampf(camera_rig.view_pitch - NEUTRAL_VIEW_PITCH, -MAX_HURTBOX_PITCH, MAX_HURTBOX_PITCH)

func hurtbox_pivot() -> Vector3:
	var height: float = athlete.build.height
	return Vector3(0.0, arms[1].position.y * (preload("res://scripts/voli_visual.gd").model_height(height) / visual_rig_height) if arms.size() > 1 else height * 0.815, 0.0)

# Where a hurtbox's centre is, relative to the athlete before the yaw: the shape's own centre, tilted about the shoulder.
func hurtbox_center_local(center: Vector3) -> Vector3:
	var pitch := hurtbox_pitch()
	if pitch == 0.0:
		return center
	var pivot := hurtbox_pivot()
	return pivot + (center - pivot).rotated(Vector3.RIGHT, pitch)

func _local_contact_position() -> Vector3:
	return local_contact_position_at(ball.position)

# A world point in the athlete's hurtbox frame: turned by the contact yaw and untilted about the shoulder.
func local_contact_position_at(world_point: Vector3) -> Vector3:
	var point := (world_point - player.position).rotated(Vector3.UP, -_contact_yaw())
	var pitch := hurtbox_pitch()
	if pitch == 0.0:
		return point
	var pivot := hurtbox_pivot()
	return pivot + (point - pivot).rotated(Vector3.RIGHT, -pitch)

func _overlaps_contact(action: int) -> bool:
	return Geometry.contains(_hurtbox_definition(action), _local_contact_position())

func contact_request(action: int) -> ContactRequest:
	var request := ContactRequest.new()
	request.action = action
	request.response_seed = _contact_event_serial + 1
	request.athlete = athlete
	request.shape = _hurtbox_definition(action)
	request.local_point = _local_contact_position()
	request.origin = ball.position
	request.incoming = ball_velocity
	request.incoming_shot = ball_shot
	request.charge = prepared_output_charge() if action == locked_action else locked_charge
	if auto_preparation.active and action == locked_action:
		request.auto_charge = true
		request.auto_evidence = auto_preparation.sample(athlete,ball_shot,ball_velocity)
		request.handling_charge = float(request.auto_evidence.handling_charge)
	if action == 3 and not auto_preparation.active: request.block_charge_reference = request.charge
	request.block_confirmation_age = block_state.confirmation_age if block_state.active else (confirm_duration-maxf(confirm_window,0) if confirm_window > 0 else -1.0)
	request.confirmation_age = confirm_duration - maxf(confirm_window, 0) if confirm_duration > 0 else Execution.ideal_age(action)
	request.remembered = not Geometry.contains(request.shape, request.local_point) and contact_memory[action] > 0
	request.facing = Vector3.FORWARD.rotated(Vector3.UP, _contact_yaw())
	request.intent_direction = _intent_direction(action, committed_intent.get("direction", request.facing))
	request.directional_input = Vector3.ZERO if moc.enabled and moc.steering_duration > 0 and moc.mode == moc.Mode.TRAJECTORY_STEERING else directional_input.value()
	request.movement_speed = Vector2(player.velocity.x, player.velocity.z).length()
	request.flow = athlete.flow
	request.gravity = GRAVITY
	request.apply_set_spread = true
	request.net_distance = receive_net_distance()
	request.apply_block_spread = true
	return request

func _contact_assessment(action: int) -> Dictionary:
	return ContactResolver.assess(contact_request(action))

func _remember_contacts(dt: float) -> void:
	for action in range(4):
		contact_memory[action] = maxf(0.0, contact_memory[action] - dt)
		if ball_active and _overlaps_contact(action):
			contact_memory[action] = 0.10

func _input(event: InputEvent) -> void:
	if is_instance_valid(creator) and creator.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			creator.close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.pressed and event.keycode == KEY_E:
		serve.release()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused and not hud.help_panel.visible and not is_benched():
		camera_rig.rotate_view(event.screen_relative)

func _return_to_title() -> void:
	moc.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://title.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if is_benched():
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_V: bench.toggle_spectate()
		# Left and right click cycle the watched teammate (R is the float serve / back set toggle).
		if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT: bench.cycle(-1)
				MOUSE_BUTTON_RIGHT: bench.cycle(1)
		if not (event is InputEventKey and event.keycode in [KEY_O, KEY_M, KEY_P, KEY_T, KEY_H, KEY_F3, KEY_F8, KEY_F9, KEY_K]):
			return
	if is_instance_valid(creator) and creator.visible:
		return
	if (animation.roll_lock > 0.0 or animation.dive_input_locked() or animation.floor_input_locked()) and not (event is InputEventKey and event.keycode in [KEY_O, KEY_M, KEY_P, KEY_T, KEY_H, KEY_F3, KEY_F8, KEY_F9, KEY_K]):
		return
	if not paused and drills.has_method("drill_input") and drills.drill_input(event):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		motion.note_direction_tap(event)
		match event.keycode:
			KEY_O: hud.toggle_moc_mode()
			KEY_K: hud.toggle_debug_volumes()
			KEY_F8: hud.ui.visible = not hud.ui.visible
			KEY_F9: hud.toggle_bot_menu()
			KEY_H:
				hud.help_panel.visible = not hud.help_panel.visible
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if hud.help_panel.visible else Input.MOUSE_MODE_CAPTURED
			KEY_P:
				paused = not paused
				if paused:
					moc.clear()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
			KEY_T: _reset()
			KEY_C: creator.open()
			KEY_M: _return_to_title()
			KEY_B: _feed()
			KEY_E: serve.input_press()
			KEY_R: toggle_modifier()
			KEY_F3: perf_meter.toggle()
			KEY_TAB: _cycle_build()
			KEY_F5:
				debug_feed_target = Vector3(clampf(player.position.x,court_center.x-court_half_width+0.3,court_center.x+court_half_width-0.3), 0.95, clampf(player.position.z, 0.6, 8.5))
				debug_feed_locked = true
				_message("Feed landing locked here / F5 to retarget; F7 restores tracking feed")
			KEY_F6:
				if event.shift_pressed: training_bots._capture_receive_target()
				else: training_bots._capture_set_target()
			KEY_F7:
				debug_feed_locked = false
				_message("Feed follows player again")
			KEY_G: training_bots.spawn_at_player()
			KEY_I:
				if inventory.try_pickup(self):
					return
				if interact_nearby_bot():
					return
				if pepper.active() or serve.tossing():
					_finish("Free play stopped / I to start nearby drill")
				if is_instance_valid(bot_pads) and bot_pads.in_zone() >= 0:
					bot_pads.interact()
				elif drills.in_zone():
					drills.interact()
				else:
					station.interact()
			KEY_V:
				camera_rig.set_mode(ViewMode.BALL if camera_rig.camera_mode == ViewMode.ATHLETE else ViewMode.ATHLETE)
		if paused:
			return
		var keys := [KEY_1, KEY_2, KEY_3, KEY_4]
		if event.keycode in keys and player.is_on_floor() and not armed and not charging and motion.jump_charge < 0:
			selected = keys.find(event.keycode)
		if event.keycode == KEY_SPACE and player.is_on_floor():
			motion.begin_jump()
	if event is InputEventKey and not event.pressed and event.keycode == KEY_SPACE and motion.jump_charge >= 0.0 and not paused:
		motion.takeoff()
	if event is InputEventMouseButton and motion.generic_jump and motion.jumped:
		return
	if event is InputEventMouseButton and not paused:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
			if not hud.help_panel.visible:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				cursor_release_click = true
			return
		if cursor_release_click and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			cursor_release_click = false
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and player.is_on_floor():
			charging = false
			armed = false
			auto_preparation.clear()
			committed_intent = {}
			confirm_window = 0.0
			if motion.jump_charge >= 0.0:
				motion.jump_charge = -1.0
				motion.approach_action = -1
				motion.approach_bound = false
				motion.approach_release_pending = false
				_message("Jump interrupted. Preparation cost remains spent.")
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if armed:
					_confirm_action()
				else:
					if selected == 2: contact_flow.on_attack_charge("player")
					charging = true
					charge = 0.0
			elif charging:
				charging = false
				armed = true
				locked_action = selected if player.is_on_floor() else motion.airborne_action
				finish_charge_preparation()
				_message("AUTO ready. Click to confirm." if auto_preparation.active else "Power ready. Click again when the ball is in reach.")

func _physics_process(dt: float) -> void:
	if paused:
		directional_input.clear()
		hud.update()
		return
	var world_dt := dt
	var motion_scale: float = moc.actor_scale("player")
	dt *= motion_scale
	elapsed += world_dt
	if auto_preparation.active and armed:
		auto_preparation.tick(world_dt,athlete,ball_shot,ball_velocity)
	contact_flow.tick(world_dt)
	ground_balls.tick(self,world_dt)
	serve.tick_toss_charge(world_dt)
	if ball_active:
		ball.show()
		shadow.show()
	_check_bench()
	if is_benched():
		_tick_benched(world_dt)
		return
	var previous_player_position := player.position
	block_state.tick(dt)
	motion.tick(dt, motion_scale)
	var rally_live: bool = ball_active and not station.running() and not drills.running() and not pepper.active()
	if rally_live and athlete_touches_net(previous_player_position,player.position):
		_finish_fault("NET FAULT / Athlete touched the net",side_index(previous_player_position.z))
	elif not rally_live:
		_hold_midline_off_net(previous_player_position)
	camera_rig.update_aim()
	animation.update()
	station.tick(world_dt)
	drills.tick(world_dt)
	_remember_contacts(dt)
	if ball_active:
		_tick_ball(world_dt)
		_remember_contacts(0.0)
		if ball_active and not station.running() and not drills.running() and not pepper.active():
			for slot in range(training_bots.actors.size()):
				var actor: Node3D = training_bots.actors[slot]
				if training_bots.slot_enabled(slot) and athlete_touches_net(actor.position,actor.position,training_bots.physique.build.height):
					_finish_fault("NET FAULT / %s bot touched the net" % ("Away" if training_bots.slot_away(slot) else "Home"),int(training_bots.slot_away(slot)))
					break
	elif auto_feed and not station.in_zone() and not station.running() and not drills.in_zone() and not drills.running():
		feed_timer -= world_dt
		if feed_timer <= 0:
			_feed()
	if not ball_active:
		training_bots.tick_motion(world_dt)
		pepper.tick(world_dt)
	if block_state.active:
		confirm_window = 0
	elif confirm_window > 0:
		confirm_window = maxf(0, confirm_window - dt)
		if confirm_window > 0 and ball_active and elapsed - last_contact > 0.22/athlete.transition_rate() and _can_contact():
			_contact()
		elif confirm_window <= 0:
			committed_intent = {}
			armed = false
			auto_preparation.clear()
			athlete.spend_resolved(float(athlete.stamina_quote("timing_miss").total))
			_message("Missed timing / reach. Move under the ball and try again.")
	_check_bench()
	if not is_benched():
		_update_preview(false)
	hud.update()

func is_benched() -> bool:
	return is_instance_valid(bench) and bench.active

func in_live_rally() -> bool:
	if station.running() or drills.running() or not ball_active or serve.tossing():
		return false
	return pepper.active() or (absf(player.position.x-court_center.x) <= court_half_width + 1.5 and absf(player.position.z) <= court_half_depth + 1.5)

func _check_bench() -> bool:
	if not is_benched() and athlete.exhausted and in_live_rally():
		bench.enter()
	return is_benched()

func _tick_benched(dt: float) -> void:
	contact_flow.impulses.erase("player")
	bench.tick(dt)
	if ball_active:
		_tick_ball(dt)
	else:
		training_bots.tick_motion(dt)
	hud.update()

func _resize_court() -> void:
	var home := 1
	var away := 0
	for slot in range(training_bots.settings.size()):
		if training_bots.slot_enabled(slot):
			home += int(not training_bots.slot_away(slot))
			away += int(training_bots.slot_away(slot))
	var team_size := maxi(home, away)
	# Provisional 1/2/3/4+ player layouts; both halves use the larger team.
	court_half_width = [2.5, 3.0, 3.75, 4.5][mini(team_size - 1, 3)]
	court_half_depth = [5.0, 6.0, 7.5, 9.0][mini(team_size - 1, 3)]
	_draw_line(court_outline, [Vector3(-court_half_width, 0.045, -court_half_depth), Vector3(court_half_width, 0.045, -court_half_depth), Vector3(court_half_width, 0.045, court_half_depth), Vector3(-court_half_width, 0.045, court_half_depth), Vector3(-court_half_width, 0.045, -court_half_depth)])

func _serve() -> void:
	serve.press()

func _feed() -> void:
	if not training_bots.ready_to_serve():
		_message("Wait for bots to clear the net")
		return
	if is_benched():
		return
	if serve.tossing() or pepper.active():
		_message("Finish free play first / T resets")
		return
	if paused:
		return
	if drills.in_zone() or drills.running():
		_message("Map drill / use I to start, stop or retry")
		return
	if station.in_zone():
		_message("Serve Receive station / use I to start, stop or retry the sequence.")
		return
	refresh_bot_rally()
	clear_net_responses()
	net_bounce_pending = false
	var target := Vector3(clampf(player.position.x+sin(attempts*1.7)*0.7,court_center.x-court_half_width+0.5,court_center.x+court_half_width-0.5), 0.95, clampf(player.position.z, 2, 8))
	if debug_feed_locked:
		target = debug_feed_target
	ball.position = Vector3(court_center.x+(target.x-court_center.x)*0.6,3.6,-7.5)
	var duration := 2.0
	ball_velocity = (target - ball.position) / duration + Vector3.UP * (GRAVITY * duration * 0.5)
	rally_rules.begin(1)
	ball_shot = ReceiveCharge.shot("serve", 0.60, "debug_feed")
	ball_active = true
	outgoing = false
	contacts = 0
	side_contacts = [0, 0]
	training_bots.last_was_block = false
	training_bots.incoming_action = -1
	contact_memory = [0.0, 0.0, 0.0, 0.0]
	attempts += 1
	trail_points.clear()
	training_bots.replan()
	_message("Incoming ball. Track its landing ring and prepare a contact.")
	_check_bench()

func _can_contact() -> bool:
	if is_benched():
		return false
	if not serve.contacts_allowed():
		return false
	if pepper.active() and (pepper.npc_turn or locked_action != pepper.required_player_action()):
		return false
	if locked_action == 0 and _local_contact_position().z > 0:
		return false
	if locked_action == 2:
		return Geometry.spike_active(_hurtbox_definition(2), _local_contact_position(), confirm_duration - maxf(confirm_window, 0.0))
	return _overlaps_contact(locked_action) or (ball_active and contact_memory[locked_action] > 0.0)

func begin_auto_preparation(action: int) -> void:
	auto_preparation.begin(action,_contact_event_serial+1)
	locked_charge = _default_charge() # Pose reference only; contact charge remains Auto.

func finish_charge_preparation() -> void:
	if charge <= 0.13:
		begin_auto_preparation(locked_action)
	else:
		auto_preparation.clear()
		locked_charge = charge

func prepared_output_charge() -> float:
	return float(auto_preparation.sample(athlete,ball_shot,ball_velocity).charge) if auto_preparation.active else locked_charge

func _default_charge() -> float:
	return 0.35 + 65.0 / 250.0

func _bump_ceiling(contact_height: float) -> float:
	# The former tapped bump's peak is now the full-charge ceiling.
	var previous_range := Flight.solve_flight(5.0 + _default_charge() * 5.5, 60.0, maxf(contact_height - 0.105, 0.0))
	var previous_tap := Flight.solve_between(float(previous_range.range_meters), 76.0, contact_height, 0.105)
	var upward := float(previous_tap.required_speed_mps) * sin(deg_to_rad(76.0))
	return contact_height + upward * upward / (2.0 * GRAVITY)

# Level aim retains the calibrated arc. Downward aim has a 35% minimum rise;
# upward aim reaches 2.5 times the rise, preserving charge-dependent range.
func _contact_loft_factor(inverted: bool = false) -> float:
	var pitch := camera_rig.view_pitch - 0.27 # Camera optical axis is level here.
	if inverted:
		pitch = -pitch # A back set inverts the aimed offset from neutral: a high front set is a low back set.
	return lerpf(1.0, 2.5, clampf(pitch / 0.88, 0, 1)) if pitch >= 0 else lerpf(1.0, 0.35, clampf(-pitch / 0.92, 0, 1))

# The receiver's distance from the net, or -1 in a Pepper (no net).
func receive_net_distance() -> float:
	if pepper.active():
		return -1.0
	return absf(player.position.z - court_center.z)

func _loft_velocity(origin: Vector3, action: int, power: float, direction: Vector3) -> Vector3:
	var peak: float
	var distance: float
	if action == 0:
		power = ReceiveCharge.CONTROL_CHARGE
		var ceiling := _bump_ceiling(origin.y)
		peak = origin.y + (ceiling - origin.y) * lerpf(0.25, 1.0, clampf(power, 0, 1))
		distance = ReceivePass.matched_distance(receive_net_distance())
	else:
		var ceiling := maxf(origin.y + 0.35, _bump_ceiling(1.0))
		peak = origin.y + (ceiling - origin.y) * SET_RISE_FACTOR * lerpf(0.65, 1.0, clampf(power, 0, 1))
		var previous := Flight.solve_flight(5.5 + power * 4.5, 76.0, maxf(origin.y - 0.105, 0.0))
		distance = previous.range_meters * SET_RANGE_FACTOR
		if not motion.jumped:
			distance *= GROUND_SET_RANGE_FACTOR
			peak = origin.y + (peak - origin.y) * GROUND_SET_RISE_FACTOR
	peak = origin.y + (peak - origin.y) * _contact_loft_factor(action == 1 and back_set)
	var upward := sqrt(2.0 * GRAVITY * maxf(peak - origin.y, 0.1))
	var duration := (upward + sqrt(upward * upward + 2.0 * GRAVITY * maxf(origin.y - 0.105, 0.0))) / GRAVITY
	return direction * distance / maxf(duration, 0.01) + Vector3.UP * upward

func _shot_velocity(origin: Vector3, action: int, power: float, target: Variant = null, evidence: Dictionary = {}) -> Vector3:
	var direction: Vector3 = (aim if target == null else Vector3(target)) - origin
	direction.y = 0
	if direction.length() < 0.2:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	if action == 1 and back_set:
		direction = -direction # the athlete still faces and aims forward; the set leaves behind
	if action in [0, 1]:
		return _loft_velocity(origin, action, power, direction)*athlete.low_stamina_factor()
	if action == 2:
		power = contact_flow.attack_charge(power,"player",origin,evidence) if is_instance_valid(contact_flow) else athlete.effective_attack_charge(power)
	var hp_factor := lerpf(0.7, 1.0, athlete.hp / 100.0)
	var speed := (6.0 + power * 7.0 + 65.0 * 0.02) * hp_factor
	if action == 2:
		speed *= ATTACK_DRIVE_FACTOR * (SPIKE_SPEED_MULTIPLIER if motion.jumped else 1.0)
	var angle := SPIKE_BASE_ANGLE + power * 2.0 if motion.jumped else 6.0
	if action == 3:
		speed = 5.0 + power * 3.5
		angle = -18.0
	angle = clampf(angle + rad_to_deg(camera_rig.view_pitch - 0.27) * 0.65, -65.0, 70.0)
	var flight: Dictionary = Flight.solve_flight(speed, angle, origin.y)
	return (direction * float(flight.horizontal_speed_mps) + Vector3.UP * float(flight.vertical_speed_mps))*(athlete.low_stamina_factor() if action != 2 else 1.0)

# A back set travels away from the aim, so steering it is relative to its own direction of travel.
func _intent_direction(action: int, direction: Vector3) -> Vector3:
	return -direction if action == 1 and back_set else direction

func toggle_modifier() -> void:
	if serve.tossing() or serve.state == serve.State.TOSS_CHARGE:
		serve.toggle_float()
	elif selected == 1 or locked_action == 1:
		if not athlete.has_access(BACK_SET_TRAIT):
			_message("Back Set needs the Back Set Trait")
			return
		back_set = not back_set
		committed_intent = {}
		_message("BACK SET" if back_set else "FRONT SET")
	else:
		_message("R toggles Back Set while setting and Float Serve while serving")

func _capture_contact_intent() -> void:
	var origin := player.position + Vector3.UP * (athlete.reach() - (1.2 if locked_action == 0 else 0.2))
	var forward := aim - origin
	forward.y = 0
	var input_charge := prepared_output_charge()
	var influence := DirectionalInfluence.resolve(_shot_velocity(origin, locked_action, input_charge), locked_action, directional_input.value(), forward, 1.0, 0.0, origin.y)
	committed_intent = ContactIntent.capture("player", side_index(player.position.z), locked_action, input_charge, origin, aim, influence.velocity, elapsed, influence,"auto" if auto_preparation.active else "manual")

func _impact_event(actor_id: String, action: int, incoming: Vector3, assessment: Dictionary, incoming_shot: Dictionary) -> ContactEvent:
	_contact_event_serial += 1
	var event := ContactEvent.new()
	event.id = "%s:%d" % [actor_id, _contact_event_serial]
	event.actor = actor_id
	event.action = action
	event.team = side_index(ball.position.z)
	event.point = ball.position
	event.incoming_velocity = incoming
	event.outgoing_velocity = ball_velocity
	event.incoming_shot = incoming_shot
	event.outgoing_shot = ball_shot
	event.charge = float(ball_shot.get("charge", 0.0))
	event.assessment = assessment
	event.simulation_time = elapsed
	return event

func _publish_impact(event: Dictionary) -> void:
	if not station.running() and not drills.running() and not pepper.active():
		var touching_side := int(event.team)
		# An opponent's touch renews the team's allowance even when a block
		# reverses the ball before it fully clears the net's crossing plane.
		side_contacts[1 - touching_side] = 0
		if touching_side != side_index(player.position.z):
			contacts = 0
		rally_rules.touch(touching_side)
	clear_net_responses()
	net_bounce_pending = false
	net_response.clear_side = signf(ball.position.z)
	if event.action == Action.RECEIVE:
		receive_resolved.emit(event)
	animation.on_contact(event)
	contact_flow.record(event)
	moc.begin(event)

func _emit_contact_impact(incoming_velocity: Vector3, assessment: Dictionary, incoming_shot: Dictionary = {}) -> void:
	var event := _impact_event("player", locked_action, incoming_velocity, assessment, incoming_shot)
	event.team = side_index(player.position.z)
	event.charge = locked_charge
	event.intent = committed_intent
	event.directional_influence = last_directional_influence
	event.assessment = assessment.duplicate()
	event.assessment["zone"] = last_quality
	last_contact_result = event.publish()
	action_endlag = [0.16, 0.12, 0.22, 0.16][locked_action]
	_publish_impact(last_contact_result)
	committed_intent = {}

func _emit_external_impact(actor_id: String, action: int, incoming: Vector3, assessment: Dictionary, incoming_shot: Dictionary = {}) -> void:
	var event := _impact_event(actor_id, action, incoming, assessment, incoming_shot)
	if actor_id.begins_with("training_bot_"):
		var slot := int(actor_id.trim_prefix("training_bot_"))
		event.team = int(training_bots.slot_away(slot))
	if actor_id == "player_serve":
		event.team = side_index(player.position.z)
		rally_rules.begin(event.team)
		action_endlag = 0.22
	_publish_impact(event.publish())

func _exit_tree() -> void:
	if is_instance_valid(moc):
		moc.clear()

func _advance_action_after_contact() -> void:
	# A queued next selection never changes the current airborne commitment.
	if pepper.active():
		selected = pepper.next_action(pepper.stage, 1.0)
		return
	# The wheel moves on to the next contact only when nobody else is on your court to take it.
	if training_bots.has_teammates(side_index(player.position.z)):
		return
	selected = (locked_action + 1) % ACTIONS.size()

# Out of a rally the net is still a wall for the body's midline, though shoulders and arms may overlap it: the athlete cannot walk through.
# In a rally the midline reaching the net is the fault instead.
func _hold_midline_off_net(previous: Vector3) -> void:
	if not athlete_touches_net(previous,player.position,1.7,NetResponse.MIDLINE_RADIUS+0.03):
		return
	var side := signf(previous.z) if absf(previous.z) > 0.0001 else (signf(player.position.z) if absf(player.position.z) > 0.0001 else 1.0)
	player.position.z = side * (NetResponse.HALF_DEPTH + NetResponse.MIDLINE_RADIUS + 0.035)
	if player.velocity.z * side < 0.0:
		player.velocity.z = 0.0

func side_index(z: float) -> int:
	return 0 if z >= 0 else 1

func block_serve_fault(action: int,shot: Dictionary,actor: String,fault_side: int = -1) -> bool:
	if action != 3 or str(shot.get("kind","")) != "serve": return false
	_finish_fault("SERVE BLOCK FAULT / %s blocked a serve" % actor,side_index(player.position.z) if fault_side < 0 else fault_side)
	return true

func _contact() -> void:
	if _check_bench():
		return
	if not serve.contacts_allowed():
		return
	if serve.state == serve.State.TOSS:
		serve.clear() # played with an action: no longer a serve attempt (it stays a free ball)
	if pepper.active() and (pepper.npc_turn or locked_action != pepper.required_player_action()):
		_message("PEPPER / next contact: " + ACTIONS[pepper.player_action])
		return
	if locked_action == 0 and _local_contact_position().z > 0:
		return
	if block_serve_fault(locked_action,ball_shot,"Athlete"): return
	var incoming_velocity := ball_velocity
	var incoming_shot := ball_shot
	if motion.jumped and motion.airborne_action == 2 and locked_action == 2 and not animation.spike_contacted:
		# The ball is struck now: the arm is at contact now, and follows through from here.
		if animation.spike_swing_time < 0.0:
			animation.spike_swing_time = 0.0
		animation.spike_hit_time = animation.spike_swing_time
		animation.spike_contacted = true
	var is_block := locked_action == 3
	if not is_block:
		contacts += 1
	var side := side_index(player.position.z)
	if not is_block and (pepper.player_contacts >= 3 if pepper.active() else (contacts > 3 or side_contacts[side] >= 3)):
		_finish_fault("Three-contact fault. Return the ball across the Net earlier.",side)
		return
	if pepper.active():
		pepper.player_contacts += 1
	elif not is_block:
		side_contacts[side] += 1
	training_bots.last_was_block = locked_action == 3
	training_bots.incoming_action = locked_action
	var request := contact_request(locked_action)
	var assessment := ContactResolver.assess(request)
	if locked_action == Action.RECEIVE:
		last_receive_match = assessment.charge_match
		if assessment.hit:
			animation.receive_pose_contact = request.local_point
			animation.receive_posture = assessment.posture
			animation.receive_pose_remaining = 0.42
	var quality: float = assessment.quality if assessment.hit else 0.35
	last_quality = assessment.zone if assessment.hit or assessment.get("rescue", false) else "STRETCHED"
	var rolled: bool = locked_action == 0 and athlete.has_trait("endurance_rolling_receive") and assessment.hit and assessment.get("edge", false) and not assessment.get("rescue", false) and assessment.get("charge_match", {}).get("matched", true)
	if committed_intent.is_empty() or int(committed_intent.action) != locked_action or (not auto_preparation.active and not is_equal_approx(float(committed_intent.charge), locked_charge)):
		_capture_contact_intent()
	ball_velocity = _shot_velocity(ball.position, locked_action, request.charge, committed_intent.target, assessment)
	if locked_action == 2 and assessment.get("rescue", false):
		rescue_swing_remaining = 0.28
	if rolled:
		var facing := motion.airborne_aim if motion.jumped else Vector3(-sin(camera_rig.facing_yaw), 0, -cos(camera_rig.facing_yaw))
		ball_velocity = _loft_velocity(ball.position, 1, 0.85, facing.normalized())
		quality = 1.0
		last_quality = "ROLLING RECEIVE"
		animation.roll_lock = ROLL_TIME
		athlete.spend(0.0, LabAthlete.ROLLING_RECEIVE_HP)
	request.base_velocity = ball_velocity
	request.rolling_receive = rolled
	request.intent_direction = _intent_direction(locked_action, committed_intent.direction)
	var result := ContactResolver.resolve(request, assessment)
	ball_velocity = result.velocity
	ball.position += result.separation_offset
	assessment = result.assessment
	last_directional_influence = result.influence
	if locked_action == Action.ATTACK:
		animation.spike_swing_yaw = result.influence.shot_yaw_radians
	ball_shot = ReceiveCharge.shot(["receive", "set", "attack", "block"][locked_action], contact_flow.attack_charge(request.charge,"player",ball.position,assessment) if locked_action == 2 else request.charge, "player")
	if not result.outgoing_shot.is_empty():
		ball_shot = result.outgoing_shot
	ball_shot = contact_flow.decorate_shot(ball_shot,request.incoming_shot,"player",locked_action,assessment)
	if locked_action == 2 and assessment.hit:
		contact_flow.consume_attack("player")
	var cost: Vector2 = request.athlete.contact_cost(locked_action, contacts,assessment,incoming_shot)
	athlete.last_stamina_cost = request.athlete.last_stamina_cost
	athlete.spend_resolved(cost.x)
	contact_memory = [0.0, 0.0, 0.0, 0.0]
	last_contact = elapsed
	if locked_action == 1:
		back_set = false
	outgoing = true
	if locked_action == 3 and block_state.active:
		block_state.latched = true
	else:
		armed = false
		auto_preparation.clear()
	_update_hurtbox_visual(0.0)
	confirm_window = 0
	trail_points.clear()
	if pepper.active():
		pepper.on_player_contact(locked_action, quality)
	else:
		training_bots.replan()
	_emit_contact_impact(incoming_velocity, assessment, incoming_shot)
	_message("%s %s   /   contact %d of 3" % [last_quality, ACTIONS[locked_action], contacts])
	if station.running():
		station.on_contact(locked_action, assessment.get("charge_match", {}).get("matched", true))
	elif drills.running():
		drills.on_contact(locked_action)
	elif ball_active and not (locked_action == 3 and block_state.active):
		_advance_action_after_contact()

	_check_bench()

func _try_swept_player_block(previous: Vector3, dt: float) -> bool:
	var passive := block_state.active
	if locked_action != 3 or not armed or (not passive and confirm_window <= 0): return false
	if passive:
		var inside := Geometry.block_overlap(_hurtbox_definition(3),_local_contact_position(),0.06)
		if block_state.latched and not inside: block_state.latched = false
		if block_state.latched: return false
	elif elapsed-last_contact <= 0.22/athlete.transition_rate(): return false
	var endpoint := ball.position
	var shape := _hurtbox_definition(3)
	var samples := maxi(1, ceili(previous.distance_to(endpoint) / 0.025))
	var initial_window := confirm_window
	for sample in range(samples + 1):
		var fraction := float(sample) / samples
		if not passive and initial_window - dt * fraction <= 0:
			break
		var point := previous.lerp(endpoint, fraction)
		var local := (point-player.position).rotated(Vector3.UP,-_contact_yaw())
		if Geometry.contains(shape,local) and Geometry.block_approaching(shape,local,ball_velocity.rotated(Vector3.UP,-_contact_yaw())):
			ball.position = point
			confirm_window = initial_window - dt * fraction
			var event_before := _contact_event_serial
			_contact()
			if _contact_event_serial > event_before:
				return true
	ball.position = endpoint
	confirm_window = initial_window
	return false

func _tick_ball(dt: float) -> void:
	var world_dt := dt
	dt *= moc.simulation_scale()
	if drills.holding_ball():
		return
	var previous := ball.position
	ball.position += ball_velocity * dt + Vector3.DOWN * (GRAVITY * dt * dt * 0.5)
	ball_velocity.y -= GRAVITY * dt
	ball.rotate_x(dt * 4)
	serve.tick(dt, previous)
	if not serve.tossing() and not inventory.free_ball and not station.running() and not drills.running():
		pepper.try_start(previous)
		if pepper.tick(world_dt):
			return
	if drills.running() and drills.sweep_ball(previous,dt):
		return
	if _try_swept_player_block(previous, dt):
		return
	var net_result := resolve_ball_net(previous,dt)
	# Helpers look again once the ball has come off the net, so they can receive it.
	if net_result.contact != "":
		net_bounce_pending = true
	elif net_bounce_pending and not bool(net_result.pocket):
		net_bounce_pending = false
		training_bots.replan_after_net()
	ball.position = net_result.position
	ball_velocity = net_result.velocity
	if previous.z*ball.position.z < 0 and not bool(net_result.pocket) and net_result.contact == "":
		var crossing := previous.lerp(ball.position,previous.z/(previous.z-ball.position.z))
		if not station.running() and not drills.running() and not pepper.active() and (serve.state != serve.State.FLIGHT or serve.main_court) and absf(crossing.x-court_center.x)+Geometry.VISUAL_BALL_RADIUS > net_response.web_half_width:
			_finish_fault("OUTSIDE-ANTENNA FAULT / Ball crossed outside the net",rally_rules.last_touch_side)
			return
		if absf(crossing.x-Vector3(net_result.net_origin).x) <= float(net_result.net_half_width) and crossing.y < float(net_result.net_bottom)-NetResponse.RADIUS:
			_finish_fault("UNDER-NET FAULT / Ball crossed beneath the webbing",rally_rules.last_touch_side)
			return
	if net_result.crossed:
		contact_flow.net_cross()
		training_bots.net_rebound = false
	if net_result.crossed and absf(ball.position.x-court_center.x) <= net_response.web_half_width+0.1:
		if not pepper.active():
			side_contacts[side_index(ball.position.z)] = 0
			contacts = 0
		if training_bots.active_action < 0:
			training_bots.replan()

	if not station.running() and not drills.running() and not serve.tossing() and not inventory.free_ball and not pepper.active() and (serve.state != serve.State.FLIGHT or serve.main_court) and training_bots.tick(world_dt):
		return
	if (serve.state != serve.State.IDLE or pepper.active()) and not station.running() and not drills.running():
		var query := PhysicsRayQueryParameters3D.create(previous, ball.position)
		var excluded := net_collision_rids()
		excluded.append(player.get_rid())
		query.exclude = excluded
		var solid := get_world_3d().direct_space_state.intersect_ray(query)
		if not solid.is_empty():
			ball.position = solid.position + solid.normal * Geometry.BALL_RADIUS
			var landing_velocity := ball_velocity
			var landing_shot := ball_shot
			var end_message := "Ball down / Pepper ended" if pepper.active() else "Ball down or obstacle / E to toss again"
			var point_result := rally_rules.landing(solid.position,court_center,court_half_width,court_half_depth,Geometry.VISUAL_BALL_RADIUS) if Vector3(solid.normal).y > 0.65 and Vector3(solid.position).y < 0.15 else rally_rules.out()
			_finish(end_message,point_result)
			if Vector3(solid.normal).y > 0.65: ground_balls.land(self,solid.position,landing_velocity,landing_shot)
			return
	if ball.position.y <= 0.105:
		var landing_velocity := ball_velocity
		var landing_shot := ball_shot
		var landing_fraction := clampf((previous.y-0.105)/maxf(previous.y-ball.position.y,0.000001),0,1)
		var landing_point := previous.lerp(ball.position,landing_fraction)
		landing_point.y = 0
		if pepper.active():
			_finish("PEPPER ended / ball down / E to toss again")
			ground_balls.land(self,landing_point,landing_velocity,landing_shot)
			return
		var floor_endpoint := ball.position
		ball.position.y = 0.105
		if station.running():
			var floor_fraction := clampf((previous.y - 0.105) / maxf(previous.y - floor_endpoint.y, 0.000001), 0, 1)
			station.on_ball_down(previous.lerp(floor_endpoint, floor_fraction))
			ground_balls.land(self,landing_point,landing_velocity,landing_shot)
			return
		if drills.running():
			drills.on_ball_down()
			ground_balls.land(self,landing_point,landing_velocity,landing_shot)
			return
		var point_result := rally_rules.landing(landing_point,court_center,court_half_width,court_half_depth,Geometry.VISUAL_BALL_RADIUS)
		if point_result.get("reason","") == "OUT":
			_finish("OUT / Ball landed outside the court.",point_result)
		else:
			if point_result.get("winner",-1) == 0 and rally_rules.last_touch_side == 0: returns += 1
			_finish("Ball down. Next feed in 3 seconds.",point_result)
		ground_balls.land(self,landing_point,landing_velocity,landing_shot)
	if ball.position.length() > 120:
		_finish("Out of the training area.",rally_rules.out())
	shadow.position = Vector3(ball.position.x, 0.03, ball.position.z)
	trail_points.append(ball.position)
	if trail_points.size() > 18:
		trail_points.pop_front()
	_draw_line(trail, trail_points)

func _finish_fault(message: String,side: int) -> void:
	_finish(message,rally_rules.fault(side,message))

func _finish_landing(point: Vector3,message: String) -> void:
	_finish(message,rally_rules.landing(point,court_center,court_half_width,court_half_depth,Geometry.VISUAL_BALL_RADIUS))

func _finish(message: String,point_result: Dictionary = {}) -> void:
	inventory.landed_free = inventory.free_ball
	if inventory.free_ball:
		message = "Free ball down / pick it up (I) before it despawns"
	elif not station.running() and not drills.running() and not pepper.active():
		rally_rules.record(point_result)
		if not rally_rules.label().is_empty(): message += " / "+rally_rules.label()
	inventory.free_ball = false
	block_state.land()
	contact_flow.end_rally()
	clear_net_responses()
	net_bounce_pending = false
	action_endlag = 0.0
	confirm_window = 0.0
	committed_intent = {}
	armed = false
	auto_preparation.clear()
	serve.clear()
	pepper.stop()
	moc.clear()
	ball_active = false
	training_bots.on_rally_end()
	feed_timer = 3.0
	_message(message)

func _message(message: String) -> void:
	feedback = message
	feedback_time = 3.0

func _draw_line(instance: MeshInstance3D, points: Array[Vector3]) -> void:
	if points.size() < 2:
		instance.mesh = null
		return
	var mesh := instance.mesh as ImmediateMesh
	if mesh == null:
		mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh

func _update_contact_preview() -> void:
	last_trajectory_preview = TrajectoryPreview.predict(self)
	preview.mesh = null if last_trajectory_preview.is_empty() else TrajectoryPreview.ribbon(last_trajectory_preview, camera.position, _preview_mesh)

func _update_preview(draw_trajectory: bool = true) -> void:
	if draw_trajectory:
		_update_contact_preview()
	var approach_points: Array[Vector3] = []
	for marker in approach_footprints:
		marker.hide()
	if motion.jump_charge >= 0 and not motion.generic_jump and motion.approach_action == 2 and motion.approach_direction.length_squared() > 0.01:
		var ground := Vector3(player.position.x, 0.06, player.position.z)
		approach_points.append(ground)
		for step in range(Approach.step_index(motion.jump_charge), 4):
			var end: float = Approach.STEP_ENDS[step]
			var distance := 0.0
			var samples := 32
			for i in range(samples):
				var progress := lerpf(motion.jump_charge, end, (i + 0.5) / samples)
				distance += Approach.speed_scale(progress) * athlete.speed() * Approach.DURATION * (end - motion.jump_charge) / samples
			var point := ground + motion.approach_direction * distance
			approach_points.append(point)
			approach_footprints[step].position = point + motion.approach_direction.cross(Vector3.UP) * Approach.foot_lateral(step)
			approach_footprints[step].rotation.y = atan2(-motion.approach_direction.x, -motion.approach_direction.z) + Approach.foot_turn(step)
			approach_footprints[step].show()
	_draw_line(approach_preview, approach_points)
	if ball_active:
		var h := maxf(ball.position.y - 0.1, 0.0)
		var t := (ball_velocity.y + sqrt(ball_velocity.y * ball_velocity.y + 2 * GRAVITY * h)) / GRAVITY
		landing_marker.position = Vector3(ball.position.x + ball_velocity.x * t, 0.035, ball.position.z + ball_velocity.z * t)
	landing_marker.visible = ball_active

func _reset() -> void:
	back_set = false
	rally_rules.begin()
	block_state.land()
	ground_balls.clear()
	if is_instance_valid(ball): ball.show()
	if is_instance_valid(shadow): shadow.show()
	clear_net_responses()
	net_bounce_pending = false
	if is_instance_valid(impact_visual):
		impact_visual.clear()
	if is_instance_valid(contact_flow):
		contact_flow.clear()
	if is_instance_valid(bench):
		bench.clear()
	if is_instance_valid(serve):
		serve.clear()
	if is_instance_valid(pepper):
		pepper.stop()
		pepper.refresh_for_rally()
	camera_rig.ball_camera_offset_ready = false
	camera_rig.ball_movement_yaw = 0.0
	animation.receive_posture = "planted"
	animation.receive_pose_remaining = 0
	animation.carry.reset()
	animation.spike_impact_latched = false
	animation.reset_contact()
	animation.receive_pose_contact = Vector3.ZERO
	if is_instance_valid(moc):
		moc.clear()
	directional_input.clear()
	last_directional_influence = {}
	committed_intent = {}
	last_contact_result = {}
	motion.gait_cycle = 0.0
	animation.roll_lock = 0.0
	animation.dive_recovery_time = -1.0
	animation.floor_recovery_time = -1.0
	animation.floor_slide_decel = 0.0
	animation.dive_launched = false
	motion.quick_step_time = 0.0
	motion.quick_step_cooldown = 0.0
	motion.tap_times.clear()
	motion.generic_jump = false
	athlete.hp = 100
	athlete.stamina = athlete.max_stamina()
	athlete.reset_fatigue()
	player.position = start_position
	player.velocity = Vector3.ZERO
	camera_rig.camera_anchor_ready = false
	camera_rig.camera_transition = 0.0
	camera_rig.view_yaw = 0.0
	camera_rig.facing_yaw = 0.0
	camera_rig.view_pitch = -0.12
	camera_rig.ball_orbit = 0.0
	ball.position = Vector3(0, 0.105, -6)
	ball_active = false
	ball_shot = {}
	last_receive_match = {}
	charging = false
	armed = false
	auto_preparation.clear()
	motion.jumped = false
	motion.jump_charge = -1
	motion.approach_action = -1
	motion.approach_plant_speed = 0.0
	motion.approach_bound = false
	motion.approach_bound_started = false
	motion.approach_release_pending = false
	motion.approach_direction = Vector3.ZERO
	hurtbox_linger = 0
	rescue_swing_remaining = 0
	hurtbox_action = -1
	confirm_duration = 0.0
	confirmed_geometry = {}
	hurtbox_root.hide()
	confirm_window = 0
	contact_memory = [0.0, 0.0, 0.0, 0.0]
	feed_timer = 2.0
	attempts = 0
	returns = 0
	contacts = 0
	side_contacts = [0, 0]
	last_quality = "—"
	action_endlag = 0.0
	last_contact = -10.0
	trail_points.clear()
	trail.mesh = null
	training_bots.reset()
	station.reset()
	drills.reset()
	if is_instance_valid(bot_pads):
		bot_pads.reset()
	_resize_court()
	_message("Explore freely / E toss → E strike / serve into purple Pepper circles / K debug boxes")

func _cycle_build() -> void:
	build_index = (build_index + 1) % Athlete.BUILDS.size()
	athlete.build = Athlete.BUILDS[build_index].duplicate()
	position_role = str(athlete.build.name).get_slice("/", 1).strip_edges()
	_rebuild_visual()
	_reset()

# --- Dive floor recovery -------------------------------------------------------------------

func _build_ui() -> void:
	hud.build()
	perf_meter = preload("res://scripts/perf_meter.gd").new()
	add_child(perf_meter)


func begin_passive_block() -> void:
	block_state.start()
	locked_action = 3
	armed = true
	hurtbox_action = 3
	confirmed_geometry = {}
	var presentation := hurtbox_view.present(_raw_hurtbox_definition(3),3)
	hurtbox_mesh = presentation.mesh
	hurtbox_label = presentation.label
	hurtbox_linger = 1
	sweet_visual_phase = ""

func end_passive_block() -> void:
	if not block_state.active: return
	block_state.land()
	armed = false
	charging = false
	auto_preparation.clear()
	confirm_window = 0
	confirmed_geometry = {}
	hurtbox_linger = 0
