extends Node3D

signal receive_resolved(event: Dictionary)
const ReceiveOutcome := preload("res://scripts/receive_outcome.gd")

const ReceivePose := preload("res://scripts/receive_pose.gd")
var receive_posture := "planted"
var receive_pose_remaining := 0.0
var receive_pose_contact := Vector3.ZERO

const ReceiveCharge := preload("res://scripts/receive_charge.gd")
var ball_shot: Dictionary = {}
var last_receive_match: Dictionary = {}
const ReceivePlatform := preload("res://scripts/receive_platform.gd")
const ContactIntent := preload("res://scripts/contact_intent.gd")
const SpikeDirection := preload("res://scripts/spike_direction.gd")
const DirectionalInfluence := preload("res://scripts/directional_influence.gd")
var directional_input := DirectionalInfluence.new()
var last_directional_influence: Dictionary = {}
const MoC := preload("res://scripts/moment_of_contact.gd")
var moc: Node
var moc_button: Button
var committed_intent: Dictionary = {}
var last_contact_result: Dictionary = {}
var _camera_frame_usec := 0
var _contact_event_serial := 0

const Athlete = preload("res://scripts/athlete.gd")
const Execution = preload("res://scripts/contact_execution.gd")
const Geometry = preload("res://scripts/contact_geometry.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const DiveStage := preload("res://scripts/dive_stage.gd")
const DiveRecovery := preload("res://scripts/dive_recovery.gd")
const FloorRecovery := preload("res://scripts/floor_recovery.gd")
const PoseLibrary := preload("res://scripts/pose_library.gd")
const PoseSmoother := preload("res://scripts/pose_smoother.gd")
const SpikeStage := preload("res://scripts/spike_stage.gd")
const SetStage := preload("res://scripts/set_stage.gd")
const VoliVisual = preload("res://scripts/voli_visual.gd")
const WingPose := preload("res://scripts/wing_pose.gd")
const Approach = preload("res://scripts/approach_run.gd")
const Flight = preload("res://vendor/vwm/ball_flight_model.gd")
const GRAVITY = Flight.DEFAULT_GRAVITY_MPS2
const SPIKE_SPEED_MULTIPLIER := 1.50
const ATTACK_DRIVE_FACTOR := 1.40
const SET_RISE_FACTOR := 0.80
const SET_RANGE_FACTOR := 1.40
const GROUND_SET_RANGE_FACTOR := 1.65
const GROUND_SET_RISE_FACTOR := 0.80
const SPIKE_LATERAL_RETENTION := 0.02
# An attack jump adds energy from the speed it was released at. The box jump tower turns that off so a layer is cleared by how long
# Space was held and nothing else.
var attack_energy_conversion := true
# Where the athlete starts, and where the drills sit. The Contact Lab leaves these at their defaults; a scene that hosts the lab on a
# different map (scripts/map_lab.gd) sets them before the lab builds itself.
var start_position := Vector3(0, 0.03, 5.0)
var station_origin := Vector3.ZERO
var box_origin := Vector3.ZERO
var spike_origin := Vector3.ZERO
const SPIKE_MOMENTUM_CONVERSION := 0.495
const ACTIONS = ["RECEIVE", "SET", "ATTACK", "BLOCK"]
const TEAL = Color("54ead0")
const GOLD = Color("ffce73")
var serve: Node3D
var pepper: Node3D
var debug_volumes_visible := true
var debug_button: Button
const ATHLETE_CAMERA_DISTANCE := 4.2
const BallFraming := preload("res://scripts/ball_camera_framing.gd")
var ball_frame_pivot := Vector3.ZERO
var ball_frame_screen_y := 0.78
var ball_movement_yaw := 0.0
var facing_arrow: MeshInstance3D
var facing_compass: Control
var ball_edge_indicator: Label
var ball_camera_offset := Vector3.ZERO
var ball_camera_offset_ready := false
var ball_view_entry_pitch := 0.0
var drills: Node3D
var generic_jump := false
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
var gait_cycle := 0.0
var visual_rig_height := 1.86
var visual_hip_x := 0.13
var approach_bound := false
var approach_bound_started := false
var approach_release_pending := false
var approach_release_progress := 0.0
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
var preview: MeshInstance3D
var approach_footprints: Array[MeshInstance3D] = []
var approach_preview: MeshInstance3D
var trail: MeshInstance3D
var ui: CanvasLayer
var info: Label
var status: Label
var metrics: Label
var charge_label: Label
var athlete_hud: Control
var athlete_level := 1
var hp_bar: ProgressBar
var sta_bar: ProgressBar
var contact_flow: Node3D
var impact_visual: Node3D
var bench: Node3D
var station: Node3D
var approach_plant_speed := 0.0
var approach_distance := 0.0
var station_status: Label
var hurtbox_root: Node3D
var hurtbox_mesh: MeshInstance3D
var hurtbox_label: Label3D
var confirmed_geometry: Dictionary = {}
var hurtbox_action := -1
var hurtbox_linger := 0.0
var training_bots: Node3D
var bot_buttons: Array[Button] = []
var bot_status: Label
var bot_panel: PanelContainer
var menu_panels: Array[Control] = []
var bot_modes: Array[OptionButton] = []
var action_wheel: Control
var build_button: Button
var feedback := "Move under the ball. 1 / 2 / 3 / 4 select a contact."
var feedback_time := 0.0
var selected := 0
var locked_action := 0
var charging := false
var armed := false
var charge := 0.0
var locked_charge := 0.0
var confirm_window := 0.0
var confirm_duration := 0.0
var sweet_visual_expired := false
var sweet_visual_phase := ""
var rescue_swing_remaining := 0.0
var approach_action := -1
var approach_direction := Vector3.ZERO
var approach_phase_name := ""
var jump_charge := -1.0
var jumped := false
var airborne_action := 0
var airborne_aim := Vector3.FORWARD
var aim := Vector3(0, 0, -6)
var ball_velocity := Vector3.ZERO
var ball_active := false
var outgoing := false
var feed_timer := 2.5
var auto_feed := false
var paused := false
var side_contacts: Array[int] = [0, 0]
var contacts := 0
var attempts := 0
var returns := 0
var build_index := 0
var last_quality := "—"
var last_contact := -10.0
var elapsed := 0.0
var trail_points: Array[Vector3] = []
enum ViewMode { ATHLETE, BALL }
var camera_mode := ViewMode.ATHLETE
const LOOK_SENSITIVITY := 0.0022
var camera_anchor := Vector3.ZERO
var camera_anchor_ready := false
var camera_transition := 0.0
var view_yaw := 0.0
var view_pitch := -0.12
var facing_yaw := 0.0
var ball_orbit := 0.0
var camera_badge: Label
var cursor_release_click := false
var last_jump_height := 0.0
var roll_lock := 0.0
var dive_air_time := 0.0
var dive_applied_yaw := 0.0
# Spike swing clock: seconds in the air, how long the jump lasts, and where the real contact moved it.
var spike_air_time := 0.0
var spike_flight_time := 0.5
var spike_swing_time := -1.0   # seconds since the click started the strike; -1 while only loaded
var spike_hit_time := -1.0     # swing-clock time of the hit, or of the window closing
var spike_contacted := false
# Set clock: seconds in the air for a jump set and how long the jump lasts.
var set_air_time := 0.0
var set_flight_time := 0.5
var action_endlag := 0.0
var spike_swing_yaw := 0.0
# Smooths the seam whenever the animation source changes (walk -> receive -> dive ...).
var pose_smoother := PoseSmoother.new()
var pose_smoothing := true
var pose_frame_dt := 0.0
var pose_last_frame := -1
var dive_flight_time := 0.5
var dive_world_direction := Vector3.ZERO
# Floor recovery after a dive lands: seconds since touchdown (-1 when not recovering).
var dive_launched := false
var dive_quality_value := 0.5
var dive_recovery_time := -1.0
var dive_recovery_dir := Vector2(0, 1)
var dive_recovery_root := Vector2.ZERO
var dive_recovery_flat := {}
# A backward dive turns the body to face where it is going: total turn in radians, and the facing it turns from.
var dive_turn_total := 0.0
var dive_turn_spine := 0.0
var dive_turn_neck := 0.0
var dive_base_yaw := 0.0
var dive_slide_decel := 0.0
# Floor recovery after a poorly handled receive (knee, fall, blown away, shrug): seconds since contact, -1 when none.
var floor_recovery_name := ""
var floor_recovery_time := -1.0
var floor_recovery_scale := 1.0     # DI penalty factor: 0.65 helped to 1.35 contrary, stretches or shortens the animation
var floor_recovery_lock := 0.0
var floor_recovery_side := 1.0
var floor_recovery_root := Vector2.ZERO
var floor_recovery_flat := {}
var floor_slide_decel := 0.0
var rolling := false
var quick_step_cooldown := 0.0
var tap_times: Dictionary = {}
const QUICK_STEP_COOLDOWN_EXPLORE := 5.0
const QUICK_STEP_COOLDOWN_RALLY := 8.0
const DOUBLE_TAP_WINDOW := 0.28
var quick_step_time := 0.0
var quick_step_velocity := Vector3.ZERO
const ROLL_TIME := 0.9
const QUICK_STEP_TIME := 0.18
var contact_memory: Array[float] = [0.0, 0.0, 0.0, 0.0]
var body_collision_view: MeshInstance3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var help_panel: PanelContainer

func _ready() -> void:
	receive_resolved.connect(_on_receive_resolved)
	moc = MoC.new()
	moc.owner_lab = self
	add_child(moc)
	_build_world()
	_build_player()
	training_bots = preload("res://scripts/training_bots.gd").new()
	add_child(training_bots)
	training_bots.setup(self)
	station = preload("res://scripts/serve_receive_station.gd").new()
	add_child(station)
	station.setup(self)
	drills = preload("res://scripts/map_drills.gd").new()
	add_child(drills)
	drills.setup(self)
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

func _process(dt: float) -> void:
	pose_frame_dt = dt * moc.actor_scale("player")
	var now := Time.get_ticks_usec()
	var real_dt := minf(float(now - _camera_frame_usec) / 1000000.0, 0.1) if _camera_frame_usec > 0 else dt
	_camera_frame_usec = now
	if paused:
		moc.clear()
	if not paused:
		_update_aim()
		_update_pose()
		_update_camera(real_dt)
		_update_contact_preview()
		_update_hurtbox_visual(dt)
		impact_visual.tick(real_dt)
		contact_flow.tick_visuals()

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	return n

func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	return n

func ring(radius: float, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.025
	mesh.outer_radius = radius + 0.025
	mesh.rings = 32
	mesh.ring_segments = 8
	n.mesh = mesh
	n.material_override = material(color, true)
	add_child(n)
	return n

func world_label(text: String, pos: Vector3, size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.007
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

# Open exploration blockout: three lanes and traversable jungle space. A scene that hosts the lab on a different map replaces this
# (see scripts/map_lab.gd) and keeps everything else, including the court and Net at the origin.
func _build_lanes_and_bases() -> void:
	for lane_x in [-36.0, 0.0, 36.0]:
		box(self, Vector3(5, 0.015, 120), Vector3(lane_x, -0.015, 0), Color("223c45"))
		world_label("%s LANE" % ("MIDDLE" if lane_x == 0 else ("WEST" if lane_x < 0 else "EAST")), Vector3(lane_x, 0.03, -25), 40, TEAL)
	for z in [-48.0, 48.0]:
		box(self, Vector3(77, 0.015, 6), Vector3(0, -0.015, z), Color("29434b"))
		world_label("AWAY BASE" if z < 0 else "HOME BASE", Vector3(0, 0.03, z), 48, GOLD)
	world_label("OPEN JUNGLE / DRILL SPACE", Vector3(-18, 0.03, 14), 30, TEAL)

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0e1928")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b5d2e4")
	e.ambient_light_energy = 0.65
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)
	box(self, Vector3(160, 0.2, 160), Vector3(0, -0.22, 0), Color("142333"))
	_build_lanes_and_bases()
	court_outline = MeshInstance3D.new()
	court_outline.material_override = material(GOLD, true)
	add_child(court_outline)
	box(self, Vector3(9, 0.12, 18), Vector3(0, -0.08, 0), Color("255b66"))
	box(self, Vector3(8.8, 0.015, 8.8), Vector3(0, -0.008, 4.5), Color("30727a"))
	for x in [-4.8, 4.8]:
		box(self, Vector3(0.10, 2.6, 0.10), Vector3(x, 1.3, 0), GOLD)
	for i in range(33):
		box(self, Vector3(0.012, 0.88, 0.012), Vector3(-4.5 + i * 9.0 / 32, 1.98, 0), Color("829dab"))
	for i in range(6):
		box(self, Vector3(9, 0.012, 0.012), Vector3(0, 1.54 + i * 0.176, 0), Color("829dab"))
	box(self, Vector3(9.5, 0.055, 0.06), Vector3(0, 2.43, 0), Color("f0e6ce"))
	# Physical floor and net; the ball uses swept intersection against these same dimensions.
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(160, 0.2, 160)
	shape.shape = floor_shape
	shape.position.y = -0.1
	floor_body.add_child(shape)
	add_child(floor_body)
	var net_body := StaticBody3D.new()
	var net_shape := CollisionShape3D.new()
	var net_box := BoxShape3D.new()
	net_box.size = Vector3(9.5, 2.43, 0.08)
	net_shape.shape = net_box
	net_shape.position.y = 1.215
	net_body.add_child(net_shape)
	add_child(net_body)
	ball = sphere(self, 0.105, Vector3.ZERO, GOLD)
	shadow = ring(0.19, Color("0d2536"))
	landing_marker = ring(0.32, Color("a9d4df"))
	aim_marker = ring(0.28, GOLD)
	facing_arrow = MeshInstance3D.new()
	var arrow_mesh := ImmediateMesh.new()
	arrow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrow_points := [Vector3(0, 0, -1.9), Vector3(-0.23, 0, -1.42), Vector3(0.23, 0, -1.42), Vector3(-0.055, 0, -0.5), Vector3(-0.055, 0, -1.5), Vector3(0.055, 0, -1.5), Vector3(-0.055, 0, -0.5), Vector3(0.055, 0, -1.5), Vector3(0.055, 0, -0.5)]
	for point in arrow_points:
		arrow_mesh.surface_add_vertex(point)
	arrow_mesh.surface_end()
	facing_arrow.mesh = arrow_mesh
	facing_arrow.material_override = debug_material(GOLD, 0.85)
	facing_arrow.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(facing_arrow)
	facing_arrow.hide()
	reach_ring = ring(0.72, TEAL)
	preview = MeshInstance3D.new()
	preview.material_override = debug_material(Color.WHITE, 1.0)
	preview.material_override.no_depth_test = true
	preview.material_override.vertex_color_use_as_albedo = true
	preview.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(preview)
	for step in range(4):
		var footprint: MeshInstance3D
		if step < 3:
			footprint = box(self, Vector3(0.18, 0.025, 0.38), Vector3.ZERO, GOLD)
		else:
			footprint = MeshInstance3D.new()
			add_child(footprint)
			_draw_line(footprint, [Vector3.ZERO, Vector3.UP * 0.9, Vector3(0.13, 0.68, 0), Vector3.UP * 0.9, Vector3(-0.13, 0.68, 0)])
		footprint.material_override = debug_material(GOLD, 0.85)
		footprint.hide()
		approach_footprints.append(footprint)
	approach_preview = MeshInstance3D.new()
	approach_preview.material_override = debug_material(GOLD, 0.80)
	add_child(approach_preview)
	trail = MeshInstance3D.new()
	trail.material_override = material(GOLD, true)
	add_child(trail)
	camera = Camera3D.new()
	camera.position = Vector3(0, 4.2, 10.5)
	camera.fov = 65
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0.8))
	world_label("CONTACT LAB", Vector3(0, 0.1, -10.3), 66, TEAL)
	world_label("01   /   TRAINING COURT", Vector3(-6.5, 0.1, 0), 28, Color("90a9ba"))
	for x in [-3, 0, 3]:
		var target := ring(0.6, Color("477b86"))
		target.position = Vector3(x, 0.025, -6)

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
	body_collision_view.material_override = debug_material(Color("ffffff"), 0.045)
	player.add_child(body_collision_view)

