extends "res://scripts/training_bots.gd"
## Generic athletes. Responsibilities select actions; identity and placement stay stable.
const Policy := preload("res://scripts/bot_contact_policy.gd")
const Blocks := preload("res://scripts/bot_block_coordinator.gd")
const MAX_PER_NET_SIDE := 5
const MAX_PER_TEAM := 14
const POOL_SIZE := MAX_PER_TEAM*2
var current_net := 1
var last_error := ""
var receive_targets: Dictionary = {}
var set_targets: Dictionary = {}
var shape_templates: Array[Dictionary] = []
var mesh_templates: Array[Mesh] = []
var execution_actions: Dictionary = {}
var support_targets: Dictionary = {}
var delivery_owner: Dictionary = {}
var last_delivery: Dictionary = {}
var blocks := Blocks.new()

func _init() -> void:
	settings.clear()
	for slot in range(POOL_SIZE):
		var config := BotSettings.new()
		config.action_type = slot%4
		config.away = slot >= 4
		config.net_index = 1
		config.moves = false
		config.contact_order = (slot%4+1)%4
		settings.append(config)

func courts() -> Dictionary:
	return lab.bot_courts()

func court(index: int) -> Dictionary:
	return courts().get(index,{})

func actions_for(slot: int) -> Dictionary:
	return settings[slot].contact_actions()

func generic_mode() -> bool:
	return settings.any(func(config: BotSettings): return config.enabled and config.responsibility_mode)

func slot_action(slot: int) -> int:
	return int(execution_actions.get(slot,settings[slot].action_type))

func slot_away(slot: int) -> bool:
	return settings[slot].away

func slot_enabled(slot: int) -> bool:
	return settings[slot].enabled and settings[slot].net_index == current_net

func responsible_for(slot: int,contact: int,action: int) -> bool:
	return settings[slot].can_block() if action == 3 else int(actions_for(slot).get(contact,-1)) == action

func slot_for(action: int,z: float) -> int:
	for slot in range(settings.size()):
		if not slot_enabled(slot) or slot_away(slot) != (z < 0): continue
		if (action == 3 and settings[slot].can_block()) or (action != 3 and action in actions_for(slot).values()): return slot
	return -1

func is_enabled(action: int,z: float) -> bool:
	return slot_for(action,z) >= 0

func has_teammates(side: int) -> bool:
	for slot in range(settings.size()):
		if slot_enabled(slot) and int(slot_away(slot)) == side: return true
	return false

func setup(owner_lab: Node3D) -> void:
	super.setup(owner_lab)
	for action in range(4):
		shape_templates.append(shapes[action].duplicate(true))
		mesh_templates.append(contact_boxes[action].mesh)

func set_execution_action(slot: int,action: int) -> void:
	execution_actions[slot] = action
	shapes[slot] = shape_templates[action].duplicate(true)
	contact_boxes[slot].mesh = mesh_templates[action]
	contact_boxes[slot].scale = Vector3.ONE
	contact_boxes[slot].position = shapes[slot].center
	for child in contact_boxes[slot].get_children(): child.hide()

func count_net(index: int,except_slot: int = -1) -> int:
	var count := 0
	for slot in range(settings.size()):
		if slot != except_slot and settings[slot].enabled and settings[slot].net_index == index: count += 1
	return count

func count_net_side(index: int,away: bool,except_slot: int = -1) -> int:
	var count := 0
	for slot in range(settings.size()):
		if slot != except_slot and settings[slot].enabled and settings[slot].net_index == index and settings[slot].away == away: count += 1
	return count

func count_team(away: bool,except_slot: int = -1) -> int:
	var count := 0
	for slot in range(settings.size()):
		if slot != except_slot and settings[slot].enabled and settings[slot].away == away: count += 1
	return count

func validate_assignment(slot: int,away: bool,index: int,action: int = 0,order: int = 1) -> bool:
	last_error = ""
	if slot < 0 or slot >= settings.size() or (index != -1 and not courts().has(index)) or action not in [0,1,2,3] or order not in [0,1,2,3]:
		last_error = "Invalid bot assignment"
	elif index >= 0 and count_net_side(index,away,slot) >= MAX_PER_NET_SIDE:
		last_error = "Net %d already has five %s bots" % [index+1,"Away" if away else "Home"]
	elif count_team(away,slot) >= MAX_PER_TEAM:
		last_error = "%s team already has fourteen bots" % ("Away" if away else "Home")
	return last_error.is_empty()

