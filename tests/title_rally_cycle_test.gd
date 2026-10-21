extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var backdrop = load("res://scripts/title_rally_backdrop.gd").new()
	root.add_child(backdrop)
	await physics_frame
	await process_frame
	backdrop.set_physics_process(false)
	backdrop.lab.set_physics_process(false)
	var bots = backdrop.lab.training_bots
	for size in [1,2,3,5,1]:
		for away in [false,true]:
			var count := 0
			var blockers := 0
			for config in bots.settings:
				if not config.enabled or config.away != away: continue
				count += 1
				if config.can_block(): blockers += 1
				check(config.tracking_accuracy == 75 and config.aiming_accuracy == 65 and config.charge_accuracy == 70,"Backdrop bots use reduced consistency")
			check(count == size,"Rally composition cycles to %dv%d"%[size,size])
			check(blockers == (2 if size == 5 else 1),"Lead blocks in every format; 5v5 has two per side")
		# An idle gap before a serve must not skip a composition.
		var index: int = backdrop.scene_index
		backdrop.wait = 10
		backdrop.lab.ball_active = false
		backdrop._physics_process(0.01)
		check(backdrop.scene_index == index,"Waiting for a serve does not advance the composition")
		backdrop.lab.ball_active = true
		backdrop._physics_process(0.01)
		backdrop.lab.ball_active = false
		backdrop._physics_process(0.01)
		check(backdrop.scene_index == (index+1)%4,"First rally end immediately advances once")
	backdrop.queue_free()
	await process_frame
	var moc = load("res://scripts/moment_of_contact.gd").new()
	check(moc.mode == moc.Mode.TRAJECTORY_STEERING,"New sessions default to trajectory steering")
	moc.free()
	print("TITLE RALLY CYCLE: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
