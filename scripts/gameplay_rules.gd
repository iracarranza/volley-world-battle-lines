extends RefCounted
## Pure preparation, explicit commitment: previews never spend resources.
var cooldowns: Dictionary = {}
var uses: Dictionary = {}
var pending: Dictionary = {}
var allies: Dictionary = {}

func tick(dt: float) -> void:
	for id in cooldowns: cooldowns[id] = maxf(0,float(cooldowns[id])-maxf(0,dt))

func reset() -> void:
	cooldowns.clear()
	uses.clear()
	pending.clear()
	allies.clear()

static func matches(when: Dictionary, event: Dictionary) -> bool:
	for key in ["sweet","rescue","mismatch"]:
		if when.has(key) and bool(when[key]) != bool(event.get(key,false)): return false
	if when.has("incoming_kind") and str(when.incoming_kind) != str(event.get("incoming_shot",{}).get("kind","")): return false
	if float(event.get("quality",1)) < float(when.get("quality_at_least",0)): return false
	if when.has("quality_below") and float(event.get("quality",1)) >= float(when.quality_below): return false
	return true

static func sum_into(target: Dictionary, values: Dictionary) -> void:
	for key in values: target[key] = float(target.get(key,0))+float(values[key])

func prepare(rules: Array, trigger: String, flow: float, event: Dictionary = {}) -> Dictionary:
	var result := {"trigger":trigger,"effects":{},"activations":[],"pending":[],"cost":0.0,"gain":0.0}
	var available := maxf(0,flow)
	for id in pending:
		if pending[id].has(trigger):
			sum_into(result.effects,pending[id][trigger])
			result.pending.append(id)
	for rule in rules:
		var id := str(rule.get("id",""))
		if id.is_empty() or str(rule.get("trigger","")) != trigger: continue
		if float(cooldowns.get(id,0)) > 0 or int(uses.get(id,0)) >= int(rule.get("uses",2147483647)): continue
		if available < float(rule.get("threshold",0)) or not matches(rule.get("when",{}),event): continue
		var consume = rule.get("consume",0)
		var cost := available if str(consume) == "all" else maxf(0,float(consume))
		if cost > available: continue
		available -= cost
		result.cost += cost
		result.gain += float(rule.get("flow_gain",0))
		result.activations.append(rule.duplicate(true))
		sum_into(result.effects,rule.get("effects",{}))
	return result

func commit(context: Dictionary) -> void:
	var trigger := str(context.get("trigger",""))
	for id in context.get("pending",[]):
		if pending.has(id):
			pending[id].erase(trigger)
			if pending[id].is_empty(): pending.erase(id)
	for rule in context.get("activations",[]):
		var id := str(rule.id)
		uses[id] = int(uses.get(id,0))+1
		cooldowns[id] = maxf(0,float(rule.get("cooldown",0)))
		for action in rule.get("pending",{}):
			if not pending.has(id): pending[id] = {}
			pending[id][action] = rule.pending[action].duplicate(true)

func clear_flow(rules: Array, reason: String) -> bool:
	for rule in rules:
		if reason in rule.get("clear_on",[]): return true
	return false