func playable_bounds(index: int,away: bool) -> Dictionary:
	var net := court(index)
	var width: float = lab.court_half_width if index == current_net else float(net.width)/2
	var depth: float = lab.court_half_depth if index == current_net else float(net.depth)/2
	return {"center":Vector3(net.position),"half_width":width,"half_depth":depth,"side":-1.0 if away else 1.0}

func receive_target(index: int,away: bool) -> Vector3:
	var key := "%d:%s" % [index,away]
	if receive_targets.has(key): return receive_targets[key]
	var bounds := playable_bounds(index,away)
	return Vector3(bounds.center)+Vector3(0,0,float(bounds.side)*float(bounds.half_depth)*0.5)

func set_delivery_target(index: int,away: bool) -> Vector3:
	var key := "%d:%s" % [index,away]
	if set_targets.has(key): return set_targets[key]
	var net := court(index)
	var side := -1.0 if away else 1.0
	var diagonal := 0.5/sqrt(2.0)
	return Vector3(net.position)+Vector3(side*(-float(net.width)/2+diagonal),0,side*diagonal)

func _capture_receive_target() -> void:
	var away: bool = lab.player.position.z < 0
	receive_targets["%d:%s" % [current_net,away]] = _safe_home(lab.player.position,away)
	lab._message("RECEIVE BOT TARGET / Net %d %s / Shift+F6 retargets" % [current_net+1,"Away" if away else "Home"])

func _capture_set_target() -> void:
	var away: bool = lab.player.position.z < 0
	set_targets["%d:%s" % [current_net,away]] = _safe_home(lab.player.position,away)
	# Retain the original target accessor for old debug fixtures.
	set_target = Vector3(lab.player.position.x,3.8,absf(lab.player.position.z))
	set_target_locked = true
	lab._message("SET BOT TARGET / Net %d %s / F6 retargets" % [current_net+1,"Away" if away else "Home"])

func _safe_home(point: Vector3,away: bool) -> Vector3:
	var side := -1.0 if away else 1.0
	return Vector3(point.x,0,maxf(0.5,point.z*side)*side)

func label_for(slot: int) -> String:
	var config := settings[slot]
	var plan: Array[String] = []
	for contact in [1,2,3]:
		if actions_for(slot).has(contact): plan.append("%d:%s" % [contact,NAMES[int(actions_for(slot)[contact])]])
	if config.can_block(): plan.append("BLOCK")
	return "#%d · %s · %s · %s" % [slot+1,"AWAY" if config.away else "HOME","UNASSIGNED" if config.net_index < 0 else "NET %d" % (config.net_index+1)," / ".join(plan)]

func _place(slot: int,point: Vector3) -> void:
	motion.plans.erase(slot)
	move_targets.erase(slot)
	support_targets.erase(slot)
	returns.release(slot)
	preparation.finish(slot)
	animation.states.erase(rigs[slot].body.get_instance_id())
	rigs[slot].body.rotation = Vector3.ZERO
	Motion.Pose.base(rigs[slot].body,0,0,0,false)
	Motion.Pose.ground_feet(rigs[slot].body)
	actors[slot].position = point
	actors[slot].rotation.y = PI if slot_away(slot) else 0.0
	settings[slot].fixed_position = point
	actors[slot].show()
	captions[slot].text = label_for(slot)
	captions[slot].modulate = Color("74dacd") if not slot_away(slot) else Color("ffb46e")

func assign_responsibilities(slot: int,away: bool,index: int,plan: Dictionary,blocking: bool,force_place: bool = false) -> bool:
	if not validate_assignment(slot,away,index): return false
	if plan.is_empty() and not blocking:
		last_error = "Assign a contact responsibility or enable Block"
		return false
	for contact in plan:
		if contact not in [1,2,3] or int(plan[contact]) not in [0,1,2]:
			last_error = "Invalid contact responsibility"
			return false
	var config := settings[slot]
	var saved_home := config.fixed_position
	var moved: bool = force_place or not config.enabled or config.away != away or config.net_index != index
	if not config.enabled:
		config.moves = true
		Vitals.refresh(athlete_for(slot))
	config.enabled = true
	config.away = away
	config.net_index = index
	config.responsibility_mode = true
	config.responsibilities = plan.duplicate()
	config.block_enabled = blocking
	config.action_type = int(plan.values()[0]) if not plan.is_empty() else 3
	config.contact_order = 0
	set_execution_action(slot,config.action_type)
	lab._resize_court()
	_place(slot,receive_target(index,away) if moved and index >= 0 else actors[slot].position)
	if not moved: config.fixed_position = saved_home
	lab._resize_court()
	replan()
	return true