func _rebuild_visual() -> void:
	if is_instance_valid(body):
		body.get_parent().remove_child(body)
		body.queue_free()
	var rig := VoliVisual.build(self, player, body_type, appearance, athlete.build)
	body = rig.body
	arms = rig.arms
	legs = rig.legs
	visual_rig_height = rig.rig_height
	visual_hip_x = rig.hip_x
	if is_instance_valid(athlete_hud):
		athlete_hud.refresh_portrait()

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
	var build := {"name": athlete_name.to_upper() + " / " + position_role, "height": float(config.height), "span": float(config.span)}
	for attribute in ["power", "speed", "accuracy", "endurance"]:
		build[attribute] = float(config[attribute])
	build["offsets"] = config.get("offsets", {}).duplicate(true)
	build["statistics"] = config.get("statistics",{}).duplicate(true)
	build["stat_version"] = config.get("stat_version",2)
	if config.has("picks"):
		build["picks"] = config.picks.duplicate()
	build["stat_names"] = config.get("stat_names",preload("res://scripts/athlete_store.gd").STATS).duplicate(true)
	athlete.build = build
	athlete.traits = preload("res://scripts/athlete_store.gd").owned_traits(config)
	_rebuild_visual()
	_reset()
	_message(athlete_name + " / " + body_type + " / ready to train" + ((" / traits: " + ", ".join(athlete.traits)) if not athlete.traits.is_empty() else ""))

