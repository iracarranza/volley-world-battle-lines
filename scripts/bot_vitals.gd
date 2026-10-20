extends RefCounted
## Bots share athlete stamina rules, but never participate in the player Bench.
const Athlete := preload("res://scripts/athlete.gd")

static func create(template: LabAthlete) -> LabAthlete:
	var athlete := Athlete.new()
	athlete.build = template.build.duplicate(true)
	athlete.trait_ids.assign(template.trait_ids)
	refresh(athlete)
	return athlete

static func refresh(athlete: LabAthlete) -> void:
	athlete.reset_fatigue()
	athlete.stamina = athlete.max_stamina()
	athlete.hp = 100.0

static func spend(athlete: LabAthlete,cost: float,flow: Node3D,actor_id: String) -> void:
	var epoch := athlete.fatigue_epoch
	athlete.spend(cost)
	if athlete.fatigue_epoch != epoch and is_instance_valid(flow):
		flow.values[actor_id] = 0.0
		flow.pending_attacks.erase(actor_id)
		flow.pending_jumps.erase(actor_id)
		if flow.auras.has(actor_id): flow.auras[actor_id].hide()