func edit_responsibilities(slot: int,away: bool,index: int,plan: Dictionary,blocking: bool) -> bool:
	return assign_responsibilities(slot,away,index,plan,blocking)

func summon_generic(away: bool,index: int,plan: Dictionary,blocking: bool,at_player: bool = false) -> int:
	for slot in range(settings.size()):
		if settings[slot].enabled: continue
		if not assign_responsibilities(slot,away,index,plan,blocking,true): return -1
		if at_player: _place(slot,lab.player.position)
		return slot
	last_error = "Both team rosters are full"
	return -1

func spawn_at_player() -> void:
	var slot := summon_generic(lab.player.position.z < 0,-1,{1:0,2:1,3:2},false,true)
	lab._message("BOT #%d summoned here / I settings / assign a net and side" % (slot+1) if slot >= 0 else last_error)

func place_at_player(slot: int) -> void:
	_place(slot,_safe_home(lab.player.position,slot_away(slot)) if settings[slot].net_index >= 0 else lab.player.position)
	replan()

func dismiss(slot: int) -> void:
	block_states.erase(slot)
	if is_instance_valid(lab.contact_flow): lab.contact_flow.clear_actor("training_bot_%d" % slot)
	settings[slot].enabled = false
	actors[slot].hide()
	motion.plans.erase(slot)
	move_targets.erase(slot)
	support_targets.erase(slot)
	returns.release(slot)
	preparation.finish(slot)
	blocks.remove(slot)
	replan()

func spawn_position(slot: int) -> Vector3:
	return settings[slot].fixed_position

func reset() -> void:
	blocks.clear()
	support_targets.clear()
	delivery_owner.clear()
	super.reset()
	for slot in range(settings.size()):
		actors[slot].visible = settings[slot].enabled
		captions[slot].text = label_for(slot)

func on_rally_end() -> void:
	blocks.clear()
	support_targets.clear()
	delivery_owner.clear()
	last_delivery.clear()
	super.on_rally_end()

func idle_return_enabled(slot: int) -> bool:
	return not generic_mode() and super.idle_return_enabled(slot)

func player_available(away: bool) -> bool:
	if lab.is_benched() or lab.athlete.exhausted or (lab.player.position.z < 0) != away: return false
	var bounds := playable_bounds(current_net,away)
	return absf(lab.player.position.x-Vector3(bounds.center).x) <= float(bounds.half_width)+1.5 and absf(lab.player.position.z) <= float(bounds.half_depth)+1.5

func opposing_target(slot: int) -> Vector3:
	var bounds := playable_bounds(current_net,slot_away(slot))
	return Vector3(bounds.center)+Vector3(0,0,-float(bounds.side)*float(bounds.half_depth)*0.65)

func can_take(slot: int,contact: int) -> bool:
	if not slot_enabled(slot) or not actions_for(slot).has(contact): return false
	return not blocks.airborne(slot,self)

