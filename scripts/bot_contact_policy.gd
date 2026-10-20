extends RefCounted
## Responsibility and recipient policy; no hidden opponent action inputs are read here.
static func floor_intersection(point: Vector3,velocity: Vector3,gravity: float) -> Dictionary:
	var height := maxf(point.y-0.105,0)
	var time := (velocity.y+sqrt(maxf(0,velocity.y*velocity.y+2*gravity*height)))/gravity
	return {"point":point+velocity*time+Vector3.DOWN*gravity*time*time*0.5,"time":time}

static func contact_time(point: Vector3,velocity: Vector3,height: float,gravity: float) -> float:
	var disc := velocity.y*velocity.y+2*gravity*(point.y-height)
	return (velocity.y+sqrt(disc))/gravity if disc >= 0 else -1.0

static func recipient(bots: Node3D,slot: int,contact: int) -> Dictionary:
	var config = bots.settings[slot]
	var next := contact+1
	var anchor: Vector3 = bots.receive_target(config.net_index,config.away) if contact == 1 else bots.set_delivery_target(config.net_index,config.away)
	if next > 3: return {"kind":"opponent","slot":-1,"anchor":bots.opposing_target(slot)}
	var best := -1
	var best_score := INF
	for candidate in range(bots.settings.size()):
		if candidate == slot or not bots.slot_enabled(candidate) or bots.slot_away(candidate) != config.away: continue
		var actions: Dictionary = bots.actions_for(candidate)
		if not actions.has(next): continue
		# First contacts prefer a designated second-contact setter, then proximity.
		var score: float = bots.actors[candidate].position.distance_squared_to(anchor)
		if contact == 1 and int(actions[next]) != 1: score += 100000.0
		if score < best_score:
			best_score = score
			best = candidate
	if best >= 0: return {"kind":"bot","slot":best,"anchor":anchor,"action":int(bots.actions_for(best)[next])}
	if bots.player_available(config.away):
		return {"kind":"player","slot":-1,"anchor":bots.lab.player.position if contact == 1 else anchor,"action":1 if contact == 1 else 2}
	if bots.actions_for(slot).has(next): return {"kind":"self","slot":slot,"anchor":anchor,"action":int(bots.actions_for(slot)[next])}
	return {"kind":"opponent","slot":-1,"anchor":bots.opposing_target(slot)}
