extends "res://tests/support/test_case.gd"
const Preparation := preload("res://scripts/bot_preparation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var prep := Preparation.new()
	var random := RandomNumberGenerator.new()
	random.seed = 75
	var shot := {"kind":"attack","charge":0.6}
	prep.begin(0,0,shot,2,100,random)
	check(prep.state_for(0).target > 0.6,"Auto receive adapts to incoming pressure")
	for target in [0.2,0.9]:
		prep.finish(0)
		prep.begin(0,0,shot,2,100,random,0,1,target)
		prep.tick(0,2)
		check(is_equal_approx(prep.state_for(0).locked_charge,target),"Fixed intended charge overrides adaptive target with enough preparation")
	var errors := []
	for index in range(10):
		prep.begin(index,2,{},2,0,random,0,1,0.65)
		errors.append(absf(prep.state_for(index).target-0.65))
	check(errors.max() > 0.1,"Charge accuracy affects fixed targets too")
	prep.finish(0)
	prep.begin(0,2,{},0.05,100,random,0,1,1)
	prep.tick(0,0.05)
	check(prep.state_for(0).locked_charge < 1,"Fixed charge still requires preparation time")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var bots = lab.training_bots
	var slot: int = bots.summon_generic(false,1,{1:0},false)
	lab.open_bot_menu()
	lab.bot_menu.selected_slot = slot
	lab.bot_menu.refresh()
	lab.bot_menu.load_selected()
	check(lab.bot_menu.charge_mode.selected == 0 and not lab.bot_menu.intended_charge.editable,"Inspector starts in Auto")
	lab.bot_menu.charge_mode.select(1)
	lab.bot_menu.intended_charge.value = 35
	lab.bot_menu.charge.value = 72
	lab.bot_menu.apply_selected()
	check(not bots.settings[slot].auto_intended_charge and is_equal_approx(bots.intended_charge_for(slot),0.35) and bots.settings[slot].charge_accuracy == 72,"Inspector persists independent intended charge and accuracy")
	lab.bot_menu.load_selected()
	check(lab.bot_menu.intended_charge.editable and lab.bot_menu.charge_mode.selected == 1,"Inspector restores fixed target mode")
	lab.queue_free()
	await process_frame
	print("BOT INTENDED CHARGE: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