func debug_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := material(Color(color, alpha), true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	return m

func wire_box(parent: Node3D, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for axis in range(3):
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				var start := Vector3.ZERO
				start[axis] = -size[axis] * 0.5
				start[(axis + 1) % 3] = a * size[(axis + 1) % 3] * 0.5
				start[(axis + 2) % 3] = b * size[(axis + 2) % 3] * 0.5
				var finish := start
				finish[axis] *= -1
				mesh.surface_add_vertex(start)
				mesh.surface_add_vertex(finish)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = debug_material(color, 0.8)
	parent.add_child(instance)
	return instance

func _hurtbox_definition(action: int) -> Dictionary:
	if confirm_window > 0 and action == hurtbox_action and not confirmed_geometry.is_empty():
		return confirmed_geometry
	return _raw_hurtbox_definition(action)

func _raw_hurtbox_definition(action: int) -> Dictionary:
	var height: float = athlete.build.height
	var scale_to_world := height / visual_rig_height
	var shoulder := arms[1].position.y * scale_to_world if arms.size() > 1 else height * 0.815
	var shoulder_x := absf(arms[1].position.x) * scale_to_world if arms.size() > 1 else height * 0.17
	var shape := Geometry.definition(action, height, athlete.reach(), jumped and airborne_action == 0, -1.0 if dominant_hand == "Left" else 1.0, shoulder, shoulder_x, athlete.ball_control(), Geometry.arm_length(arms[0 if dominant_hand == "Left" else 1], scale_to_world))
	if action == 0:
		shape["platform_quality"] = athlete.trait_effect("platform_quality")
	return shape

func _contact_yaw() -> float:
	var facing := airborne_aim if jumped else Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	return atan2(-facing.x, -facing.z)

func _build_hurtbox() -> void:
	hurtbox_root = Node3D.new()
	add_child(hurtbox_root)
	hurtbox_root.hide()

func ground_contact_locked() -> bool:
	return (confirm_window > 0.0 or action_endlag > 0.0 or (is_instance_valid(serve) and serve.channeling())) and player.is_on_floor() and not jumped and not approach_bound

func _confirm_action(window: float = -1.0) -> void:
	if _check_bench():
		return
	# The click is what starts the strike. Until then the spiker only loads.
	if jumped and airborne_action == 2 and locked_action == 2 and spike_swing_time < 0.0:
		spike_swing_time = 0.0
	_capture_contact_intent()
	confirmed_geometry = {}
	confirm_window = minf(window, Execution.CONTACT_SECONDS) if window > 0 else Execution.CONTACT_SECONDS
	confirm_duration = confirm_window
	if ground_contact_locked():
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		quick_step_time = 0.0
	sweet_visual_expired = false
	sweet_visual_phase = ""
	hurtbox_action = locked_action
	hurtbox_linger = confirm_window + 0.35
	for child in hurtbox_root.get_children():
		hurtbox_root.remove_child(child)
		child.queue_free()
	var shape := _hurtbox_definition(locked_action)
	confirmed_geometry = shape.duplicate(true)
	var color: Color = [TEAL, Color("ac9df2"), GOLD, Color("8bbdf4")][locked_action]
	hurtbox_mesh = MeshInstance3D.new()
	hurtbox_root.add_child(hurtbox_mesh)
	if shape.shape == "sector":
		hurtbox_mesh.mesh = Geometry.zone_mesh(shape)
		var m := debug_material(Color.WHITE, 1.0)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		hurtbox_mesh.material_override = m
		var wire := MeshInstance3D.new()
		wire.mesh = Geometry.zone_mesh(shape, true)
		wire.material_override = m
		hurtbox_root.add_child(wire)
		var sweet_point := Geometry.sector_point(shape, 0.74, 67.5, 0.0)
		sphere(hurtbox_root, 0.045, sweet_point, Color("67f3a3"))
	elif shape.shape == "set_sector":
		hurtbox_mesh.mesh = Geometry.SetHurtbox.mesh(shape)
		var m := debug_material(Color.WHITE, 1.0)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		hurtbox_mesh.material_override = m
		var wire := MeshInstance3D.new()
		wire.mesh = Geometry.SetHurtbox.mesh(shape, true)
		wire.material_override = m
		hurtbox_root.add_child(wire)
	elif shape.get("receive_platform", false):
		hurtbox_mesh.mesh = ReceivePlatform.mesh(shape)
		var m := debug_material(Color.WHITE, 1.0)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		hurtbox_mesh.material_override = m
		var wire := MeshInstance3D.new()
		wire.mesh = ReceivePlatform.mesh(shape, true)
		wire.material_override = m
		hurtbox_root.add_child(wire)
	elif shape.shape == "ellipsoid":
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 32
		mesh.rings = 16
		hurtbox_mesh.mesh = mesh
		hurtbox_mesh.scale = shape.size * 0.5
		hurtbox_mesh.material_override = debug_material(color, 0.12)
		var wire := MeshInstance3D.new()
		var lines := ImmediateMesh.new()
		lines.surface_begin(Mesh.PRIMITIVE_LINES)
		for axis in range(3):
			for i in range(48):
				var a := TAU * i / 48.0
				var b := TAU * (i + 1) / 48.0
				var first := Vector3.ZERO
				var second := Vector3.ZERO
				first[(axis + 1) % 3] = cos(a) * shape.size[(axis + 1) % 3] * 0.5
				first[(axis + 2) % 3] = sin(a) * shape.size[(axis + 2) % 3] * 0.5
				second[(axis + 1) % 3] = cos(b) * shape.size[(axis + 1) % 3] * 0.5
				second[(axis + 2) % 3] = sin(b) * shape.size[(axis + 2) % 3] * 0.5
				lines.surface_add_vertex(first)
				lines.surface_add_vertex(second)
		lines.surface_end()
		wire.mesh = lines
		wire.material_override = debug_material(color, 0.85)
		hurtbox_root.add_child(wire)
		if shape.has("edge_zone"):
			for side in [-1.0, 1.0]:
				sphere(hurtbox_root, 0.07, Vector3(side * (shape.size.x * 0.5 + Geometry.BALL_RADIUS) * float(shape.edge_zone), 0, 0), Color("ee617b"))
	elif shape.shape == "block_columns":
		hurtbox_mesh.mesh = Geometry.block_mesh(shape)
		var material := debug_material(Color.WHITE, 1.0)
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		hurtbox_mesh.material_override = material
		for side in [-1.0, 1.0]:
			var marker := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = shape.column_radius * 0.58
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = shape.size.y * 0.65
			marker.mesh = cylinder
			marker.position.x = side * shape.column_x
			marker.material_override = debug_material(Color("67f3a3"), 0.35)
			hurtbox_root.add_child(marker)
			var sweet_wire := wire_box(hurtbox_root, Vector3(shape.column_radius * 1.16, shape.size.y * 0.65, shape.column_radius * 1.16), Color("67f3a3"))
			sweet_wire.position.x = side * shape.column_x
	else:
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		hurtbox_mesh.mesh = mesh
		hurtbox_mesh.material_override = debug_material(color, 0.14)
		wire_box(hurtbox_root, shape.size, color)
	hurtbox_label = Label3D.new()
	hurtbox_label.text = ACTIONS[locked_action] + " HURTBOX"
	hurtbox_label.font_size = 29
	hurtbox_label.pixel_size = 0.005
	hurtbox_label.position.y = (float(shape.radius) if shape.shape == "sector" else (float(shape.radius) if shape.shape == "set_sector" else shape.size.y * 0.5)) + 0.18
	hurtbox_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hurtbox_label.modulate = color
	hurtbox_root.add_child(hurtbox_label)
	hurtbox_root.show()
	_update_hurtbox_visual(0.0)

func _update_hurtbox_visual(dt: float) -> void:
	if hurtbox_action < 0 or not is_instance_valid(hurtbox_root):
		return
	rescue_swing_remaining = maxf(0, rescue_swing_remaining - dt*athlete.transition_rate())
	hurtbox_linger = maxf(0.0, hurtbox_linger - dt)
	if confirm_window > 0:
		var definition := _hurtbox_definition(hurtbox_action)
		hurtbox_root.rotation.y = _contact_yaw()
		hurtbox_root.position = player.position + (definition.center as Vector3).rotated(Vector3.UP, _contact_yaw())
	var age := confirm_duration - maxf(confirm_window, 0)
	sweet_visual_expired = age > Execution.SWEET_DELAY + Execution.sweet_seconds(hurtbox_action)
	var phase := "sweet" if Execution.sweet_active(hurtbox_action, age) else ("windup" if age < Execution.SWEET_DELAY else "rescue")
	if phase != sweet_visual_phase:
		for child in hurtbox_root.get_children():
			if child is MeshInstance3D:
				if not child.has_meta("sweet_material"):
					child.set_meta("sweet_material", child.material_override)
				child.material_override = child.get_meta("sweet_material") if phase == "sweet" else debug_material(Color("8faabb") if phase == "windup" else Color("f69c69"), 0.22)
		sweet_visual_phase = phase
	if is_instance_valid(hurtbox_label):
		hurtbox_label.text = ACTIONS[hurtbox_action] + (" / WINDUP" if phase == "windup" else (" / SWEET ACTIVE" if phase == "sweet" else " / RESCUE"))
		if hurtbox_action == 2 and phase == "rescue" and age < Execution.SPIKE_RESCUE_SECONDS:
			hurtbox_label.text = "ATTACK / FORGIVING SPIKE"
	if hurtbox_action == 0 and is_instance_valid(hurtbox_label):
		hurtbox_label.text += " / " + receive_posture.to_upper()
	hurtbox_root.visible = debug_volumes_visible and hurtbox_linger > 0

func _local_contact_position() -> Vector3:
	return (ball.position - player.position).rotated(Vector3.UP, -_contact_yaw())

func _overlaps_contact(action: int) -> bool:
	return Geometry.contains(_hurtbox_definition(action), _local_contact_position())

func _contact_assessment(action: int) -> Dictionary:
	var spatial := Geometry.evaluate(_hurtbox_definition(action), _local_contact_position())
	var assessment := Execution.assess(spatial, confirm_duration - maxf(confirm_window, 0) if confirm_duration > 0 else Execution.SWEET_DELAY, not bool(spatial.hit) and contact_memory[action] > 0, action)
	return athlete.stabilize_set(assessment) if action == 1 else assessment

func _remember_contacts(dt: float) -> void:
	for action in range(4):
		contact_memory[action] = maxf(0.0, contact_memory[action] - dt)
		if ball_active and _overlaps_contact(action):
			contact_memory[action] = 0.10

func panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142536")
	style.border_color = Color("30485b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", style)
	ui.add_child(p)
	return p

func label(text: String, size: int = 16, color: Color = Color("d8e8ed")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 36)
	b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_NONE
	return b

func bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(255, 9)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("293e50")
	b.add_theme_stylebox_override("background", back)
	return b

func _bot_aim_control(title: String, value: float, changed: Callable, charge_control: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	var caption := label("%s: %d%%" % [title, value], 12)
	caption.custom_minimum_size.x = 185
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.custom_minimum_size.x = 220
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = "100% adds no aim error; 0% allows up to 2.5 m scatter at floor intercept. Contact quality still matters. Receivers keep their same-side setter heading and vary depth."
	if charge_control:
		slider.tooltip_text = "Charge accuracy controls preparation target error separately from tracking and aim. 100% targets the clean band; limited preparation time can still undercharge."
	slider.value_changed.connect(func(next: float):
		changed.call(next)
		caption.text = "%s: %d%%" % [title, next]
	)
	row.add_child(slider)
	return row

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var top := panel(Vector2(24, 20), Vector2(1392, 85))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	top.add_child(row)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	title.add_child(label("RALLY LANES", 27, TEAL))
	title.add_child(label("CONTACT LAB   /   C CREATE ATHLETE   /   M MAIN MENU", 12, Color("8faabb")))
	build_button = button("", _cycle_build)
	row.add_child(build_button)
	row.add_child(button("TITLE  [M]", _return_to_title))
	row.add_child(button("FEED BALL  [B]", _feed))
	row.add_child(button("AUTO FEED: OFF", func():
		auto_feed = not auto_feed
		(row.get_child(4) as Button).text = "AUTO FEED: " + ("ON" if auto_feed else "OFF")
	))
	row.add_child(button("RESET  [T]", _reset))
	row.add_child(button("CREATE  [C]", func(): creator.open()))
	var left := panel(Vector2(24, 126), Vector2(295, 240))
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	left.add_child(stats)
	stats.add_child(label("ATHLETE / LIVE RESOURCES", 13, TEAL))
	info = label("", 15)
	stats.add_child(info)
	metrics = label("", 13)
	stats.add_child(metrics)
	bot_panel = panel(Vector2(24, 180), Vector2(610, 530))
	var bot_scroll := ScrollContainer.new()
	bot_scroll.custom_minimum_size = Vector2(570, 490)
	bot_panel.add_child(bot_scroll)
	var bot_stack := VBoxContainer.new()
	bot_stack.add_theme_constant_override("separation", 7)
	bot_scroll.add_child(bot_stack)
	bot_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_stack.add_child(label("CAMERA TEST BOTS", 13, TEAL))
	bot_stack.add_child(label("Esc: free cursor   /   F9: close bots", 12))
	for slot in range(8):
		if slot == 3:
			var unused := CheckButton.new()
			bot_stack.add_child(unused)
			unused.hide()
			bot_buttons.append(unused)
			continue # Home court deliberately has no blocker.
		var action := slot % 4
		var bot_row := HBoxContainer.new()
		bot_stack.add_child(bot_row)
		var toggle := CheckButton.new()
		toggle.text = ("HOME " if slot < 4 else "AWAY ") + ACTIONS[action]
		toggle.custom_minimum_size.x = 185
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.toggled.connect(func(_on: bool): training_bots.toggle(action, slot >= 4))
		bot_buttons.append(toggle)
		bot_row.add_child(toggle)
		var order := OptionButton.new()
		for text in ["Any contact", "1st contact", "2nd contact", "3rd contact"]:
			order.add_item(text)
		order.select(training_bots.contact_order[slot])
		order.tooltip_text = "Block jumps for reachable incoming attacks before the first contact." if action == 3 else "Which contact this action attempts on its side."
		order.item_selected.connect(func(index: int): training_bots.set_contact_order(slot, index))
		order.focus_mode = Control.FOCUS_NONE
		bot_row.add_child(order)
		var mode := OptionButton.new()
		mode.add_item("Follow ball")
		mode.add_item("Static")
		mode.add_item("Move")
		mode.focus_mode = Control.FOCUS_NONE
		mode.item_selected.connect(func(index: int): training_bots.set_mode(slot, index))
		bot_row.add_child(mode)
		bot_modes.append(mode)
		var place := button("Place at my position", func():
			training_bots.place_at_player(slot)
			mode.select(1)
		)
		place.tooltip_text = "Locks this bot to your X/Z position, mirrored onto its court side."
		bot_stack.add_child(place)
		var accuracy_row := HBoxContainer.new()
		bot_stack.add_child(accuracy_row)
		var accuracy_label := label("Tracking accuracy: 100%", 12)
		accuracy_label.custom_minimum_size.x = 185
		accuracy_row.add_child(accuracy_label)
		var accuracy := HSlider.new()
		accuracy.min_value = 0
		accuracy.max_value = 100
		accuracy.step = 1
		accuracy.value = training_bots.tracking_accuracy[slot]
		accuracy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		accuracy.custom_minimum_size.x = 220
		accuracy.tooltip_text = "Follow Ball / Move: 100% centers the hurtbox; lower values add up to 2.5m of positioning error."
		accuracy.value_changed.connect(func(value: float):
			training_bots.set_tracking_accuracy(slot, value)
			accuracy_label.text = "Tracking accuracy: %d%%" % value
		)
		accuracy_row.add_child(accuracy)
		mode.item_selected.connect(func(index: int): accuracy.editable = index != 1)
		place.pressed.connect(func(): accuracy.editable = false)
		var speed_row := HBoxContainer.new()
		bot_stack.add_child(speed_row)
		var speed_label := label("Move speed: 6.0 m/s", 12)
		speed_label.custom_minimum_size.x = 185
		speed_row.add_child(speed_label)
		var speed := HSlider.new()
		speed.min_value = 0
		speed.max_value = 12
		speed.step = 0.25
		speed.value = training_bots.move_speeds[slot]
		speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speed.custom_minimum_size.x = 220
		speed.editable = false
		speed.tooltip_text = "Move mode only: maximum ground travel speed toward the assigned contact. Zero holds position."
		speed.value_changed.connect(func(value: float):
			training_bots.set_move_speed(slot, value)
			speed_label.text = "Move speed: %.2f m/s" % value
		)
		mode.item_selected.connect(func(index: int): speed.editable = index == 2)
		place.pressed.connect(func(): speed.editable = false)
		speed_row.add_child(speed)
		bot_stack.add_child(_bot_aim_control("Aiming accuracy", training_bots.aiming_accuracy[slot], func(value: float): training_bots.set_aiming_accuracy(slot, value)))
		bot_stack.add_child(_bot_aim_control("Charge accuracy", training_bots.charge_accuracy[slot], func(value: float): training_bots.set_charge_accuracy(slot, value), true))

	bot_stack.add_child(label("PEPPER PARTNER AIM / always Move", 13, TEAL))
	for index in range(3):
		var aim_title: String = ["Box partner aim", "East partner aim", "Home path aim"][index]
		bot_stack.add_child(_bot_aim_control(aim_title, pepper.aiming_accuracy[index], func(value: float): pepper.set_aiming_accuracy(index, value)))
		bot_stack.add_child(_bot_aim_control("Pepper %d charge accuracy" % (index + 1), pepper.charge_accuracy[index], func(value: float): pepper.set_charge_accuracy(index, value), true))
	bot_stack.add_child(button("G  /  TOGGLE ALL BOTS", func(): training_bots.toggle_all()))
	bot_status = label("Helpers off", 12)
	bot_stack.add_child(bot_status)
	bot_panel.hide()
	var station_panel := panel(Vector2(345, 126), Vector2(670, 102))
	station_status = label("", 13, Color("a8cbff"))
	station_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	station_status.custom_minimum_size = Vector2(630, 74)
	station_panel.add_child(station_status)
	athlete_hud = preload("res://scripts/athlete_hud.gd").new()
	ui.add_child(athlete_hud)
	athlete_hud.setup(self)
	hp_bar = athlete_hud.hp_bar
	sta_bar = athlete_hud.sta_bar
	var bottom := Control.new()
	ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -320
	bottom.offset_right = 320
	bottom.offset_top = -150
	bottom.offset_bottom = -90
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status = label("", 14, TEAL)
	status.add_theme_color_override("font_outline_color", Color("0e2532"))
	status.add_theme_constant_override("outline_size", 3)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(status)
	charge_label = label("", 12)
	charge_label.position = Vector2(0, -55)
	charge_label.size = Vector2(640, 50)
	charge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(charge_label)
	action_wheel = preload("res://scripts/action_wheel.gd").new()
	action_wheel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action_wheel.offset_left = -364
	action_wheel.offset_top = -364
	action_wheel.offset_right = -24
	action_wheel.offset_bottom = -24
	ui.add_child(action_wheel)
	help_panel = panel(Vector2(390, 180), Vector2(660, 460))
	var help := VBoxContainer.new()
	help.add_theme_constant_override("separation", 14)
	help_panel.add_child(help)
	help.add_child(label("MAKE THE CONTACT", 25, TEAL))
	help.add_child(label("1   Select 1 receive, 2 set, 3 attack or 4 block.\n\n2   Hold left mouse to choose power, then release.\n      A quick tap uses your athlete’s default power.\n\n3   Click again as the ball enters your reach ring.\n      Confirm is buffered for a short timing window.\n\nMove + hold Space: long right, short left, inward right.\nFourth step launches upward. Right lead is fixed for now.\nReceive: release in the first step for a fast dive.\nSet / Block: release for a quick jump; no full-run bonus.\nAttack: full approach gives the strongest spike jump.\n\nReceive low. Set overhead. Jump to spike or block.\nAim across the Net to score; keep sets on your side.\nAfter three personal contacts, return the ball.\n\nRight mouse cancels a grounded preparation.\nHold E: channel a safe standing serve. Tap E: toss; tap again to swing. Rising contact lofts higher. Quick Step: double-tap a direction while an action is charged. B feeds a debug ball. T resets. P pauses. H toggles help.\nI: start / retry / stop nearby drill.\nEast: Serve Receive. West: Spike Trainer. West lane: Box Jump.\nF1–F3: home bots. Shift+F1–F4: away bots. G: all.\nK: toggle hit/hurtboxes. Purple circles: serve to start Pepper.\nF5: feed landing here. F6: set target here. F7: tracking feed.\nV switches Athlete View / Ball View.\nMouse looks around. WASD is relative to the view.\nEsc releases the cursor for buttons; click court to return.", 17))
	help.add_child(button("LET’S PLAY", func():
		help_panel.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	))
	help_panel.hide()
	camera_badge = label("", 15, GOLD)
	camera_badge.position = Vector2(1040, 126)
	ui.add_child(camera_badge)
	menu_panels.assign([top, left, station_panel, charge_label])
	for menu in menu_panels:
		menu.hide()
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(24, 20)
	ui.add_child(toolbar)
	toolbar.add_child(button("MENUS", func():
		var show_menus := not top.visible
		for menu in menu_panels:
			menu.visible = show_menus
		toolbar.position.y = 112 if show_menus else 20
	))
	toolbar.add_child(button("BOTS [F9]", _toggle_bot_menu))
	debug_button = button("BOXES: ON [K]", _toggle_debug_volumes)
	toolbar.add_child(debug_button)
	moc_button = button("MoC: CURRENT [O]", _toggle_moc_mode)
	moc_button.tooltip_text = "Compare current world slowdown with a short contact hold followed by full-speed flight."
	toolbar.add_child(moc_button)
	toolbar.add_child(button("HIDE HUD [F8]", func(): ui.visible = false))
	facing_compass = preload("res://scripts/facing_indicator.gd").new()
	facing_compass.lab = self
	ui.add_child(facing_compass)
	facing_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	facing_compass.offset_left = 248
	facing_compass.offset_right = 330
	facing_compass.offset_top = -94
	facing_compass.offset_bottom = -16
	facing_compass.hide()
	ball_edge_indicator = label("", 14, GOLD)
	ball_edge_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_edge_indicator.hide()
	ui.add_child(ball_edge_indicator)
	var reticle := label("+", 22, Color(0.85, 0.97, 1.0, 0.65))
	reticle.position = Vector2(710, 438)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(reticle)

func _toggle_moc_mode() -> void:
	moc.set_mode((moc.mode + 1) % 3)
	moc_button.text = ["MoC: CURRENT [O]", "MoC: TUNED [O]", "MoC: OFF [O]"][moc.mode]
	_message("MoC / " + moc.mode_name())

func _toggle_debug_volumes() -> void:
	debug_volumes_visible = not debug_volumes_visible
	debug_button.text = "BOXES: %s [K]" % ("ON" if debug_volumes_visible else "OFF")
	body_collision_view.visible = debug_volumes_visible
	reach_ring.visible = debug_volumes_visible
	for volume in training_bots.contact_boxes:
		volume.visible = debug_volumes_visible
	for volume in pepper.volumes:
		volume.visible = debug_volumes_visible
	serve.hand_volume.visible = debug_volumes_visible and serve.tossing()
	_update_hurtbox_visual(0)

func _toggle_bot_menu() -> void:
	ui.visible = true
	bot_panel.visible = not bot_panel.visible
	if bot_panel.visible:
		for menu in menu_panels:
			menu.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused and not help_panel.visible and not is_benched():
		_rotate_view(event.screen_relative)

func _return_to_title() -> void:
	moc.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://title.tscn")

func _rotate_view(relative: Vector2) -> void:
	var yaw_delta := -relative.x * LOOK_SENSITIVITY
	if camera_mode == ViewMode.ATHLETE:
		view_yaw += yaw_delta
		# Looking in the air is independent of committed athlete aim.
		if jumped:
			var locked_yaw := atan2(-airborne_aim.x, -airborne_aim.z)
			view_yaw = locked_yaw + clampf(wrapf(view_yaw - locked_yaw, -PI, PI), -0.65, 0.65)
	else:
		# Ball tracking owns the camera; mouse yaw owns the athlete.
		if not jumped or (confirm_window <= 0 and committed_intent.is_empty()):
			facing_yaw += yaw_delta
			if jumped:
				airborne_aim = Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	view_pitch = clampf(view_pitch - relative.y * LOOK_SENSITIVITY, -0.65, 1.15)
	# Apply the exact mouse delta immediately; smoothing belongs to camera translation.
	_update_aim()
	_update_pose()

func _set_camera_mode(mode: int) -> void:
	if not camera_anchor_ready:
		_update_camera(0)
	camera_mode = mode
	camera_transition = 0.18
	if camera_mode == ViewMode.ATHLETE:
		view_yaw = facing_yaw
	else:
		ball_movement_yaw = view_yaw
		ball_orbit = 0.0
		ball_camera_offset = camera.position - (player.position + Vector3.UP * float(athlete.build.height) * 0.55)
		ball_camera_offset_ready = true
		ball_view_entry_pitch = view_pitch
	_message("ATHLETE VIEW / mouse controls facing" if camera_mode == ViewMode.ATHLETE else "BALL VIEW / camera tracks ball · mouse turns athlete / adjusts loft")

func _movement_direction(local: Vector3) -> Vector3:
	if camera_mode == ViewMode.BALL and ball_active:
		var toward_ball := Vector3(ball.position.x - player.position.x, 0, ball.position.z - player.position.z)
		if toward_ball.length_squared() > 0.001:
			ball_movement_yaw = atan2(-toward_ball.x, -toward_ball.z)
	var yaw := view_yaw if camera_mode == ViewMode.ATHLETE else ball_movement_yaw
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	return (right * local.x - forward * local.z).normalized()

func _unhandled_input(event: InputEvent) -> void:
	if is_benched():
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_V: bench.toggle_spectate()
				KEY_Q: bench.cycle(-1)
				KEY_R: bench.cycle(1)
		if not (event is InputEventKey and event.keycode in [KEY_O, KEY_M, KEY_P, KEY_T, KEY_H, KEY_F8, KEY_F9, KEY_K]):
			return
	if is_instance_valid(creator) and creator.visible:
		return
	if (roll_lock > 0.0 or dive_input_locked() or floor_input_locked()) and not (event is InputEventKey and event.keycode in [KEY_O, KEY_M, KEY_P, KEY_T, KEY_H, KEY_F8, KEY_F9, KEY_K]):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_note_direction_tap(event)
		match event.keycode:
			KEY_O: _toggle_moc_mode()
			KEY_K: _toggle_debug_volumes()
			KEY_F8: ui.visible = not ui.visible
			KEY_F9: _toggle_bot_menu()
			KEY_H:
				help_panel.visible = not help_panel.visible
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if help_panel.visible else Input.MOUSE_MODE_CAPTURED
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
			KEY_TAB: _cycle_build()
			KEY_F1, KEY_F2, KEY_F3, KEY_F4:
				training_bots.toggle(event.keycode - KEY_F1, event.shift_pressed)
			KEY_F5:
				debug_feed_target = Vector3(clampf(player.position.x, -4.2, 4.2), 0.95, clampf(player.position.z, 0.6, 8.5))
				debug_feed_locked = true
				_message("Feed landing locked here / F5 to retarget; F7 restores tracking feed")
			KEY_F6: training_bots._capture_set_target()
			KEY_F7:
				debug_feed_locked = false
				_message("Feed follows player again")
			KEY_G: training_bots.toggle_all()
			KEY_I:
				if pepper.active() or serve.tossing():
					_finish("Free play stopped / I to start nearby drill")
				if drills.in_zone():
					drills.interact()
				else:
					station.interact()
			KEY_V:
				_set_camera_mode(ViewMode.BALL if camera_mode == ViewMode.ATHLETE else ViewMode.ATHLETE)
		if paused:
			return
		var keys := [KEY_1, KEY_2, KEY_3, KEY_4]
		if event.keycode in keys and player.is_on_floor() and not armed and not charging and jump_charge < 0:
			selected = keys.find(event.keycode)
		if event.keycode == KEY_SPACE and player.is_on_floor():
			_begin_jump()
	if event is InputEventKey and not event.pressed and event.keycode == KEY_SPACE and jump_charge >= 0.0 and not paused:
		_takeoff()
	if event is InputEventMouseButton and generic_jump and jumped:
		return
	if event is InputEventMouseButton and not paused:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
			if not help_panel.visible:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				cursor_release_click = true
			return
		if cursor_release_click and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			cursor_release_click = false
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and player.is_on_floor():
			charging = false
			armed = false
			committed_intent = {}
			confirm_window = 0.0
			if jump_charge >= 0.0:
				jump_charge = -1.0
				approach_action = -1
				approach_bound = false
				approach_release_pending = false
				_message("Jump interrupted. Preparation cost remains spent.")
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if armed:
					_confirm_action()
				else:
					charging = true
					charge = 0.0
			elif charging:
				charging = false
				armed = true
				locked_action = selected if player.is_on_floor() else airborne_action
				locked_charge = charge if charge > 0.13 else (0.35 + 65.0 / 250.0)
				_message("Power ready. Click again when the ball is in reach.")

func _physics_process(dt: float) -> void:
	if paused:
		directional_input.clear()
		_update_ui()
		return
	var world_dt := dt
	var motion_scale: float = moc.actor_scale("player")
	dt *= motion_scale
	elapsed += world_dt
	contact_flow.tick(world_dt)
	_check_bench()
	if is_benched():
		_tick_benched(world_dt)
		return
	action_endlag = maxf(0,action_endlag-dt*athlete.transition_rate())
	var jump_gravity := athlete.jump_gravity(GRAVITY,player.velocity.y > 0) if jumped else (GRAVITY*pow(athlete.explosiveness_rate(),2) if approach_bound else GRAVITY)
	receive_pose_remaining = maxf(0, receive_pose_remaining - dt*athlete.transition_rate())
	feedback_time = maxf(0.0, feedback_time - dt)
	roll_lock = maxf(0.0, roll_lock - dt*athlete.transition_rate())
	dive_air_time = dive_air_time + dt if jumped and airborne_action == 0 else 0.0
	_tick_dive_recovery(dt)
	_tick_floor_recovery(dt)
	spike_air_time = spike_air_time + dt if jumped and airborne_action == 2 else 0.0
	if jumped and airborne_action == 2 and spike_swing_time >= 0.0:
		spike_swing_time += dt*(athlete.transition_rate() if spike_hit_time >= 0 else 1.0)
		# The swing waits at contact for the ball; if the window closes without a hit it carries on regardless.
		if spike_hit_time < 0.0 and spike_swing_time > SpikeStage.STRIKE_SECONDS and confirm_window <= 0.0:
			spike_hit_time = spike_swing_time
	set_air_time = set_air_time + dt if jumped and airborne_action == 1 else 0.0
	if not (jumped and airborne_action == 2):
		spike_swing_time = -1.0
		spike_hit_time = -1.0
		spike_contacted = false
		spike_swing_yaw = 0.0
	quick_step_time = maxf(0.0, quick_step_time - dt)
	quick_step_cooldown = maxf(0.0, quick_step_cooldown - dt)
	var local_move := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	if roll_lock > 0.0 or dive_input_locked() or floor_input_locked():
		local_move = Vector3.ZERO
	var move := _movement_direction(local_move)
	directional_input.sample(move, dt / motion_scale)
	var contact_locked := ground_contact_locked()
	var locomotion := Vector3.ZERO if contact_locked else move
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT) and locomotion.length() > 0 and athlete.stamina > 0 and jump_charge < 0
	var facing_right := Vector3.RIGHT.rotated(Vector3.UP,_contact_yaw())
	var strafe := absf(locomotion.dot(facing_right))
	var desired := locomotion * athlete.speed() * lerpf(1.0,athlete.strafe_factor(),strafe) * (1.32 if sprint else 1.0)
	if dive_recovery_time >= 0.0:
		desired *= 0.55
	var acceleration := athlete.acceleration()
	if contact_locked:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	elif generic_jump and jump_charge >= 0 and not jumped:
		jump_charge = minf(1.0, jump_charge + dt / 0.8)
		approach_direction = move
		approach_phase_name = "TRAVEL JUMP / CHARGING"
		player.velocity.x = move_toward(player.velocity.x, desired.x * 0.45, dt * acceleration)
		player.velocity.z = move_toward(player.velocity.z, desired.z * 0.45, dt * acceleration)
	elif jump_charge >= 0 and not jumped:
		jump_charge = minf(1.0, jump_charge + dt * athlete.explosiveness_rate() / Approach.DURATION)
		if move.length_squared() > 0.01 and not approach_bound:
			approach_direction = approach_direction.lerp(move, minf(1.0, dt * 7.0)).normalized()
		approach_phase_name = Approach.STEP_NAMES[Approach.step_index(jump_charge)]
		if approach_bound:
			# The long first step has a real flight phase: momentum carries it
			# until landing instead of continuously sliding a planted foot.
			player.velocity.y -= jump_gravity * dt
		elif player.is_on_floor():
			var step_velocity := approach_direction * athlete.speed() * Approach.speed_scale(jump_charge) * athlete.explosiveness_rate()
			player.velocity.x = step_velocity.x
			player.velocity.z = step_velocity.z
			if not approach_bound_started and jump_charge >= 0.11 and jump_charge < 0.40 and approach_direction.length_squared() > 0.01:
				approach_bound = true
				approach_bound_started = true
				player.velocity.y = sqrt(2.0 * GRAVITY * pow(athlete.explosiveness_rate(),2) * 0.15)
				player.velocity.x = approach_direction.x * athlete.speed() * 1.10 * athlete.explosiveness_rate()
				player.velocity.z = approach_direction.z * athlete.speed() * 1.10 * athlete.explosiveness_rate()
				athlete.spend(3.0)
		else:
			player.velocity.y -= jump_gravity * dt
	elif floor_input_locked() and player.is_on_floor():
		var floor_slide := Vector2(player.velocity.x, player.velocity.z).move_toward(Vector2.ZERO, floor_slide_decel * dt)
		player.velocity.x = floor_slide.x
		player.velocity.z = floor_slide.y
	elif dive_input_locked() and player.is_on_floor():
		var slide := Vector2(player.velocity.x, player.velocity.z).move_toward(Vector2.ZERO, dive_slide_decel * dt)
		player.velocity.x = slide.x
		player.velocity.z = slide.y
	elif quick_step_time > 0.0 and player.is_on_floor() and not jumped:
		player.velocity.x = quick_step_velocity.x
		player.velocity.z = quick_step_velocity.z
	elif player.is_on_floor() and not jumped:
		player.velocity.x = move_toward(player.velocity.x, desired.x, dt * acceleration)
		player.velocity.z = move_toward(player.velocity.z, desired.z, dt * acceleration)
	else:
		player.velocity.y -= jump_gravity * dt
	var before_move := player.position
	drills.update_one_way()
	var knock_travel: Vector3 = contact_flow.displacement("player",dt)
	player.velocity *= motion_scale
	player.move_and_slide()
	player.velocity /= motion_scale
	if knock_travel.length_squared() > 0:
		player.move_and_collide(knock_travel)
	if not jumped and not approach_bound:
		var walked := Vector2(player.position.x - before_move.x, player.position.z - before_move.z).length()
		gait_cycle += walked / maxf(athlete.stride() * 2.0, 0.1)
	if jump_charge >= 0:
		approach_distance += Vector2(player.position.x - before_move.x, player.position.z - before_move.z).length()
		if Approach.step_index(jump_charge) == 2:
			approach_plant_speed = maxf(approach_plant_speed, Vector2(player.velocity.x, player.velocity.z).length())
	player.position.x = clampf(player.position.x, -78, 78)
	player.position.z = clampf(player.position.z, -78, 78)
	if player.is_on_floor() and jumped:
		action_endlag = maxf(action_endlag,0.12)
		jumped = false
		_begin_dive_recovery()
	if approach_bound and player.is_on_floor():
		approach_bound = false
		if approach_release_pending:
			jump_charge = approach_release_progress
			approach_release_pending = false
			_takeoff()
	if sprint:
		athlete.spend(dt * (10.0 if ball_active or station.running() else 3.0))
	athlete.recover(dt, move.length() < 0.1 and player.is_on_floor() and jump_charge < 0)
	if jump_charge >= 0:
		athlete.spend(dt * 3.0)
		if jump_charge >= (1.0 if generic_jump else Approach.LAUNCH_START):
			_takeoff()
	if charging:
		charge = minf(1.0, charge + dt / 0.85)
	_update_aim()
	_update_pose()
	station.tick(world_dt)
	drills.tick(world_dt)
	_remember_contacts(dt)
	if ball_active:
		_tick_ball(world_dt)
		_remember_contacts(0.0)
	elif auto_feed and not station.in_zone() and not station.running() and not drills.in_zone() and not drills.running():
		feed_timer -= world_dt
		if feed_timer <= 0:
			_feed()
	if not ball_active:
		training_bots.tick_motion(world_dt)
		pepper.tick(world_dt)
	if confirm_window > 0:
		confirm_window = maxf(0, confirm_window - dt)
		if confirm_window > 0 and ball_active and elapsed - last_contact > 0.22/athlete.transition_rate() and _can_contact():
			_contact()
		elif confirm_window <= 0:
			committed_intent = {}
			armed = false
			athlete.spend(2.0)
			_message("Missed timing / reach. Move under the ball and try again.")
	_check_bench()
	if not is_benched():
		_update_preview()
	_update_ui()

func is_benched() -> bool:
	return is_instance_valid(bench) and bench.active

func in_live_rally() -> bool:
	if station.running() or drills.running() or not ball_active or serve.tossing():
		return false
	return pepper.active() or (absf(player.position.x) <= court_half_width + 1.5 and absf(player.position.z) <= court_half_depth + 1.5)

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
	_update_ui()

func _note_direction_tap(event: InputEventKey) -> void:
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var directions := {KEY_W: Vector3(0, 0, -1), KEY_S: Vector3(0, 0, 1), KEY_A: Vector3(-1, 0, 0), KEY_D: Vector3(1, 0, 0)}
	if not directions.has(code):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if tap_times.has(code) and now - float(tap_times[code]) <= DOUBLE_TAP_WINDOW:
		tap_times.erase(code)
		_quick_step(directions[code])
	else:
		tap_times[code] = now

func _quick_step(tapped: Vector3 = Vector3(0, 0, -1)) -> void:
	if ground_contact_locked() or paused or not athlete.has_trait("Quick Step") or not (armed or charging) or jumped or jump_charge >= 0.0 or not player.is_on_floor() or roll_lock > 0.0:
		return
	if quick_step_cooldown > 0.0:
		_message("Quick Step ready in %.1fs" % quick_step_cooldown)
		return
	var cost := athlete.quick_step_stamina_cost()
	if athlete.exhausted or athlete.stamina < cost:
		_message("Quick Step needs more Stamina.")
		return
	# Combine the tapped key with any other held direction, snapped to eight compass directions.
	var local := tapped + Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))) * 0.5
	var snapped := roundf(atan2(local.x, local.z) / (PI / 4.0)) * (PI / 4.0)
	var direction := _movement_direction(Vector3(sin(snapped), 0, cos(snapped)))
	quick_step_velocity = direction.normalized() * maxf(athlete.speed() * 2.2, 7.0)
	quick_step_time = QUICK_STEP_TIME
	var in_rally: bool = ball_active or station.running() or drills.running()
	quick_step_cooldown = QUICK_STEP_COOLDOWN_RALLY if in_rally else QUICK_STEP_COOLDOWN_EXPLORE
	athlete.spend(cost, LabAthlete.QUICK_STEP_HP)
	_message("QUICK STEP / cooldown %ds" % int(quick_step_cooldown))

