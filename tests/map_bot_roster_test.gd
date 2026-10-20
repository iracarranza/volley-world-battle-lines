extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	check(bots.settings.size() == 28 and not bots.any_enabled(),"Map starts with an empty bounded configurable roster")
	for i in range(5): check(bots.summon(false,0,0,1) >= 0,"Repeated contact types can be summoned on Net 1")
	check(bots.summon(false,0,2,3) == -1,"Sixth Home bot on the same net is rejected")
	for i in range(5): check(bots.summon(true,0,2,3) >= 0,"Away side has five independent net places")
	check(bots.count_net(0) == 10 and bots.count_net_side(0,false) == 5 and bots.count_net_side(0,true) == 5,"A net supports five athletes on each side")
	check(bots.summon(true,0,2,3) == -1,"Sixth Away bot on the same net is rejected")
	for i in range(5): check(bots.summon(false,1,1,2) >= 0,"Net 2 accepts its own roster")
	for i in range(4): check(bots.summon(false,2,2,3) >= 0,"Net 3 accepts remaining team places")
	check(bots.count_team(false) == 14 and bots.summon(false,2,3,0) == -1,"Fourteen-bot team cap applies across primary nets")
	var away: int = bots.summon(true,2,3,0)
	check(away >= 0 and bots.count_net(2) == 5,"Other team can use the remaining net place")
	check(not bots.assign(away,false,2,3,0) and bots.settings[away].away,"Rejected reassignment is atomic")
	lab.open_bot_menu()
	lab.bot_menu.open_bot(away)
	lab.bot_menu.team.select(0)
	lab.bot_menu.apply_selected()
	check(lab.bot_menu.team.selected == 1 and bots.settings[away].away,"Rejected inspector edit restores the bot's actual settings")
	lab.bot_menu.toggle()
	lab.contact_flow.values["training_bot_0"] = 80.0
	lab.contact_flow.impulses["training_bot_0"] = {"remaining":1.0}
	bots.dismiss(0)
	check(lab.contact_flow.amount("training_bot_0") == 0 and not lab.contact_flow.impulses.has("training_bot_0"),"Dismissed bot places do not transfer Flow or knockback to a new summon")
	check(bots.assign(away,false,2,3,0) and bots.count_team(false) == 14,"Dismissing a bot frees team capacity")
	check(not bots.assign(away,false,3,0,1),"Pit/falling nets cannot be assigned")
	for slot in range(bots.settings.size()): bots.dismiss(slot)
	var receiver: int = bots.summon(false,0,0,1)
	var setter: int = bots.summon(false,0,1,2)
	var attacker: int = bots.summon(true,2,2,3)
	lab.select_net(0)
	check(bots.slot_enabled(receiver) and bots.slot_enabled(setter) and not bots.slot_enabled(attacker),"Only bots assigned to the live court intercept its ball")
	check(bots.actors[attacker].visible,"Bots on other nets remain present on the map")
	lab.player.position = bots.actors[setter].position+Vector3(0.5,0,0)
	var interact := InputEventKey.new()
	interact.keycode = KEY_I
	interact.pressed = true
	lab._unhandled_input(interact)
	check(lab.bot_menu.selected_slot == setter and lab.bot_menu.panel.visible,"Nearby I interaction opens that particular bot inspector")
	for field in lab.bot_menu.contacts: field.select(0)
	lab.bot_menu.blocking.button_pressed = true
	lab.bot_menu.apply_selected()
	check(bots.settings[setter].action_type == 3 and bots.shapes[setter].shape == "block_columns","Inspector changes actual role and hurtbox")
	lab.bot_menu.toggle()
	lab._reset()
	check(bots.settings[receiver].enabled and bots.settings[setter].enabled and bots.settings[attacker].enabled,"Reset preserves all bot assignments")
	lab.queue_free()
	await process_frame
	print("MAP BOT ROSTER: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
