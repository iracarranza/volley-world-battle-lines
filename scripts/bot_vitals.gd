extends RefCounted
## Bots share athlete stamina rules, but never participate in the player Bench.
const Athlete := preload("res://scripts/athlete.gd")

static func create(template: LabAthlete) -> LabAthlete:
	var athlete := Athlete.new()
	athlete.build = template.build.duplicate(true)
	athlete.gameplay_effects = template.gameplay_effects.duplicate(true)
	athlete.gameplay_rules.assign(template.gameplay_rules.duplicate(true))
	athlete.trait_ids.assign(template.trait_ids)
	athlete.trait_via = template.trait_via.duplicate()
	refresh(athlete)
	return athlete

static func refresh(athlete: LabAthlete) -> void:
	athlete.reset_fatigue()
	athlete.refill()

## contact_spend (G-01, MS-16): the contact spend now precedes the publish, so the epoch change is left for ContactFlow.record to see (as for the player),
## otherwise a depleting contact would record a Flow gain on a Winded bot. Everything else here still applies immediately.
static func spend(athlete: LabAthlete,cost: float,flow: Node3D,actor_id: String,resolved: bool = false,contact_spend: bool = false) -> void:
	var epoch := athlete.fatigue_epoch
	if resolved: athlete.spend_resolved(cost)
	else: athlete.spend(cost)
	if athlete.fatigue_epoch != epoch and is_instance_valid(flow):
		if not contact_spend: flow.actor_fatigue_changed(actor_id)
		flow.values[actor_id] = 0.0
		flow.pending_attacks.erase(actor_id)
		flow.pending_jumps.erase(actor_id)
		if flow.auras.has(actor_id): flow.auras[actor_id].hide()