func _begin_jump() -> void:
	if is_benched():
		return
	if ground_contact_locked():
		return
	if charging:
		locked_action = selected
		locked_charge = charge if charge > 0.13 else _default_charge()
		charging = false
		armed = true
	if armed or ball_active or station.running() or drills.running():
		_begin_approach()
	else:
		generic_jump = true
		jump_charge = 0.0
		approach_bound = false
		approach_action = -1
		approach_direction = Vector3.ZERO

func _travel_takeoff() -> void:
	if not player.is_on_floor():
		jump_charge = -1
		generic_jump = false
		return
	var power := clampf(jump_charge, 0, 1)
	last_jump_height = lerpf(0.6, maxf(0.6, athlete.explore_jump_max()), power)
	var flight_time := athlete.jump_flight_time(last_jump_height,GRAVITY)
	var distance := lerpf(1.5, 5.5, power)
	var input_direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := _movement_direction(input_direction)
	player.velocity = direction * distance / flight_time + Vector3.UP * athlete.jump_velocity(last_jump_height,GRAVITY)
	jump_charge = -1
	airborne_action = -1
	airborne_aim = Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	jumped = true
	armed = false
	charging = false
	contact_flow.consume_jump("player")
	athlete.spend(5.0)
	_message("TRAVEL JUMP / %.1fm high / %.1fm distance" % [last_jump_height, distance if direction.length_squared() > 0 else 0.0])

