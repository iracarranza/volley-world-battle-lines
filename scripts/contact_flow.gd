extends Node3D

const CAP := 100.0
const DECAY_DELAY := 14.0
const DECAY_HALF_LIFE := 8.0
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

func attack_charge(charge: float, actor_id: String, origin: Vector3 = Vector3.ZERO) -> float:
	var athlete = profile(actor_id)
	var bonus := float(pending_attacks.get(actor_id,0))
	if amount(actor_id) > 0:
		bonus += athlete.trait_effect("flow_attack_velocity")
	bonus += athlete.trait_effect("back_attack_velocity")*clampf((absf(origin.z)-2.0)/6.0,0,1)
	return maxf(0,athlete.effective_attack_charge(charge*athlete.low_stamina_factor())+bonus/100.0)

func consume_attack(actor_id: String) -> void:
	pending_attacks.erase(actor_id)
	if profile(actor_id).trait_effect("flow_attack_velocity") > 0 and amount(actor_id) > 0:
		values[actor_id] = 0.0
		if actor_id == "player":
			lab.athlete.flow = 0.0

func jump_bonus(actor_id: String) -> float:
	return float(pending_jumps.get(actor_id,0))

func consume_jump(actor_id: String) -> void:
	pending_jumps.erase(actor_id)
	if actor_id == "player":
		lab.athlete.jump_power_bonus = 0.0

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
	var delta := change_for(event)
	if actor_id == "player" and (_fatigue_changed() or lab.athlete.exhausted):
		delta = 0.0
	if profile(actor_id).exhausted: delta = 0.0
	var before := amount(actor_id)
	var after := clampf(before+delta,0,CAP)
	values[actor_id] = after
	if actor_id == "player":
		lab.athlete.flow = after
	last_changes[actor_id] = {"before":before,"after":after,"delta":after-before,"event":event}
	if after < before and int(event.get("action",-1)) == 0 and event.get("incoming_shot",{}).get("kind","") == "attack":
		var athlete = profile(actor_id)
		pending_attacks[actor_id] = athlete.trait_effect("revenge_spike_velocity")
		pending_jumps[actor_id] = athlete.trait_effect("revenge_jump_power")
		if actor_id == "player":
			lab.athlete.jump_power_bonus = pending_jumps[actor_id]
	var impulse := knockback_for(event,actors[actor_id].global_position)
	if not impulse.is_empty():
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
