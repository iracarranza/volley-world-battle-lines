extends "res://tests/support/test_case.gd"
const Athlete := preload("res://scripts/athlete.gd")
const Stats := preload("res://scripts/stat_tuning.gd")
const Rules := preload("res://scripts/gameplay_rules.gd")
const Registry := preload("res://scripts/contact/mechanic_registry.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const Request := preload("res://scripts/contact/contact_request.gd")
const Resolver := preload("res://scripts/contact/contact_resolver.gd")
const Influence := preload("res://scripts/directional_influence.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var athlete := Athlete.new()
	athlete.gameplay_effects = {"cushioning":5,"ball_control":15,"swing_power_band":2,"swing_power_band_cap":2}
	check(athlete.stat("cushioning") == 70 and athlete.cushioning_bonus() == 0.08,"Cushioning rating reaches its effective band")
	check(athlete.ball_control() == 80 and Stats.rating(athlete.build,"ball_control") == 65,"Effective Ball Control never changes stored rating")
	check(athlete.stat("swing_power") == 70,"Capped band uplift reaches T2")
	athlete.build.statistics = {"swing_power":99}
	check(athlete.stat("swing_power") == 99,"Band caps never downgrade an already higher stat")
	athlete.modifiers.add("a",{"stats":{"acceleration":5},"duration":1})
	athlete.modifiers.add("a",{"stats":{"acceleration":10},"duration":1})
	check(athlete.stat("acceleration") == 75,"Temporary modifiers replace their own source")
	athlete.modifiers.tick(1)
	check(athlete.stat("acceleration") == 65,"Timed modifier expires exactly")
	athlete.modifiers.add("tier-a",{"bands":{"explosiveness":{"amount":1,"cap":5}}})
	athlete.modifiers.add("tier-b",{"bands":{"explosiveness":{"amount":1,"cap":5}}})
	check(athlete.stat("explosiveness") == 70,"Independent capped band upgrades combine")
	athlete.modifiers.clear()
	for key in Registry.EFFECT_KEYS: check(Registry.registered(key),"Registered effect: "+key)
	var rules := Rules.new()
	var definitions := [{"id":"first","trigger":"receive","threshold":100,"consume":80,"effects":{"receive_control":10},"pending":{"attack":{"spike_velocity":12},"jump":{"jump_power":5}},"cooldown":2,"uses":1},{"id":"second","trigger":"receive","threshold":30,"consume":30}]
	var prepared := rules.prepare(definitions,"receive",100)
	check(prepared.activations.size() == 1 and prepared.cost == 80,"Ordered Flow reservation prevents overspending")
	check(rules.pending.is_empty() and rules.uses.is_empty(),"Preparing a preview is pure")
	rules.commit(prepared)
	check(rules.prepare(definitions,"receive",100).activations.size() == 1,"Used rule is disabled while other rule remains usable")
	check(rules.prepare([],"attack",0).effects.spike_velocity == 12,"Pending attack survives without Flow")
	rules.commit(rules.prepare([],"jump",0))
	check(rules.prepare([],"jump",0).effects.is_empty() and rules.prepare([],"attack",0).effects.spike_velocity == 12,"Jump and attack pending bonuses are independent")
	rules.commit(rules.prepare([],"attack",0))
	check(rules.pending.is_empty(),"Pending bonuses consume once")
	var base := Geometry.definition(2,1.86,2.4,false,1)
	var grown := Geometry.with_effects(base,{"broad_range":30,"vertical_reach":20})
	check(grown.size.x > base.size.x and grown.size.y > base.size.y,"Geometry modifiers enlarge lateral and vertical dimensions")
	var original_sweet := Vector3(base.center)+Geometry.sector_point(base,0.74,67.5,0)
	check(Geometry.evaluate(grown,original_sweet).zone == "SWEET SPOT","Reach extensions preserve the physical arm sweetspot")
	var unreachable := Vector3(base.center)+Vector3(base.radius*1.15,0.2,0)
	if Geometry.contains(grown,unreachable): check(Geometry.evaluate(grown,unreachable).zone != "SWEET SPOT","Enlarged spike cannot grant unreachable sweetspot")
	var plain := Influence.resolve(Vector3(0,8,-15),1,Vector3.RIGHT,Vector3.FORWARD,1)
	var vision := Influence.resolve(Vector3(0,8,-15),1,Vector3.RIGHT,Vector3.FORWARD,1,50)
	check(absf(vision.yaw_degrees) > absf(plain.yaw_degrees),"Court Vision expands DI authority")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var flow = lab.contact_flow
	lab.athlete.trait_ids.clear()
	lab.athlete.gameplay_rules.assign(definitions)
	lab.athlete.flow = 100
	var context: Dictionary = flow.context("player",0)
	check(lab.athlete.flow == 100,"Contact preparation does not spend actor Flow")
	var event := {"id":"runtime","actor":"player","action":0,"physical_hit":true,"quality":1,"sweet":true,"gameplay":context,"charge_match":{"matched":true},"point":lab.player.position}
	flow.record(event)
	check(lab.athlete.flow == 45,"Successful contact spends prepared Flow before earning contact Flow")
	flow.record(event)
	check(lab.athlete.flow == 45,"Duplicate contact cannot spend or earn twice")
	check(flow.jump_bonus("player") == 5,"Player can query structured pending jump")
	flow.consume_jump("player")
	check(flow.jump_bonus("player") == 0 and flow.context("player",2).effects.spike_velocity == 12,"Real jump consumes only jump pending")
	var request := Request.new()
	request.athlete = lab.athlete
	request.shape = lab._raw_hurtbox_definition(0)
	request.local_point = Vector3(0,request.shape.center.y,-request.shape.forward_reach*0.6)
	request.incoming = Vector3(0,-4,12)
	request.incoming_shot = {"kind":"serve","charge":0.5}
	request.charge = 0.5
	var assessment := Resolver.assess(request)
	request.base_velocity = Vector3(0,6,-9)
	Resolver.resolve(request,assessment)
	check(lab.athlete.flow == 45 and request.athlete != lab.athlete,"Resolver overlays are pure and athlete-local")
	lab.athlete.gameplay_effects = {"placement":15,"ally_attack_charge_tolerance":25,"mismatch_knockback":50,"transition_speed_penalty":10}
	var setup: Dictionary = flow.decorate_shot({"kind":"set"},{},"player",1,{"quality":0.5})
	check(setup.setup.placement == 15 and setup.setup.tolerance == 25,"Set records distinct attacker support")
	check(flow.transfer_efficiency({"kind":"receive","delivery_quality":1},0) < 1,"Attacking a receive loses intended transfer before additive velocity")
	check(flow.transfer_efficiency(setup,setup.setup.team) == 1,"Placement restores lost transfer without exceeding 100 percent")
	check(flow.transfer_efficiency(setup,1-int(setup.setup.team)) == 1,"Opponent cannot use allied set support")
	var attack: Dictionary = flow.decorate_shot({"kind":"attack"},setup,"player",2,{})
	check(attack.setup.used and flow.transfer_efficiency(attack,setup.setup.team) == 1,"Setup support is consumed by one attack while retaining attribution")
	check(not flow.decorate_shot({"kind":"receive"},setup,"player",0,{}).has("setup"),"Receive clears setup ownership")
	var serve: Dictionary = flow.decorate_serve({"kind":"serve","actor":"player"},"player")
	lab.athlete.gameplay_effects.mismatch_knockback = 0
	check(serve.serve_effects.mismatch_knockback == 50,"Serve consequences snapshot launch values")
	var bot = flow.profile("training_bot_0")
	bot.gameplay_rules.assign([{"id":"bot-flow","trigger":"set","threshold":30,"consume":30,"effects":{"placement":10}}])
	flow.set_amount("training_bot_0",30)
	flow.record({"id":"bot-set","actor":"training_bot_0","action":1,"physical_hit":true,"quality":1,"sweet":true})
	check(flow.amount("training_bot_0") == 25 and lab.athlete.flow == 45,"Bot rule transactions are independent of player")
	lab.athlete.gameplay_rules.assign([{"id":"second-wind","trigger":"low_stamina","stamina_below":0.2,"restore_stamina":0.3,"cooldown":10}])
	lab.athlete.stamina = 10
	flow.tick(0.01)
	check(lab.athlete.stamina == 40,"Low stamina rule restores authored capacity fraction")
	lab.athlete.stamina = 10
	flow.tick(0.01)
	check(lab.athlete.stamina == 10,"Low stamina cooldown prevents repeated restoration")
	lab.athlete.modifiers.add("net",{"stats":{"acceleration":10},"until":"net_cross"})
	flow.net_cross()
	check(lab.athlete.modifiers.entries.is_empty(),"Net crossing clears event-lifetime modifiers")
	# Concrete trait hooks: ally charging, serve recovery, and exhausted restoration.
	lab.athlete.gameplay_rules.assign([{"id":"options","trigger":"ally_attack_charge","max_allies":2,"recipient":"self","until":"net_cross","effects":{"swing_power":5}}])
	lab.training_bots.settings[0].enabled = true
	lab.training_bots.settings[0].away = false
	lab.training_bots.settings[0].net_index = lab.training_bots.current_net
	lab.player.position.z = 4
	flow.on_attack_charge("training_bot_0")
	var buffed: float = lab.athlete.stat("swing_power")
	flow.on_attack_charge("training_bot_0")
	check(buffed == 70 and lab.athlete.stat("swing_power") == 70,"Ally charging buffs once per distinct ally")
	flow.net_cross()
	check(lab.athlete.stat("swing_power") == 65,"Ally charge buff expires at net crossing")
	flow.on_attack_charge("training_bot_0")
	check(lab.athlete.stat("swing_power") == 65,"Same ally cannot refresh a consumed rally allowance")
	var stamina_before: float = bot.stamina
	var penalty_event := {"incoming_shot":{"actor":"player","serve_effects":{"mismatch_stamina_drain":100,"transition_speed_penalty":10}},"charge_match":{"severity":1},"recovery_seconds":0.55}
	bot.spend_resolved(bot.contact_cost(0,1,penalty_event,penalty_event.incoming_shot).x)
	var paid_once: float = bot.stamina
	flow.serve_consequences("training_bot_0",penalty_event)
	check(bot.stamina < stamina_before and bot.stamina == paid_once and bot.stat("transition_speed") == 55,"Contact quote includes mismatch drain once; serve effects apply recovery debuff without a second charge")
	bot.modifiers.tick(0.55)
	check(bot.stat("transition_speed") == 65,"Serve recovery penalty expires")
	lab.athlete.stamina = 100
	lab.athlete.gameplay_effects = {"jump_stamina_threshold":15}
	check(is_equal_approx(lab.athlete.leap(0.1,1),lab.athlete.leap(1,1)),"Never Stay Down protects diminished jump charge above stamina threshold")
	lab.athlete.stamina = 15
	check(lab.athlete.leap(0.1,1) < lab.athlete.leap(1,1),"Jump protection ends at threshold")
	lab.athlete.gameplay_rules.assign([{"id":"restore","trigger":"low_stamina","stamina_below":0.2,"restore_stamina":1}])
	lab.athlete.exhausted = true
	lab.athlete.stamina = 0
	flow.tick(0.1)
	check(lab.athlete.stamina == 0,"Structured restoration cannot bypass Exhaustion")
	lab.athlete.exhausted = false
	lab.athlete.stamina = 100
	lab.athlete.gameplay_rules.clear()
	lab.athlete.gameplay_effects.clear()
	flow.start_rally()
	check(flow.state("player").pending.is_empty() and flow.state("player").uses.is_empty(),"New rally resets pending effects and activation limits")
	lab.queue_free()
	await process_frame
	print("GAMEPLAY HOOKS: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
