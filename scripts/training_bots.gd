extends Node3D

# Camera-test helpers with independent contact assignments and tracking/static modes.
# Real ball physics continues between all contacts.
const ReceiveOutcome := preload("res://scripts/receive_outcome.gd")
const ReceiveCharge := preload("res://scripts/receive_charge.gd")
const Preparation := preload("res://scripts/bot_preparation.gd")
var preparation := Preparation.new()
var charge_accuracy := [100.0,100.0,100.0,100.0,100.0,100.0,100.0,100.0]
var charge_random := RandomNumberGenerator.new()
var last_preparation: Dictionary = {}
var last_receive_match: Dictionary = {}

const BotAim := preload("res://scripts/bot_aim.gd")
const Execution := preload("res://scripts/contact_execution.gd")
const SpikeDirection := preload("res://scripts/spike_direction.gd")
const Influence := preload("res://scripts/directional_influence.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Store := preload("res://scripts/athlete_store.gd")
const BotAnimation :=  preload("res://scripts/bot_animation.gd")
var animation := BotAnimation.new()
const Motion := preload("res://scripts/bot_motion.gd")
var motion := Motion.new()
var rigs: Array[Dictionary] = []
var incoming_action := -1
var physique := Athlete.new()
var shapes: Array[Dictionary] = []
var tracking_accuracy := [100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
var random := RandomNumberGenerator.new()
var aim_random := RandomNumberGenerator.new()
var aiming_accuracy := [100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0]
var last_aim: Dictionary = {}
const NAMES := ["RECEIVE", "SET", "ATTACK", "BLOCK"]
const HEIGHTS := [1.0, 2.25, 3.8, 3.15]
const COLORS := [Color("74dacd"), Color("ac9df2"), Color("ffb46e"), Color("8bbdf4")]
var lab: Node3D
var enabled: Array[bool] = [false, false, false, false]
var away_enabled: Array[bool] = [false, false, false, false]
var actors: Array[Node3D] = []
var captions: Array[Label3D] = []
var contact_boxes: Array[MeshInstance3D] = []
var contact_order := [1, 2, 3, 0, 1, 2, 3, 0]
var follows_ball := [true, true, true, true, true, true, true, true]
var moves := [false, false, false, false, false, false, false, false]
var move_speeds := [6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 6.0, 6.0]
var move_targets: Dictionary = {}
var fixed_positions: Array[Vector3] = []
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
	for slot in range(8):
		var action := slot % 4
		var actor := Node3D.new()
		add_child(actor)
		actors.append(actor)
		var rig := Visual.build(lab, actor, "Feli", {"palette_index": 0, "marking": "none"}, physique.build)
		rigs.append(rig)
		var scale: float = physique.build.height / rig.rig_height
		var shape := Geometry.definition(action, physique.build.height, physique.reach(), false, 1.0, rig.arms[1].position.y * scale, absf(rig.arms[1].position.x) * scale, physique.ball_control(), Geometry.arm_length(rig.arms[1], scale))
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
			wire.material_override = lab.debug_material(Color.WHITE, 1.0)
			wire.material_override.vertex_color_use_as_albedo = true
		elif shape.get("receive_platform", false):
			contact_box.mesh = Geometry.ReceivePlatform.mesh(shape)
		elif shape.shape == "block_columns":
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
		var material: StandardMaterial3D = lab.debug_material(COLORS[action], 0.18)
		if action in [0, 1, 2, 3]:
			material.vertex_color_use_as_albedo = true
			material.albedo_color = Color.WHITE
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		contact_box.material_override = material
		contact_boxes.append(contact_box)
		var caption := Label3D.new()
		caption.text = ("HOME " if slot < 4 else "AWAY ") + NAMES[action]
		caption.font_size = 32
		caption.pixel_size = 0.006
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.modulate = COLORS[action]
		actor.add_child(caption)
		captions.append(caption)
		actor.position = Vector3(-3.0 + action * 2.0, 0, 5 if slot < 4 else -5)
		fixed_positions.append(actor.position)
		actor.rotation.y = PI if slot >= 4 else 0.0
		actor.visible = false

func is_enabled(action: int, z: float) -> bool:
	return away_enabled[action] if z < 0 else (enabled[action] and action != 3)

func toggle(action: int, away: bool = false) -> void:
	if action == 3 and not away:
		return
	var states := away_enabled if away else enabled
	states[action] = not states[action]
	actors[action + (4 if away else 0)].visible = states[action]
	if action == 1 and states[action] and not set_target_locked and not away:
		_capture_set_target()
	lab._resize_court()
	replan()

func toggle_all() -> void:
	var turn_on := not (enabled[0] and enabled[1] and enabled[2] and not away_enabled.has(false))
	if turn_on and not enabled[1] and not set_target_locked:
		_capture_set_target()
	for action in range(4):
		enabled[action] = turn_on and action != 3
		away_enabled[action] = turn_on
		actors[action].visible = enabled[action]
		actors[action + 4].visible = turn_on
	lab._resize_court()
	replan()

func _capture_set_target() -> void:
	set_target_locked = true
	set_target = Vector3(clampf(lab.player.position.x, -4.2, 4.2), 3.8, clampf(absf(lab.player.position.z), 0.6, 8.5))
	lab._message("SET BOT target locked to your position / F6 to retarget")

func reset() -> void:
	preparation.reset()
	active_action = -1
	motion.plans.clear()
	animation.reset()
	move_targets.clear()
	incoming_action = -1
	total_contacts = 0
	last_action = -1
	last_was_block = false
	for slot in range(8):
		var action := slot % 4
		actors[slot].position = Vector3(-3.0 + action * 2.0, 0, 5 if slot < 4 else -5) if follows_ball[slot] else fixed_positions[slot]
		captions[slot].text = ("HOME " if slot < 4 else "AWAY ") + NAMES[action]
		captions[slot].position.y = 2.15
		contact_boxes[slot].position = shapes[slot].center
		Motion.Pose.base(rigs[slot].body, 0, 0, 0, false)
		Motion.Pose.ground_feet(rigs[slot].body)

func replan(skip_block: bool = false) -> void:
	active_action = -1
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
	if not skip_block and incoming_action == 2 and away_enabled[3] and (contact_order[7] in [0, 1]) and velocity.z < 0 and not last_was_block and absf(velocity.z) > 0.01 and origin.z * velocity.z < 0:
		var receiving_sign := -1.0 if velocity.z < 0 else 1.0
		var block_time := (receiving_sign * 0.25 - origin.z) / velocity.z
		if block_time > 0.025 and block_time < 3.0:
			var block_point := origin + velocity * block_time + Vector3.DOWN * gravity * block_time * block_time * 0.5
			if absf(block_point.x) <= 4.5 and block_point.y >= 2.43 and block_point.y <= contact_anchor(7).y + _jump_ceiling(7) + 0.25 and (follows_ball[7] or _static_intercept(7, origin, velocity, gravity) > 0):
				var t := block_time if follows_ball[7] else _static_intercept(7, origin, velocity, gravity)
				_plan(3, origin + velocity * t + Vector3.DOWN * gravity * t * t * 0.5, t)
				return
	var best_time := 6.0
	var best_action := -1
	var best_point := Vector3.ZERO
	for slot in range(8):
		var action := slot % 4
		if action == 3 or not is_enabled(action, -1 if slot >= 4 else 1):
			continue
		var time := -1.0
		if follows_ball[slot]:
			var contact_height: float = HEIGHTS[action]
			if action == 1 and moves[slot]:
				var apex := origin.y + maxf(velocity.y, 0) * maxf(velocity.y, 0) / (2 * gravity)
				contact_height = clampf(apex - 0.08, contact_anchor(slot).y + 0.25, contact_anchor(slot).y + minf(0.9, _jump_ceiling(slot)))
			var discriminant: float = velocity.y * velocity.y + 2.0 * gravity * (origin.y - contact_height)
			if discriminant >= 0:
				time = (velocity.y + sqrt(discriminant)) / gravity
		else:
			time = _static_intercept(slot, origin, velocity, gravity)
		if time < 0.025 or time > 5.0 or time >= best_time:
			continue
		var point := origin + velocity * time + Vector3.DOWN * gravity * time * time * 0.5
		if (point.z < 0) != (slot >= 4):
			continue
		var side: int = lab.side_index(point.z)
		var count: int = lab.side_contacts[side] if lab.side_index(origin.z) == side else 0
		if count >= 3 or (contact_order[slot] != 0 and contact_order[slot] != count + 1):
			continue
		if absf(point.x) > 5.5 or absf(point.z) > 10 or absf(point.z) < 0.35:
			continue
		best_time = time
		best_action = action
		best_point = point
	if best_action >= 0:
		_plan(best_action, best_point, best_time)
	else:
		_attempt_unreachable_jumps(origin, velocity, gravity)

func _jump_ceiling(slot: int) -> float:
	return physique.leap(1.0,1.0,lab.contact_flow.jump_bonus("training_bot_%d"%slot) if is_instance_valid(lab.contact_flow) else 0.0)

func _attempt_unreachable_jumps(origin: Vector3, velocity: Vector3, gravity: float) -> void:
	# An invalid prediction must not leave the assigned overhead role motionless.
	# This is a physical attempt only: it never awards a touch or changes flight.
	var time := clampf(maxf(velocity.y / gravity, 0.25), 0.25, 0.65)
	var projected := origin + velocity * time + Vector3.DOWN * gravity * time * time * 0.5
	for slot in [1, 2, 5, 6]:
		var action: int = slot % 4
		var away: bool = slot >= 4
		if not is_enabled(action, -1 if away else 1) or motion.plans.has(slot):
			continue
		if (projected.z < 0) != away:
			continue
		var side := 1 if away else 0
		var count: int = lab.side_contacts[side] if lab.side_index(origin.z) == side else 0
		if count >= 3 or (contact_order[slot] != 0 and contact_order[slot] != count + 1):
			continue
		var target: Vector3 = fixed_positions[slot] if not follows_ball[slot] else projected - contact_anchor(slot).rotated(Vector3.UP, actors[slot].rotation.y)
		target.x = clampf(target.x, -5.5, 5.5)
		target.z = clampf(absf(target.z), 0.5, 10.0) * (-1.0 if away else 1.0)
		target.y = clampf(projected.y - contact_anchor(slot).y, 0.30, _jump_ceiling(slot))
		motion.begin(slot, actors[slot], target, time, follows_ball[slot], gravity, move_speeds[slot] if moves[slot] else -1.0,NAN,physique.explosiveness_rate())
		if is_instance_valid(lab.contact_flow):
			lab.contact_flow.consume_jump("training_bot_%d"%slot)
		motion.plans[slot]["fallback"] = true
		if active_action < 0:
			active_action = action
			intercept = projected
			remaining = time
			preparation.begin(slot, action, lab.ball_shot, time, charge_accuracy[slot], charge_random,physique.cushioning_bonus(),physique.low_stamina_factor())

func set_contact_order(slot: int, order: int) -> void:
	contact_order[slot] = clampi(order, 0, 3)
	replan()

func set_following(slot: int, follow: bool) -> void:
	fixed_positions[slot] = actors[slot].position
	follows_ball[slot] = follow
	moves[slot] = false
	contact_boxes[slot].position = shapes[slot].center
	replan()

func set_mode(slot: int, mode: int) -> void:
	fixed_positions[slot] = actors[slot].position
	follows_ball[slot] = mode != 1
	moves[slot] = mode == 2
	replan()

func set_move_speed(slot: int, value: float) -> void:
	move_speeds[slot] = clampf(value, 0, 12)
	if motion.plans.has(slot) and moves[slot]:
		motion.plans[slot]["move_speed"] = move_speeds[slot]

func setter_direction(slot: int, origin: Vector3) -> Vector3:
	var setter_slot := 1 if slot < 4 else 5
	if not is_enabled(1, -1 if slot >= 4 else 1):
		return Vector3.ZERO
	var direction := actors[setter_slot].position - origin
	direction.y = 0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD.rotated(Vector3.UP, actors[slot].rotation.y)

func place_at_player(slot: int) -> void:
	fixed_positions[slot] = Vector3(clampf(lab.player.position.x, -5.5, 5.5), 0, clampf(absf(lab.player.position.z), 0.5, 10.0) * (-1 if slot >= 4 else 1))
	actors[slot].position = fixed_positions[slot]
	follows_ball[slot] = false
	moves[slot] = false
	contact_boxes[slot].position = shapes[slot].center
	replan()

# Use the same narrow-phase geometry as player contacts, including the forward
# receive fan and dominant-arm sector. Small spatial steps avoid fast-ball tunneling.
func _static_intercept(slot: int, origin: Vector3, velocity: Vector3, gravity: float) -> float:
	var step := clampf(0.025 / maxf(velocity.length() + gravity * 5.0, 1.0), 0.0005, 0.01)
	var time := 0.35 if slot % 4 == 2 else (0.12 if slot % 4 == 3 else 0.025)
	var frame := Basis(Vector3.UP,-actors[slot].rotation.y)
	var fixed := fixed_positions[slot]
	var overhead := slot % 4 in [2,3]
	var max_jump := _jump_ceiling(slot)*(1.2 if slot % 4 == 2 else 1.0) if overhead else 0.0
	var anchor_height := contact_anchor(slot).y
	while time <= 5.0:
		var point := origin + velocity * time + Vector3.DOWN * gravity * time * time * 0.5
		if point.y < -0.2:
			break
		var local := frame*(point-fixed)
		if overhead:
			local.y -= clampf(point.y-anchor_height,0,max_jump)
		if Geometry.contains(shapes[slot], local):
			return time
		time += step
	return -1.0

func contains_ball(slot: int, point: Vector3) -> bool:
	return Geometry.contains(shapes[slot], (point - actors[slot].position).rotated(Vector3.UP, -actors[slot].rotation.y))

func contact_anchor(slot: int) -> Vector3:
	var shape := shapes[slot]
	if slot % 4 == 1:
		return Vector3(shape.center) + Vector3.UP * (float(shape.radius) * 0.55)
	if slot % 4 == 2:
		return Vector3(shape.center) + Geometry.sector_point(shape, 0.74, 67.5, 0.0)
	return Vector3(shape.center) + (Vector3.RIGHT * float(shape.column_x) if slot % 4 == 3 else Vector3.ZERO)

func set_charge_accuracy(slot: int, value: float) -> void:
	charge_accuracy[slot] = clampf(value, 0, 100)

func set_aiming_accuracy(slot: int, value: float) -> void:
	aiming_accuracy[slot] = clampf(value, 0, 100)

func set_tracking_accuracy(slot: int, value: float) -> void:
	tracking_accuracy[slot] = clampf(value, 0, 100)
	replan()

func _plan(action: int, point: Vector3, time: float) -> void:
	active_action = action
	intercept = point
	remaining = time
	var slot := action + (4 if point.z < 0 else 0)
	preparation.begin(slot, action, lab.ball_shot, time, charge_accuracy[slot], charge_random,physique.cushioning_bonus(),physique.low_stamina_factor())
	if action == 0:
		var toward_setter := setter_direction(slot, actors[slot].position)
		if toward_setter.length_squared() > 0:
			actors[slot].rotation.y = atan2(-toward_setter.x, -toward_setter.z)
	var aim_yaw: float = actors[slot].rotation.y
	if action == 2:
		var destination := Vector3(1.8 * sin(total_contacts * 1.3), 1.0, -6.0 if point.z > 0 else 6.0)
		var heading := destination - point
		aim_yaw = atan2(-heading.x, -heading.z)
	if follows_ball[slot]:
		var anchor := contact_anchor(slot).rotated(Vector3.UP, aim_yaw)
		var error_radius: float = 2.5 * (1.0 - tracking_accuracy[slot] / 100.0)
		var angle := random.randf_range(0, TAU)
		var error := Vector3(cos(angle), 0, sin(angle)) * sqrt(random.randf()) * error_radius
		var target := point - anchor + error
		target.y = maxf(0, target.y)
		if action in [2, 3] or (action == 1 and moves[slot]):
			if action in [1, 2]:
				target.y = maxf(0.25, target.y)
			target.y = minf(target.y, _jump_ceiling(slot) * (1.2 if action == 2 else 1.0))
			motion.begin(slot, actors[slot], target, time, true, lab.GRAVITY, move_speeds[slot] if moves[slot] else -1.0, aim_yaw,physique.explosiveness_rate())
			if is_instance_valid(lab.contact_flow):
				lab.contact_flow.consume_jump("training_bot_%d"%slot)
		elif moves[slot]:
			move_targets[slot] = target
		else:
			actors[slot].position = target
	elif action in [2, 3]:
		var target := fixed_positions[slot]
		target.y = clampf(point.y - contact_anchor(slot).y, 0.25 if action == 2 else 0.0, _jump_ceiling(slot) * (1.2 if action == 2 else 1.0))
		motion.begin(slot, actors[slot], target, time, false, lab.GRAVITY, -1.0, aim_yaw,physique.explosiveness_rate())
		if is_instance_valid(lab.contact_flow):
			lab.contact_flow.consume_jump("training_bot_%d"%slot)
	captions[slot].position.y = maxf(contact_anchor(slot).y + 0.55, 2.15)

func tick_motion(dt: float) -> void:
	for slot in range(8):
		if is_enabled(slot % 4, -1 if slot >= 4 else 1):
			preparation.tick(slot, dt * lab.moc.actor_scale("training_bot_%d" % slot))
	var previous_positions: Array[Vector3] = []
	for actor in actors:
		previous_positions.append(actor.position)
	var scales := {}
	for slot in range(8):
		scales[slot] = lab.moc.actor_scale("training_bot_%d" % slot)
	motion.tick(dt, actors, rigs, scales)
	for slot in move_targets.keys():
		var actor := actors[slot]
		var target: Vector3 = move_targets[slot]
		var ground := Vector3(target.x, actor.position.y, target.z)
		var before := actor.position
		actor.position = actor.position.move_toward(ground, move_speeds[slot] * dt * float(scales[slot]))
		var speed := actor.position.distance_to(before) / maxf(dt, 0.0001)
		Motion.Pose.base(rigs[slot].body, float(Time.get_ticks_msec()) * 0.008, speed, 0, slot % 4 == 0)
		Motion.Pose.ground_feet(rigs[slot].body)
	for slot in range(rigs.size()):
		var action := slot % 4
		var planned := active_action == action and ((slot >= 4) == (intercept.z < 0))
		var motion_plan: Dictionary = motion.plans.get(slot, {})
		var airborne := not motion_plan.is_empty() and str(motion_plan.get("phase", "")) in ["jump", "landing"]
		var animation_state: Dictionary = animation.states.get(rigs[slot].body.get_instance_id(), {})
		var following_contact := float(animation_state.get("since", 100)) < 0.75
		if not actors[slot].visible and not planned and motion_plan.is_empty() and not following_contact:
			continue
		var point: Vector3 = (lab.ball.position - actors[slot].position).rotated(Vector3.UP, -actors[slot].rotation.y) if planned and lab.ball_active else contact_anchor(slot)
		var speed := Vector2(actors[slot].position.x - previous_positions[slot].x, actors[slot].position.z - previous_positions[slot].z).length() / maxf(dt, 0.001)
		if action == 0 and not Geometry.contains(shapes[slot], point):
			point = contact_anchor(slot)
		var posture := Geometry.ReceivePlatform.posture(shapes[slot], point, speed) if action == 0 else "planted"
		animation.update(rigs[slot], dt * float(scales[slot]), {"action": action, "charge": float(preparation.state_for(slot).charge), "planned": planned or not motion_plan.is_empty(), "airborne": airborne, "remaining": float(motion_plan.get("contact", remaining)) - float(motion_plan.get("elapsed", 0)) if not motion_plan.is_empty() else remaining, "rise": motion_plan.get("rise", 0.4), "preserve_base": not motion_plan.is_empty(), "contact_point": point, "posture": posture, "speed": speed, "cycle": float(Time.get_ticks_msec()) * 0.008, "swing_yaw": motion_plan.get("swing_yaw", 0.0),"transition_rate":physique.transition_rate()})
	for slot in range(actors.size()):
		var travel: Vector3 = lab.contact_flow.displacement("training_bot_%d" % slot,dt*float(scales[slot])) if is_instance_valid(lab.contact_flow) else Vector3.ZERO
		actors[slot].position += travel
		fixed_positions[slot] += travel
		if motion.plans.has(slot):
			motion.plans[slot].start += travel
			motion.plans[slot].ground += travel
	for slot in range(contact_boxes.size()):
		var precision := active_action == slot % 4 and ((slot >= 4) == (intercept.z < 0)) and Execution.sweet_active(slot % 4, float(preparation.state_for(slot).confirmation_age))
		var material: StandardMaterial3D = contact_boxes[slot].material_override
		material.vertex_color_use_as_albedo = precision
		material.albedo_color = Color.WHITE if precision else Color(0.96, 0.61, 0.41, 0.16)
		for child in contact_boxes[slot].get_children():
			if child is MeshInstance3D:
				child.material_override.vertex_color_use_as_albedo = precision
				child.material_override.albedo_color = material.albedo_color

func tick(dt: float) -> bool:
	tick_motion(dt)
	if not lab.ball_active or active_action < 0:
		return false
	remaining -= dt
	if remaining > 0:
		return false
	var action := active_action
	if remaining < -Execution.CONTACT_SECONDS:
		active_action = -1
		replan(action == 3)
		return false
	if not is_enabled(action, intercept.z):
		active_action = -1
		if action == 3:
			replan(true)
		return false
	# A manual contact replans the intercept, so a helper never follows an old flight.
	var bot_slot := action + (4 if intercept.z < 0 else 0)
	var prepared := preparation.state_for(bot_slot)
	if prepared.phase != "confirmed":
		return false
	if float(prepared.confirmation_age) > Execution.CONTACT_SECONDS:
		active_action = -1
		preparation.finish(bot_slot)
		if action == 3:
			replan(true)
		return false
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
			var cleared_block: bool = action == 3 and local_velocity.z > 0 and local.z > float(shapes[bot_slot].center.z) + float(shapes[bot_slot].size.z) * 0.5 + Geometry.BALL_RADIUS
			if remaining < -Execution.CONTACT_SECONDS or cleared_block:
				active_action = -1
				if action == 3:
					replan(true)
			return false
	else:
		intercept = lab.ball.position
	active_action = -1
	var side: int = lab.side_index(intercept.z)
	var slot := action + (4 if intercept.z < 0 else 0)
	if action != 3 and (lab.side_contacts[side] >= 3 or (contact_order[slot] != 0 and lab.side_contacts[side] + 1 != contact_order[slot])):
		replan()
		return false
	lab.ball.position = intercept
	if action != 3:
		lab.side_contacts[side] += 1
	last_was_block = action == 3
	incoming_action = action
	var incoming: Vector3 = lab.ball_velocity
	var incoming_shot: Dictionary = lab.ball_shot
	var local_contact: Vector3 = (lab.ball.position - actors[slot].position).rotated(Vector3.UP, -actors[slot].rotation.y)
	var execution := Execution.assess(Geometry.evaluate(shapes[slot], local_contact), float(prepared.confirmation_age), false, action)
	if action == 0:
		execution = ReceiveCharge.assess(execution, lab.ball_shot, float(prepared.locked_charge)*physique.low_stamina_factor(),physique.cushioning_bonus(),physique.trait_effect("charge_tolerance"))
		execution = ReceiveOutcome.assess(execution,shapes[slot],local_contact,move_speeds[slot] if moves[slot] else 0.0,Vector3.ZERO,actors[slot].rotation.y)
		last_receive_match = execution.charge_match
	if action == 1:
		execution = physique.stabilize_set(execution)
	last_preparation = preparation.evidence(slot)
	_launch(action)
	if action != 2:
		lab.ball_velocity *= physique.low_stamina_factor()
	if action != 0:
		lab.ball_velocity *= Preparation.output_factor(lab.contact_flow.attack_charge(float(prepared.locked_charge),"training_bot_%d"%slot,lab.ball.position) if action == 2 else float(prepared.locked_charge))
	var ideal: Vector3 = lab.ball_velocity
	if action == 1:
		var local: Vector3 = (lab.ball.position - actors[slot].position).rotated(Vector3.UP, -actors[slot].rotation.y)
		var assessment := physique.stabilize_set(Geometry.evaluate(shapes[slot], local))
		var deviation := (1.0 - float(assessment.quality)) * (1.0 - physique.ball_control() / 120.0)
		lab.ball_velocity = lab.ball_velocity.rotated(Vector3.UP, deviation * sin(total_contacts * 1.7 + 0.8) * 0.5)
	if action == 0 and execution.hit:
		lab.ball_velocity = Geometry.ReceivePlatform.redirect(lab.ball_velocity, lab.ball.position, actors[slot].rotation.y, incoming, execution, lab.GRAVITY)
	elif action == 2:
		lab.ball_velocity *= float(execution.get("strength", 0.48))
	var forward := Vector3.FORWARD.rotated(Vector3.UP, actors[slot].rotation.y)
	if action == 2:
		last_aim = BotAim.apply(lab.ball.position, lab.ball_velocity, aiming_accuracy[slot], lab.GRAVITY, aim_random)
		lab.ball_velocity = last_aim.velocity
		var direction_result := SpikeDirection.resolve(lab.ball_velocity, execution, Vector3.ZERO, forward, true)
		lab.ball_velocity = direction_result.velocity
		if motion.plans.has(slot):
			motion.plans[slot]["swing_yaw"] = direction_result.shot_yaw_radians
	lab.ball_velocity = Execution.velocity(action, lab.ball_velocity, incoming, forward, execution, physique.timing(), ideal,physique.ball_control(),lab.contact_flow.amount("training_bot_%d"%slot),physique.low_stamina_factor())
	if action == 0:
		var toward_setter := setter_direction(slot, lab.ball.position)
		if toward_setter.length_squared() > 0:
			var horizontal_speed := Vector2(lab.ball_velocity.x, lab.ball_velocity.z).length()
			lab.ball_velocity.x = toward_setter.x * horizontal_speed
			lab.ball_velocity.z = toward_setter.z * horizontal_speed
	if action != 2:
		var keep_setter_heading := action == 0 and setter_direction(slot, lab.ball.position).length_squared() > 0
		last_aim = BotAim.apply(lab.ball.position, lab.ball_velocity, aiming_accuracy[slot], lab.GRAVITY, aim_random, keep_setter_heading)
		lab.ball_velocity = last_aim.velocity
	if action == 0:
		lab.ball_velocity = ReceiveCharge.velocity(ReceiveOutcome.velocity(lab.ball_velocity,execution), incoming, forward, execution)
	lab.ball_shot = ReceiveCharge.shot(["receive", "set", "attack", "block"][action], lab.contact_flow.attack_charge(float(prepared.locked_charge),"training_bot_%d"%slot,lab.ball.position) if action == 2 else float(prepared.locked_charge), "training_bot_%d" % slot)
	if action == 2 and execution.hit:
		lab.contact_flow.consume_attack("training_bot_%d"%slot)
	preparation.finish(slot)
	lab._emit_external_impact("training_bot_%d" % slot, action, incoming, execution,incoming_shot)
	var posture := Geometry.ReceivePlatform.posture(shapes[slot], local_contact, move_speeds[slot] if moves[slot] else 0.0) if action == 0 else "planted"
	var swing_yaw := wrapf(atan2(-lab.ball_velocity.x, -lab.ball_velocity.z) - actors[slot].rotation.y, -PI, PI) if action == 2 else 0.0
	animation.contact(rigs[slot], action, local_contact, posture, swing_yaw, execution.get("rescue", false))
	total_contacts += 1
	last_action = action
	lab.trail_points.clear()
	lab.contacts = 0
	for memory_slot in range(4):
		lab.contact_memory[memory_slot] = 0.0
	lab.outgoing = false
	lab._message(NAMES[action] + " BOT contact / Ball View tracks the new flight")
	replan()
	return true

func _bump_ceiling(height: float) -> float:
	var charge := 0.35 + 65.0 / 250.0
	var previous: Dictionary = lab.Flight.solve_flight(5.0 + charge * 5.5, 60.0, maxf(height - 0.105, 0))
	var launch: Dictionary = lab.Flight.solve_between(previous.range_meters, 76.0, height, 0.105)
	var up := float(launch.required_speed_mps) * sin(deg_to_rad(76.0))
	return height + up * up / (2 * float(lab.GRAVITY))

func _launch(action: int) -> void:
	var origin: Vector3 = lab.ball.position
	var side := 1.0 if origin.z > 0 else -1.0
	var lane_x := 1.8 * sin(total_contacts * 1.3)
	var target := Vector3(lane_x, 2.25, side * 3.0)
	var duration := 1.35
	match action:
		0: # Loft receive toward a setter on the same side.
			target = Vector3(lane_x, 2.25, side * 3.0)
		1: # Repeat a fixed destination; mirror it for the opposite court.
			target = Vector3(set_target.x, set_target.y, side * set_target.z)
			duration = 1.25
		2: # Send a driven ball through the opposing court.
			target = Vector3(lane_x, 1.0, -side * 6.0)
			duration = 1.0 / (lab.SPIKE_SPEED_MULTIPLIER * lab.ATTACK_DRIVE_FACTOR)
		3: # Redirect the block over the Net with enough lift for a receiver.
			target = Vector3(lane_x, 1.0, -side * 5.0)
			duration = 1.15
	if action == 0:
		var receiver_slot := 0 if origin.z >= 0 else 4
		var toward_setter := setter_direction(receiver_slot, origin)
		if toward_setter.length_squared() > 0:
			var setter_slot := receiver_slot + 1
			var range_flight: Dictionary = lab.Flight.solve_flight(5.0 + 0.70 * 5.5, 60.0, maxf(origin.y - Geometry.VISUAL_BALL_RADIUS, 0))
			var nominal_range: float = range_flight.range_meters
			var setter_distance := Vector2(actors[setter_slot].position.x - origin.x, actors[setter_slot].position.z - origin.z).length()
			target = origin + toward_setter * minf(setter_distance, nominal_range)
			target.y = 2.25
	if action in [0, 1]:
		var ceiling: float = _bump_ceiling(origin.y) if action == 0 else maxf(origin.y + 0.35, _bump_ceiling(1.0))
		var peak := origin.y + (ceiling - origin.y) * (0.70 if action == 0 else 0.85)
		if action == 1:
			var setter_slot := 1 if origin.z >= 0 else 5
			var ground_factor: float = 1.0 if actors[setter_slot].position.y > 0.05 else lab.GROUND_SET_RISE_FACTOR
			peak = origin.y + (peak - origin.y) * lab.SET_RISE_FACTOR * ground_factor
		peak = maxf(peak, target.y + 0.25)
		var gravity: float = lab.GRAVITY
		var upward := sqrt(2.0 * gravity * (peak - origin.y))
		duration = (upward + sqrt(maxf(0, upward * upward + 2 * gravity * (origin.y - target.y)))) / gravity
	lab.ball_velocity = (target - origin) / duration + Vector3.UP * float(lab.GRAVITY) * duration * 0.5
	if action == 2:
		var slot := 2 if origin.z >= 0 else 6
		var yaw: float = actors[slot].rotation.y
		lab.ball_velocity = Influence.constrain_attack(lab.ball_velocity, yaw)
		var shot_yaw := atan2(-lab.ball_velocity.x, -lab.ball_velocity.z)
		var swing := wrapf(shot_yaw - yaw, -PI, PI)
		if motion.plans.has(slot):
			motion.plans[slot]["swing_yaw"] = swing
