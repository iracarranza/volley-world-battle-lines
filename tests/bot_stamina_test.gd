extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	var first: int = bots.summon_generic(true,1,{1:0,2:1,3:2},true)
	var second: int = bots.summon_generic(false,1,{1:0},false)
	var athlete: LabAthlete = bots.athlete_for(first)
	var other: LabAthlete = bots.athlete_for(second)
	var fresh_jump: float = bots._jump_ceiling(first)
	var fresh_speed: float = bots.move_speed_for(first)
	lab.contact_flow.values["training_bot_%d" % first] = 80
	bots.spend_stamina(first,athlete.max_stamina())
	check(athlete.winded and not athlete.exhausted and is_equal_approx(athlete.winded_remaining,10.5),"First stamina depletion makes only that bot Winded")
	check(other.stamina == other.max_stamina() and not other.winded,"Bots have independent stamina reserves")
	check(lab.contact_flow.amount("training_bot_%d" % first) == 0,"Becoming Winded clears that bot's Flow")
	athlete.recover(1,true)
	check(is_equal_approx(athlete.stamina,1),"Winded bot regeneration uses the shared slowed rate")
	bots.spend_stamina(first,5)
	check(athlete.exhausted and is_equal_approx(athlete.exhaustion_remaining,7),"Second depletion while Winded exhausts the bot for seven seconds")
	check(is_equal_approx(bots.move_speed_for(first),fresh_speed*0.55) and bots._jump_ceiling(first) < fresh_jump*0.7,"Exhaustion lowers bot movement speed and jump height")
	lab.ball_active = true
	bots.replan()
	check(bots.slot_enabled(first) and bots.actors[first].visible and not lab.is_benched(),"Exhausted bots remain active without benching the player")
	lab.open_bot_menu()
	lab.bot_menu.open_bot(first)
	check("EXHAUSTED" in lab.bot_menu.vitals.text,"The inspector exposes that bot’s live fatigue state")
	lab.bot_menu.toggle()
	athlete.recover(6.9,true)
	check(athlete.exhausted and athlete.stamina == 0,"Exhaustion locks bot regeneration at zero")
	athlete.recover(0.2,true)
	check(not athlete.exhausted and athlete.winded and athlete.stamina > 0,"After exhaustion the bot returns to Winded")
	lab.ball_active = false
	athlete.hp = 12
	var pepper: LabAthlete = lab.pepper.athlete_for(0)
	pepper.spend(pepper.max_stamina())
	lab.serve.press()
	check(athlete.stamina == athlete.max_stamina() and athlete.hp == 100 and not athlete.winded and not athlete.exhausted,"A new rally fully restores bot stamina, HP and fatigue")
	check(pepper.stamina == pepper.max_stamina() and not pepper.winded,"New rallies refresh Pepper partners too")
	bots.spend_stamina(first,10)
	lab.serve.press()
	check(is_equal_approx(athlete.stamina,athlete.max_stamina()-10),"The strike tap is not treated as another rally refresh")
	lab.serve.clear()
	lab.ball_active = false
	bots.spend_jump(first)
	check(athlete.stamina < athlete.max_stamina()-10,"Bot jump preparation spends its own stamina")
	lab.queue_free()
	await process_frame
	print("BOT STAMINA: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