func _begin_approach() -> void:
	generic_jump = false
	jump_charge = 0.0
	approach_action = locked_action if armed else selected
	approach_distance = 0.0
	approach_plant_speed = 0.0
	approach_bound = false
	approach_bound_started = false
	approach_release_pending = false
	var input_direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	approach_direction = _movement_direction(input_direction)
	approach_phase_name = Approach.STEP_NAMES[0]

func _takeoff() -> void:
	if generic_jump:
		_travel_takeoff()
		return
	var action := approach_action if approach_action >= 0 else (locked_action if armed else selected)
	if not player.is_on_floor() and not (approach_bound and action == 0):
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
	_update_aim()
	var progress := clampf(jump_charge, 0, 1)
	airborne_action = approach_action if approach_action >= 0 else (locked_action if armed else selected)
	var base_jump := athlete.leap(1.0, 1.0)
	var jump_factor := Approach.jump_factor(airborne_action, progress)
	var run_quality := clampf(approach_distance / (athlete.stride() * 2.0), 0.0, 1.0)
	if airborne_action == 2:
		jump_factor = lerpf(0.60, jump_factor, run_quality)
	last_jump_height = base_jump * jump_factor
	airborne_aim = (aim - player.position).normalized()
	airborne_aim.y = 0
	airborne_aim = airborne_aim.normalized()
	player.velocity.y = sqrt(2.0 * GRAVITY * last_jump_height)
	if airborne_action == 0:
		var quality := Approach.dive_quality(progress)
		var dive_direction := approach_direction
		if dive_direction.length_squared() < 0.01:
			dive_direction = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
		if dive_direction.length_squared() < 0.01:
			dive_direction = airborne_aim
		last_jump_height = lerpf(0.16, 0.32, quality)
		player.velocity.y = sqrt(2.0 * GRAVITY * last_jump_height)
		dive_flight_time = 2.0 * player.velocity.y / GRAVITY
		dive_world_direction = dive_direction
		dive_turn_total = _dive_turn_for(dive_direction, dive_base_yaw)
		dive_launched = true
		dive_quality_value = quality
		var dive_speed := athlete.speed() * lerpf(1.05, 1.85, quality) * athlete.explosiveness_rate() * athlete.low_stamina_factor()
		player.velocity.x = dive_direction.x * dive_speed
		player.velocity.z = dive_direction.z * dive_speed
		if not armed:
			locked_charge = 0.35 + 65.0 / 250.0
		armed = true
		locked_action = 0
		_message("DIVE / " + ("TIMED FIRST STEP" if quality > 0.7 else "EARLY / LATE RELEASE"))
	elif airborne_action == 2:
		# Redirect the run into the plant, including momentum already arrested
		# during the closing step. Only the Attack takeoff uses this transfer.
		var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
		var transfer_speed := minf(maxf(horizontal_speed, approach_plant_speed)/athlete.explosiveness_rate(), athlete.speed() * 1.4)
		var converted_energy := transfer_speed * transfer_speed * (1.0 - SPIKE_LATERAL_RETENTION * SPIKE_LATERAL_RETENTION) * SPIKE_MOMENTUM_CONVERSION
		if attack_energy_conversion:
			player.velocity.y = sqrt(player.velocity.y * player.velocity.y + converted_energy)
			last_jump_height = player.velocity.y * player.velocity.y / (2.0 * GRAVITY)
		player.velocity.x *= SPIKE_LATERAL_RETENTION
		player.velocity.z *= SPIKE_LATERAL_RETENTION
		spike_flight_time = 2.0 * player.velocity.y / GRAVITY
		spike_swing_time = -1.0
		spike_hit_time = -1.0
		spike_contacted = false
		spike_swing_yaw = 0.0
	else:
		# Jump Set and Block Jump retain their existing lateral carry.
		player.velocity.x *= 0.38
		player.velocity.z *= 0.38
		if airborne_action == 1:
			set_flight_time = 2.0 * player.velocity.y / GRAVITY
	# Explosiveness changes ascent time without changing the resolved jump height.
	player.velocity.y = athlete.jump_velocity(last_jump_height,GRAVITY)
	if airborne_action == 0:
		dive_flight_time = athlete.jump_flight_time(last_jump_height,GRAVITY)
	elif airborne_action == 1:
		set_flight_time = athlete.jump_flight_time(last_jump_height,GRAVITY)
	elif airborne_action == 2:
		spike_flight_time = athlete.jump_flight_time(last_jump_height,GRAVITY)
	if airborne_action != 0:
		contact_flow.consume_jump("player")
	athlete.spend(athlete.jump_stamina_cost())
	jump_charge = -1
	approach_action = -1
	jumped = true
	approach_phase_name = Approach.STEP_NAMES[3]
	if airborne_action == 0:
		_confirm_action(0.65)

func _update_aim() -> void:
	if is_benched():
		aim_marker.hide()
		reach_ring.hide()
		facing_arrow.hide()
		return
	aim_marker.visible = debug_volumes_visible
	reach_ring.visible = debug_volumes_visible
	if not jumped:
		if camera_mode == ViewMode.ATHLETE:
			facing_yaw = view_yaw
		var facing := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
		aim = Vector3(player.position.x, 0, player.position.z) + facing * 9.0
	else:
		aim = Vector3(player.position.x, 0, player.position.z) + airborne_aim * 9.0
	aim_marker.position = Vector3(aim.x, 0.035, aim.z)
	reach_ring.position = Vector3(player.position.x, 0.04, player.position.z)
	if is_instance_valid(facing_arrow):
		facing_arrow.position = player.position + Vector3.UP * 0.045
		facing_arrow.rotation.y = _contact_yaw()
		facing_arrow.visible = camera_mode == ViewMode.BALL

func _update_camera(dt: float) -> void:
	if is_benched():
		bench.update_camera(dt)
		return
	var stable_target := player.position + Vector3.UP * float(athlete.build.height) * 0.55
	if not camera_anchor_ready:
		camera_anchor = stable_target
		camera_anchor_ready = true
	# Ball View is attached to the athlete, not a lagging world-space pivot.
	camera_anchor = stable_target if camera_mode == ViewMode.BALL else camera_anchor.lerp(stable_target, 1.0 - exp(-dt * 18.0))
	var anchor := camera_anchor
	var forward := Vector3(-sin(view_yaw), 0, -cos(view_yaw))
	var orbit_pitch := view_pitch - 0.27
	var floor_pitch := asin(clampf((anchor.y - 0.4) / ATHLETE_CAMERA_DISTANCE, -0.99, 0.99))
	var position_pitch := minf(orbit_pitch, floor_pitch)
	var orbit_forward := forward * cos(position_pitch) + Vector3.UP * sin(position_pitch)
	var desired_position := anchor - orbit_forward * ATHLETE_CAMERA_DISTANCE
	var look_target := anchor
	if orbit_pitch > floor_pitch:
		look_target = desired_position + (forward * cos(orbit_pitch) + Vector3.UP * sin(orbit_pitch)) * ATHLETE_CAMERA_DISTANCE
	if camera_mode == ViewMode.BALL:
		if not ball_camera_offset_ready:
			ball_camera_offset = desired_position - anchor
			ball_camera_offset_ready = true
			ball_view_entry_pitch = view_pitch
		var feet := anchor - Vector3.UP * float(athlete.build.height) * 0.55
		var focus := ball.position if ball_active else feet + Vector3(-sin(ball_movement_yaw), 0, -cos(ball_movement_yaw)) * 8 + Vector3.UP * float(athlete.build.height)
		var frame := BallFraming.frame(feet, float(athlete.build.height), focus, ball_camera_offset, ATHLETE_CAMERA_DISTANCE, dt)
		ball_camera_offset = frame.offset
		ball_frame_pivot = frame.pivot
		ball_frame_screen_y = frame.screen_y
		desired_position = anchor + ball_camera_offset
		look_target = BallFraming.look_target(desired_position, ball_frame_pivot, ball_frame_screen_y, 65.0)
	var query := PhysicsRayQueryParameters3D.create(anchor, desired_position)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired_position = hit.position + hit.normal * 0.25
	desired_position.y = maxf(0.4, desired_position.y)
	if camera_mode == ViewMode.BALL:
		look_target = BallFraming.look_target(desired_position, ball_frame_pivot, ball_frame_screen_y, 65.0)
		if ball_active:
			var net_allowance := (1.0 - smoothstep(1.0, 3.5, absf(player.position.z))) * (1.0 - smoothstep(4.75, 6.0, absf(player.position.x)))
			look_target = BallFraming.net_look_target(desired_position, ball_frame_pivot, ball.position, look_target, net_allowance, 65.0)
	camera_transition = maxf(0, camera_transition - dt)
	# Ball View automatically positions around the athlete/ball pair; mouse controls athlete aim.
	camera.position = desired_position
	camera.fov = 65.0
	if camera.position.distance_squared_to(look_target) > 0.01:
		var desired_rotation := Transform3D(Basis.IDENTITY, camera.position).looking_at(look_target, Vector3.UP).basis.get_rotation_quaternion()
		camera.quaternion = desired_rotation
	_update_ball_edge_indicator()

func _update_ball_edge_indicator() -> void:
	if not is_instance_valid(ball_edge_indicator):
		return
	ball_edge_indicator.visible = camera_mode == ViewMode.BALL and ball_active and not camera.is_position_in_frustum(ball.position)
	if not ball_edge_indicator.visible:
		return
	var local := camera.to_local(ball.position)
	var direction := Vector2(local.x, -local.y).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.UP
	var half := get_viewport().get_visible_rect().size * 0.5
	var scale := minf((half.x - 60) / maxf(absf(direction.x), 0.001), (half.y - 40) / maxf(absf(direction.y), 0.001))
	ball_edge_indicator.position = half + direction * scale - Vector2(30, 10)
	ball_edge_indicator.text = "↑ BALL" if direction.y < -0.5 else ("BALL ↓" if direction.y > 0.5 else ("BALL →" if direction.x > 0 else "← BALL"))

