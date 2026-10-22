extends RefCounted
## Returning is independent of Follow/Static/Move and never rewrites saved homes.
var falling: Dictionary = {}
var slots: Dictionary = {}
var pending: Dictionary = {}

func clear() -> void:
	pending.clear()
	slots.clear()
	falling.clear()

func begin(bots: Node3D) -> void:
	clear()
	for slot in range(bots.settings.size()):
		if not bots.settings[slot].enabled: continue
		slots[slot] = true
		falling[slot] = 0.0
		if is_instance_valid(bots.lab.contact_flow):
			bots.lab.contact_flow.impulses.erase("training_bot_%d" % slot)

func request(slot: int) -> void:
	pending[slot] = true

func release(slot: int) -> void:
	pending.erase(slot)
	slots.erase(slot)
	falling.erase(slot)

func contains(slot: int) -> bool:
	return slots.has(slot) or pending.has(slot)

func net_clear(bots: Node3D) -> bool:
	for slot in range(bots.settings.size()):
		if bots.settings[slot].enabled and bots.lab.athlete_touches_net(bots.actors[slot].position,bots.actors[slot].position,bots.physique.build.height):
			return false
	return true

func tick(bots: Node3D,dt: float) -> void:
	for slot in pending.keys():
		if not bots.settings[slot].enabled:
			release(slot)
			continue
		if bots.motion.plans.has(slot) or bots.dives.busy(slot) or bots.active_slot == slot: continue
		pending.erase(slot)
		slots[slot] = true
		falling[slot] = 0.0
	for slot in slots.keys():
		if not bots.settings[slot].enabled:
			release(slot)
			continue
		var step: float = dt*bots.lab.moc.bot_scale("training_bot_%d"%slot)
		var actor: Node3D = bots.actors[slot]
		var home: Vector3 = bots.settings[slot].fixed_position
		var speed := maxf(3.0,float(bots.settings[slot].move_speed))
		var before := actor.position
		var point := Vector3(actor.position.x,0,actor.position.z).move_toward(Vector3(home.x,0,home.z),speed*step)
		falling[slot] = float(falling.get(slot,0))-bots.lab.GRAVITY*step
		point.y = maxf(home.y,actor.position.y+float(falling[slot])*step)
		actor.position = point
		bots.Motion.Pose.base(bots.rigs[slot].body,float(bots.motion_clocks.get(slot,0))*8.0,Vector2(point.x-before.x,point.z-before.z).length()/maxf(step,0.001),0,false)
		bots.Motion.Pose.ground_feet(bots.rigs[slot].body)
		if actor.position.distance_to(home) < 0.025:
			actor.position = home
			release(slot)
