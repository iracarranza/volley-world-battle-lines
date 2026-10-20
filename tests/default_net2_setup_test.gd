extends "res://tests/support/test_case.gd"
const Presets := preload("res://scripts/bot_roster_presets.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	title._enter_lab()
	await scene_changed
	await process_frame
	var lab = current_scene
	lab.set_process(false)
	lab.set_physics_process(false)
	var bots = lab.training_bots
	check(bots.count_net_side(1,false) == 4 and bots.count_net_side(1,true) == 4,"Contact Lab entry loads four athletes per side at Net 2")
	var speeds := [1.75,7.25,7.25,7.25,3.5,3.5,3.5,6.0]
	var blocking := [true,false,false,false,true,true,true,true]
	var plans := [{1:0},{1:0},{2:1},{1:0},{1:0},{2:1},{3:2},{}]
	var homes := []
	for slot in range(8):
		var config = bots.settings[slot]
		check(config.enabled and config.responsibility_mode and config.responsibilities == plans[slot] and config.can_block() == blocking[slot],"Bot #%d restores inspected responsibilities"%(slot+1))
		check(config.moves and config.follows_ball and is_equal_approx(config.move_speed,speeds[slot]),"Bot #%d restores inspected movement"%(slot+1))
		check(config.tracking_accuracy == 100 and config.aiming_accuracy == 100 and config.charge_accuracy == 100,"Bot #%d restores inspected accuracy"%(slot+1))
		check(config.away == (slot in [3,4,5,6]),"Bot #%d restores its team"%(slot+1))
		check(not homes.has(config.fixed_position),"Default starting positions are spread out")
		homes.append(config.fixed_position)
	check(not bots.settings[8].enabled,"Accidental ninth bot is excluded")
	lab._reset()
	check(bots.count_net(1) == 8 and bots.settings[0].fixed_position == homes[0],"Reset preserves the default roster and saved formation")
	check(not Presets.apply_net_2(bots),"Startup defaults cannot overwrite a live roster")
	check(not has_meta(Presets.STARTUP_META),"Startup request is consumed once")
	lab.queue_free()
	await process_frame
	print("DEFAULT NET 2: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
