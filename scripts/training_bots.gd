extends Node3D
const AttackTarget := preload("res://scripts/bot_attack_target.gd")
const BotSettings := preload("res://scripts/bot_settings.gd")
var settings: Array[BotSettings] = []

func _init() -> void:
	for slot in range(8):
		var config := BotSettings.new()
		config.contact_order = (slot % 4 + 1) % 4
		settings.append(config)

const ContactRequest := preload("res://scripts/contact/contact_request.gd")
const ContactResolver := preload("res://scripts/contact/contact_resolver.gd")

# Camera-test helpers with independent contact assignments and tracking/static modes.
# Real ball physics continues between all contacts.
const ReceiveCharge := preload("res://scripts/receive_charge.gd")
const Preparation := preload("res://scripts/bot_preparation.gd")
var preparation := Preparation.new()
var charge_random := RandomNumberGenerator.new()
var last_preparation: Dictionary = {}
var last_receive_match: Dictionary = {}

const Execution := preload("res://scripts/contact_execution.gd")
const Influence := preload("res://scripts/directional_influence.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Store := preload("res://scripts/athlete_store.gd")
const BotAnimation :=  preload("res://scripts/bot_animation.gd")
var animation := BotAnimation.new()
const Motion := preload("res://scripts/bot_motion.gd")
var motion := Motion.new()
var dives := preload("res://scripts/bot_receive_dive.gd").new()
var rigs: Array[Dictionary] = []
var incoming_action := -1
var physique := Athlete.new()
const Vitals := preload("res://scripts/bot_vitals.gd")
var athletes: Array[LabAthlete] = []
var shapes: Array[Dictionary] = []
var random := RandomNumberGenerator.new()
var aim_random := RandomNumberGenerator.new()
var last_aim: Dictionary = {}
const NAMES := ["RECEIVE", "SET", "ATTACK", "BLOCK"]
const HEIGHTS := [1.0, 2.25, 3.8, 3.15]
const COLORS := [Color("74dacd"), Color("ac9df2"), Color("ffb46e"), Color("8bbdf4")]
var lab: Node3D
var actors: Array[Node3D] = []
var captions: Array[Label3D] = []
var contact_boxes: Array[MeshInstance3D] = []
var move_targets: Dictionary = {}
var attack_targets: Dictionary = {}
const ReturnController := preload("res://scripts/bot_return.gd")
var returns := ReturnController.new()
# Set after the ball comes off the net: receivers may then take a ball that drops right at the tape, and plans made on the pre-net flight are dropped.
var net_rebound := false
var active_slot := -1
var active_action := -1
var intercept := Vector3.ZERO
var remaining := 0.0
var total_contacts := 0
var last_action := -1
var last_was_block := false
# Ground destination is captured once when enabling the setter.
var set_target_locked := false
var set_target := Vector3(0, 3.8, 1.7)

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	physique.build.height = Store.DEFAULT_INCHES * 0.0254
	physique.build.span = 1.90
	random.randomize()
	aim_random.randomize()
	charge_random.randomize()
	for slot in range(settings.size()):
		athletes.append(Vitals.create(physique))
		var action := slot_action(slot)
		var actor := Node3D.new()
		add_child(actor)
		actors.append(actor)
		var rig := Visual.build(lab, actor, "Feli", {"palette_index": 0, "marking": "none"}, physique.build)
		rigs.append(rig)
		var scale: float = physique.build.height / rig.rig_height
		var shape := Geometry.definition(action, physique.build.height, physique.reach(), false, 1.0, rig.arms[1].position.y * scale, absf(rig.arms[1].position.x) * scale, physique.ball_control(), Geometry.arm_length(rig.arms[1], scale),physique.build)
		if action == 0:
			shape["platform_quality"] = physique.trait_effect("platform_quality")
		shapes.append(shape)
		var contact_box := MeshInstance3D.new()
		actor.add_child(contact_box)
		contact_box.position = shape.center
		if shape.shape == "sector":
			contact_box.mesh = Geometry.zone_mesh(shape)
		elif shape.shape == "set_sector":
			contact_box.mesh = Geometry.SetHurtbox.mesh(shape)
			var wire := MeshInstance3D.new()
			wire.mesh = Geometry.SetHurtbox.mesh(shape, true)
			contact_box.add_child(wire)
			wire.material_override = lab.world_builder.debug_material(Color.WHITE, 1.0)
			wire.material_override.vertex_color_use_as_albedo = true
		elif shape.get("receive_platform", false):
			contact_box.mesh = Geometry.ReceivePlatform.mesh(shape)
		elif shape.shape == "block_triangle":
			contact_box.mesh = Geometry.block_mesh(shape)
		elif shape.shape == "ellipsoid":
			var mesh := SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 2.0
			contact_box.mesh = mesh
			contact_box.scale = shape.size * 0.5
		else:
			var mesh := BoxMesh.new()
			mesh.size = shape.size
			contact_box.mesh = mesh
		var material: StandardMaterial3D = lab.world_builder.debug_material(COLORS[action], 0.18)
		if action in [0, 1, 2, 3]:
			material.vertex_color_use_as_albedo = true
			material.albedo_color = Color.WHITE
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		contact_box.material_override = material
		contact_boxes.append(contact_box)
		var caption := Label3D.new()
		caption.text = ("HOME " if not slot_away(slot) else "AWAY ") + NAMES[action]
		caption.font_size = 32
		caption.pixel_size = 0.006
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.modulate = COLORS[action]
		actor.add_child(caption)
		captions.append(caption)
		actor.position = spawn_position(slot)
		settings[slot].fixed_position = actor.position
		actor.rotation.y = PI if slot_away(slot) else 0.0
		actor.visible = false

func responsible_for(slot: int,contact: int,action: int) -> bool:
	return settings[slot].contact_order == 0 or settings[slot].contact_order == contact

func idle_return_enabled(slot: int) -> bool:
	return settings[slot].moves

func return_after_contact(slot: int) -> void:
	move_targets.erase(slot)
	returns.request(slot)

func on_rally_end() -> void:
	dives.clear()
	animation.reset()
	active_action = -1
	active_slot = -1
	preparation.reset()
	motion.plans.clear()
	move_targets.clear()
	returns.begin(self)

func ready_to_serve() -> bool:
	return returns.net_clear(self)

func spawn_at_player() -> void:
	lab._message("Open bot settings to summon a generic bot")

func _capture_receive_target() -> void:
	pass

func slot_action(slot: int) -> int:
	return slot % 4

func slot_away(slot: int) -> bool:
	return slot >= 4

func slot_enabled(slot: int) -> bool:
	return settings[slot].enabled and not (slot_action(slot) == 3 and not slot_away(slot))

func slot_for(action: int,z: float) -> int:
	return action+(4 if z < 0 else 0)

func spawn_position(slot: int) -> Vector3:
	return Vector3(lab.court_center.x-3.0+slot_action(slot)*2.0,0,-5 if slot_away(slot) else 5)

func is_enabled(action: int, z: float) -> bool:
	return settings[(action) + 4].enabled if z < 0 else (settings[action].enabled and action != 3)

# Whether any helper is playing on this side of the net (0 home, 1 away): the player is then not the only one on their court.
func has_teammates(side: int) -> bool:
	for slot in range(side * 4, side * 4 + 4):
		if is_enabled(slot_action(slot), -1 if side == 1 else 1):
			return true
	return false

func ensure_receiver(home: bool = false) -> void:
	if not is_enabled(0,1 if home else -1):
		toggle(0,not home)

func toggle(action: int, away: bool = false) -> void:
	if action == 3 and not away:
		return
	var config := settings[action + (4 if away else 0)]
	config.enabled = not config.enabled
	actors[action + (4 if away else 0)].visible = config.enabled
	if action == 1 and config.enabled and not set_target_locked and not away:
		_capture_set_target()
	lab._resize_court()
	replan()

func toggle_all() -> void:
	var turn_on := not (settings[0].enabled and settings[1].enabled and settings[2].enabled and all_enabled(true))
	if turn_on and not settings[1].enabled and not set_target_locked:
		_capture_set_target()
	for action in range(4):
		settings[action].enabled = turn_on and action != 3
		settings[(action) + 4].enabled = turn_on
		actors[action].visible = settings[action].enabled
		actors[action + 4].visible = turn_on
	lab._resize_court()
	replan()

func _capture_set_target() -> void:
	set_target_locked = true
	set_target = Vector3(clampf(lab.player.position.x, lab.court_center.x-lab.court_half_width+0.3, lab.court_center.x+lab.court_half_width-0.3), 3.8, clampf(absf(lab.player.position.z), 0.6, 8.5))
	lab._message("SET BOT target locked to your position / F6 to retarget")

func reset() -> void:
	dives.clear()
	block_states.clear()
	refresh_for_rally()
	returns.clear()
	net_rebound = false
	preparation.reset()
	active_action = -1
	active_slot = -1
	motion.plans.clear()
	animation.reset()
	move_targets.clear()
	incoming_action = -1
	total_contacts = 0
	last_action = -1
	last_was_block = false
	for slot in range(settings.size()):
		var action := slot_action(slot)
		actors[slot].position = spawn_position(slot) if settings[slot].follows_ball else settings[slot].fixed_position
		captions[slot].text = ("HOME " if not slot_away(slot) else "AWAY ") + NAMES[action]
		captions[slot].position.y = 2.15
		contact_boxes[slot].position = contact_shape(slot).center
		contact_boxes[slot].scale = contact_shape(slot).get("geometry_scale",Vector3.ONE)
		Motion.Pose.base(rigs[slot].body, 0, 0, 0, false)
		Motion.Pose.ground_feet(rigs[slot].body)

func replan(skip_block: bool = false) -> void:
	active_action = -1
	active_slot = -1
	move_targets.clear()
	if (is_instance_valid(lab.serve) and lab.serve.tossing()) or (is_instance_valid(lab.pepper) and lab.pepper.active()):
		return
	if not lab.ball_active or (is_instance_valid(lab.station) and lab.station.running()) or (is_instance_valid(lab.drills) and lab.drills.running()):
		return
	var origin: Vector3 = lab.ball.position
	var velocity: Vector3 = lab.ball_velocity
	var gravity: float = lab.GRAVITY
	# Optional block is an incoming near-Net interception before the first
	# ordinary contact. It does not replace a missing setter or attacker.
	var blocker := slot_for(3,velocity.z)
	if not skip_block and incoming_action == 2 and blocker >= 0 and slot_enabled(blocker) and settings[blocker].contact_order in [0,1] and not last_was_block and absf(velocity.z) > 0.01 and origin.z*velocity.z < 0:
		var receiving_sign := signf(velocity.z)
		var block_time := (receiving_sign*0.25-origin.z)/velocity.z
		if block_time > 0.025 and block_time < 3.0:
			var block_point := origin+velocity*block_time+Vector3.DOWN*gravity*block_time*block_time*0.5
			if absf(block_point.x-lab.court_center.x) <= lab.court_half_width and block_point.y >= lab.net_height and block_point.y <= contact_anchor(blocker).y+_jump_ceiling(blocker)+0.25 and (settings[blocker].follows_ball or _static_intercept(blocker,origin,velocity,gravity)>0):
				var t := block_time if settings[blocker].follows_ball else _static_intercept(blocker,origin,velocity,gravity)
				_plan(3,origin+velocity*t+Vector3.DOWN*gravity*t*t*0.5,t,blocker)
				return

	var best_time := 6.0
	var best_action := -1
	var best_slot := -1
	var best_point := Vector3.ZERO
	var best_distance := INF
	for slot in range(settings.size()):
		var action := slot_action(slot)
		if dives.busy(slot): continue
		if action == 3 or not slot_enabled(slot):
			continue
		var time := -1.0
		if settings[slot].follows_ball:
			var contact_height: float = HEIGHTS[action]
			if action == 1 and settings[slot].moves:
				var apex := origin.y + maxf(velocity.y, 0) * maxf(velocity.y, 0) / (2 * gravity)
				contact_height = clampf(apex - 0.08, contact_anchor(slot).y + 0.25, contact_anchor(slot).y + minf(0.9, _jump_ceiling(slot)))
			var discriminant: float = velocity.y * velocity.y + 2.0 * gravity * (origin.y - contact_height)
			if discriminant >= 0:
				time = (velocity.y + sqrt(discriminant)) / gravity
		else:
			time = _static_intercept(slot, origin, velocity, gravity)
		if time < 0.025 or time > 5.0 or time > best_time+0.00001:
			continue
		var point := origin + velocity * time + Vector3.DOWN * gravity * time * time * 0.5
		if (point.z < 0) != (slot_away(slot)):
			continue
		var side: int = lab.side_index(point.z)
		var count: int = lab.side_contacts[side] if lab.side_index(origin.z) == side else 0
		if count >= 3 or (settings[slot].contact_order != 0 and settings[slot].contact_order != count + 1):
			continue
		if absf(point.x-lab.court_center.x) > maxf(5.5,lab.court_half_width+1.0) or absf(point.z) > maxf(10.0,lab.court_half_depth+1.0) or absf(point.z) < (0.12 if net_rebound else 0.35):
			continue
		var distance := actors[slot].position.distance_squared_to(point)
		if is_equal_approx(time,best_time) and distance >= best_distance: continue
		best_distance = distance
		best_time = time
		best_action = action
		best_slot = slot
		best_point = point
	if best_action >= 0:
		_plan(best_action, best_point, best_time,best_slot)
	else:
		_attempt_unreachable_jumps(origin, velocity, gravity)

# The ball has hit the net or its webbing and come off it. Whatever the helpers had planned was for the flight before the net, so drop it
# and look again at where the ball is now going. Both sides can take it: it may fall back where it came from or drop over.
func replan_after_net() -> void:
	net_rebound = true
	for slot in range(settings.size()):
		if preparation.state_for(slot).planned:
			preparation.finish(slot)
		motion.plans.erase(slot)
	replan()

func athlete_for(slot: int) -> LabAthlete:
	return athletes[slot]

func move_speed_for(slot: int) -> float:
	return settings[slot].move_speed*(0.55 if athlete_for(slot).exhausted else 1.0)

func spend_stamina(slot: int,cost: float,resolved: bool = false) -> void:
	Vitals.spend(athlete_for(slot),cost,lab.contact_flow,"training_bot_%d" % slot,resolved)

func spend_jump(slot: int) -> void:
	spend_stamina(slot,athlete_for(slot).jump_stamina_cost(),true)

func refresh_for_rally() -> void:
	for athlete in athletes: Vitals.refresh(athlete)

func _jump_ceiling(slot: int) -> float:
	return athlete_for(slot).leap(1.0,1.0,lab.contact_flow.jump_bonus("training_bot_%d"%slot) if is_instance_valid(lab.contact_flow) else 0.0)

func _attempt_unreachable_jumps(origin: Vector3, velocity: Vector3, gravity: float) -> void:
	# An invalid prediction must not leave the assigned overhead role motionless.
	# This is a physical attempt only: it never awards a touch or changes flight.
	var time := clampf(maxf(velocity.y / gravity, 0.25), 0.25, 0.65)
	var projected := origin + velocity * time + Vector3.DOWN * gravity * time * time * 0.5
	for slot in range(settings.size()):
		if slot_action(slot) not in [1,2]: continue
		var action: int = slot_action(slot)
		var away: bool = slot_away(slot)
		if not slot_enabled(slot) or motion.plans.has(slot):
			continue
		if (projected.z < 0) != away:
			continue
		var side := 1 if away else 0
		var count: int = lab.side_contacts[side] if lab.side_index(origin.z) == side else 0
		if count >= 3 or (settings[slot].contact_order != 0 and settings[slot].contact_order != count + 1):
			continue
		var target: Vector3 = settings[slot].fixed_position if not settings[slot].follows_ball else projected - contact_anchor(slot).rotated(Vector3.UP, actors[slot].rotation.y)
		target.x = clampf(target.x, lab.court_center.x-lab.court_half_width-1, lab.court_center.x+lab.court_half_width+1)
		target.z = clampf(absf(target.z), 0.5, 10.0) * (-1.0 if away else 1.0)
		target.y = clampf(projected.y - contact_anchor(slot).y, 0.30, _jump_ceiling(slot))
		motion.begin(slot, actors[slot], target, time, settings[slot].follows_ball, gravity, move_speed_for(slot) if settings[slot].moves else -1.0,NAN,athlete_for(slot).explosiveness_rate(),action)
		spend_jump(slot)
		if is_instance_valid(lab.contact_flow):
			lab.contact_flow.consume_jump("training_bot_%d"%slot)
		motion.plans[slot]["fallback"] = true
		if active_action < 0:
			active_action = action
			active_slot = slot
			intercept = projected
			remaining = time
			if action == 2: lab.contact_flow.on_attack_charge("training_bot_%d"%slot)
			preparation.begin(slot, action, lab.ball_shot, time, settings[slot].charge_accuracy, charge_random,athlete_for(slot).cushioning_bonus(),athlete_for(slot).low_stamina_factor(),intended_charge_for(slot))

func set_contact_order(slot: int, order: int) -> void:
	settings[slot].contact_order = clampi(order, 0, 3)
	replan()

func set_following(slot: int, follow: bool) -> void:
	settings[slot].fixed_position = actors[slot].position
	settings[slot].follows_ball = follow
	settings[slot].moves = false
	contact_boxes[slot].position = contact_shape(slot).center
	contact_boxes[slot].scale = contact_shape(slot).get("geometry_scale",Vector3.ONE)
	replan()

func set_mode(slot: int, mode: int) -> void:
	settings[slot].fixed_position = actors[slot].position
	settings[slot].follows_ball = mode != 1
	settings[slot].moves = mode == 2
	replan()

func set_move_speed(slot: int, value: float) -> void:
	settings[slot].move_speed = clampf(value, 0, 12)
	if motion.plans.has(slot) and settings[slot].moves:
		motion.plans[slot]["move_speed"] = settings[slot].move_speed

func setter_direction(slot: int, origin: Vector3) -> Vector3:
	var setter_slot := slot_for(1,-1 if slot_away(slot) else 1)
	if not is_enabled(1, -1 if slot_away(slot) else 1):
		return Vector3.ZERO
	var direction := actors[setter_slot].position - origin
	direction.y = 0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD.rotated(Vector3.UP, actors[slot].rotation.y)

func place_at_player(slot: int) -> void:
	settings[slot].fixed_position = Vector3(clampf(lab.player.position.x, lab.court_center.x-lab.court_half_width-1, lab.court_center.x+lab.court_half_width+1), 0, clampf(absf(lab.player.position.z), 0.5, 10.0) * (-1 if slot_away(slot) else 1))
	actors[slot].position = settings[slot].fixed_position
	# Only the spot changes: a follow, move or static helper stays what it was. A move helper comes back here after its contacts.
	contact_boxes[slot].position = contact_shape(slot).center
	contact_boxes[slot].scale = contact_shape(slot).get("geometry_scale",Vector3.ONE)
	replan()

# Use the same narrow-phase geometry as player contacts, including the forward
# receive fan and dominant-arm sector. Small spatial steps avoid fast-ball tunneling.
func _static_intercept(slot: int, origin: Vector3, velocity: Vector3, gravity: float) -> float:
	var step := clampf(0.025 / maxf(velocity.length() + gravity * 5.0, 1.0), 0.0005, 0.01)
	var time := 0.35 if slot_action(slot) == 2 else (0.12 if slot_action(slot) == 3 else 0.025)
	var frame := Basis(Vector3.UP,-actors[slot].rotation.y)
	var fixed := settings[slot].fixed_position
	var overhead := slot_action(slot) in [2,3]
	var max_jump := _jump_ceiling(slot)*(1.2 if slot_action(slot) == 2 else 1.0) if overhead else 0.0
	var anchor_height := contact_anchor(slot).y
	while time <= 5.0:
		var point := origin + velocity * time + Vector3.DOWN * gravity * time * time * 0.5
		if point.y < -0.2:
			break
		var local := frame*(point-fixed)
		if overhead:
			local.y -= clampf(point.y-anchor_height,0,max_jump)
		if Geometry.contains(contact_shape(slot), local):
			return time
		time += step
	return -1.0

func contains_ball(slot: int, point: Vector3) -> bool:
	return Geometry.contains(contact_shape(slot), (point - actors[slot].position).rotated(Vector3.UP, -actors[slot].rotation.y))

func contact_anchor(slot: int) -> Vector3:
	var shape := contact_shape(slot)
	if slot_action(slot) == 3 and shape.has("sweet_center"): return shape.sweet_center
	if slot_action(slot) == 1:
		return Vector3(shape.center) + Vector3.UP * (float(shape.radius) * 0.55)
	if slot_action(slot) == 2:
		return Vector3(shape.center) + Geometry.sector_point(shape, 0.74, 67.5, 0.0)
	return Vector3(shape.center) + (Vector3.RIGHT * float(shape.hand_x) if slot_action(slot) == 3 else Vector3.ZERO)

func intended_charge_for(slot: int) -> float:
	return -1.0 if settings[slot].auto_intended_charge else settings[slot].intended_charge

func set_intended_charge(slot: int,auto: bool,value: float) -> void:
	settings[slot].auto_intended_charge = auto
	settings[slot].intended_charge = clampf(value,0,1)
	replan()

func set_charge_accuracy(slot: int, value: float) -> void:
	settings[slot].charge_accuracy = clampf(value, 0, 100)

func set_aiming_accuracy(slot: int, value: float) -> void:
	settings[slot].aiming_accuracy = clampf(value, 0, 100)

func set_tracking_accuracy(slot: int, value: float) -> void:
	settings[slot].tracking_accuracy = clampf(value, 0, 100)
	replan()

func _plan(action: int, point: Vector3, time: float, chosen_slot: int = -1) -> void:
	active_action = action
	intercept = point
	remaining = time
	var slot := chosen_slot if chosen_slot >= 0 else slot_for(action,point.z)
	if slot < 0: return
	active_slot = slot
	returns.release(slot)
	if action == 2: lab.contact_flow.on_attack_charge("training_bot_%d"%slot)
	if action == 0:
		var toward_setter := setter_direction(slot, actors[slot].position)
		if toward_setter.length_squared() > 0:
			actors[slot].rotation.y = atan2(-toward_setter.x, -toward_setter.z)
	var aim_yaw: float = actors[slot].rotation.y
	var dive := dives.offer(self,slot,point,time,aim_yaw) if action == 0 else {}
	if not dive.is_empty():
		point = dive.point
		time = dive.time
		intercept = point
		remaining = time
	preparation.begin(slot, action, lab.ball_shot, time, settings[slot].charge_accuracy, charge_random,athlete_for(slot).cushioning_bonus(),athlete_for(slot).low_stamina_factor(),intended_charge_for(slot))
	if action == 2:
		var current_plan: Dictionary = motion.plans.get(slot,{})
		var committed := int(current_plan.get("action",-1)) == 2 and current_plan.has("committed_yaw")
		var destination: Vector3 = attack_targets[slot] if committed and attack_targets.has(slot) else choose_attack_target(slot,point)
		attack_targets[slot] = destination
		var heading := destination - point
		aim_yaw = atan2(-heading.x, -heading.z)
	if settings[slot].follows_ball:
		var anchor := Vector3(Geometry.ReceivePlatform.definition(float(athlete_for(slot).build.height),true,0,athlete_for(slot).build).center).rotated(Vector3.UP,aim_yaw) if not dive.is_empty() else contact_anchor(slot).rotated(Vector3.UP, aim_yaw)
		var error_radius: float = 2.5 * (1.0 - settings[slot].tracking_accuracy / 100.0)
		var angle := random.randf_range(0, TAU)
		var error := Vector3(cos(angle), 0, sin(angle)) * sqrt(random.randf()) * error_radius
		var target := point - anchor + error
		target.y = maxf(0, target.y)
		if not dive.is_empty():
			dives.begin(self,slot,target,time)
		elif action in [2, 3] or (action == 1 and settings[slot].moves):
			if action in [1, 2]:
				target.y = maxf(0.25, target.y)
			target.y = minf(target.y, _jump_ceiling(slot) * (1.2 if action == 2 else 1.0))
			motion.begin(slot, actors[slot], target, time, true, lab.GRAVITY, move_speed_for(slot) if settings[slot].moves else -1.0, aim_yaw,athlete_for(slot).explosiveness_rate(),action)
			spend_jump(slot)
			if is_instance_valid(lab.contact_flow):
				lab.contact_flow.consume_jump("training_bot_%d"%slot)
		elif settings[slot].moves:
			move_targets[slot] = target
		else:
			actors[slot].position = target
	elif action in [2, 3]:
		var target := settings[slot].fixed_position
		target.y = clampf(point.y - contact_anchor(slot).y, 0.25 if action == 2 else 0.0, _jump_ceiling(slot) * (1.2 if action == 2 else 1.0))
		motion.begin(slot, actors[slot], target, time, false, lab.GRAVITY, -1.0, aim_yaw,athlete_for(slot).explosiveness_rate(),action)
		spend_jump(slot)
		if is_instance_valid(lab.contact_flow):
			lab.contact_flow.consume_jump("training_bot_%d"%slot)
	captions[slot].position.y = maxf(contact_anchor(slot).y + 0.55, 2.15)

func tick_support_motion(_dt: float,_scales: Dictionary) -> void:
	pass

const BlockState := preload("res://scripts/block_state.gd")
var block_states: Dictionary = {}
var motion_clocks: Dictionary = {}
func block_state_for(slot: int):
	if not block_states.has(slot): block_states[slot] = BlockState.new()
	return block_states[slot]
func tick_motion(dt: float) -> void:
	for slot in range(settings.size()):
		if slot_enabled(slot):
			preparation.tick(slot, dt * lab.moc.bot_scale("training_bot_%d" % slot))
	var previous_positions: Array[Vector3] = []
	for actor in actors:
		previous_positions.append(actor.position)
	var scales := {}
	for slot in range(settings.size()):
		scales[slot] = lab.moc.bot_scale("training_bot_%d" % slot)
		motion_clocks[slot] = float(motion_clocks.get(slot,0))+dt*float(scales[slot])
	returns.tick(self,dt)
	dives.tick(self,dt,scales)
	for slot in motion.plans:
		if float(motion.plans[slot].move_speed) >= 0: motion.plans[slot].move_speed = move_speed_for(slot)
	motion.tick(dt, actors, rigs, scales)
	for slot in move_targets.keys():
		var actor := actors[slot]
		var target: Vector3 = move_targets[slot]
		var ground := Vector3(target.x, actor.position.y, target.z)
		var before := actor.position
		actor.position = actor.position.move_toward(ground, move_speed_for(slot) * dt * float(scales[slot]))
		var speed := actor.position.distance_to(before) / maxf(dt*float(scales[slot]), 0.0001)
		Motion.Pose.base(rigs[slot].body, float(motion_clocks.get(slot,0)) * 8.0, speed, 0, slot_action(slot) == 0)
		Motion.Pose.ground_feet(rigs[slot].body)
	tick_support_motion(dt,scales)
	# A move helper walks back to its placed spot once it has no ball to go to: after its contact and landing, and whenever it has been pulled away.
	for slot in range(settings.size()):
		if not idle_return_enabled(slot) or returns.contains(slot) or not slot_enabled(slot) or move_targets.has(slot) or motion.plans.has(slot) or dives.busy(slot):
			continue
		if lab.ball_active and active_action == slot_action(slot) and slot == active_slot:
			continue
		var home: Vector3 = settings[slot].fixed_position
		var home_ground := Vector3(home.x, actors[slot].position.y, home.z)
		if actors[slot].position.distance_to(home_ground) < 0.03:
			continue
		var from_here := actors[slot].position
		actors[slot].position = from_here.move_toward(home_ground, move_speed_for(slot) * dt * float(scales[slot]))
		var walked := actors[slot].position.distance_to(from_here) / maxf(dt*float(scales[slot]), 0.0001)
		Motion.Pose.base(rigs[slot].body, float(motion_clocks.get(slot,0)) * 8.0, walked, 0, false)
		Motion.Pose.ground_feet(rigs[slot].body)
	for slot in range(rigs.size()):
		var profile := athlete_for(slot)
		var walked := Vector2(actors[slot].position.x-previous_positions[slot].x,actors[slot].position.z-previous_positions[slot].z).length()
		if settings[slot].enabled:
			if walked > 0.00001 and actors[slot].position.y <= 0.01: spend_stamina(slot,dt*float(scales[slot])*profile.movement_stamina_rate(),true)
			profile.recover(dt*float(scales[slot]),walked <= 0.00001 and actors[slot].position.y <= 0.01)
		var action := slot_action(slot)
		var planned := active_action == action and slot == active_slot
		var motion_plan: Dictionary = motion.plans.get(slot, {})
		var airborne := not motion_plan.is_empty() and str(motion_plan.get("phase", "")) in ["jump", "landing"]
		var blocking = block_state_for(slot)
		if action == 3 and airborne and actors[slot].position.y > 0.01:
			if not blocking.active: blocking.start()
			blocking.tick(dt*float(scales[slot]))
			if preparation.state_for(slot).phase == "confirmed": blocking.confirm(float(preparation.state_for(slot).confirmation_age))
			if blocking.latched and not Geometry.block_overlap(contact_shape(slot),(lab.ball.position-actors[slot].position).rotated(Vector3.UP,-actors[slot].rotation.y),0.06): blocking.latched = false
		elif blocking.active:
			blocking.land()
			preparation.finish(slot)
		var animation_state: Dictionary = animation.states.get(rigs[slot].body.get_instance_id(), {})
		var following_contact := float(animation_state.get("since", 100)) < 0.75
		if not actors[slot].visible and not planned and motion_plan.is_empty() and not following_contact:
			continue
		var point: Vector3 = (lab.ball.position - actors[slot].position).rotated(Vector3.UP, -actors[slot].rotation.y) if planned and lab.ball_active else contact_anchor(slot)
		var speed := Vector2(actors[slot].position.x - previous_positions[slot].x, actors[slot].position.z - previous_positions[slot].z).length() / maxf(dt*float(scales[slot]), 0.001)
		if action == 0 and not Geometry.contains(contact_shape(slot), point):
			point = contact_anchor(slot)
		var posture := Geometry.ReceivePlatform.posture(contact_shape(slot), point, speed) if action == 0 else "planted"
		var pose_context := {"action": action, "charge": float(preparation.state_for(slot).charge), "planned": planned or not motion_plan.is_empty(), "airborne": airborne, "remaining": float(motion_plan.get("contact", remaining)) - float(motion_plan.get("elapsed", 0)) if not motion_plan.is_empty() else remaining, "rise": motion_plan.get("rise", 0.4), "preserve_base": not motion_plan.is_empty(), "contact_point": point, "posture": posture, "speed": speed, "cycle": float(motion_clocks.get(slot,0)) * 8.0, "swing_yaw": motion_plan.get("swing_yaw", 0.0),"transition_rate":athlete_for(slot).transition_rate()}
		pose_context.merge(dives.context(slot))
		animation.update(rigs[slot],dt*float(scales[slot]),pose_context)
	for slot in range(actors.size()):
		var travel: Vector3 = lab.contact_flow.displacement("training_bot_%d" % slot,dt*float(scales[slot])) if is_instance_valid(lab.contact_flow) else Vector3.ZERO
		actors[slot].position += travel
		# Knockback displaces the athlete, never their saved placement.
		if motion.plans.has(slot):
			motion.plans[slot].start += travel
			motion.plans[slot].ground += travel
	for slot in range(contact_boxes.size()):
		var geometry := contact_shape(slot)
		contact_boxes[slot].position = geometry.center
		contact_boxes[slot].scale = geometry.get("geometry_scale",Vector3.ONE)
		var precision := slot_action(slot) == 3 or (active_action == slot_action(slot) and slot == active_slot and Execution.sweet_active(slot_action(slot), float(preparation.state_for(slot).confirmation_age)))
		var material: StandardMaterial3D = contact_boxes[slot].material_override
		material.vertex_color_use_as_albedo = precision
		material.albedo_color = Color.WHITE if precision else Color(0.96, 0.61, 0.41, 0.16)
		for child in contact_boxes[slot].get_children():
			if child is MeshInstance3D:
				child.material_override.vertex_color_use_as_albedo = precision
				child.material_override.albedo_color = material.albedo_color

func tick(dt: float) -> bool:
	tick_motion(dt)
	return tick_contact(dt)

var resolving_contact := false

func tick_contact(dt: float) -> bool:
	dt *= lab.moc.simulation_scale()
	if not lab.ball_active or active_action < 0:
		return false
	remaining -= dt
	var action := active_action
	var passive: bool = action == 3 and active_slot >= 0 and block_state_for(active_slot).active
	if remaining > 0 and not passive:
		return false
	if passive and block_state_for(active_slot).latched: return false
	if not passive and remaining < -Execution.CONTACT_SECONDS:
		active_action = -1
		active_slot = -1
		replan(action == 3)
		return false
	if not is_enabled(action, intercept.z):
		active_action = -1
		active_slot = -1
		if action == 3:
			replan(true)
		return false
	# A manual contact replans the intercept, so a helper never follows an old flight.
	var bot_slot := active_slot if active_slot >= 0 else slot_for(action,intercept.z)
	var prepared := preparation.state_for(bot_slot)
	if not passive and prepared.phase != "confirmed":
		return false
	if not passive and float(prepared.confirmation_age) > Execution.CONTACT_SECONDS:
		active_action = -1
		active_slot = -1
		preparation.finish(bot_slot)
		if action == 3:
			replan(true)
		return false
	if action == 3 and not Geometry.block_approaching(contact_shape(bot_slot),(lab.ball.position-actors[bot_slot].position).rotated(Vector3.UP,-actors[bot_slot].rotation.y),lab.ball_velocity.rotated(Vector3.UP,-actors[bot_slot].rotation.y)): return false
	if not contains_ball(bot_slot, lab.ball.position):
		# Test swept flight points over this simulation step, using identical geometry.
		var hit := false
		var steps := maxi(1, ceili(lab.ball_velocity.length() * dt / 0.025))
		for sample in range(steps + 1):
			var point: Vector3 = lab.ball.position - lab.ball_velocity * dt * float(sample) / steps
			if contains_ball(bot_slot, point):
				intercept = point
				hit = true
				break
		if not hit:
			# Once the ball clears the block wall, immediately give the remaining
			# flight to the receiving role. A whiff is not a team contact.
			var local: Vector3 = (lab.ball.position - actors[bot_slot].position).rotated(Vector3.UP, -actors[bot_slot].rotation.y)
			var local_velocity: Vector3 = lab.ball_velocity.rotated(Vector3.UP, -actors[bot_slot].rotation.y)
			var cleared_block: bool = action == 3 and local_velocity.z > 0 and local.z > float(contact_shape(bot_slot).center.z) + float(contact_shape(bot_slot).size.z) * 0.5 + Geometry.BALL_RADIUS
			if (not passive and remaining < -Execution.CONTACT_SECONDS) or cleared_block:
				active_action = -1
				active_slot = -1
				if action == 3:
					replan(true)
			return false
	else:
		intercept = lab.ball.position
	active_action = -1
	active_slot = -1
	var side: int = int(slot_away(bot_slot))
	var slot := bot_slot
	if action != 3 and lab.side_contacts[side] >= 3:
		lab._finish_fault("Four-contact fault / Bot #%d" % (slot+1),int(slot_away(slot)))
		return true
	if action != 3 and not responsible_for(slot,lab.side_contacts[side]+1,action):
		replan()
		return false
	if lab.block_serve_fault(action,lab.ball_shot,"Bot #%d" % (slot+1),int(slot_away(slot))): return true
	lab.ball.position = intercept
	if action != 3:
		lab.side_contacts[side] += 1
	last_was_block = action == 3
	incoming_action = action
	var incoming: Vector3 = lab.ball_velocity
	var incoming_shot: Dictionary = lab.ball_shot
	var local_contact: Vector3 = (lab.ball.position - actors[slot].position).rotated(Vector3.UP, -actors[slot].rotation.y)
	resolving_contact = true
	var request := ContactRequest.new()
	request.action = action
	request.response_seed = total_contacts + 1
	request.athlete = athlete_for(slot)
	request.actor_id = "training_bot_%d" % slot
	request.shape = contact_shape(slot)
	request.local_point = local_contact
	request.origin = lab.ball.position
	request.incoming = incoming
	request.incoming_shot = incoming_shot
	request.charge = float(prepared.locked_charge)
	if action == 3:
		var reference: float = preload("res://scripts/stat_tuning.gd").reaction_cap(request.athlete.stat("reaction_speed"))
		request.block_charge_reference = request.charge if not settings[slot].auto_intended_charge else reference*request.charge/Preparation.DEFAULT_CHARGE
	request.block_confirmation_age = block_state_for(slot).confirmation_age if passive else float(prepared.confirmation_age)
	request.confirmation_age = float(prepared.confirmation_age)
	request.facing = Vector3.FORWARD.rotated(Vector3.UP, actors[slot].rotation.y)
	request.intent_direction = request.facing
	request.movement_speed = move_speed_for(slot) if settings[slot].moves else 0.0
	request.gravity = lab.GRAVITY
	request.flow = lab.contact_flow.amount(request.actor_id)
	request.keep_attack_intent = true
	request.apply_set_spread = true
	request.spread_phase = total_contacts * 1.7 + 0.8
	request.aiming_accuracy = settings[slot].aiming_accuracy
	request.aim_random = aim_random
	request.receive_heading = setter_direction(slot, lab.ball.position) if action == 0 else Vector3.ZERO
	var execution := ContactResolver.assess(request)
	if action == 0:
		last_receive_match = execution.charge_match
	last_preparation = preparation.evidence(slot)
	_launch(action,slot)
	if action != 2:
		lab.ball_velocity *= athlete_for(slot).low_stamina_factor()
	if action != 0:
		lab.ball_velocity *= Preparation.output_factor(lab.contact_flow.attack_charge(float(prepared.locked_charge),"training_bot_%d"%slot,lab.ball.position,execution) if action == 2 else float(prepared.locked_charge))
	request.base_velocity = lab.ball_velocity
	var result := ContactResolver.resolve(request, execution)
	lab.ball_velocity = result.velocity
	lab.ball.position += result.separation_offset
	execution = result.assessment
	last_aim = result.aiming
	if action == 2 and motion.plans.has(slot):
		motion.plans[slot]["swing_yaw"] = result.influence.shot_yaw_radians
	lab.ball_shot = ReceiveCharge.shot(["receive", "set", "attack", "block"][action], lab.contact_flow.attack_charge(float(prepared.locked_charge),"training_bot_%d"%slot,lab.ball.position,execution) if action == 2 else float(prepared.locked_charge), "training_bot_%d" % slot)
	if not result.outgoing_shot.is_empty():
		lab.ball_shot = result.outgoing_shot
	lab.ball_shot = lab.contact_flow.decorate_shot(lab.ball_shot,request.incoming_shot,"training_bot_%d"%slot,action,execution)
	if action == 2 and execution.hit:
		lab.contact_flow.consume_attack("training_bot_%d"%slot)
	if passive: block_state_for(slot).latched = true
	else: preparation.finish(slot)
	lab._emit_external_impact("training_bot_%d" % slot, action, incoming, execution,incoming_shot)
	var posture := Geometry.ReceivePlatform.posture(contact_shape(slot), local_contact, move_speed_for(slot) if settings[slot].moves else 0.0) if action == 0 else "planted"
	var swing_yaw := wrapf(atan2(-lab.ball_velocity.x, -lab.ball_velocity.z) - actors[slot].rotation.y, -PI, PI) if action == 2 else 0.0
	animation.contact(rigs[slot], action, local_contact, posture, swing_yaw, execution.get("rescue", false))
	dives.contacted(slot)
	return_after_contact(slot)
	var contact_cost: float = request.athlete.contact_cost(action,1,execution,incoming_shot).x
	athlete_for(slot).last_stamina_cost = request.athlete.last_stamina_cost
	spend_stamina(slot,contact_cost,true)
	total_contacts += 1
	last_action = action
	lab.trail_points.clear()
	lab.contacts = 0
	for memory_slot in range(4):
		lab.contact_memory[memory_slot] = 0.0
	lab.outgoing = false
	lab._message(NAMES[action] + " BOT contact / Ball View tracks the new flight")
	resolving_contact = false
	replan()
	return true

func choose_attack_target(slot: int,point: Vector3) -> Vector3:
	var blockers: Array = []
	var defenders: Array = []
	for other in range(settings.size()):
		if not slot_enabled(other) or slot_away(other) == slot_away(slot): continue
		defenders.append(actors[other].position)
		if settings[other].can_block(): blockers.append(actors[other].position)
	if lab.player.visible and (lab.player.position.z < 0) != slot_away(slot):
		defenders.append(lab.player.position)
		if lab.block_state.active or (lab.armed and lab.locked_action == 3): blockers.append(lab.player.position)
	return AttackTarget.choose(point,lab.court_center,lab.court_half_width,lab.court_half_depth,blockers,defenders)

func _bump_ceiling(height: float) -> float:
	var charge := 0.35 + 65.0 / 250.0
	var previous: Dictionary = lab.Flight.solve_flight(5.0 + charge * 5.5, 60.0, maxf(height - 0.105, 0))
	var launch: Dictionary = lab.Flight.solve_between(previous.range_meters, 76.0, height, 0.105)
	var up := float(launch.required_speed_mps) * sin(deg_to_rad(76.0))
	return height + up * up / (2 * float(lab.GRAVITY))

func _launch(action: int,firing_slot: int = -1) -> void:
	net_rebound = false
	var origin: Vector3 = lab.ball.position
	var side := 1.0 if origin.z > 0 else -1.0
	var lane_x: float = lab.court_center.x+1.8 * sin(total_contacts * 1.3)
	var target := Vector3(lane_x, 2.25, side * 3.0)
	var duration := 1.35
	match action:
		0: # Loft receive toward a setter on the same side.
			target = Vector3(lane_x, 2.25, side * 3.0)
		1: # Repeat a fixed destination; mirror it for the opposite court.
			target = Vector3(set_target.x, set_target.y, side * set_target.z)
			duration = 1.25
		2: # Send a driven ball through the opposing court.
			var attacker := firing_slot if firing_slot >= 0 else slot_for(2,origin.z)
			target = attack_targets.get(attacker,origin+Vector3.FORWARD.rotated(Vector3.UP,actors[attacker].rotation.y)*6.0)
			duration = 1.0 / (lab.SPIKE_SPEED_MULTIPLIER * lab.ATTACK_DRIVE_FACTOR)
		3: # Redirect the block over the Net with enough lift for a receiver.
			target = Vector3(lane_x, 1.0, -side * 5.0)
			duration = 1.15
	if action == 0:
		var receiver_slot := firing_slot if firing_slot >= 0 else slot_for(0,origin.z)
		var toward_setter := setter_direction(receiver_slot, origin)
		if toward_setter.length_squared() > 0:
			var setter_slot := slot_for(1,origin.z)
			var range_flight: Dictionary = lab.Flight.solve_flight(5.0 + 0.70 * 5.5, lab.BUMP_ANGLE, maxf(origin.y - Geometry.VISUAL_BALL_RADIUS, 0))
			var nominal_range: float = range_flight.range_meters
			var setter_distance := Vector2(actors[setter_slot].position.x - origin.x, actors[setter_slot].position.z - origin.z).length()
			target = origin + toward_setter * minf(setter_distance, nominal_range)
			target.y = 2.25
	if action in [0, 1]:
		var ceiling: float = _bump_ceiling(origin.y) if action == 0 else maxf(origin.y + 0.35, _bump_ceiling(1.0))
		var peak := origin.y + (ceiling - origin.y) * (0.70 if action == 0 else 0.85)
		if action == 1:
			var setter_slot := firing_slot if firing_slot >= 0 else slot_for(1,origin.z)
			var ground_factor: float = 1.0 if actors[setter_slot].position.y > 0.05 else lab.GROUND_SET_RISE_FACTOR
			peak = origin.y + (peak - origin.y) * lab.SET_RISE_FACTOR * ground_factor
		peak = maxf(peak, target.y + 0.25)
		var gravity: float = lab.GRAVITY
		var upward := sqrt(2.0 * gravity * (peak - origin.y))
		duration = (upward + sqrt(maxf(0, upward * upward + 2 * gravity * (origin.y - target.y)))) / gravity
	lab.ball_velocity = (target - origin) / duration + Vector3.UP * float(lab.GRAVITY) * duration * 0.5
	if action == 2:
		var slot := firing_slot if firing_slot >= 0 else slot_for(2,origin.z)
		var yaw: float = actors[slot].rotation.y
		lab.ball_velocity = Influence.constrain_attack(lab.ball_velocity, yaw,athlete_for(slot).trait_effect("court_vision"))
		var shot_yaw := atan2(-lab.ball_velocity.x, -lab.ball_velocity.z)
		var swing := wrapf(shot_yaw - yaw, -PI, PI)
		if motion.plans.has(slot):
			motion.plans[slot]["swing_yaw"] = swing

func any_enabled() -> bool:
	return settings.any(func(config: BotSettings): return config.enabled)

func all_enabled(away: bool) -> bool:
	for action in range(4):
		if not settings[action + (4 if away else 0)].enabled:
			return false
	return true

func disable_side(away: bool) -> void:
	for action in range(4):
		var slot := action + (4 if away else 0)
		settings[slot].enabled = false
		actors[slot].hide()
	replan()

var geometry_cache: Dictionary = {}
func contact_shape(slot: int) -> Dictionary:
	var base: Dictionary = shapes[slot]
	if slot_action(slot) == 0:
		var profile := athlete_for(slot)
		base = Geometry.ReceivePlatform.definition(float(profile.build.height),dives.active(slot),0,profile.build)
	if not is_instance_valid(lab.contact_flow): return base
	var effects: Dictionary = lab.contact_flow.shape_effects("training_bot_%d"%slot,slot_action(slot))
	var control := athlete_for(slot).ball_control()
	var cached: Dictionary = geometry_cache.get(slot,{})
	if cached.get("base",{}) == base and cached.get("effects",{}) == effects and cached.get("control",-1) == control:
		return cached.shape
	var definition := base.duplicate(true)
	if slot_action(slot) == 0: definition["platform_quality"] = effects.get("platform_quality",0)
	if slot_action(slot) == 1:
		definition["ball_control"] = control
		definition["column_radius"] = lerpf(0.16,0.42,clampf(control/100.0,0,1))*float(athlete_for(slot).build.height)/1.86
	var shape := Geometry.with_effects(definition,effects)
	if slot < contact_boxes.size():
		var drawing: Dictionary = shape.get("base_geometry",shape)
		match slot_action(slot):
			0: contact_boxes[slot].mesh = Geometry.ReceivePlatform.mesh(drawing)
			1:
				contact_boxes[slot].mesh = Geometry.SetHurtbox.mesh(drawing)
				for child in contact_boxes[slot].get_children():
					if child is MeshInstance3D: child.mesh = Geometry.SetHurtbox.mesh(drawing,true)
			2: contact_boxes[slot].mesh = Geometry.zone_mesh(drawing,false,shape)
			3: contact_boxes[slot].mesh = Geometry.block_mesh(drawing)
	geometry_cache[slot] = {"base":base.duplicate(true),"effects":effects.duplicate(true),"control":control,"shape":shape}
	return shape