func _update_pose() -> void:
	if is_benched():
		bench.apply_pose()
		return
	# The dive layer adds yaw/roll on top of the body; take it off first so it never accumulates between frames.
	body.rotation.y -= dive_applied_yaw
	dive_applied_yaw = 0.0
	body.rotation.z = 0.0
	body.scale = Vector3.ONE * float(athlete.build.height) / visual_rig_height
	var direction := aim - player.position
	if direction.length_squared() > 0.1:
		body.rotation.y = facing_yaw if camera_mode == ViewMode.BALL and ball_active else atan2(-direction.x, -direction.z)
	dive_base_yaw = body.rotation.y
	dive_applied_yaw = _dive_turn_offset()
	body.rotation.y += dive_applied_yaw
	_pivot_dive_turn()
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var receive_ready := not jumped and jump_charge < 0 and ((armed and locked_action == 0) or (charging and selected == 0))
	var travel_heading := wrapf(atan2(-player.velocity.x, -player.velocity.z) - facing_yaw, -PI, PI) if speed > 0.1 else 0.0
	var follow_receive := receive_pose_remaining > 0 and not jumped
	var receive_weight := 1.0 if receive_ready else smoothstep(0, 0.18, receive_pose_remaining)
	var gait := Pose.base(body, gait_cycle, speed if not jumped and jump_charge < 0 else 0.0, travel_heading, receive_ready or follow_receive, receive_weight)
	body.get_node("Torso").rotation.y = 0
	body.get_node("Head").rotation.y = 0
	for i in range(2):
		legs[i].position.x = -visual_hip_x if i == 0 else visual_hip_x
		if jumped:
			legs[i].rotation.x = -0.25
			legs[i].get_node("Knee").rotation_degrees.x = -20.0
		if not generic_jump and selected != 0 and (armed or jumped):
			arms[i].rotation.x = -2.7
		elif armed:
			arms[i].rotation.x = -0.8

	if jump_charge < 0 and ((armed and locked_action == 2) or (jumped and airborne_action == 2)):
		var dominant := 0 if dominant_hand == "Left" else 1
		arms[dominant].rotation.x = -2.95
		arms[dominant].rotation.z = 0.35 if dominant_hand == "Left" else -0.35
		arms[1 - dominant].rotation.x = -1.3
	body.position.y = 0.0
	if generic_jump and jump_charge >= 0:
		body.position.y = -0.22 * jump_charge
		for leg in legs:
			leg.rotation.x = 0.35 * jump_charge
			leg.get_node("Knee").rotation.x = -0.8 * jump_charge
	elif jump_charge >= 0 and approach_action != 0:
		# A dive charges as its crouching step (DiveStage prep), not as a jump approach.
		var step := Approach.step_index(jump_charge)
		var phase := Approach.step_phase(jump_charge)
		var lead := Approach.lead_foot(step)
		var swing: float = [1.05, 0.65, 0.48, 0.0][step]
		legs[lead].rotation.x = -sin(phase * PI) * swing
		legs[1 - lead].rotation.x = sin(phase * PI) * swing * 0.55
		body.position.y = -0.14 * sin(phase * PI)
		if step == 0 and approach_bound:
			body.position.y = 0.0
			legs[lead].rotation.x = -0.85
			legs[1 - lead].rotation.x = 0.55
		if step == 2:
			var closing := smoothstep(0.15, 1.0, phase)
			legs[lead].position.x = lerpf(visual_hip_x, Approach.foot_lateral(2), closing)
			legs[lead].rotation.y = Approach.foot_turn(2) * closing
			body.position.y = -0.16 * closing
			if approach_direction.length_squared() > 0.01:
				var plant_yaw := atan2(-approach_direction.x, -approach_direction.z)
				var correction := clampf(wrapf(plant_yaw - body.rotation.y, -PI, PI), -0.25, 0.25)
				body.rotation.y += correction * closing
		for arm in arms:
			arm.rotation.x = 0.55 if step < 2 else -0.7
	body.rotation.x = 0.0
	if roll_lock > 0.0:
		var roll_progress := 1.0 - roll_lock / ROLL_TIME
		body.rotation.x = -TAU * roll_progress
		body.position.y = 0.45 * sin(roll_progress * PI)
	body.get_node("Torso").rotation.x = float(gait.torso_pitch_radians)
	if (receive_ready or follow_receive or (jumped and airborne_action == 0)) and roll_lock <= 0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0:
		if receive_pose_remaining <= 0:
			var shape := _hurtbox_definition(0)
			receive_pose_contact = Vector3(shape.center)
			if ball_active and Geometry.contains(shape, _local_contact_position()):
				receive_pose_contact = _local_contact_position()
			receive_posture = ReceivePlatform.posture(shape, receive_pose_contact, speed)
		ReceivePose.apply(body, receive_posture, receive_pose_contact, 1.0 if receive_ready or jumped else receive_weight)
	var diving_now := jumped and airborne_action == 0
	var preparing_dive := not jumped and jump_charge >= 0 and approach_action == 0
	if (diving_now or preparing_dive) and roll_lock <= 0:
		var dive_dir := dive_world_direction if diving_now else (approach_direction if approach_direction.length_squared() > 0.01 else Vector3(-sin(facing_yaw), 0, -cos(facing_yaw)))
		var dive_phase := DiveStage.phase_for(jump_charge, dive_air_time, dive_flight_time, diving_now)
		var dive_stage := DiveStage.resolve(dive_phase, DiveStage.local_direction(dive_dir, body.rotation.y), _dive_pivot_foot())
		dive_stage["turn_spine"] = dive_turn_spine
		dive_stage["turn_neck"] = dive_turn_neck
		dive_applied_yaw += DiveStage.apply(body, dive_stage)
	if jumped and airborne_action == 2 and roll_lock <= 0.0:
		var swing_yaw := spike_swing_yaw
		if not spike_contacted and ball_active:
			var preview_assessment := _contact_assessment(2)
			if preview_assessment.hit:
				var forward := Vector3(-sin(_contact_yaw()), 0, -cos(_contact_yaw()))
				var preview := SpikeDirection.resolve(_shot_velocity(ball.position, 2, locked_charge), preview_assessment, directional_input.value(), forward)
				swing_yaw = preview.shot_yaw_radians
		var aim_context := {"shot_yaw": swing_yaw}
		if ball_active:
			aim_context["ball_local"] = body.global_transform.affine_inverse() * ball.position
		SpikeStage.apply(body, SpikeStage.phase_for(spike_air_time, spike_flight_time, spike_swing_time, spike_hit_time), -1.0 if dominant_hand == "Left" else 1.0, locked_charge, "Power swing", aim_context)
	if dive_recovery_time >= 0.0 and roll_lock <= 0.0:
		_apply_dive_recovery()
	elif floor_recovery_time >= 0.0 and roll_lock <= 0.0:
		_apply_floor_recovery()
	var set_phase := _set_phase()
	if set_phase > -1.5 and roll_lock <= 0.0 and dive_recovery_time < 0.0 and floor_recovery_time < 0.0 and not (diving_now or preparing_dive):
		SetStage.apply_data(body, set_phase, jumped and airborne_action == 1, -1.0 if dominant_hand == "Left" else 1.0)
	_smooth_pose(_pose_source(diving_now, preparing_dive, receive_ready or follow_receive))
	var wing_pose := "tucked"
	var wing_weight := 0.0
	if diving_now or preparing_dive:
		wing_pose = "balance"
		wing_weight = 1.0 if diving_now else 0.35
	elif jumped and airborne_action == 3:
		wing_pose = "block"
		wing_weight = 1.0
	WingPose.apply(body, "tucked", wing_pose, wing_weight)
	if dive_recovery_time >= 0.0 or (floor_recovery_time >= 0.0 and floor_recovery_name != "shrug"):
		DiveRecovery.rest_on_floor(body, player.global_position.y)
	elif not jumped and not approach_bound:
		Pose.ground_feet(body)
	if rescue_swing_remaining > 0:
		var dominant := 0 if dominant_hand == "Left" else 1
		var progress := 1.0 - rescue_swing_remaining / 0.28
		arms[dominant].rotation.x = lerpf(-1.0, -1.65, sin(progress * PI))
		arms[dominant].get_node("Elbow").rotation.x = -0.25
	if is_instance_valid(serve):
		serve.apply_pose()

# Where the set is: -2 when the body is not setting. Hands up and ready while a set is armed, the push and
# extension after contact, and through the air for a jump set (contact at the top).
func _set_phase() -> float:
	if jumped and airborne_action == 1:
		var f := clampf(set_air_time / maxf(set_flight_time, 0.001), 0.0, 1.0)
		return lerpf(-0.30, 0.04, f / 0.5) if f < 0.5 else lerpf(0.04, 0.45, (f - 0.5) / 0.5)
	if jumped or jump_charge >= 0.0:
		return -2.0
	var since := (elapsed - last_contact)*athlete.transition_rate()
	if since >= 0.0 and since < 0.5 and int(last_contact_result.get("action", -1)) == 1:
		return SetStage.follow_phase(since)
	if armed and locked_action == 1:
		return -0.16
	return -2.0

# Which animation is driving the body right now. A change in this is what gets smoothed.
func _pose_source(diving_now: bool, preparing_dive: bool, receiving: bool) -> String:
	if roll_lock > 0.0:
		return "roll"
	if floor_recovery_time >= 0.0:
		return "floor:%s" % floor_recovery_name
	if _set_phase() > -1.5 and dive_recovery_time < 0.0 and not (diving_now or preparing_dive):
		return "set"
	if dive_recovery_time >= 0.0 or diving_now or preparing_dive:
		# The crouching step, the dive, the landing and the getting up are one animation. It is
		# continuous inside itself, so only its edges are smoothed.
		return "dive"
	if jumped:
		if airborne_action == 2 and spike_contacted:
			return "air:2:hit"
		return "air:%d" % airborne_action
	if jump_charge >= 0.0:
		return "approach:%d" % approach_action
	if receiving:
		return "receive:%s" % receive_posture
	if armed:
		return "armed:%d" % locked_action
	return "locomotion"

# Read the pose the code just built, and draw it with the seam from the previous source removed.
# Outside a running frame (tests, screenshots) there is no time to smooth over, so the pose stands.
func _smooth_pose(source: String) -> void:
	if not pose_smoothing or pose_frame_dt <= 0.0:
		pose_smoother.reset()
		return
	var frame := Engine.get_process_frames()
	var step := pose_frame_dt if frame != pose_last_frame else 0.0
	pose_last_frame = frame
	var shown := pose_smoother.update(PoseLibrary.read_rig(body), source, step)
	PoseLibrary.apply(body, PoseLibrary.from_flat(shown, false), 1.0)

func _resize_court() -> void:
	var home := 1
	var away := 0
	for action in range(4):
		home += int(training_bots.is_enabled(action, 1))
		away += int(training_bots.is_enabled(action, -1))
	var team_size := maxi(home, away)
	# Provisional 1/2/3/4+ player layouts; both halves use the larger team.
	court_half_width = [2.5, 3.0, 3.75, 4.5][mini(team_size - 1, 3)]
	court_half_depth = [5.0, 6.0, 7.5, 9.0][mini(team_size - 1, 3)]
	_draw_line(court_outline, [Vector3(-court_half_width, 0.045, -court_half_depth), Vector3(court_half_width, 0.045, -court_half_depth), Vector3(court_half_width, 0.045, court_half_depth), Vector3(-court_half_width, 0.045, court_half_depth), Vector3(-court_half_width, 0.045, -court_half_depth)])

func _serve() -> void:
	serve.press()

func _feed() -> void:
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
	var target := Vector3(clampf(player.position.x + sin(attempts * 1.7) * 0.7, -3.5, 3.5), 0.95, clampf(player.position.z, 2, 8))
	if debug_feed_locked:
		target = debug_feed_target
	ball.position = Vector3(target.x * 0.6, 3.6, -7.5)
	var duration := 2.0
	ball_velocity = (target - ball.position) / duration + Vector3.UP * (GRAVITY * duration * 0.5)
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
	if serve.tossing():
		return false
	if pepper.active() and (pepper.npc_turn or locked_action != pepper.required_player_action()):
		return false
	if locked_action == 0 and _local_contact_position().z > 0:
		return false
	return _overlaps_contact(locked_action) or (ball_active and contact_memory[locked_action] > 0.0)

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
func _contact_loft_factor() -> float:
	var pitch := view_pitch - 0.27 # Camera optical axis is level here.
	return lerpf(1.0, 2.5, clampf(pitch / 0.88, 0, 1)) if pitch >= 0 else lerpf(1.0, 0.35, clampf(-pitch / 0.92, 0, 1))

func _loft_velocity(origin: Vector3, action: int, power: float, direction: Vector3) -> Vector3:
	var peak: float
	var distance: float
	if action == 0:
		power = ReceiveCharge.CONTROL_CHARGE
		var ceiling := _bump_ceiling(origin.y)
		peak = origin.y + (ceiling - origin.y) * lerpf(0.25, 1.0, clampf(power, 0, 1))
		var previous := Flight.solve_flight(5.0 + power * 5.5, 60.0, maxf(origin.y - 0.105, 0.0))
		distance = previous.range_meters
	else:
		var ceiling := maxf(origin.y + 0.35, _bump_ceiling(1.0))
		peak = origin.y + (ceiling - origin.y) * SET_RISE_FACTOR * lerpf(0.65, 1.0, clampf(power, 0, 1))
		var previous := Flight.solve_flight(5.5 + power * 4.5, 76.0, maxf(origin.y - 0.105, 0.0))
		distance = previous.range_meters * SET_RANGE_FACTOR
		if not jumped:
			distance *= GROUND_SET_RANGE_FACTOR
			peak = origin.y + (peak - origin.y) * GROUND_SET_RISE_FACTOR
	peak = origin.y + (peak - origin.y) * _contact_loft_factor()
	var upward := sqrt(2.0 * GRAVITY * maxf(peak - origin.y, 0.1))
	var duration := (upward + sqrt(upward * upward + 2.0 * GRAVITY * maxf(origin.y - 0.105, 0.0))) / GRAVITY
	return direction * distance / maxf(duration, 0.01) + Vector3.UP * upward

func _shot_velocity(origin: Vector3, action: int, power: float, target: Variant = null) -> Vector3:
	var direction: Vector3 = (aim if target == null else Vector3(target)) - origin
	direction.y = 0
	if direction.length() < 0.2:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	if action in [0, 1]:
		return _loft_velocity(origin, action, power, direction)*athlete.low_stamina_factor()
	if action == 2:
		power = contact_flow.attack_charge(power,"player",origin) if is_instance_valid(contact_flow) else athlete.effective_attack_charge(power)
	var hp_factor := lerpf(0.7, 1.0, athlete.hp / 100.0)
	var speed := (6.0 + power * 7.0 + 65.0 * 0.02) * hp_factor
	if action == 2:
		speed *= ATTACK_DRIVE_FACTOR * (SPIKE_SPEED_MULTIPLIER if jumped else 1.0)
	var angle := -3.0 + power * 2.0 if jumped else 6.0
	if action == 3:
		speed = 5.0 + power * 3.5
		angle = -18.0
	angle = clampf(angle + rad_to_deg(view_pitch - 0.27) * 0.65, -65.0, 70.0)
	var flight: Dictionary = Flight.solve_flight(speed, angle, origin.y)
	return (direction * float(flight.horizontal_speed_mps) + Vector3.UP * float(flight.vertical_speed_mps))*(athlete.low_stamina_factor() if action != 2 else 1.0)

