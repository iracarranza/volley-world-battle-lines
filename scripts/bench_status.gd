extends Node3D
const Pose := preload("res://scripts/athlete_pose.gd")
const DURATION := 5.0
const RETURN_SECONDS := 1.0
const HOME := Vector3(0, 0.03, 48)
const EXIT := Vector3(0, 0.03, 46.5)
const SEAT_HEIGHT := 0.55
var lab: Node3D
var active := false
var remaining := 0.0
var flight_age := 0.0
var origin := Vector3.ZERO
var spectator := -1
var saved_layer := 0
var saved_mask := 0
var panel: PanelContainer
var caption: Label
var watch: Button
var previous: Button
var next: Button

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	lab.world_builder.box(self, Vector3(3.4,0.16,0.9), HOME + Vector3(0,SEAT_HEIGHT - 0.08,0), Color("a78653"))
	lab.world_builder.box(self, Vector3(3.4,0.7,0.12), HOME + Vector3(0,0.95,0.44), Color("a78653"))
	for x in [-1.3,1.3]:
		for z in [-0.30,0.30]:
			lab.world_builder.box(self, Vector3(0.13,0.47,0.13), HOME + Vector3(x,0.235,z), Color("526575"))
	lab.world_builder.world_label("HOME BENCH", HOME + Vector3(0,2.2,0.8), 32, Color("f4cf75"))
	panel = PanelContainer.new()
	lab.hud.ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = 235
	panel.offset_bottom = 355
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	caption = lab.hud.label("",18,Color("f4cf75"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(caption)
	watch = lab.hud.button("WATCH HOME TEAM [V]", toggle_spectate)
	stack.add_child(watch)
	var row := HBoxContainer.new()
	stack.add_child(row)
	previous = lab.hud.button("PREVIOUS [Q]", func(): cycle(-1))
	next = lab.hud.button("NEXT [R]", func(): cycle(1))
	row.add_child(previous)
	row.add_child(next)
	panel.hide()

func teammates() -> Array[int]:
	var result: Array[int] = []
	for slot in range(lab.training_bots.actors.size()):
		if lab.training_bots.settings[slot].enabled and not lab.training_bots.slot_away(slot):
			result.append(slot)
	return result

func enter() -> void:
	if active:
		return
	active = true
	remaining = DURATION
	flight_age = 0
	origin = lab.player.position
	spectator = -1
	saved_layer = lab.player.collision_layer
	saved_mask = lab.player.collision_mask
	lab.player.collision_layer = 0
	lab.player.collision_mask = 0
	lab.player.velocity = Vector3.ZERO
	lab.armed = false
	lab.charging = false
	lab.confirm_window = 0
	lab.confirm_duration = 0
	lab.committed_intent = {}
	lab.contact_memory.fill(0.0)
	lab.directional_input.clear()
	lab.motion.jump_charge = -1
	lab.motion.jumped = false
	lab.motion.airborne_action = -1
	lab.motion.generic_jump = false
	lab.motion.approach_bound = false
	lab.motion.approach_release_pending = false
	lab.motion.quick_step_time = 0
	lab.animation.roll_lock = 0
	lab.animation.dive_recovery_time = -1
	lab.animation.dive_launched = false
	lab.animation.receive_pose_remaining = 0
	lab.rescue_swing_remaining = 0
	lab.hurtbox_linger = 0
	lab.hurtbox_root.hide()
	lab.preview.mesh = null
	lab.landing_marker.hide()
	lab.aim_marker.hide()
	lab.reach_ring.hide()
	lab.serve.clear()
	lab.moc.clear()
	if lab.pepper.active():
		lab.pepper.stop()
		lab.ball_active = false
	lab.camera_rig.camera_anchor_ready = false
	lab._message("BENCHED / Exhausted in live play / returning to Home Base")
	refresh_ui()

func tick(dt: float) -> void:
	if not active:
		return
	var step := minf(maxf(dt,0),remaining)
	remaining = maxf(0,remaining-step)
	flight_age += step
	lab.athlete.recover(step,true)
	var progress := clampf(flight_age / RETURN_SECONDS,0,1)
	lab.player.position = origin.lerp(HOME, smoothstep(0,1,progress)) + Vector3.UP * sin(progress*PI) * 6.0
	lab.player.velocity = Vector3.ZERO
	if remaining <= 0.000001:
		clear()
		lab.player.position = EXIT
		lab.camera_rig.facing_yaw = 0
		lab.camera_rig.view_yaw = 0
		lab.camera_rig.camera_anchor_ready = false
		lab._message("Off the Bench / back at Home Base")
	refresh_ui()

func clear() -> void:
	if active:
		lab.player.collision_layer = saved_layer
		lab.player.collision_mask = saved_mask
		lab.body.rotation = Vector3.ZERO
		lab.body.position = Vector3.ZERO
		lab.body.get_node("Torso").rotation = Vector3.ZERO
		lab.body.get_node("Head").rotation = Vector3.ZERO
		Pose.base(lab.body,0,0,0,false)
		Pose.ground_feet(lab.body)
	active = false
	remaining = 0
	spectator = -1
	if is_instance_valid(panel):
		panel.hide()

func toggle_spectate() -> void:
	if not active:
		return
	if spectator >= 0:
		spectator = -1
	else:
		var choices := teammates()
		if not choices.is_empty():
			spectator = choices[0]
	refresh_ui()

func cycle(direction: int) -> void:
	if not active:
		return
	var choices := teammates()
	if choices.is_empty():
		spectator = -1
	else:
		var index := choices.find(spectator)
		spectator = choices[(0 if direction > 0 else choices.size()-1)] if index < 0 else choices[posmod(index + direction, choices.size())]
	refresh_ui()

func refresh_ui() -> void:
	panel.visible = active
	if not active:
		return
	var choices := teammates()
	if spectator >= 0 and not spectator in choices:
		spectator = choices[0] if not choices.is_empty() else -1
	var target: String = " / WATCHING HOME " + lab.ACTIONS[spectator] if spectator >= 0 else (" / RETURNING HOME" if flight_age < RETURN_SECONDS else " / SEATED AT HOME")
	caption.text = "BENCHED %.1fs%s" % [remaining,target]
	watch.text = "BACK TO BENCH [V]" if spectator >= 0 else ("WATCH HOME TEAM [V]" if not choices.is_empty() else "NO ACTIVE HOME TEAMMATES")
	watch.disabled = choices.is_empty()
	previous.disabled = choices.size() < 2
	next.disabled = choices.size() < 2

func apply_pose() -> void:
	var body: Node3D = lab.body
	Pose.base(body,0,0,0,false)
	body.scale = Vector3.ONE * float(lab.athlete.build.height) / lab.visual_rig_height
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	lab.animation.dive_applied_yaw = 0
	var seated := flight_age >= RETURN_SECONDS
	for leg in lab.legs:
		leg.rotation = Vector3(PI*0.5 if seated else 0.25,0,0)
		leg.get_node("Knee").rotation = Vector3(-PI*0.5 if seated else -0.45,0,0)
	for arm in lab.arms:
		arm.rotation = Vector3(0.55 if seated else 2.1,0,0)
		arm.get_node("Elbow").rotation = Vector3(0.6,0,0)
	if seated:
		body.position.y = SEAT_HEIGHT - lab.legs[0].position.y * body.scale.y
		body.get_node("Torso").rotation.x = 0.15
		body.get_node("Head").rotation.x = 0.15
	else:
		var heading: Vector3 = HOME-origin
		body.rotation.y = atan2(-heading.x,-heading.z)
		body.rotation.x = -0.2

func update_camera(dt: float) -> void:
	refresh_ui()
	var target: Vector3 = lab.player.position + Vector3.UP * float(lab.athlete.build.height)*0.55
	var offset := Vector3(4,2.6,-6)
	if spectator >= 0:
		var actor: Node3D = lab.training_bots.actors[spectator]
		target = actor.position + Vector3.UP*1.15
		offset = Vector3(0,2.8,5.5).rotated(Vector3.UP,actor.rotation.y)
	lab.camera.position = lab.camera.position.lerp(target+offset,1-exp(-dt*12))
	lab.camera.look_at(target)