func replan(skip_block: bool = false) -> void:
	if not generic_mode():
		super.replan(skip_block)
		return
	active_slot = -1
	active_action = -1
	move_targets.clear()
	if not lab.ball_active or (is_instance_valid(lab.serve) and lab.serve.tossing()) or (is_instance_valid(lab.station) and lab.station.running()) or (is_instance_valid(lab.drills) and lab.drills.running()) or (is_instance_valid(lab.pepper) and lab.pepper.active()): return
	var landing := Policy.floor_intersection(lab.ball.position,lab.ball_velocity,lab.GRAVITY)
	var side: int = lab.side_index(Vector3(landing.point).z)
	var current_side: int = lab.side_index(lab.ball.position.z)
	if incoming_action in [0,1] and lab.side_contacts[current_side] in [1,2] and last_delivery.get("kind","") in ["bot","player","self"]:
		side = current_side
	var contact: int = (lab.side_contacts[side] if lab.side_index(lab.ball.position.z) == side else 0)+1
	if contact > 3: return
	var owner := -1
	var distance := INF
	var hinted: int = int(delivery_owner.get(side,-1)) if contact > 1 else -1
	for slot in range(settings.size()):
		if not can_take(slot,contact) or int(slot_away(slot)) != side: continue
		var next: float = actors[slot].position.distance_squared_to(landing.point)
		if slot == hinted:
			owner = slot
			break
		if next < distance:
			distance = next
			owner = slot
	if owner < 0: return
	var action: int = actions_for(owner)[contact]
	set_execution_action(owner,action)
	var height: float = HEIGHTS[action]
	if action == 1 and settings[owner].moves:
		var apex: float = lab.ball.position.y+maxf(lab.ball_velocity.y,0)*maxf(lab.ball_velocity.y,0)/(2*lab.GRAVITY)
		height = clampf(apex-0.08,contact_anchor(owner).y+0.25,contact_anchor(owner).y+minf(0.9,_jump_ceiling(owner)))
	var time := Policy.contact_time(lab.ball.position,lab.ball_velocity,height,lab.GRAVITY)
	if time < 0.025:
		# Assigned attacks/sets still attempt a physical jump on an unreachable ball.
		time = clampf(float(landing.time)*0.7,0.15,0.65)
	var point: Vector3 = lab.ball.position+lab.ball_velocity*time+Vector3.DOWN*lab.GRAVITY*time*time*0.5
	_plan(action,point,time,owner)

func _plan(action: int,point: Vector3,time: float,chosen_slot: int = -1) -> void:
	var slot := chosen_slot if chosen_slot >= 0 else slot_for(action,point.z)
	if slot < 0 and not generic_mode(): slot = action+(4 if point.z < 0 else 0)
	if slot < 0: return
	set_execution_action(slot,action)
	super._plan(action,point,time,slot)
	if generic_mode() and action == 1:
		var heading := setter_direction(slot,actors[slot].position)
		if heading.length_squared() > 0: actors[slot].rotation.y = atan2(-heading.x,-heading.z)

func setter_direction(slot: int,origin: Vector3) -> Vector3:
	if not generic_mode(): return super.setter_direction(slot,origin)
	var delivery := intended_delivery(slot,maxi(1,lab.side_contacts[int(slot_away(slot))]+(0 if resolving_contact else 1)))
	var direction: Vector3 = delivery.target-origin
	direction.y = 0
	return direction.normalized()

func intended_delivery(slot: int,requested_contact: int = -1) -> Dictionary:
	var contact: int = lab.side_contacts[int(slot_away(slot))] if requested_contact < 0 else requested_contact
	# The executor increments the team count before resolving the contact.
	contact = maxi(1,contact)
	var route := Policy.recipient(self,slot,contact)
	var target: Vector3 = route.anchor
	if route.kind == "bot":
		var receiver: int = route.slot
		if contact == 1:
			target = actors[receiver].position.move_toward(target,move_speed_for(receiver)*1.0) if settings[receiver].moves else actors[receiver].position
		support_targets[receiver] = target
		delivery_owner[int(slot_away(slot))] = receiver
	elif route.kind == "self":
		var delta := target-actors[slot].position
		delta.y = 0
		target = actors[slot].position+delta.limit_length(maxf(1.0,move_speed_for(slot)*0.8))
		if target.distance_to(actors[slot].position) < 0.65:
			target += Vector3(0,0,-1 if slot_away(slot) else 1)*0.8
		support_targets[slot] = target
		delivery_owner[int(slot_away(slot))] = slot
	route["target"] = target
	return route

func _launch(action: int,firing_slot: int = -1) -> void:
	if not generic_mode() or action in [2,3]:
		super._launch(action,firing_slot if firing_slot >= 0 else action+(4 if lab.ball.position.z < 0 else 0))
		return
	var slot := firing_slot
	net_rebound = false
	last_delivery = intended_delivery(slot)
	var origin: Vector3 = lab.ball.position
	var target: Vector3 = last_delivery.target
	var next_action := int(last_delivery.get("action",0))
	target.y = 0.105 if last_delivery.kind == "opponent" else (2.8 if next_action == 2 else (2.3 if next_action == 1 else 1.0))
	var peak: float = _bump_ceiling(origin.y) if action == 0 else maxf(origin.y+0.35,_bump_ceiling(1.0))*lab.SET_RISE_FACTOR
	peak = maxf(peak,target.y+0.5)
	var up := sqrt(2*lab.GRAVITY*maxf(0.1,peak-origin.y))
	var time: float = (up+sqrt(maxf(0,up*up+2*lab.GRAVITY*(origin.y-target.y))))/lab.GRAVITY
	lab.ball_velocity = (target-origin)/maxf(time,0.1)+Vector3.UP*lab.GRAVITY*time*0.5

