extends SceneTree
const Flow := preload("res://scripts/contact_flow.gd")
const Athlete := preload("res://scripts/athlete.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func event(id: String, quality: float = 1, sweet: bool = false, actor: String = "player") -> Dictionary:
	return {"id":id,"actor":actor,"physical_hit":true,"action":0,"quality":quality,"sweet":sweet,"point":Vector3(0,1,-0.5),"incoming_velocity":Vector3(0,-5,20),"charge_match":{"matched":true,"status":"matched","severity":0}}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(Flow.change_for(event("sweet",1,true)) == 25,"Sweet contact gives 25 Flow")
	check(Flow.change_for(event("ordinary")) == 24,"Best ordinary contact gives 24 Flow")
	for quality in [0.4,0.5,0.7,0.9]:
		var delta := Flow.change_for(event("quality",quality))
		check(delta >= 1 and delta <= 24,"Successful contacts give 1–24 Flow")
	check(Flow.change_for(event("poor",0.2)) < 0,"Poor contact depletes Flow")
	var under := event("shank")
	under.charge_match = {"matched":false,"status":"undercharged","severity":1.0}
	check(Flow.change_for(under) < 0,"Severe shank depletes Flow")
	var direct := Flow.knockback_for(under,Vector3.ZERO)
	check(direct.velocity.z > 0 and absf(direct.velocity.x) < 0.00001,"Direct hit knocks receiver along incoming path")
	under.point.x = 0.8
	var glance := Flow.knockback_for(under,Vector3.ZERO)
	check(glance.velocity.x > 0 and glance.velocity.z > 0,"Glancing hit deflects receiver sideways while retaining incoming direction")
	under.point.x = -0.8
	var mirrored := Flow.knockback_for(under,Vector3.ZERO)
	check(is_equal_approx(glance.velocity.x,-mirrored.velocity.x),"Glancing knockback mirrors contact side")
	under.charge_match.severity = 0.001
	check(Flow.knockback_for(under,Vector3.ZERO).velocity.length() < 0.01,"Near charge mismatch causes only tiny recoil")
	under.charge_match.status = "overcharged"
	check(Flow.knockback_for(under,Vector3.ZERO).is_empty(),"Overcharge does not knock receiver back")
	var athlete := Athlete.new()
	athlete.flow = 90
	athlete.spend(100)
	check(athlete.winded and athlete.flow == 0,"Winded immediately clears Flow")
	athlete.stamina = 5
	athlete.flow = 50
	athlete.spend(5)
	check(athlete.exhausted and athlete.flow == 0,"Exhausted immediately clears Flow")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var flow = lab.contact_flow
	flow.record(event("a",1,true))
	check(lab.athlete.flow == 25,"Player contact stores own Flow")
	flow.record(event("a",1,true))
	check(lab.athlete.flow == 25,"Duplicate events cannot add Flow twice")
	flow.record(event("bot",1,true,"training_bot_0"))
	check(flow.amount("training_bot_0") == 25 and flow.amount("training_bot_1") == 0 and lab.athlete.flow == 25,"Bot Flow is independent")
	flow.record(event("serve-flow",1,true,"player_serve"))
	check(lab.athlete.flow == 50,"Player serve contacts add Flow to the athlete")
	for i in range(6):
		flow.record(event("cap%d"%i,1,true))
	check(lab.athlete.flow == 100,"Flow caps at 100")
	flow.tick(13.9)
	check(lab.athlete.flow == 100,"No decay for first 14 seconds")
	flow.tick(0.1)
	check(is_equal_approx(lab.athlete.flow,100),"Grace period includes 14-second boundary")
	flow.tick(8)
	check(is_equal_approx(lab.athlete.flow,50),"Exponential decay halves Flow in eight seconds")
	flow.tick(8)
	check(is_equal_approx(lab.athlete.flow,25),"Exponential decay halves again rather than subtracting fixed amount")
	flow.record(event("refresh",0.4))
	var retained: float = lab.athlete.flow
	flow.tick(14)
	check(is_equal_approx(lab.athlete.flow,retained),"Contact restarts grace period")
	flow.clear()
	lab.athlete.flow = 100
	flow.tick(18)
	check(is_equal_approx(lab.athlete.flow,100*sqrt(0.5)),"Cross-boundary tick only decays time after 14 seconds")
	flow.clear()
	lab.athlete.flow = 100
	for i in range(180):
		flow.tick(0.1)
	check(absf(lab.athlete.flow-100*sqrt(0.5)) < 0.001,"Decay is frame-rate independent")
	lab.athlete.stamina = 1
	lab.athlete.spend(1)
	flow.record(event("depletion-contact",1,true))
	check(lab.athlete.flow == 0,"Contact causing Winded cannot immediately restore Flow")
	flow.clear()
	under = event("knock")
	under.point = lab.player.global_position+Vector3(0.8,1,-0.5)
	under.charge_match = {"matched":false,"status":"undercharged","severity":1}
	flow.record(under)
	var origin: Vector3 = lab.player.position
	lab._physics_process(1.0/60)
	check(lab.player.position.z > origin.z and lab.player.position.x > origin.x,"Knockback actually displaces player along glancing path")
	flow.clear()
	flow.record(event("aura",1,true))
	flow.tick_visuals()
	check(flow.auras.player.visible and is_equal_approx(flow.auras.player.material_override.get_shader_parameter("flow"),0.25),"Aura opacity follows Flow fraction")
	check(flow.auras.size() == 12,"Player and all bots have prepared aura resources")
	lab.athlete_hud.update_values()
	check(lab.athlete_hud.flow_bar.value == lab.athlete.flow,"Provisional smaller Flow bar reflects meter")
	flow.clear()
	var bot_under := event("bot-knock",0.25,false,"training_bot_0")
	bot_under.point = lab.training_bots.actors[0].global_position+Vector3(0.8,1,-0.5)
	bot_under.charge_match = {"matched":false,"status":"undercharged","severity":1}
	var bot_before: Vector3 = lab.training_bots.actors[0].position
	flow.record(bot_under)
	lab.training_bots.tick_motion(0.1)
	check(lab.training_bots.actors[0].position.z > bot_before.z,"Bot receiver physically recoils too")
	check(not flow.impulses.has("training_bot_1"),"Knockback affects only the receiver")
	lab._reset()
	check(lab.athlete.flow == 0 and flow.impulses.is_empty() and not flow.auras.player.visible,"Reset clears Flow, aura and knockback")
	lab.queue_free()
	await process_frame
	print("CONTACT FLOW / KNOCKBACK: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
