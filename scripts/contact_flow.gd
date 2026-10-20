extends Node3D

const CAP := 100.0
const DECAY_DELAY := 14.0
const DECAY_HALF_LIFE := 8.0
const RuleState := preload("res://scripts/gameplay_rules.gd")
var rule_states: Dictionary = {}
var fatigue_epochs: Dictionary = {}
var idle_seconds: Dictionary = {}
const POOR_QUALITY := 0.40
var lab: Node3D
var actors: Dictionary = {}
var values: Dictionary = {}
var auras: Dictionary = {}
var impulses: Dictionary = {}
var recent: Array[String] = []
var last_changes: Dictionary = {}
var pending_attacks: Dictionary = {}
var pending_jumps: Dictionary = {}
var seen_fatigue := 0
var aura_mesh: QuadMesh
var aura_shader: Shader

static func change_for(event: Dictionary) -> float:
	if not bool(event.get("physical_hit",false)):
		return 0.0
	var quality := clampf(float(event.get("quality",0.75)),0,1)
	var mismatch: Dictionary = event.get("charge_match",{})
	var severity := float(mismatch.get("severity",0))
	var poor := quality < POOR_QUALITY or severity >= 0.5
	if poor:
		return -lerpf(5.0,25.0,maxf(1.0-quality,severity))
	if bool(event.get("sweet",false)) and bool(mismatch.get("matched",true)):
		return 25.0
	var execution := quality*(1.0-severity)
	if bool(event.get("rescue",false)):
		execution *= 0.5
	return lerpf(1.0,24.0,clampf((execution-POOR_QUALITY)/(1.0-POOR_QUALITY),0,1))

