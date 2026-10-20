extends "res://tests/support/test_case.gd"
const Auto := preload("res://scripts/auto_charge.gd")
const Stats := preload("res://scripts/stat_tuning.gd")
const Store := preload("res://scripts/athlete_store.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Resolver := preload("res://scripts/contact/contact_resolver.gd")
func mouse(lab: Node3D,pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	lab._unhandled_input(event)
func run_set(lab: Node3D,pressure: float) -> Dictionary:
	lab.locked_action = 1
	lab.selected = 1
	lab.armed = true
	lab.begin_auto_preparation(1)
	lab.ball_shot = {"kind":"receive","charge":pressure}
	lab.ball_velocity = Vector3(0,-8,3)
	lab.auto_preparation.tick(1,lab.athlete,lab.ball_shot,lab.ball_velocity)
	var shape: Dictionary = lab._raw_hurtbox_definition(1)
	lab.ball.position = lab.player.position+Vector3(shape.center)+Vector3.UP*float(shape.radius)*0.55
	var request = lab.contact_request(1)
	request.base_velocity = Vector3(0,6,-7)
	request.apply_set_spread = false
	request.confirmation_age = 0.22
	var assessment: Dictionary = Resolver.assess(request)
	var result = Resolver.resolve(request,assessment)
	return {"request":request,"assessment":assessment,"result":result}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for pair in [[50,0.35],[56,0.48],[61,0.61],[65,0.61],[66,0.65],[70,0.70],[80,0.75],[90,0.80],[99,0.85]]:
		check(is_equal_approx(Stats.reaction_cap(pair[0]),pair[1]),"Reaction Speed ceiling %s" % pair[0])
	var a := Athlete.new()
	var ordinary := Auto.new()
	ordinary.begin(0,1)
	ordinary.tick(0.3,a,{"charge":0.7},Vector3(0,-5,20))
	var low: Dictionary = ordinary.sample(a,{"charge":0.7},Vector3(0,-5,20))
	a.build.statistics = {"reaction_speed":99}
	var quick := Auto.new()
	quick.begin(0,1)
	quick.tick(0.3,a,{"charge":0.7},Vector3(0,-5,20))
	var high: Dictionary = quick.sample(a,{"charge":0.7},Vector3(0,-5,20))
	check(high.charge >= 0.7 and high.charge <= 0.85 and high.charge > low.charge,"Higher Reaction Speed adapts quickly enough to match a harder ball")
	check(absf(float(high.error)) < absf(float(low.error)),"Higher tiers reduce matching error")
	var before := quick.prepared
	quick.sample(a,{"charge":1.5},Vector3(0,-5,30))
	check(quick.prepared == before,"Contact sampling and preview do not mutate preparation")
	check(quick.sample(a,{"charge":0.4},Vector3(0,0,40)).target_pressure == 0.4,"Receive matching evidence reports ball charge rather than Set Isolation pressure")
	for action in [2,3]:
		quick.begin(action,1)
		check(quick.sample(a,{},Vector3.ZERO).charge == 0.85,"Tapped attack/block use tier ceiling without matching incoming charge")
	var legacy := Store.blank()
	legacy.stat_version = 2
	legacy.stat_names.speed = ["Acceleration","Lateral Speed","Transition Speed"]
	legacy.offsets.speed = [3,-2,-1]
	legacy.statistics.erase("reaction_speed")
	legacy.statistics["lateral_speed"] = 63
	var converted := Store.migrate(legacy)
	check(converted.statistics.reaction_speed == 65 and converted.offsets.speed == [0.0,0.0,0.0],"Retired Lateral Speed allocations reset SPD for respec")
	check(converted.retired_statistics.pre_reaction_speed.offsets.speed == [3,-2,-1],"Old allocations remain archived losslessly")
	check(Store.migrate(converted) == converted,"Reaction schema migration is idempotent")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	await physics_frame
	lab.ball_active = true
	lab.ball.position = Vector3(0,12,5)
	lab.ball_shot = {"kind":"receive","charge":0.2}
	mouse(lab,true)
	mouse(lab,false)
	check(lab.armed and lab.auto_preparation.active,"Real tap input arms Auto instead of fixed power")
	lab.hud.update()
	check(lab.hud.action_wheel.auto_charge and lab.hud.action_wheel.charge_level == 0,"The wheel shows Auto instead of a numerical charge fill")
	lab.auto_preparation.tick(0.3,lab.athlete,lab.ball_shot,Vector3.ZERO)
	mouse(lab,true)
	check(lab.committed_intent.charge == "auto" and lab.committed_intent.charge_mode == "auto","Confirmation commits Auto, not a numerical charge snapshot")
	var prepared: float = lab.auto_preparation.prepared
	lab.ball_shot = {"kind":"attack","charge":0.7}
	lab._physics_process(0.1)
	check(lab.auto_preparation.active and lab.auto_preparation.prepared > prepared,"Auto continues reacting during the confirmed contact window")
	var shape: Dictionary = lab._raw_hurtbox_definition(0)
	lab.ball.position = lab.player.position+Vector3(shape.center)
	lab.ball_velocity = Vector3(0,-8,18)
	lab.confirm_window = lab.confirm_duration-0.22
	lab._contact()
	check(lab.last_receive_match.incoming_charge == 0.7,"Actual hurtbox contact uses the newly arriving ball’s pressure")
	check(lab.ball_shot.has("action_charge") and lab.ball_shot.charge != lab.ball_shot.action_charge,"Receive input and resultant ball charge remain distinct")
	lab._reset()
	mouse(lab,true)
	lab.charge = 0.8
	mouse(lab,false)
	check(not lab.auto_preparation.active and lab.locked_charge == 0.8,"Held preparation remains explicit numeric charge")
	lab._reset()
	lab.ball_active = true
	lab.selected = 0
	mouse(lab,true)
	lab.motion.begin_jump()
	check(lab.auto_preparation.active and lab.auto_preparation.action == 0,"Interrupting a tap with jump preparation retains Auto receive")
	lab._reset()
	var gentle := run_set(lab,0.3)
	var hard := run_set(lab,0.8)
	check(gentle.request.charge == 0.61 and hard.request.charge == 0.61,"Tapped sets keep standard 61% outgoing intent")
	check(hard.request.handling_charge > gentle.request.handling_charge,"Tapped set handling effort adapts independently of output")
	check(gentle.assessment.set_isolation.severity == 0 and hard.assessment.set_isolation.severity == 0,"Set Isolation comfortably handles a range of incoming pressure")
	check(gentle.result.velocity.is_equal_approx(hard.result.velocity),"Within capacity, incoming pressure does not alter the standard set output")
	var overwhelmed := run_set(lab,1.8)
	check(overwhelmed.assessment.set_isolation.severity > 0.8 and not overwhelmed.assessment.sweet,"Incoming pressure above handling capacity defeats isolation without granting sweetness")
	check(overwhelmed.result.outgoing_shot.action_charge == 0.61 and overwhelmed.result.outgoing_shot.charge > hard.result.outgoing_shot.charge,"Overwhelmed sets retain more pressure without confusing action charge and ball charge")
	lab._reset()
	lab.ball_active = true
	lab.locked_action = 1
	lab.selected = 1
	lab.armed = true
	lab.begin_auto_preparation(1)
	lab.ball_shot = {"kind":"receive","charge":0.8}
	lab.ball_velocity = Vector3(0,-8,3)
	lab.auto_preparation.tick(1,lab.athlete,lab.ball_shot,lab.ball_velocity)
	var set_shape: Dictionary = lab._raw_hurtbox_definition(1)
	lab.ball.position = lab.player.position+Vector3(set_shape.center)+Vector3.UP*float(set_shape.radius)*0.55
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration-0.22
	lab._contact()
	check(lab.ball_shot.kind == "set" and lab.ball_shot.action_charge == 0.61 and lab.ball_shot.handling_charge > 0.4,"An actual confirmed tapped set applies separate handling and standard output at contact")
	lab.queue_free()
	await process_frame
	print("AUTO CHARGE / REACTION SPEED: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
