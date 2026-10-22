extends RefCounted
## Physical receive attempts. Running reach selects dives; normal contact geometry still awards hits.
const Stage := preload("res://scripts/dive_stage.gd")
const Recovery := preload("res://scripts/dive_recovery.gd")
const Platform := preload("res://scripts/receive_platform.gd")
const Policy := preload("res://scripts/bot_contact_policy.gd")
var plans: Dictionary = {}
func clear() -> void: plans.clear()
func remove(slot: int) -> void: plans.erase(slot)
func busy(slot: int) -> bool: return plans.has(slot)
func active(slot: int) -> bool: return busy(slot) and not plans[slot].has("recovery")

func offer(bots: Node3D,slot: int,point: Vector3,time: float,yaw: float) -> Dictionary:
	if not bots.settings[slot].moves or not bots.settings[slot].follows_ball: return {}
	var actor: Node3D = bots.actors[slot]
	var standing := Platform.definition(float(bots.athlete_for(slot).body_height()),false,0,bots.athlete_for(slot).build)
	var target := point-Vector3(standing.center).rotated(Vector3.UP,yaw)
	var distance := Vector2(target.x-actor.position.x,target.z-actor.position.z).length()
	var low := point.y < float(standing.center.y)-float(standing.size.y)*0.5+0.15
	if distance <= bots.move_speed_for(slot)*time+0.15 and not low: return {}
	var shape := Platform.definition(float(bots.athlete_for(slot).body_height()),true,0,bots.athlete_for(slot).build)
	var later := Policy.contact_time(bots.lab.ball.position,bots.lab.ball_velocity,maxf(0.15,float(shape.center.y)),bots.lab.GRAVITY)
	if later >= time and later <= time+0.6:
		time = later
		point = bots.lab.ball.position+bots.lab.ball_velocity*time+Vector3.DOWN*bots.lab.GRAVITY*time*time*0.5
	if (point.z < 0) != bots.slot_away(slot): return {}
	return {"point":point,"time":time}

func begin(bots: Node3D,slot: int,target: Vector3,time: float) -> void:
	var actor: Node3D = bots.actors[slot]
	var delta := Vector3(target.x-actor.position.x,0,target.z-actor.position.z)
	var speed: float = bots.move_speed_for(slot)*1.6*bots.athlete_for(slot).explosiveness_rate()*bots.athlete_for(slot).low_stamina_factor()
	var direction := delta.normalized() if delta.length_squared() > 0.001 else Vector3.FORWARD.rotated(Vector3.UP,actor.rotation.y)
	plans[slot] = {"elapsed":0.0,"contact":maxf(0.08,time),"duration":maxf(0.12,time/Stage.CONTACT_FRACTION),"target":Vector3(target.x,0,target.z),"speed":speed,"direction":direction,"local_direction":Stage.local_direction(direction,actor.rotation.y),"quality":0.65,"contacted":false}
	bots.move_targets.erase(slot)
	bots.spend_jump(slot)

func contacted(slot: int) -> void:
	if busy(slot): plans[slot].contacted = true

func tick(bots: Node3D,dt: float,scales: Dictionary) -> void:
	var finished := false
	for slot in plans.keys():
		if not bots.slot_enabled(slot):
			remove(slot)
			continue
		var plan: Dictionary = plans[slot]
		var step: float = dt*float(scales.get(slot,1))
		var actor: Node3D = bots.actors[slot]
		plan.elapsed += step
		if not plan.has("recovery"):
			var ground := Vector3(actor.position.x,0,actor.position.z)
			if float(plan.elapsed) <= float(plan.contact):
				actor.position = ground.move_toward(plan.target,float(plan.speed)*step)
			else:
				actor.position = ground+Vector3(plan.direction)*float(plan.speed)*0.25*step
			actor.position.y = 0.12*sin(clampf(float(plan.elapsed)/float(plan.duration),0,1)*PI)
			if float(plan.elapsed) >= float(plan.duration):
				plan["recovery"] = 0.0
				plan["root"] = Vector2(bots.rigs[slot].body.rotation.x,bots.rigs[slot].body.rotation.z)
		else:
			plan.recovery += step*bots.athlete_for(slot).transition_rate()
			actor.position.y = 0
			if float(plan.recovery) >= Recovery.duration(float(plan.quality)):
				remove(slot)
				finished = true
	if finished and bots.lab.ball_active and bots.active_slot < 0: bots.replan()

func context(slot: int) -> Dictionary:
	if not busy(slot): return {}
	var plan: Dictionary = plans[slot]
	var result := {"dive_direction":plan.local_direction,"dive_quality":plan.quality,"floor_y":0.0}
	if plan.has("recovery"):
		result.merge({"dive_recovery_time":plan.recovery,"dive_root":plan.root})
	else:
		result["dive_phase"] = Stage.phase_for(0,float(plan.elapsed),float(plan.duration),true)
	return result