func tick_motion(dt: float) -> void:
	if generic_mode() and lab.ball_active: blocks.update(self,dt*lab.moc.simulation_scale())
	super.tick_motion(dt)

func tick_support_motion(dt: float,scales: Dictionary) -> void:
	if generic_mode():
		for slot in support_targets.keys():
			if not slot_enabled(slot) or returns.contains(slot) or motion.plans.has(slot) or active_slot == slot or not settings[slot].moves: continue
			var ground: Vector3 = support_targets[slot]
			ground.y = actors[slot].position.y
			actors[slot].position = actors[slot].position.move_toward(ground,move_speed_for(slot)*dt*float(scales.get(slot,1.0)))

func tick(dt: float) -> bool:
	if not generic_mode(): return super.tick(dt)
	tick_motion(dt)
	var ordinary := {"slot":active_slot,"action":active_action,"point":intercept,"remaining":remaining}
	for slot in blocks.candidates(self):
		active_slot = slot
		active_action = 3
		intercept = lab.ball.position
		remaining = 0
		if tick_contact(dt):
			if not block_state_for(slot).active: blocks.remove(slot)
			return true
	active_slot = ordinary.slot
	active_action = ordinary.action
	intercept = ordinary.point
	remaining = ordinary.remaining
	return tick_contact(dt)

# Old role presets are migration/automation adapters, not generic bot identities.
func summon(away: bool,index: int,action: int,order: int) -> int:
	for slot in range(settings.size()):
		if not settings[slot].enabled:
			settings[slot].moves = true
			return slot if assign(slot,away,index,action,order) else -1
	return -1

func assign(slot: int,away: bool,index: int,action: int,order: int) -> bool:
	if not validate_assignment(slot,away,index,action,order): return false
	var config := settings[slot]
	config.enabled = true
	config.away = away
	config.net_index = index
	config.responsibility_mode = false
	config.action_type = action
	config.contact_order = order
	set_execution_action(slot,action)
	var net := court(index)
	_place(slot,Vector3(net.position)+Vector3(-3+action*2,0,(-1 if away else 1)*(1 if action in [1,3] else 5)))
	replan()
	return true

func toggle(action: int,away: bool = false) -> void:
	var slot := action+(4 if away else 0)
	if settings[slot].enabled:
		dismiss(slot)
		return
	assign(slot,away,current_net,action,(action+1)%4)
	lab._resize_court()

func ensure_receiver(home: bool = false) -> void:
	for candidate in range(settings.size()):
		if slot_enabled(candidate) and slot_away(candidate) == (not home) and actions_for(candidate).has(1): return
	var preferred := 0 if home else 4
	if not settings[preferred].enabled:
		assign_responsibilities(preferred,not home,current_net,{1:0,2:1,3:2},false,true)
	else:
		summon_generic(not home,current_net,{1:0,2:1,3:2},false)

func toggle_all() -> void:
	# Isolated legacy fixtures retain their old preset. G now summons one bot.
	if courts().size() == 1:
		if all_enabled(true):
			for slot in range(settings.size()):
				if settings[slot].enabled: dismiss(slot)
			lab._resize_court()
			return
		for slot in [0,1,2,4,5,6,7]:
			var action: int = int(slot)%4
			var config := settings[slot]
			config.enabled = true
			config.away = slot >= 4
			config.net_index = current_net
			config.action_type = action
			config.contact_order = (action+1)%4
			config.responsibility_mode = false
			set_execution_action(slot,action)
			_place(slot,Vector3(lab.court_center.x-3+action*2,0,(-1 if slot >= 4 else 1)*(0.7 if action == 3 else (1.7 if action == 1 else 5.0))))
		lab._resize_court()
	else:
		for slot in range(settings.size()):
			if slot_enabled(slot): dismiss(slot)

func all_enabled(away: bool) -> bool:
	return [0,1,2,3].all(func(action: int): return is_enabled(action,-1 if away else 1))

func disable_side(away: bool) -> void:
	for slot in range(settings.size()):
		if slot_enabled(slot) and slot_away(slot) == away: dismiss(slot)
