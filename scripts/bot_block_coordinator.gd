extends RefCounted
## Block reads use only visible ball flight, athlete position and facing.
const Policy := preload("res://scripts/bot_contact_policy.gd")
var committed: Dictionary = {}
var observed: Dictionary = {}
var cues: Dictionary = {}
var attempted: Dictionary = {}
var episode := 0

func clear() -> void:
	committed.clear()
	observed.clear()
	cues.clear()
	attempted.clear()

func remove(slot: int) -> void:
	committed.erase(slot)

func airborne(slot: int,bots: Node3D) -> bool:
	return committed.has(slot) and bots.motion.plans.has(slot)

func candidates(bots: Node3D) -> Array[int]:
	var result: Array[int] = []
	if bots.last_was_block: return result
	for slot in committed.keys():
		if bots.slot_enabled(slot) and bots.preparation.state_for(slot).phase == "confirmed" and bots.motion.plans.has(slot): result.append(slot)
	return result

func update(bots: Node3D,dt: float) -> void:
	var lab: Node3D = bots.lab
	if lab.serve.tossing() or lab.station.running() or lab.drills.running() or lab.pepper.active(): return
	for slot in committed.keys():
		if not bots.motion.plans.has(slot):
			committed.erase(slot)
			bots.preparation.finish(slot)
			bots.replan()
	observe_approaches(bots,dt)
	if bots.last_was_block: return
	if str(lab.ball_shot.get("kind","")) == "serve": return
	var origin: Vector3 = lab.ball.position
	var velocity: Vector3 = lab.ball_velocity
	var threat := {}
	var closest := INF
	for cue in cues.values():
		var distance: float = Vector3(cue.position).distance_squared_to(origin)
		if distance < closest:
			closest = distance
			threat = cue
	if threat.is_empty(): return
	var facing: Vector3 = threat.facing
	var threat_position: Vector3 = threat.position
	var defending_away: bool = not bool(threat.away)
	var crossing_time := -1.0
	var crossing := origin
	# Only an observed approach authorizes a jump. After the strike, refine
	# the line using public ball flight; before it, use facing and falling-ball time.
	var struck: bool = str(lab.ball_shot.get("kind","")) == "attack" and str(lab.ball_shot.get("actor","")) == str(threat.actor)
	if struck and absf(velocity.z) > 0.1:
		crossing_time = -origin.z/velocity.z
		crossing = origin+velocity*crossing_time+Vector3.DOWN*lab.GRAVITY*crossing_time*crossing_time*0.5
	else:
		if (origin.z < 0) != bool(threat.away) or closest > 64 or absf(facing.z) < 0.1 or threat_position.z*facing.z >= 0: return
		var until_hit := Policy.contact_time(origin,velocity,3.8,lab.GRAVITY)
		if until_hit < 0: return
		var hit: Vector3 = origin+velocity*until_hit+Vector3.DOWN*lab.GRAVITY*until_hit*until_hit*0.5
		crossing = hit+facing*(-hit.z/facing.z)
		crossing.y = maxf(lab.net_height+0.1,hit.y)
		crossing_time = until_hit+absf(hit.z)/12.0
	if crossing_time <= 0 or crossing_time > 0.85 or crossing.y < lab.net_height-0.3: return
	var group: Array[int] = []
	for slot in range(bots.settings.size()):
		if bots.slot_enabled(slot) and bots.slot_away(slot) == defending_away and bots.settings[slot].can_block(): group.append(slot)
	var spacing := 0.65
	for index in range(group.size()):
		var slot := group[index]
		if committed.has(slot) or attempted.has("%d:%d" % [slot,int(threat.episode)]): continue
		var target := crossing
		target.x = clampf(target.x+(index-(group.size()-1)*0.5)*spacing,lab.court_center.x-lab.court_half_width+0.35,lab.court_center.x+lab.court_half_width-0.35)
		target.z = -0.42 if defending_away else 0.42
		var actor: Node3D = bots.actors[slot]
		if not bots.settings[slot].follows_ball:
			target.x = actor.position.x
			target.z = actor.position.z
		bots.set_execution_action(slot,3)
		bots.returns.release(slot)
		bots.move_targets.erase(slot)
		actor.rotation.y = PI if defending_away else 0.0
		var jump: float = clampf(target.y-bots.contact_anchor(slot).y,0.15,bots._jump_ceiling(slot))
		var accuracy: float = clampf(bots.settings[slot].tracking_accuracy/100.0,0,1)
		var timing_error: float = bots.random.randf_range(-0.22,0.22)*(1.0-accuracy)
		var jump_time := maxf(0.04,crossing_time+timing_error)
		bots.motion.begin(slot,actor,Vector3(target.x,jump,target.z),jump_time,true,lab.GRAVITY,bots.move_speed_for(slot) if bots.settings[slot].moves else -1.0,actor.rotation.y,bots.athlete_for(slot).explosiveness_rate(),3)
		bots.spend_jump(slot)
		bots.preparation.begin(slot,3,{},jump_time,bots.settings[slot].charge_accuracy,bots.charge_random)
		committed[slot] = true
		attempted["%d:%d" % [slot,int(threat.episode)]] = true
		if bots.active_slot == slot: bots.replan()

func observe_approaches(bots: Node3D,dt: float) -> void:
	for key in cues.keys():
		cues[key].age += dt
		if cues[key].age > 3.0: cues.erase(key)
	for slot in range(bots.settings.size()):
		var plan: Dictionary = bots.motion.plans.get(slot,{})
		var running: bool = bots.slot_enabled(slot) and int(plan.get("action",-1)) == 2 and str(plan.get("phase","")) == "approach"
		observe("training_bot_%d" % slot,running,bots.actors[slot].position,bots.actors[slot].rotation.y)
	var motor = bots.lab.motion
	var running: bool = motor.approach_action == 2 and motor.jump_charge >= 0 and not motor.jumped and not motor.generic_jump
	observe("player",running,bots.lab.player.position,bots.lab.player.rotation.y)

func observe(actor: String,running: bool,position: Vector3,yaw: float) -> void:
	if running and not bool(observed.get(actor,false)):
		episode += 1
		cues[actor] = {"actor":actor,"episode":episode,"age":0.0,"away":position.z < 0,"position":position,"facing":Vector3.FORWARD.rotated(Vector3.UP,yaw)}
	if cues.has(actor):
		cues[actor].position = position
		cues[actor].facing = Vector3.FORWARD.rotated(Vector3.UP,yaw)
	observed[actor] = running