func _capture_contact_intent() -> void:
	var origin := player.position + Vector3.UP * (athlete.reach() - (1.2 if locked_action == 0 else 0.2))
	var forward := aim - origin
	forward.y = 0
	var influence := DirectionalInfluence.resolve(_shot_velocity(origin, locked_action, locked_charge), locked_action, directional_input.value(), forward, 1.0)
	committed_intent = ContactIntent.capture("player", side_index(player.position.z), locked_action, locked_charge, origin, aim, influence.velocity, elapsed, influence)

func _emit_contact_impact(incoming_velocity: Vector3, assessment: Dictionary, incoming_shot: Dictionary = {}) -> void:
	_contact_event_serial += 1
	last_contact_result = {"id": "player:%d" % _contact_event_serial, "actor": "player", "team": side_index(player.position.z), "action": locked_action, "charge": locked_charge, "physical_hit": bool(assessment.hit), "point": ball.position, "incoming_velocity": incoming_velocity, "incoming_shot": incoming_shot, "outgoing_shot": ball_shot, "charge_match": assessment.get("charge_match", {}), "outgoing_velocity": ball_velocity, "zone": last_quality, "quality":assessment.get("quality",0.0), "sweet": assessment.get("sweet", false), "rescue": assessment.get("rescue", false), "confirmation_age": assessment.get("confirmation_age", 0.0), "posture": assessment.get("posture", ""), "receive_outcome": assessment.get("receive_outcome", {}), "recovery": assessment.get("recovery", ""), "recovery_seconds": assessment.get("recovery_seconds", 0.0), "recovery_penalty_seconds":assessment.get("receive_outcome",{}).get("recovery_penalty_seconds",0.0), "platform_band": assessment.get("band", ""), "platform_coord": assessment.get("platform_coord", Vector3.ZERO), "simulation_time": elapsed, "intent": committed_intent, "directional_influence": last_directional_influence}
	last_contact_result.make_read_only()
	if locked_action == 0:
		receive_resolved.emit(last_contact_result)
	action_endlag = [0.16,0.12,0.22,0.16][locked_action]
	contact_flow.record(last_contact_result)
	moc.begin(last_contact_result)
	# The next preparation owns a new snapshot; history retains this immutable one.
	committed_intent = {}

func _emit_external_impact(actor_id: String, action: int, incoming: Vector3, assessment: Dictionary, incoming_shot: Dictionary = {}) -> void:
	_contact_event_serial += 1
	var event := {"id": "%s:%d" % [actor_id, _contact_event_serial], "actor": actor_id, "incoming_shot":incoming_shot, "action": action, "point": ball.position, "quality": assessment.get("quality", 0.75), "rescue": assessment.get("rescue", false), "charge_match": assessment.get("charge_match", {}), "physical_hit": assessment.get("hit", false), "sweet": assessment.get("sweet", false), "incoming_velocity": incoming, "outgoing_velocity": ball_velocity, "receive_outcome": assessment.get("receive_outcome", {}), "recovery": assessment.get("recovery", ""), "recovery_seconds": assessment.get("recovery_seconds", 0.0), "recovery_penalty_seconds":assessment.get("receive_outcome",{}).get("recovery_penalty_seconds",0.0)}
	event.make_read_only()
	if action == 0:
		receive_resolved.emit(event)
	if actor_id == "player_serve":
		action_endlag = 0.22
	contact_flow.record(event)
	moc.begin(event)

func _exit_tree() -> void:
	if is_instance_valid(moc):
		moc.clear()

func _advance_action_after_contact() -> void:
	# A queued next selection never changes the current airborne commitment.
	selected = pepper.next_action(pepper.stage, 1.0) if pepper.active() else (locked_action + 1) % ACTIONS.size()

func side_index(z: float) -> int:
	return 0 if z >= 0 else 1

func _contact() -> void:
	if _check_bench():
		return
	if serve.tossing():
		return
	if pepper.active() and (pepper.npc_turn or locked_action != pepper.required_player_action()):
		_message("PEPPER / next contact: " + ACTIONS[pepper.player_action])
		return
	if locked_action == 0 and _local_contact_position().z > 0:
		return
	var incoming_velocity := ball_velocity
	var incoming_shot := ball_shot
	if jumped and airborne_action == 2 and locked_action == 2 and not spike_contacted:
		# The ball is struck now: the arm is at contact now, and follows through from here.
		if spike_swing_time < 0.0:
			spike_swing_time = 0.0
		spike_hit_time = spike_swing_time
		spike_contacted = true
	var is_block := locked_action == 3
	if not is_block:
		contacts += 1
	var side := side_index(ball.position.z)
	if not is_block and (pepper.player_contacts >= 3 if pepper.active() else (contacts > 3 or side_contacts[side] >= 3)):
		_finish("Three-contact fault. Return the ball across the Net earlier.")
		return
	if pepper.active():
		pepper.player_contacts += 1
	elif not is_block:
		side_contacts[side] += 1
	training_bots.last_was_block = locked_action == 3
	training_bots.incoming_action = locked_action
	var assessment := _contact_assessment(locked_action)
	if locked_action == 0:
		assessment = ReceiveCharge.assess(assessment, incoming_shot, locked_charge*athlete.low_stamina_factor(),athlete.cushioning_bonus(),athlete.trait_effect("charge_tolerance"))
		last_receive_match = assessment.charge_match
	if locked_action == 0 and assessment.hit:
		receive_pose_contact = _local_contact_position()
		receive_posture = ReceivePlatform.posture(_hurtbox_definition(0), receive_pose_contact, Vector2(player.velocity.x, player.velocity.z).length())
		assessment["posture"] = receive_posture
		assessment["band"] = receive_posture.to_upper()
		assessment = ReceiveOutcome.assess(assessment,_hurtbox_definition(0),receive_pose_contact,Vector2(player.velocity.x,player.velocity.z).length(),directional_input.value(),_contact_yaw())
		last_receive_match = assessment.charge_match
		receive_pose_remaining = 0.42
	var quality: float = assessment.quality if assessment.hit else 0.35
	last_quality = assessment.zone if assessment.hit or assessment.get("rescue", false) else "STRETCHED"
	var rolled: bool = locked_action == 0 and athlete.has_trait("Rolling Receive") and assessment.hit and assessment.get("edge", false) and not assessment.get("rescue", false) and assessment.get("charge_match", {}).get("matched", true)
	if committed_intent.is_empty() or int(committed_intent.action) != locked_action or not is_equal_approx(float(committed_intent.charge), locked_charge):
		_capture_contact_intent()
	ball_velocity = _shot_velocity(ball.position, locked_action, locked_charge, committed_intent.target)
	var ideal_velocity := ball_velocity
	if locked_action == 2 and assessment.get("rescue", false):
		rescue_swing_remaining = 0.28
	if rolled:
		var facing := airborne_aim if jumped else Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
		ball_velocity = _loft_velocity(ball.position, 1, 0.85, facing.normalized())
		quality = 1.0
		last_quality = "ROLLING RECEIVE"
		roll_lock = ROLL_TIME
		athlete.spend(0.0, LabAthlete.ROLLING_RECEIVE_HP)
	if locked_action == 0 and assessment.hit and not rolled:
		ball_velocity = ReceivePlatform.redirect(ball_velocity, ball.position, _contact_yaw(), incoming_velocity, assessment, GRAVITY)
	if locked_action == 2:
		ball_velocity *= float(assessment.strength) if assessment.hit else 0.48
	# Accuracy helps execution fidelity, but never upgrades a sour zone to sweet.
	var deviation := (1.0 - quality) * (1.0 - athlete.ball_control() / 120.0)
	if locked_action in [1, 3]:
		ball_velocity = ball_velocity.rotated(Vector3.UP, deviation * sin(elapsed * 7.0) * 0.50)
	var contact_facing := Vector3(-sin(_contact_yaw()), 0, -cos(_contact_yaw()))
	if locked_action == 2:
		last_directional_influence = SpikeDirection.resolve(ball_velocity, assessment, directional_input.value(), contact_facing)
		spike_swing_yaw = last_directional_influence.shot_yaw_radians
	else:
		last_directional_influence = DirectionalInfluence.resolve(ball_velocity, locked_action, directional_input.value(), committed_intent.direction, quality)
	ball_velocity = last_directional_influence.velocity
	ball_velocity = Execution.velocity(locked_action, ball_velocity, incoming_velocity, contact_facing, assessment, athlete.timing(), ideal_velocity,athlete.ball_control(),athlete.flow,athlete.low_stamina_factor())
	if locked_action == 0:
		ball_velocity = ReceiveCharge.velocity(ReceiveOutcome.velocity(ball_velocity,assessment), incoming_velocity, contact_facing, assessment)
	ball_shot = ReceiveCharge.shot(["receive", "set", "attack", "block"][locked_action], contact_flow.attack_charge(locked_charge,"player",ball.position) if locked_action == 2 else locked_charge, "player")
	if locked_action == 2 and assessment.hit:
		contact_flow.consume_attack("player")
	var cost: Vector2 = athlete.contact_cost(locked_action, contacts)
	athlete.spend(cost.x)
	contact_memory = [0.0, 0.0, 0.0, 0.0]
	last_contact = elapsed
	outgoing = true
	armed = false
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
	elif ball_active:
		_advance_action_after_contact()

	_check_bench()

func _try_swept_player_block(previous: Vector3, dt: float) -> bool:
	if locked_action != 3 or not armed or confirm_window <= 0 or elapsed - last_contact <= 0.22/athlete.transition_rate():
		return false
	var endpoint := ball.position
	var shape := _hurtbox_definition(3)
	var samples := maxi(1, ceili(previous.distance_to(endpoint) / 0.025))
	var initial_window := confirm_window
	for sample in range(samples + 1):
		var fraction := float(sample) / samples
		if initial_window - dt * fraction <= 0:
			break
		var point := previous.lerp(endpoint, fraction)
		if Geometry.contains(shape, (point - player.position).rotated(Vector3.UP, -_contact_yaw())):
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
	if not serve.tossing() and not station.running() and not drills.running():
		pepper.try_start(previous)
		if pepper.tick(world_dt):
			return
	if _try_swept_player_block(previous, dt):
		return
	if previous.z * ball.position.z < 0 and absf(ball.position.x) <= 4.6:
		var ratio := previous.z / (previous.z - ball.position.z)
		var crossing := previous.lerp(ball.position, ratio)
		if crossing.y < 2.43 + 0.105:
			_finish("Net fault. Get under the ball or use a higher launch.")
			return
		if not pepper.active():
			side_contacts[side_index(ball.position.z)] = 0
			contacts = 0
		if training_bots.active_action < 0:
			training_bots.replan()
	if not station.running() and not drills.running() and not serve.tossing() and not pepper.active() and (serve.state != serve.State.FLIGHT or serve.main_court) and training_bots.tick(world_dt):
		return
	if (serve.state != serve.State.IDLE or pepper.active()) and not station.running() and not drills.running():
		var query := PhysicsRayQueryParameters3D.create(previous, ball.position)
		query.exclude = [player.get_rid()]
		var solid := get_world_3d().direct_space_state.intersect_ray(query)
		if not solid.is_empty():
			ball.position = solid.position + solid.normal * Geometry.BALL_RADIUS
			_finish("Ball down / Pepper ended" if pepper.active() else "Serve hit the ground or obstacle / E to toss again")
			return
	if ball.position.y <= 0.105:
		if pepper.active():
			_finish("PEPPER ended / ball down / E to toss again")
			return
		var floor_endpoint := ball.position
		ball.position.y = 0.105
		if station.running():
			var floor_fraction := clampf((previous.y - 0.105) / maxf(previous.y - floor_endpoint.y, 0.000001), 0, 1)
			station.on_ball_down(previous.lerp(floor_endpoint, floor_fraction))
			return
		if drills.running():
			drills.on_ball_down()
			return
		if outgoing and ball.position.z < 0 and ball.position.z >= -court_half_depth and absf(ball.position.x) <= court_half_width:
			returns += 1
			_finish("IN! Clean return across the Net. Next feed in 3 seconds.")
		elif outgoing and ball.position.z < 0:
			_finish("OUT. Reduce power or adjust your direction.")
		else:
			_finish("Ball down. Prepare under the flight and confirm in reach.")
	if ball.position.length() > 120:
		_finish("Out of the training area.")
	shadow.position = Vector3(ball.position.x, 0.03, ball.position.z)
	trail_points.append(ball.position)
	if trail_points.size() > 18:
		trail_points.pop_front()
	_draw_line(trail, trail_points)

func _finish(message: String) -> void:
	action_endlag = 0.0
	confirm_window = 0.0
	committed_intent = {}
	armed = false
	serve.clear()
	pepper.stop()
	moc.clear()
	ball_active = false
	feed_timer = 3.0
	_message(message)

func _message(message: String) -> void:
	feedback = message
	feedback_time = 3.0

func _draw_line(instance: MeshInstance3D, points: Array[Vector3]) -> void:
	if points.size() < 2:
		instance.mesh = null
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh

func _update_contact_preview() -> void:
	last_trajectory_preview = TrajectoryPreview.predict(self)
	preview.mesh = null if last_trajectory_preview.is_empty() else TrajectoryPreview.ribbon(last_trajectory_preview,camera.position)

func _update_preview() -> void:
	_update_contact_preview()
	var approach_points: Array[Vector3] = []
	for marker in approach_footprints:
		marker.hide()
	if jump_charge >= 0 and not generic_jump and approach_direction.length_squared() > 0.01:
		var ground := Vector3(player.position.x, 0.06, player.position.z)
		approach_points.append(ground)
		for step in range(Approach.step_index(jump_charge), 4):
			var end: float = Approach.STEP_ENDS[step]
			var distance := 0.0
			var samples := 32
			for i in range(samples):
				var progress := lerpf(jump_charge, end, (i + 0.5) / samples)
				distance += Approach.speed_scale(progress) * athlete.speed() * Approach.DURATION * (end - jump_charge) / samples
			var point := ground + approach_direction * distance
			approach_points.append(point)
			approach_footprints[step].position = point + approach_direction.cross(Vector3.UP) * Approach.foot_lateral(step)
			approach_footprints[step].rotation.y = atan2(-approach_direction.x, -approach_direction.z) + Approach.foot_turn(step)
			approach_footprints[step].show()
	_draw_line(approach_preview, approach_points)
	if ball_active:
		var h := maxf(ball.position.y - 0.1, 0.0)
		var t := (ball_velocity.y + sqrt(ball_velocity.y * ball_velocity.y + 2 * GRAVITY * h)) / GRAVITY
		landing_marker.position = Vector3(ball.position.x + ball_velocity.x * t, 0.035, ball.position.z + ball_velocity.z * t)
	landing_marker.visible = ball_active

