extends "res://tests/support/test_case.gd"
const Costs := preload("res://scripts/stamina_costs.gd")
const Athlete := preload("res://scripts/athlete.gd")
func neutral() -> LabAthlete:
	var athlete := Athlete.new()
	athlete.build = {"height":73*0.0254,"span":73*0.0254,"stride_ratio":1.0,"wingspan_ratio":1.0,"power":65,"speed":65,"accuracy":65,"endurance":65}
	return athlete
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var samples := {60:8.0,65:13.0,66:15.5,68:17.0,69:18.125,71:19.375,72:20.0,73:20.0,74:20.0,75:20.5,77:21.5,78:22.5,80:23.75,81:25.25,86:29.0}
	for inches in samples:
		var a := neutral()
		a.build.height = inches*0.0254
		check(is_equal_approx(a.jump_stamina_cost(),samples[inches]),"Reference jump cost at %d inches"%inches)
	var move := [2.25,2.5,2.75,3.0,3.5,4.0,4.5]
	for index in range(7):
		var build := {"height":[60,66,69,73,75,78,81][index]*0.0254}
		var walking := Costs.quote("movement",build,99,0)
		var sprint := Costs.quote("sprint",build,99,0)
		check(is_equal_approx(walking.total,move[index]) and is_equal_approx(sprint.total-walking.total,12),"Height movement band preserves twelve-point Sprint premium")
	var a := neutral()
	check(a.contact_cost(0,1).x == 15 and a.contact_cost(2,3).x == 15,"Contacts have fifteen base, independent of action/repetition")
	var neutral_speed := a.speed()
	a.build.stride_ratio = 1.2
	check(is_equal_approx(a.speed(),neutral_speed*1.2),"Physical stride feeds the existing gait/base-speed calculation")
	check(is_equal_approx(a.jump_stamina_cost(),25),"Long stride adds five to jump")
	a.build.stride_ratio = 0.8
	check(is_equal_approx(a.jump_stamina_cost(),12.5),"Short stride subtracts seven and a half")
	a.build.wingspan_ratio = 1.2
	check(is_equal_approx(a.contact_cost(0,1).x,20),"Long wingspan adds five to contact")
	a.build.wingspan_ratio = 0.8
	check(is_equal_approx(a.contact_cost(2,1).x,7.5),"Short wingspan reduces arm cost")
	a.build.statistics = {"work_rate":99}
	check(a.jump_stamina_cost() == 5 and a.contact_cost(0,1).x == 5,"Work Rate reductions respect the discrete floor")
	a.gameplay_effects = {"exertion_efficiency":90}
	check(a.jump_stamina_cost() == 5,"Efficiency cannot reduce a floored action a second time")
	a.stamina = 100
	a.spend_resolved(a.contact_cost(0,1).x)
	check(a.stamina == 95,"Resolved quote is deducted exactly once")
	a = neutral()
	check(a.stamina_quote("serve").total == 5,"Standing serve respects the discrete floor")
	check(a.quick_step_stamina_cost() == 10,"Quick Step retains half-jump base before its own reductions/floor")
	check(a.stamina_quote("bound").total == 0 and a.stamina_quote("split_step").total == 0,"Preparation steps remain free rather than receiving the discrete floor")
	check(a.stamina_quote("timing_miss").total == 2 and a.stamina_quote("drill_step").total == 3,"Timing misses and drill steps preserve their calibrated exceptions")
	check(a.stamina_quote("jump_charge").total == 3,"Existing jump-charging drain remains unchanged pending design")
	a.spend(2)
	check(a.stamina == 98,"Timing-miss expenditure remains exempt from action floor")
	a = neutral()
	a.stamina = 15
	var before := a.low_stamina_factor()
	a.build.statistics = {"work_rate":99}
	check(is_equal_approx(a.low_stamina_factor(),before),"Work Rate no longer changes low-stamina output")
	for hz in [30,60,120]:
		a = neutral()
		a.stamina = 20
		for frame in range(hz*4): a.recover(1.0/hz,true)
		check(absf(a.stamina-32) < 0.001,"Rest delay/regeneration is timestep independent at %d Hz"%hz)
		a.recover(1,false)
		check(is_equal_approx(a.stationary_seconds,0) and absf(a.stamina-34) < 0.001,"Movement resets rest delay and regenerates two per second")
		a = neutral()
		a.stamina = 60
		for frame in range(hz*2):
			a.spend_resolved(a.movement_stamina_rate(true)/hz)
			a.recover(1.0/hz,false)
		check(absf(a.stamina-34) < 0.001,"Sprint replaces walking and nets thirteen per second at %d Hz"%hz)
		a = neutral()
		a.spend(100)
		for frame in range(hz*11): a.recover(1.0/hz,true)
		check(absf(a.stamina-78.5) < 0.005 and not a.winded,"Rest and Winded boundaries remain timestep independent")
	a = neutral()
	a.build.endurance = 99
	a.gameplay_effects = {"second_wind":23}
	a.stamina = a.max_stamina()
	a.spend(a.stamina)
	a.spend(a.stamina)
	a.recover(7,true)
	check(absf(a.stamina-75) < 0.001,"Large recovery frame cannot trigger Second Wind before its cooldown actually expires")
	print("STAMINA CALIBRATION: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
