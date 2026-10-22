extends Node3D

# Dependencies and fixed configuration.
const Settings := preload("res://scripts/bot_settings.gd")
const Vitals := preload("res://scripts/bot_vitals.gd")
const ContactRequest := preload("res://scripts/contact/contact_request.gd")
const ContactResolver := preload("res://scripts/contact/contact_resolver.gd")
const ReceiveCharge := preload("res://scripts/receive_charge.gd")
const Preparation := preload("res://scripts/bot_preparation.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const BotAnimation :=  preload("res://scripts/bot_animation.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const Execution := preload("res://scripts/contact_execution.gd")
const Influence := preload("res://scripts/directional_influence.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const SPOTS := [Vector3(-29, 3.5, 3), Vector3(8, 0, 5), Vector3(0, 0, 27)]
const LABELS := ["AWAY PEPPER / BOX 3", "AWAY PEPPER / EAST", "AWAY PEPPER / HOME PATH"]
const MOVEMENT_MODE := "Move"
const MOVE_SPEED := 6.0
# Equal area to a one-player 5x10m court.
const RADIUS := 3.9894228

# Per-controller state; presentation arrays use the same slot ordering.
var athletes: Array[LabAthlete] = []
var settings: Array[Settings] = [Settings.new(), Settings.new(), Settings.new()]
var preparation := Preparation.new()
var charge_random := RandomNumberGenerator.new()
var animation := BotAnimation.new()
var spots: Array = SPOTS.duplicate()
var home_rings: Array[MeshInstance3D] = []
var home_labels: Array[Label3D] = []
var aim_random := RandomNumberGenerator.new()
var last_aim: Dictionary = {}
var lab: Node3D
var actors: Array[Node3D] = []
var rigs: Array[Dictionary] = []
var volumes: Array[Node3D] = []
var partner := -1
var stage := 0
var player_contacts := 0
var player_action := 1
var last_delivery := {}
var npc_turn := false
var planned := false
var remaining := 0.0
var point := Vector3.ZERO
var jump_height := 0.0
var rise_time := 0.3
var landing_velocity := 0.0
var recovering := false
var exchanges := 0
var move_target := Vector3.ZERO
var approach_yaw := 0.0
var attack_facing_locked := false
var movement_cycle := 0.0

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	spots = lab.pepper_spots()
	aim_random.randomize()
	charge_random.randomize()
	for index in range(3):
		athletes.append(Vitals.create(lab.training_bots.physique))
		var actor := Node3D.new()
		add_child(actor)
		actors.append(actor)
		actor.set_meta("team", "away")
		actor.position = spots[index]
		var rig := Visual.build(lab, actor, "Avi" if index == 0 else "Feli", {"palette_index": index, "marking": "none"}, athletes[index].build)
		rigs.append(rig)
		var volume := Node3D.new()
		actor.add_child(volume)
		volumes.append(volume)
		var ring: MeshInstance3D = lab.world_builder.ring(RADIUS, Color("b49fee"))
		home_rings.append(ring)
		ring.position = spots[index] + Vector3.UP * 0.04
		home_labels.append(lab.world_builder.world_label(LABELS[index] + " / SERVE TO BEGIN", spots[index] + Vector3(0, 2.5, 0), 26, Color("b49fee")))
		actor.rotation.y = PI

func move_home(index: int,point: Vector3) -> void:
	spots[index] = point
	home_rings[index].position = point+Vector3.UP*0.04
	home_labels[index].position = point+Vector3.UP*2.5
	if not active() or partner != index: actors[index].position = point

func athlete_for(index: int) -> LabAthlete:
	return athletes[index]

func refresh_for_rally() -> void:
	for athlete in athletes: Vitals.refresh(athlete)

func spend_stamina(cost: float,resolved: bool = false) -> void:
	Vitals.spend(athlete_for(partner),cost,lab.contact_flow,"pepper_%d" % partner,resolved)

func set_charge_accuracy(index: int, value: float) -> void:
	settings[index].charge_accuracy = clampf(value, 0, 100)

func set_aiming_accuracy(index: int, value: float) -> void:
	settings[index].aiming_accuracy = clampf(value, 0, 100)

func active() -> bool:
	return partner >= 0

func stop() -> void:
	preparation.reset()
	animation.reset()
	partner = -1
	exchanges = 0
	stage = 0
	planned = false
	npc_turn = false
	player_contacts = 0
	recovering = false
	attack_facing_locked = false
	for index in range(3):
		actors[index].position = spots[index]
		for child in volumes[index].get_children():
			child.queue_free()
		Pose.base(rigs[index].body, 0, 0, 0, false)
		Pose.ground_feet(rigs[index].body)

func try_start(previous: Vector3) -> bool:
	if lab.athlete.exhausted or lab.is_benched():
		return false
	if active() or lab.serve.state != lab.serve.State.FLIGHT:
		return false
	var delta: Vector3 = lab.ball.position - previous
	for index in range(3):
		var center: Vector3 = spots[index] + Vector3.UP
		var t := clampf((center - previous).dot(delta) / maxf(delta.length_squared(), 0.000001), 0, 1)
		if (previous + delta * t).distance_to(center) <= RADIUS:
			partner = index
			Vitals.refresh(athlete_for(partner))
			stage = 0
			player_contacts = 0
			exchanges = 0
			npc_turn = true
			lab.training_bots.active_action = -1
			lab.contacts = 0
			lab.side_contacts.fill(0)
			lab.selected = 0
			plan()
			lab._message(LABELS[index] + " / PEPPER START / receive, set, attack back to your partner")
			return true
	return false

func shape() -> Dictionary:
	var rig := rigs[partner]
	var physique = athlete_for(partner)
	var scale: float = physique.body_height() / rig.rig_height
	var definition := Geometry.definition(stage, physique.body_height(), physique.reach(), false, 1, rig.arms[1].position.y * scale, absf(rig.arms[1].position.x) * scale, physique.ball_control(), Geometry.arm_length(rig.arms[1], scale),physique.build)
	if stage == 0:
		definition["platform_quality"] = physique.trait_effect("platform_quality")
	var effects: Dictionary = lab.contact_flow.shape_effects("pepper_%d"%partner,stage)
	if stage == 0: definition["platform_quality"] = effects.get("platform_quality",0)
	return Geometry.with_effects(definition,effects)

func anchor(definition: Dictionary) -> Vector3:
	if stage == 1:
		return Vector3(definition.center) + Vector3.UP * float(definition.radius) * 0.55
	if stage == 2:
		return Vector3(definition.center) + Geometry.sector_point(definition, 0.74, 67.5, 0)
	return definition.center

func plan() -> void:
	planned = false
	if not active() or not npc_turn:
		return
	var ground: Vector3 = spots[partner]
	var height: float = ground.y + [1.0, 2.25, 3.2][stage]
	if stage == 1:
		var apex: float = lab.ball.position.y + maxf(lab.ball_velocity.y, 0) * maxf(lab.ball_velocity.y, 0) / (2 * lab.GRAVITY)
		height = clampf(apex - 0.08, ground.y + anchor(shape()).y + 0.25, ground.y + anchor(shape()).y + 0.90)
	var d: float = lab.ball_velocity.y * lab.ball_velocity.y + 2 * lab.GRAVITY * (lab.ball.position.y - height)
	if d < 0 and stage == 1:
		# A low but valid set can use the shoulder/chin extension rather than
		# silently converting every low receive into another receive.
		height = ground.y + float(athlete_for(partner).body_height()) * 0.80
		d = lab.ball_velocity.y * lab.ball_velocity.y + 2 * lab.GRAVITY * (lab.ball.position.y - height)
	if d < 0:
		if stage == 0:
			return
		# Keep the intended overhead action and attempt a jump toward the
		# best available point, even when it cannot become a legal contact.
		remaining = clampf(lab.ball_velocity.y / lab.GRAVITY, 0.25, 0.65)
	else:
		remaining = (lab.ball_velocity.y + sqrt(d)) / lab.GRAVITY
	if remaining < 0.015 or remaining > 8:
		if stage == 0:
			return
		remaining = 0.30
	point = lab.ball.position + lab.ball_velocity * remaining + Vector3.DOWN * lab.GRAVITY * remaining * remaining * 0.5
	var radius := 1.1 if partner == 0 else 3.0
	if stage == 0 and Vector2(point.x - ground.x, point.z - ground.z).length() > radius + 0.9:
		return
	if stage == 0 and point.distance_to(lab.player.position + Vector3.UP) + 0.5 < point.distance_to(ground + Vector3.UP):
		return # Leave the athlete's own receive/set to the athlete.
	var actor := actors[partner]
	var facing: Vector3 = lab.player.position - ground
	facing.y = 0
	approach_yaw = atan2(-facing.x, -facing.z)
	attack_facing_locked = false
	var definition := shape()
	var desired := point - anchor(definition).rotated(Vector3.UP, approach_yaw)
	var offset := Vector2(desired.x - ground.x, desired.z - ground.z).limit_length(radius)
	move_target = Vector3(ground.x + offset.x, ground.y, ground.z + offset.y)
	jump_height = clampf(desired.y - ground.y, 0.25, 1.7*athlete_for(partner).leap(1,1,lab.contact_flow.jump_bonus("pepper_%d"%partner))/(athlete_for(partner).JUMP_HEIGHT_MULTIPLIER*(0.20+65.0*0.007))) if stage in [1, 2] else 0
	if stage in [1,2]:
		lab.contact_flow.consume_jump("pepper_%d"%partner)
		spend_stamina(athlete_for(partner).jump_stamina_cost(),true)
	rise_time = minf(sqrt(2 * maxf(jump_height, 0.01) / lab.GRAVITY)/athlete_for(partner).explosiveness_rate(), remaining)
	planned = true
	if stage == 2: lab.contact_flow.on_attack_charge("pepper_%d"%partner)
	preparation.begin(partner, stage, lab.ball_shot, remaining, settings[partner].charge_accuracy, charge_random,athlete_for(partner).cushioning_bonus(),athlete_for(partner).low_stamina_factor(),-1.0 if settings[partner].auto_intended_charge else settings[partner].intended_charge)
	_show_volume(definition)

func _show_volume(definition: Dictionary) -> void:
	var root := volumes[partner]
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	root.visible = lab.debug_volumes_visible
	var mesh := MeshInstance3D.new()
	root.add_child(mesh)
	mesh.position = definition.center
	mesh.scale = definition.get("geometry_scale",Vector3.ONE)
	var grading_shape := definition
	definition = definition.get("base_geometry",definition)
	mesh.mesh = Geometry.ReceivePlatform.mesh(definition) if stage == 0 else (Geometry.SetHurtbox.mesh(definition, true) if stage == 1 else Geometry.zone_mesh(definition,false,grading_shape))
	var material: StandardMaterial3D = lab.world_builder.debug_material(Color.WHITE, 1)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material

func next_action(action: int, quality: float) -> int:
	if quality < 0.72 or action == 2:
		return 0
	return action + 1

func required_player_action() -> int:
	# A delivery that drops below overhead reach is a recovery receive, not a
	# forced impossible set/spike. Good on-height deliveries keep their action.
	if not npc_turn and player_action > 0 and lab.ball_velocity.y < 0:
		var offset: Vector3 = lab.ball.position - lab.player.position
		if Vector2(offset.x, offset.z).length() < 3.5 and offset.y < float(lab.athlete.body_height()) * 0.9:
			player_action = 0
			lab.selected = 0
	return player_action

func on_player_contact(action: int, quality: float) -> void:
	if not active():
		return
	stage = next_action(action, quality)
	npc_turn = true
	plan()

func tick(dt: float) -> bool:
	for index in range(athletes.size()):
		if not (active() and index == partner): athletes[index].recover(dt*lab.moc.bot_scale("pepper_%d"%index),actors[index].position.y <= spots[index].y+0.01)
	for index in range(3):
		preparation.tick(index,dt*lab.moc.bot_scale("pepper_%d"%index))
	dt *= lab.moc.bot_scale("pepper_%d" % partner)
	if not active():
		return false
	var actor := actors[partner]
	if is_instance_valid(lab.contact_flow):
		actor.position += lab.contact_flow.displacement("pepper_%d" % partner,dt)
	var rig := rigs[partner]
	var ground: Vector3 = spots[partner]
	if recovering:
		landing_velocity -= lab.GRAVITY * dt
		actor.position.y = maxf(ground.y, actor.position.y + landing_velocity * dt)
		if actor.position.y <= ground.y:
			recovering = false
	if not planned:
		athlete_for(partner).recover(dt,actor.position.y <= ground.y+0.01)
		_animate(dt, 0.0)
		return false
	remaining -= dt
	var before := actor.position
	var horizontal_target := Vector3(move_target.x, actor.position.y, move_target.z)
	actor.position = actor.position.move_toward(horizontal_target, MOVE_SPEED * (0.55 if athlete_for(partner).exhausted else 1.0) * dt)
	var travelled := Vector2(actor.position.x - before.x, actor.position.z - before.z).length()
	if travelled > 0.00001 and actor.position.y <= ground.y+0.01: spend_stamina(dt*athlete_for(partner).movement_stamina_rate(),true)
	movement_cycle += travelled / maxf(athlete_for(partner).stride() * 2, 0.1) * TAU
	if stage not in [1, 2] or remaining > rise_time:
		actor.rotation.y = lerp_angle(actor.rotation.y, approach_yaw, 1 - exp(-dt * 12))
	elif not attack_facing_locked:
		actor.rotation.y = approach_yaw
		attack_facing_locked = true
	for child in volumes[partner].get_children():
		if child is MeshInstance3D:
			var precision := Execution.sweet_active(stage, float(preparation.state_for(partner).confirmation_age))
			child.material_override.vertex_color_use_as_albedo = precision
			child.material_override.albedo_color = Color.WHITE if precision else Color(0.96, 0.61, 0.41, 0.18)
	if stage in [1, 2] and remaining <= rise_time:
		actor.position.y = ground.y + jump_height * maxf(0, 1 - pow(remaining / maxf(rise_time, 0.01), 2))
	athlete_for(partner).recover(dt,travelled <= 0.00001 and actor.position.y <= ground.y+0.01)
	_animate(dt, travelled / maxf(dt, 0.001))

	if remaining > 0:
		return false
	if remaining < -Execution.contact_seconds(stage):
		planned = false
		return false
	var prepared := preparation.state_for(partner)
	if prepared.phase != "confirmed":
		return false
	if float(prepared.confirmation_age) > Execution.contact_seconds(stage):
		planned = false
		preparation.finish(partner)
		return false
	var definition := shape()
	var hit := false
	var steps := maxi(1, ceili(lab.ball_velocity.length() * dt / 0.025))
	for sample in range(steps + 1):
		var candidate: Vector3 = lab.ball.position - lab.ball_velocity * dt * float(sample) / steps
		if (Geometry.spike_active(definition, (candidate - actor.position).rotated(Vector3.UP, -actor.rotation.y), float(prepared.confirmation_age)) if stage == 2 else Geometry.contains(definition, (candidate - actor.position).rotated(Vector3.UP, -actor.rotation.y))):
			lab.ball.position = candidate
			hit = true
			break
	if not hit:
		if remaining < -Execution.contact_seconds(stage):
			planned = false
		return false
	player_contacts = 0
	var incoming_shot: Dictionary = lab.ball_shot
	var request := ContactRequest.new()
	request.action = stage
	request.response_seed = exchanges + 1
	request.athlete = athlete_for(partner)
	request.actor_id = "pepper_%d" % partner
	request.shape = definition
	request.local_point = (lab.ball.position - actor.position).rotated(Vector3.UP, -actor.rotation.y)
	request.origin = lab.ball.position
	request.incoming = lab.ball_velocity
	request.incoming_shot = incoming_shot
	request.charge = float(prepared.locked_charge)
	request.confirmation_age = float(prepared.confirmation_age)
	request.facing = Vector3.FORWARD.rotated(Vector3.UP, actor.rotation.y)
	request.intent_direction = request.facing
	request.movement_speed = MOVE_SPEED if travelled > 0.001 else 0.0
	request.gravity = lab.GRAVITY
	request.flow = lab.contact_flow.amount(request.actor_id)
	request.keep_attack_intent = true
	# Cooperative target solving uses baseline sweet strength as its reference.
	request.attack_strength_reference = 1.08
	var assessment := ContactResolver.assess(request)
	request.aiming_accuracy = 100.0 if assessment.get("rescue", false) else settings[partner].aiming_accuracy
	request.aim_random = aim_random
	var incoming: Vector3 = lab.ball_velocity
	player_action = next_action(stage, float(assessment.quality))
	var target_height: float = [0.95, 2.25, 3.2][player_action]
	var target: Vector3 = lab.player.position + Vector3.UP * target_height
	var origin: Vector3 = lab.ball.position
	var set_clearance := 0.65 if actor.position.y > ground.y + 0.05 else 0.50
	var apex := maxf(origin.y, target.y) + (0.25 if stage == 2 else (set_clearance if stage == 1 else 0.9))
	var upward := sqrt(2 * lab.GRAVITY * (apex - origin.y))
	var duration: float = (upward + sqrt(upward * upward + 2 * lab.GRAVITY * (origin.y - target.y))) / lab.GRAVITY
	if stage == 2:
		duration = maxf(0.16, Vector2(target.x - origin.x, target.z - origin.z).length() / 24.0)
	lab.ball_velocity = (target - origin) / duration + Vector3.UP * lab.GRAVITY * duration * 0.5
	if stage != 2:
		lab.ball_velocity *= athlete_for(partner).low_stamina_factor()
	if stage != 0:
		lab.ball_velocity *= Preparation.output_factor(lab.contact_flow.attack_charge(float(prepared.locked_charge),"pepper_%d"%partner,lab.ball.position,assessment) if stage == 2 else float(prepared.locked_charge))
	if stage == 2:
		lab.ball_velocity = Influence.constrain_attack(lab.ball_velocity, actor.rotation.y,athlete_for(partner).trait_effect("court_vision"))
	request.base_velocity = lab.ball_velocity
	var result := ContactResolver.resolve(request, assessment)
	lab.ball_velocity = result.velocity
	lab.ball.position += result.separation_offset
	assessment = result.assessment
	last_aim = result.aiming
	lab.ball_shot = ReceiveCharge.shot(["receive", "set", "attack"][stage], lab.contact_flow.attack_charge(float(prepared.locked_charge),"pepper_%d"%partner,lab.ball.position,assessment) if stage == 2 else float(prepared.locked_charge), "pepper_%d" % partner)
	if not result.outgoing_shot.is_empty():
		lab.ball_shot = result.outgoing_shot
	lab.ball_shot = lab.contact_flow.decorate_shot(lab.ball_shot,request.incoming_shot,"pepper_%d"%partner,stage,assessment)
	if stage == 2 and assessment.hit:
		lab.contact_flow.consume_attack("pepper_%d"%partner)
	lab._emit_external_impact("pepper_%d" % partner, stage, incoming, assessment,incoming_shot)
	var local_contact: Vector3 = (lab.ball.position - actor.position).rotated(Vector3.UP, -actor.rotation.y)
	var posture := Geometry.ReceivePlatform.posture(definition, local_contact, MOVE_SPEED if travelled > 0.001 else 0.0) if stage == 0 else "planted"
	var swing_yaw := wrapf(atan2(-lab.ball_velocity.x, -lab.ball_velocity.z) - actor.rotation.y, -PI, PI) if stage == 2 else 0.0
	animation.contact(rig, stage, local_contact, posture, swing_yaw, assessment.get("rescue", false), assessment)
	_animate(0, 0)
	var contact_cost: float = request.athlete.contact_cost(stage,1,assessment,incoming_shot).x
	athlete_for(partner).last_stamina_cost = request.athlete.last_stamina_cost
	spend_stamina(contact_cost,true)
	last_delivery = {"action": stage, "quality": assessment.quality, "required_action": player_action, "target": target, "origin": origin, "velocity": lab.ball_velocity, "duration": duration, "aim": last_aim, "preparation": preparation.evidence(partner), "incoming_shot": incoming_shot, "charge_match": assessment.get("charge_match", {}), "receive_outcome":assessment.get("receive_outcome",{})}
	last_delivery.make_read_only()
	preparation.finish(partner)
	lab.trail_points.clear()
	lab.contacts = 0
	lab.side_contacts.fill(0)
	lab.contact_memory.fill(0.0)
	exchanges += 1
	npc_turn = false
	planned = false
	if stage in [1, 2]:
		recovering = true
		landing_velocity = 0
	lab.selected = player_action
	lab._message("PEPPER / partner %s → your %s" % [lab.ACTIONS[stage], lab.ACTIONS[player_action]])
	return true

func _animate(dt: float, speed: float) -> void:
	var actor := actors[partner]
	var airborne := recovering or (planned and stage in [1, 2] and remaining <= rise_time and jump_height > 0.01)
	var point: Vector3 = (lab.ball.position - actor.position).rotated(Vector3.UP, -actor.rotation.y) if lab.ball_active and planned else Vector3(shape().center)
	if stage == 0 and not Geometry.contains(shape(), point):
		point = shape().center
	var posture := Geometry.ReceivePlatform.posture(shape(), point, speed) if stage == 0 else "planted"
	animation.update(rigs[partner], dt, {"action": stage, "charge": float(preparation.state_for(partner).charge), "planned": planned, "airborne": airborne, "remaining": remaining, "rise": rise_time, "contact_point": point, "posture": posture, "speed": speed, "cycle": movement_cycle, "floor_y": spots[partner].y,"transition_rate":athlete_for(partner).transition_rate()})
