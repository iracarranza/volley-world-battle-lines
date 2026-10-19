extends "res://tests/support/test_case.gd"
const Store := preload("res://scripts/athlete_store.gd")
const Stats := preload("res://scripts/stat_tuning.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Charge := preload("res://scripts/receive_charge.gd")
func athlete(name: String, value: float) -> RefCounted:
	var a := Athlete.new()
	a.build = Athlete.BUILDS[0].duplicate(true)
	a.build.statistics = {name:value}
	a.stamina = a.max_stamina()
	return a
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for pair in [[50,-2],[55,-2],[56,-1],[60,-1],[61,0],[65,0],[66,1],[69,1],[70,2],[79,2],[80,3],[89,3],[90,4],[98,4],[99,5]]:
		check(Stats.tier(pair[0]) == pair[1],"Exact corrected band boundary %d"%pair[0])
	for pair in [[50,55],[56,60],[61,65],[66,69],[70,79],[80,89],[90,98]]:
		check(Stats.pace(pair[0]) == Stats.pace(pair[1]) and Stats.charge_multiplier(pair[0]) == Stats.charge_multiplier(pair[1]),"No capability drift within band")
	check(Stats.pace(65) == 1 and is_equal_approx(Stats.pace(66),1.08) and is_equal_approx(Stats.pace(99),1.4),"Explosiveness baseline and +8% steps")
	check(Stats.charge_multiplier(65) == 1 and is_equal_approx(Stats.charge_multiplier(66),1.04) and is_equal_approx(Stats.charge_multiplier(99),1.2),"Jump/Swing charge +4% steps")
	check(Stats.rating({"power":65,"statistics":{"explosiveness":99}},"explosiveness") == 99,"Named stat overrides parent")
	check(Stats.rating({"power":65,"offsets":{"power":[8,8,8]}},"explosiveness") == 65,"Legacy offsets are never silently remapped")
	var labelled := Store.migrate({"stat_version": 2, "power":65,"stat_names":{"power":["Explosiveness"]},"offsets":{"power":[5]}})
	check(Stats.rating(labelled,"explosiveness") == 70,"Labelled offsets migrate at the save boundary before runtime lookup")
	var base := athlete("explosiveness",65)
	var fast := athlete("explosiveness",99)
	var height := 1.5
	check(is_equal_approx(fast.jump_velocity(height,9.8)/base.jump_velocity(height,9.8),1.4),"Faster upward takeoff")
	check(is_equal_approx(pow(fast.jump_velocity(height,9.8),2)/(2*fast.jump_gravity(9.8,true)),height),"Faster ascent preserves apex height")
	check(fast.jump_velocity(height,9.8)/fast.jump_gravity(9.8,true) < base.jump_velocity(height,9.8)/9.8,"Explosiveness reduces time to apex")
	check(fast.jump_gravity(9.8,false) == 9.8,"Explosiveness does not speed world gravity or falling")
	check(is_equal_approx(fast.leap(1,1),base.leap(1,1)),"Explosiveness alone never raises jump ceiling")
	var high_jump := athlete("jump_power",99)
	check(high_jump.leap(1,1) > base.leap(1,1) and is_equal_approx(high_jump.explosiveness_rate(),1),"Jump Power raises jump separately from pace")
	check(is_equal_approx(high_jump.effective_jump_charge(0.5),0.6),"Jump Power multiplies partial charge")
	var stable := athlete("stability",99)
	var raw := {"hit":true,"quality":0.3,"zone":"WEAK","sweet":false}
	var helped: Dictionary = stable.stabilize_set(raw)
	check(helped.quality > raw.quality and helped.zone == "WEAK" and not helped.sweet,"Stability improves weak set execution without granting sweet/zone")
	check(stable.stabilize_set({"quality":1}).quality == 1,"No effect on already perfect set")
	var cushion := athlete("cushioning",99)
	var incoming := Charge.shot("attack",1.2,"test")
	check(incoming.charge > 1,"Effective attack metadata is uncapped")
	check(Charge.match_charge(incoming,1,cushion.cushioning_bonus()).matched,"Cushioning adds charge, including above 100%")
	check(not Charge.match_charge(incoming,1).matched,"Missing Cushioning cannot silently match >100% attack")
	check(athlete("stability",99).cushioning_bonus() == 0,"Stability does not modify receive charge")
	var capacity := athlete("capacity",99)
	check(capacity.max_stamina() == 150 and base.max_stamina() == 100,"Capacity increases actual maximum stamina")
	capacity.stamina = 149
	capacity.recover(2,true)
	check(capacity.stamina == 150,"Regeneration clamps to capacity rather than 100")
	var worker := athlete("work_rate",99)
	base.stamina = 15
	worker.stamina = 15
	check(worker.low_stamina_factor() > base.low_stamina_factor(),"Work Rate mitigates low-stamina output penalty")
	check(worker.leap(1,1) > base.leap(1,1),"Work Rate preserves low-stamina jump performance")
	worker.stamina = worker.max_stamina()
	base.stamina = base.max_stamina()
	check(worker.low_stamina_factor() == 1 and is_equal_approx(worker.leap(1,1),base.leap(1,1)),"Work Rate does not raise fresh output")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	await physics_frame
	for rating in [65,99]:
		lab._reset()
		lab.athlete.build.statistics = {"explosiveness":rating}
		lab.selected = 2
		lab.motion.begin_approach()
		lab._physics_process(0.1)
		check(is_equal_approx(lab.motion.jump_charge,0.1*Stats.pace(rating)/lab.Approach.DURATION),"Actual approach clock uses tier pace")
	lab._reset()
	lab.athlete.build.statistics = {"explosiveness":99}
	var normal_shot: Vector3 = lab._shot_velocity(Vector3(0,3,4),2,0.8)
	lab.athlete.build.statistics = {"swing_power":99}
	var strong_shot: Vector3 = lab._shot_velocity(Vector3(0,3,4),2,0.8)
	check(strong_shot.length() > normal_shot.length(),"Actual spike velocity uses Swing Power charge")
	lab.action_endlag = 0.2
	lab.athlete.build.statistics = {"transition_speed":99}
	lab._physics_process(0.05)
	check(is_equal_approx(lab.action_endlag,0.2-0.05*1.4),"Actual endlag runs faster with Transition Speed")
	lab.athlete.build.statistics = {"capacity":99}
	lab._reset()
	lab.hud.athlete_hud.update_values()
	check(lab.athlete.stamina == 150 and lab.hud.athlete_hud.sta_bar.max_value == 150,"Reset and HUD respect capacity")
	check(athlete("acceleration",99).acceleration() > base.acceleration(),"Acceleration raises velocity convergence rate")
	check(athlete("lateral_speed",99).strafe_factor() > base.strafe_factor() and base.strafe_factor() < 1,"Lateral Speed reduces real strafe penalty")
	lab.queue_free()
	await process_frame
	print("STAT TIERS / MECHANICS: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