func _update_ui() -> void:
	station_status.text = drills.hud_text() if drills.in_zone() or drills.running() else station.hud_text()
	for slot in range(8):
		bot_buttons[slot].set_pressed_no_signal(training_bots.is_enabled(slot % 4, -1 if slot >= 4 else 1))
	bot_status.text = "Next: %d / 3  ·  %d bot contacts" % [mini(side_contacts[side_index(ball.position.z)] + 1, 3), training_bots.total_contacts] if training_bots.enabled.has(true) or training_bots.away_enabled.has(true) else "Helpers off / E serve / G bots"
	action_wheel.set_action(selected, armed or charging or jumped)
	action_wheel.set_charge(charge if charging else (locked_charge if armed else 0.0))
	athlete_hud.update_values()
	camera_badge.text = ("ATHLETE VIEW" if camera_mode == ViewMode.ATHLETE else "BALL VIEW") + "   /   V switch\n" + ("Mouse look / aim   ·   Esc cursor" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Cursor free   ·   click court to play")
	if camera_mode == ViewMode.BALL:
		camera_badge.text = "BALL VIEW / AUTO TRACK   ·   V switch\nMouse: turn athlete / adjust loft\nWASD: toward / away from ball"
	if pepper.active():
		camera_badge.text += "\n" + (("PARTNER " + ACTIONS[pepper.stage]) if pepper.npc_turn else ("YOUR " + ACTIONS[pepper.required_player_action()]))
	camera_badge.text += "\n" + ("DRILL" if station.running() or drills.running() or drills.box_state == drills.State.ACTIVE else ("PEPPER" if pepper.active() else ("HOLD E / STANDING SERVE" if serve.channeling() else ("TOSS / E STRIKE" if serve.tossing() else ("RALLY" if ball_active else "EXPLORE / hold E serve · tap E toss / strike")))))
	if is_benched():
		bench.refresh_ui()
		camera_badge.text = "BENCHED / %.1fs\nV spectate / Q–R cycle Home teammates" % bench.remaining
	build_button.text = athlete.build.name + "  [TAB]"
	hp_bar.value = athlete.hp
	sta_bar.value = athlete.stamina
	info.text = "HP  %03d       STA  %03d%s" % [athlete.hp, athlete.stamina, "  " + athlete.fatigue_text() if athlete.exhausted or athlete.winded else ""]
	metrics.text = "Height %.2fm  ·  Reach %.2fm\nPOW %d   SPD %d   ACC %d   END %d\nReturns %d / %d   ·   Last %s" % [athlete.build.height, athlete.reach(), athlete.build.power, athlete.build.speed, athlete.build.accuracy, athlete.build.endurance, returns, attempts, last_quality]
	status.text = "PAUSED  /  P to resume" if paused else feedback
	var state := "HOLD LEFT MOUSE TO CHARGE → RELEASE → CLICK TO CONFIRM"
	if jump_charge >= 0:
		state = "TRAVEL JUMP / RELEASE TO LAUNCH" if generic_jump else approach_phase_name + (" / RELEASE FOR DIVE" if approach_action == 0 else " / RELEASE TO TAKE OFF")
	elif jumped:
		state = "TRAVEL JUMP" if airborne_action == -1 else Approach.STEP_NAMES[3] + (" / DIVE" if airborne_action == 0 else " / AIRBORNE")
	elif charging:
		state = "CHARGING POWER  /  release to arm"
	elif armed:
		state = "READY  /  click at contact    ·    right click cancels on ground"
	if hurtbox_root.visible and hurtbox_action == 2:
		state += " / GREEN sweet · GOLD fair · ORANGE weak · RED sour"
	if (armed or charging) and (locked_action if armed else selected) in [0, 1, 2]:
		state += " / WASD influences contact · live until impact"
	if ball_active and selected == 0:
		var demand := ReceiveCharge.match_charge(ball_shot, locked_charge if armed else charge)
		if demand.required:
			state += " / RECEIVE %d–%d%% INPUT" % [roundi(maxf(0,(demand.minimum-athlete.cushioning_bonus())/athlete.low_stamina_factor()) * 100), roundi(maxf(0,(demand.maximum-athlete.cushioning_bonus())/athlete.low_stamina_factor()) * 100)]
	charge_label.text = "%s   /   %s%s" % [ACTIONS[selected], state, "   ·   AIRBORNE AIM LOCKED" if jumped else ""]

func _reset() -> void:
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
	ball_camera_offset_ready = false
	ball_movement_yaw = 0.0
	receive_posture = "planted"
	receive_pose_remaining = 0
	receive_pose_contact = Vector3.ZERO
	if is_instance_valid(moc):
		moc.clear()
	directional_input.clear()
	last_directional_influence = {}
	committed_intent = {}
	last_contact_result = {}
	gait_cycle = 0.0
	roll_lock = 0.0
	dive_recovery_time = -1.0
	floor_recovery_time = -1.0
	floor_slide_decel = 0.0
	dive_launched = false
	quick_step_time = 0.0
	quick_step_cooldown = 0.0
	tap_times.clear()
	generic_jump = false
	athlete.hp = 100
	athlete.stamina = athlete.max_stamina()
	athlete.reset_fatigue()
	player.position = start_position
	player.velocity = Vector3.ZERO
	camera_anchor_ready = false
	camera_transition = 0.0
	view_yaw = 0.0
	facing_yaw = 0.0
	view_pitch = -0.12
	ball_orbit = 0.0
	ball.position = Vector3(0, 0.105, -6)
	ball_active = false
	ball_shot = {}
	last_receive_match = {}
	charging = false
	armed = false
	jumped = false
	jump_charge = -1
	approach_action = -1
	approach_plant_speed = 0.0
	approach_bound = false
	approach_bound_started = false
	approach_release_pending = false
	approach_direction = Vector3.ZERO
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
	_resize_court()
	_message("Explore freely / E toss → E strike / serve into purple Pepper circles / K debug boxes")

func _cycle_build() -> void:
	build_index = (build_index + 1) % Athlete.BUILDS.size()
	athlete.build = Athlete.BUILDS[build_index].duplicate()
	position_role = str(athlete.build.name).get_slice("/", 1).strip_edges()
	_rebuild_visual()
	_reset()

# --- Dive floor recovery -------------------------------------------------------------------
func dive_input_locked() -> bool:
	return dive_recovery_time >= 0.0 and dive_recovery_time < DiveRecovery.lock_seconds(dive_quality_value)

# How far the hips have turned toward a backward dive at this moment, in radians. The upper body turns ahead of
# them (dive_turn_spine, dive_turn_neck in degrees), so the torso leads and the hips and feet follow.
func _dive_turn_offset() -> float:
	var prepping := not jumped and jump_charge >= 0.0 and approach_action == 0
	var airborne := jumped and airborne_action == 0
	dive_turn_spine = 0.0
	dive_turn_neck = 0.0
	if not (prepping or airborne or dive_recovery_time >= 0.0):
		dive_turn_total = 0.0
		return 0.0
	if dive_recovery_time >= 0.0 and not prepping and not airborne:
		return dive_turn_total * (1.0 - DiveRecovery.facing_release(dive_recovery_time, dive_quality_value))
	var phase := 0.0
	if prepping:
		var dir := approach_direction if approach_direction.length_squared() > 0.01 else Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
		dive_turn_total = _dive_turn_for(dir, dive_base_yaw)
		phase = DiveStage.phase_for(jump_charge, 0.0, dive_flight_time, false)
	else:
		phase = DiveStage.phase_for(jump_charge, dive_air_time, dive_flight_time, true)
	var hips := dive_turn_total * smoothstep(-0.52, -0.08, phase)
	var upper := dive_turn_total * smoothstep(-0.64, -0.30, phase)
	var lead := rad_to_deg(upper - hips)
	dive_turn_spine = clampf(lead, -55.0, 55.0)
	dive_turn_neck = clampf(lead - dive_turn_spine, -70.0, 70.0)
	return hips

# The turn pivots on the trailing foot: the body rotates about that foot, so it stays where it was put.
func _pivot_dive_turn() -> void:
	body.position.x = 0.0
	body.position.z = 0.0
	if absf(dive_applied_yaw) < 0.0001 or dive_turn_total == 0.0:
		return
	var foot := Basis(Vector3.UP, dive_base_yaw) * Vector3((visual_hip_x if dive_turn_total < 0.0 else -visual_hip_x) * body.scale.x, 0.0, 0.0)
	var shift := foot - Basis(Vector3.UP, dive_applied_yaw) * foot
	body.position.x = shift.x
	body.position.z = shift.z

# The foot a backward dive pivots on, as DiveStage names its trailing foot (1 right, 0 left); -1 when nothing turns.
func _dive_pivot_foot() -> int:
	if absf(dive_turn_total) < 0.01:
		return -1
	return 1 if dive_turn_total < 0.0 else 0

# The turn a dive toward `dir` needs from facing `base_yaw`: none to the front or side, all of it behind.
func _dive_turn_for(dir: Vector3, base_yaw: float) -> float:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return 0.0
	var ahead := DiveStage.local_direction(dir, base_yaw).y
	var weight := smoothstep(-0.15, -0.55, ahead)
	if weight <= 0.0:
		return 0.0
	var delta := wrapf(atan2(-dir.x, -dir.z) - base_yaw, -PI, PI)
	if absf(delta) > PI - 0.05:
		delta = -PI if dominant_hand == "Right" else PI
	return delta * weight

func _begin_dive_recovery() -> void:
	if not dive_launched:
		return
	dive_launched = false
	if roll_lock > 0.0:
		return
	dive_recovery_dir = DiveStage.local_direction(dive_world_direction, body.rotation.y)
	dive_recovery_root = Vector2(body.rotation.x, body.rotation.z)
	dive_recovery_flat = PoseLibrary.read_rig(body)
	dive_recovery_time = 0.0
	var slide: Dictionary = DiveRecovery.plan().slide_metres
	var metres := lerpf(float(slide.forward), float(slide.lateral), absf(dive_recovery_dir.x)) * lerpf(0.75, 1.15, dive_quality_value)
	metres = maxf(metres, float(slide.floor))
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	dive_slide_decel = speed * speed / (2.0 * metres)

func _tick_dive_recovery(dt: float) -> void:
	dt *= athlete.transition_rate()*athlete.recovery_rate()
	if dive_recovery_time < 0.0:
		return
	# Starting any new action ends the recovery where it is.
	if jumped or jump_charge >= 0.0 or approach_bound:
		_end_dive_recovery()
		return
	var step := dt
	if not dive_input_locked() and (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D)):
		step *= 1.6
	dive_recovery_time += step
	if dive_recovery_time >= DiveRecovery.duration(dive_quality_value):
		_end_dive_recovery()

func _end_dive_recovery() -> void:
	dive_recovery_time = -1.0
	dive_slide_decel = 0.0

func _apply_dive_recovery() -> void:
	var state := DiveRecovery.at(dive_recovery_time, dive_recovery_dir, dive_quality_value, dive_recovery_root, dive_recovery_flat)
	DiveRecovery.apply(body, state)

# --- Floor recovery after a poorly handled receive ------------------------------------------------
# Codex's receive_resolved event is authoritative for which recovery, its DI penalty and the contact side.
# Not for dives (they have their own floor recovery), jumps or rolling receives.
func _on_receive_resolved(event: Dictionary) -> void:
	if String(event.get("actor", "")) != "player":
		return
	var recovery := FloorRecovery.resolve(String(event.get("recovery", "")))
	if recovery.is_empty() or not FloorRecovery.names().has(recovery):
		return
	if jumped or dive_launched or dive_recovery_time >= 0.0 or roll_lock > 0.0 or floor_recovery_time >= 0.0:
		return
	var outcome: Dictionary = event.get("receive_outcome", {})
	var coord: Vector3 = outcome.get("platform_coord", Vector3.ZERO)
	floor_recovery_name = recovery
	floor_recovery_side = FloorRecovery.side_of(coord.x, dominant_hand)
	floor_recovery_scale = clampf(float(outcome.get("penalty_factor", 1.0)), 0.65, 1.35)
	floor_recovery_root = Vector2(body.rotation.x, body.rotation.z)
	floor_recovery_flat = PoseLibrary.read_rig(body)
	floor_recovery_time = 0.0
	var total := _floor_recovery_total()
	# Input comes back at the rise (the penalty budget for a shrug, whose gameplay budget is shorter than its animation).
	floor_recovery_lock = float(event.get("recovery_penalty_seconds", total)) if recovery == "shrug" else FloorRecovery.lock_seconds(recovery) * floor_recovery_scale
	var plan := FloorRecovery.plan(recovery)
	var forward := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	var right := Vector3(cos(facing_yaw), 0, -sin(facing_yaw))
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
	player.velocity.x = direction.x * launch
	player.velocity.z = direction.z * launch

func _floor_recovery_total() -> float:
	return FloorRecovery.duration(floor_recovery_name) * floor_recovery_scale

func floor_input_locked() -> bool:
	return floor_recovery_time >= 0.0 and floor_recovery_time < floor_recovery_lock

func _tick_floor_recovery(dt: float) -> void:
	dt *= athlete.transition_rate()*athlete.recovery_rate()
	if floor_recovery_time < 0.0:
		return
	var step := dt
	if not floor_input_locked() and (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D)):
		step *= 1.6
	floor_recovery_time += step
	if floor_recovery_time >= _floor_recovery_total():
		floor_recovery_time = -1.0
		floor_recovery_name = ""
		floor_slide_decel = 0.0

func _apply_floor_recovery() -> void:
	var seconds := floor_recovery_time / floor_recovery_scale
	var state := FloorRecovery.at(floor_recovery_name, seconds, floor_recovery_side, floor_recovery_root, floor_recovery_flat)
	FloorRecovery.apply(body, state)