static func knockback_for(event: Dictionary, center: Vector3) -> Dictionary:
	var match_result: Dictionary = event.get("charge_match",{})
	if int(event.get("action",-1)) != 0 or not event.get("physical_hit",false) or match_result.get("status","") != "undercharged":
		return {}
	var incoming: Vector3 = event.get("incoming_velocity",Vector3.ZERO)
	var path := Vector3(incoming.x,0,incoming.z)
	var severity := clampf(float(match_result.get("severity",0)),0,1)
	if path.length() < 0.01 or severity <= 0:
		return {}
	var tangent := path.normalized().cross(Vector3.UP)
	var point: Vector3 = event.get("point",center)
	var offset := clampf((point-center).dot(tangent)/0.9,-1,1)
	var direction := (path.normalized()+tangent*offset*0.55).normalized()
	var speed := minf(7.0,path.length()*0.28)*severity
	return {"velocity":direction*speed,"duration":0.18+0.42*severity,"remaining":0.18+0.42*severity,"direction":direction,"severity":severity,"tangential_offset":offset}

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	seen_fatigue = lab.athlete.fatigue_epoch
	actors["player"] = lab.player
	for slot in range(lab.training_bots.actors.size()):
		actors["training_bot_%d" % slot] = lab.training_bots.actors[slot]
	for index in range(3):
		actors["pepper_%d" % index] = lab.pepper.actors[index]
	aura_mesh = QuadMesh.new()
	aura_mesh.size = Vector2(1.7,2.35)
	aura_shader = Shader.new()
	aura_shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float flow = 0.0;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
}
void fragment() {
 float y = 1.0-UV.y;
 float wave = sin(UV.x*35.0+TIME*4.0)+0.45*sin(UV.x*67.0-TIME*6.0);
 float tip = 0.62+0.15*wave;
 float edge = abs(UV.x-0.5)*2.0;
 float width = 0.76-0.30*y+0.06*sin(y*20.0-TIME*7.0);
 float outer = 1.0-smoothstep(width-0.12,width,edge);
 float hollow = smoothstep(0.20,0.57,edge);
 float flame = outer*(0.25+0.75*hollow)*(1.0-smoothstep(tip-0.20,tip,y))*smoothstep(0.0,0.12,y);
 ALBEDO = mix(vec3(0.12,0.85,0.75),vec3(1.0,0.68,0.16),y);
 ALPHA = flame*flow*0.38;
}
"""
	for actor_id in actors:
		values[actor_id] = 0.0
		idle_seconds[actor_id] = 0.0
		var aura := MeshInstance3D.new()
		aura.mesh = aura_mesh
		var material := ShaderMaterial.new()
		material.shader = aura_shader
		aura.material_override = material
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(aura)
		aura.visible = false
		auras[actor_id] = aura
	for actor_id in actors:
		bind_profile(actor_id)
		fatigue_epochs[actor_id] = profile(actor_id).fatigue_epoch
	_warm.call_deferred()

func _warm() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var warm := MeshInstance3D.new()
	warm.mesh = aura_mesh
	var material := ShaderMaterial.new()
	material.shader = aura_shader
	material.set_shader_parameter("flow",0.00001)
	warm.material_override = material
	add_child(warm)
	warm.global_position = lab.camera.global_position-lab.camera.global_basis.z*2
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	warm.queue_free()

func amount(actor_id: String) -> float:
	return lab.athlete.flow if actor_id == "player" else float(values.get(actor_id,0))

func profile(actor_id: String):
	if actor_id in ["player","player_serve"]: return lab.athlete
	if actor_id.begins_with("training_bot_"):
		return lab.training_bots.athlete_for(int(actor_id.trim_prefix("training_bot_")))
	if actor_id.begins_with("pepper_"):
		return lab.pepper.athlete_for(int(actor_id.trim_prefix("pepper_")))
	return lab.training_bots.physique

func state(actor_id: String):
	if not rule_states.has(actor_id): rule_states[actor_id] = RuleState.new()
	return rule_states[actor_id]

func set_amount(actor_id: String, value: float) -> void:
	values[actor_id] = 0.0 if profile(actor_id).exhausted else clampf(value,0,CAP)
	if actor_id == "player": lab.athlete.flow = values[actor_id]

func context(actor_id: String,action: int,evidence: Dictionary = {}) -> Dictionary:
	if action < 0 or action > 3: return {"effects":{}}
	var rules: Array = profile(actor_id).rules()
	if rules.is_empty() and state(actor_id).pending.is_empty(): return {"effects":{}}
	return state(actor_id).prepare(rules,["receive","set","attack","block"][action],amount(actor_id),evidence)

func bind_profile(actor_id: String) -> void:
	profile(actor_id).gameplay_context = func(action: int,evidence: Dictionary): return context(actor_id,action,evidence)

func commit_context(actor_id: String, prepared: Dictionary) -> void:
	if prepared.is_empty(): return
	state(actor_id).commit(prepared)
	set_amount(actor_id,amount(actor_id)-float(prepared.get("cost",0))+float(prepared.get("gain",0))*maxf(0,1.0+profile(actor_id).trait_effect("flow_state")/100.0))

func trigger(actor_id: String, kind: String, evidence: Dictionary = {}) -> Dictionary:
	evidence = evidence.duplicate(true)
	if evidence.has("charge_match"): evidence["mismatch"] = not bool(evidence.charge_match.get("matched",true))
	var prepared: Dictionary = state(actor_id).prepare(profile(actor_id).rules(),kind,amount(actor_id),evidence)
	commit_context(actor_id,prepared)
	return prepared

func start_rally() -> void:
	for actor_id in actors:
		state(actor_id).reset()
		profile(actor_id).modifiers.clear()

func end_rally() -> void:
	start_rally()

func net_cross() -> void:
	for actor_id in actors: profile(actor_id).modifiers.expire("net_cross")

func team_of(actor_id: String) -> int:
	if actor_id.begins_with("training_bot_"):
		return int(lab.training_bots.slot_away(int(actor_id.trim_prefix("training_bot_"))))
	return lab.side_index(actors[actor_id].global_position.z) if actors.has(actor_id) else -1

func allied(first: String,second: String) -> bool:
	# Pepper partners are individual opponents, not a second team of lab helpers.
	if first.begins_with("pepper_") or second.begins_with("pepper_"): return false
	for actor_id in [first,second]:
		if actor_id.begins_with("training_bot_"):
			var slot := int(actor_id.trim_prefix("training_bot_"))
			if not lab.training_bots.slot_enabled(slot): return false
	return team_of(first) == team_of(second)

func attack_charge(charge: float, actor_id: String, origin: Vector3 = Vector3.ZERO, evidence: Dictionary = {}) -> float:
	var athlete = profile(actor_id)
	var bonus := float(pending_attacks.get(actor_id,0))
	if athlete.rules().is_empty() and amount(actor_id) > 0:
		bonus += athlete.trait_effect("flow_attack_velocity")
	bonus += athlete.trait_effect("back_attack_velocity")*clampf((absf(origin.z)-2.0)/6.0,0,1)
	var input := evidence.duplicate(true)
	input["incoming_shot"] = lab.ball_shot
	var effects: Dictionary = context(actor_id,2,input).effects
	var transfer := transfer_efficiency(lab.ball_shot,team_of(actor_id))
	return maxf(0,athlete.effective_attack_charge(charge*athlete.low_stamina_factor()*transfer,effects)+bonus/100.0)

func consume_attack(actor_id: String) -> void:
	if not profile(actor_id).rules().is_empty():
		pending_attacks.erase(actor_id)
		return
	pending_attacks.erase(actor_id)
	if profile(actor_id).trait_effect("flow_attack_velocity") > 0 and amount(actor_id) > 0:
		values[actor_id] = 0.0
		if actor_id == "player":
			lab.athlete.flow = 0.0

func jump_bonus(actor_id: String) -> float:
	var prepared: Dictionary = state(actor_id).prepare(profile(actor_id).rules(),"jump",amount(actor_id))
	return float(pending_jumps.get(actor_id,0))+float(prepared.effects.get("jump_power",0))

func consume_jump(actor_id: String) -> void:
	trigger(actor_id,"jump")
	profile(actor_id).modifiers.expire("jump")
	pending_jumps.erase(actor_id)
	if actor_id == "player":
		lab.athlete.jump_power_bonus = 0.0

func actor_fatigue_changed(actor_id: String) -> bool:
	var epoch: int = profile(actor_id).fatigue_epoch
	var changed := int(fatigue_epochs.get(actor_id,epoch)) != epoch
	fatigue_epochs[actor_id] = epoch
	if changed:
		set_amount(actor_id,0)
		state(actor_id).pending.clear()
		pending_attacks.erase(actor_id)
		pending_jumps.erase(actor_id)
	return changed

func _fatigue_changed() -> bool:
	if seen_fatigue == lab.athlete.fatigue_epoch:
		return false
	seen_fatigue = lab.athlete.fatigue_epoch
	lab.athlete.flow = 0
	return true

func record(event: Dictionary) -> void:
	var actor_id := str(event.get("actor",""))
	if actor_id == "player_serve":
		actor_id = "player"
	if not actors.has(actor_id) or not event.get("physical_hit",false):
		return
	var id := str(event.get("id",""))
	if not id.is_empty():
		if id in recent:
			return
		recent.append(id)
		if recent.size() > 128:
			recent.pop_front()
	idle_seconds[actor_id] = 0.0
	var prepared: Dictionary = event.get("gameplay",{})
	if prepared.is_empty(): prepared = context(actor_id,int(event.get("action",0)),event)
	commit_context(actor_id,prepared)
	profile(actor_id).modifiers.expire("contact")
	var di: Dictionary = event.get("directional_influence",{})
	var weight := Vector3(di.get("world_input",Vector3.ZERO)).length()
	var actor_profile = profile(actor_id)
	var cost_factor := weight*maxf(0,1.0-actor_profile.trait_effect("di_cost_reduction")/100.0)
	actor_profile.spend(maxf(0,actor_profile.trait_effect("di_stamina_cost"))*cost_factor,maxf(0,actor_profile.trait_effect("di_hp_cost"))*cost_factor)
	var delta := change_for(event)
	if delta > 0: delta *= maxf(0,1.0+actor_profile.trait_effect("flow_state")/100.0)
	if actor_id == "player" and (_fatigue_changed() or lab.athlete.exhausted):
		delta = 0.0
	if actor_fatigue_changed(actor_id) or profile(actor_id).exhausted: delta = 0.0
	var before := amount(actor_id)
	var after := clampf(before+delta,0,CAP)
	values[actor_id] = after
	if actor_id == "player":
		lab.athlete.flow = after
	last_changes[actor_id] = {"before":before,"after":after,"delta":after-before,"event":event}
	if int(event.get("action",-1)) == 1 and event.get("rescue",false) and state(actor_id).clear_flow(profile(actor_id).rules(),"set_rescue"):
		set_amount(actor_id,0)
	if after < before and int(event.get("action",-1)) == 0 and event.get("incoming_shot",{}).get("kind","") == "attack":
		trigger(actor_id,"attack_receive_flow_loss",event)
		var athlete = profile(actor_id)
		pending_attacks[actor_id] = athlete.trait_effect("revenge_spike_velocity") if athlete.rules().is_empty() else 0.0
		pending_jumps[actor_id] = athlete.trait_effect("revenge_jump_power") if athlete.rules().is_empty() else 0.0
		if actor_id == "player":
			lab.athlete.jump_power_bonus = pending_jumps[actor_id]
	serve_consequences(actor_id,event)
	set_block_feedback(event)
	var impulse := knockback_for(event,actors[actor_id].global_position)
	if not impulse.is_empty():
		var consequences: Dictionary = event.get("incoming_shot",{}).get("serve_effects",{})
		impulse.velocity *= maxf(0,1.0+float(consequences.get("mismatch_knockback",0))/100.0)
		impulses[actor_id] = impulse

# Exact integral of a linearly decaying impulse; independent of frame rate.
func displacement(actor_id: String, dt: float) -> Vector3:
	if not impulses.has(actor_id):
		return Vector3.ZERO
	var impulse: Dictionary = impulses[actor_id]
	var step := minf(maxf(dt,0),float(impulse.remaining))
	var start := float(impulse.remaining)/float(impulse.duration)
	impulse.remaining = maxf(0,float(impulse.remaining)-step)
	var end := float(impulse.remaining)/float(impulse.duration)
	var travel := Vector3(impulse.velocity)*(start+end)*0.5*step
	if impulse.remaining <= 0:
		impulses.erase(actor_id)
	return travel

func tick(dt: float) -> void:
	_fatigue_changed()
	for actor_id in actors:
		bind_profile(actor_id)
		var athlete = profile(actor_id)
		athlete.modifiers.tick(dt)
		state(actor_id).tick(dt)
		actor_fatigue_changed(actor_id)
		if not athlete.exhausted:
			var eligible: Array = []
			for rule in athlete.rules():
				if rule.get("trigger","") == "low_stamina" and athlete.stamina/athlete.max_stamina() < float(rule.get("stamina_below",0)):
					eligible.append(rule)
			var prepared: Dictionary = state(actor_id).prepare(eligible,"low_stamina",amount(actor_id))
			commit_context(actor_id,prepared)
			for rule in prepared.activations:
				athlete.stamina = minf(athlete.max_stamina(),athlete.stamina+maxf(0,float(rule.get("restore_stamina",0)))*athlete.max_stamina())
		var before := float(idle_seconds.get(actor_id,0))
		var after := before+maxf(dt,0)
		idle_seconds[actor_id] = after
		var decay_time := maxf(0,after-DECAY_DELAY)-maxf(0,before-DECAY_DELAY)
		var value := amount(actor_id)*pow(0.5,decay_time/DECAY_HALF_LIFE)
		if value < 0.01:
			value = 0.0
		values[actor_id] = value
		if actor_id == "player":
			lab.athlete.flow = value

func tick_visuals() -> void:
	_fatigue_changed()
	for actor_id in actors:
		var aura: MeshInstance3D = auras[actor_id]
		var actor: Node3D = actors[actor_id]
		var flow := amount(actor_id)/CAP
		aura.visible = flow > 0 and actor.is_visible_in_tree() and not (actor_id == "player" and lab.is_benched())
		if not aura.visible:
			continue
		var height: float = lab.athlete.build.height if actor_id == "player" else lab.training_bots.physique.build.height
		aura.global_position = actor.global_position+Vector3.UP*height*0.55
		aura.scale = Vector3.ONE*height/1.86
		aura.material_override.set_shader_parameter("flow",flow)

func clear_actor(actor_id: String) -> void:
	rule_states.erase(actor_id)
	fatigue_epochs.erase(actor_id)
	profile(actor_id).modifiers.clear()
	# A dismissed/reused roster place must not inherit its previous athlete's state.
	values[actor_id] = 0.0
	idle_seconds[actor_id] = 0.0
	impulses.erase(actor_id)
	pending_attacks.erase(actor_id)
	pending_jumps.erase(actor_id)
	last_changes.erase(actor_id)
	if auras.has(actor_id): auras[actor_id].hide()
	if actor_id == "player":
		lab.athlete.flow = 0.0
		lab.athlete.jump_power_bonus = 0.0

func clear() -> void:
	start_rally()
	impulses.clear()
	recent.clear()
	last_changes.clear()
	pending_attacks.clear()
	pending_jumps.clear()
	lab.athlete.jump_power_bonus = 0.0
	for actor_id in values:
		values[actor_id] = 0.0
		idle_seconds[actor_id] = 0.0
	lab.athlete.flow = 0.0
	seen_fatigue = lab.athlete.fatigue_epoch
	for aura in auras.values():
		aura.visible = false

static func transfer_efficiency(shot: Dictionary,team: int) -> float:
	if shot.get("kind","") == "receive":
		return lerpf(0.70,0.90,clampf(float(shot.get("delivery_quality",0.75)),0,1))
	var setup: Dictionary = shot.get("setup",{})
	if setup.is_empty() or int(setup.get("team",-1)) != team or setup.get("used",false): return 1.0
	var loss := (1.0-clampf(float(setup.get("quality",1)),0,1))*0.30
	loss /= maxf(1,1.0+float(setup.get("tolerance",0))/100.0)
	return clampf(1.0-loss+float(setup.get("placement",0))/100.0,0,1)

func decorate_shot(shot: Dictionary,incoming: Dictionary,actor_id: String,action: int,assessment: Dictionary) -> Dictionary:
	var result := shot.duplicate(true)
	var effects: Dictionary = assessment.get("gameplay",{}).get("effects",{})
	var athlete = profile(actor_id)
	if action == 1:
		result["setup"] = {"owner":actor_id,"team":team_of(actor_id),"quality":assessment.get("quality",1),"placement":athlete.trait_effect("placement")+float(effects.get("placement",0)),"tolerance":athlete.trait_effect("ally_attack_charge_tolerance")+float(effects.get("ally_attack_charge_tolerance",0)),"rules":assessment.get("gameplay",{}).get("activations",[]).duplicate(true),"used":false}
	elif action == 2:
		var setup: Dictionary = incoming.get("setup",{})
		if int(setup.get("team",-1)) == team_of(actor_id) and not setup.get("used",false):
			result["setup"] = setup.duplicate(true)
			result.setup.used = true
	return preload("res://scripts/contact/snapshot.gd").freeze(result)

func decorate_serve(shot: Dictionary,actor_id: String) -> Dictionary:
	var result := shot.duplicate(true)
	var effects := {}
	for key in ["mismatch_knockback","mismatch_stamina_drain","transition_speed_penalty","inflicted_recovery_duration"]:
		effects[key] = profile(actor_id).trait_effect(key)
	result["serve_effects"] = effects
	return preload("res://scripts/contact/snapshot.gd").freeze(result)

func serve_consequences(actor_id: String,event: Dictionary) -> void:
	var shot: Dictionary = event.get("incoming_shot",{})
	var effects: Dictionary = shot.get("serve_effects",{})
	if effects.is_empty(): return
	var severity := float(event.get("charge_match",{}).get("severity",0))
	var athlete = profile(actor_id)
	athlete.spend(maxf(0,float(effects.get("mismatch_stamina_drain",0)))*severity/100.0*athlete.contact_cost(0,1).x)
	var duration := float(event.get("recovery_seconds",0))
	if duration <= 0: return
	var authored := float(effects.get("inflicted_recovery_duration",0))
	if authored > 0: duration = authored
	athlete.modifiers.add("serve-recovery",{"stats":{"transition_speed":-maxf(0,float(effects.get("transition_speed_penalty",0)))},"duration":duration})
	var source := str(shot.get("actor",""))
	if source == "player_serve": source = "player"
	if actors.has(source): trigger(source,"inflicted_recovery",event)

func set_block_feedback(event: Dictionary) -> void:
	if int(event.get("action",-1)) != 3: return
	var setup: Dictionary = event.get("incoming_shot",{}).get("setup",{})
	var owner := str(setup.get("owner",""))
	if not actors.has(owner) or not setup.get("used",false) or int(setup.get("team",-1)) == int(event.get("team",-2)): return
	if state(owner).clear_flow(profile(owner).rules(),"set_attack_blocked"): set_amount(owner,0)

func on_attack_charge(charging: String) -> void:
	if not actors.has(charging): return
	for owner in actors:
		if owner == charging or not allied(owner,charging): continue
		var athlete = profile(owner)
		for rule in athlete.rules():
			if rule.get("trigger","") != "ally_attack_charge": continue
			var id := str(rule.get("id",""))
			if id.is_empty(): continue
			var seen: Array = state(owner).allies.get(id,[])
			if charging in seen or seen.size() >= int(rule.get("max_allies",4)): continue
			var prepared: Dictionary = state(owner).prepare([rule],"ally_attack_charge",amount(owner))
			if prepared.activations.is_empty(): continue
			seen.append(charging)
			state(owner).allies[id] = seen
			commit_context(owner,prepared)
			var recipient := charging if rule.get("recipient","self") == "ally" else str(owner)
			var effects: Dictionary = rule.get("effects",{}).duplicate(true)
			if recipient == owner:
				for key in effects: effects[key] *= seen.size()
			var spec := {"effects":effects,"source":owner}
			if rule.has("duration"): spec["duration"] = rule.duration
			if rule.has("until"): spec["until"] = rule.until
			profile(recipient).modifiers.add("%s:%s"%[owner,id],spec)

func shape_effects(actor_id: String,action: int) -> Dictionary:
	var result: Dictionary = context(actor_id,action).effects.duplicate(true)
	for key in ["broad_range","vertical_reach","platform_quality"]:
		result[key] = float(result.get(key,0))+profile(actor_id).trait_effect(key)
	return result
