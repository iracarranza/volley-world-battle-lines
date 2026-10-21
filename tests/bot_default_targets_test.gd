extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	bots.receive_targets.clear()
	bots.set_targets.clear()
	var center: Vector3 = lab.court_center
	var index: int = bots.current_net
	var diagonal := 1.0/sqrt(2.0)
	for scale in [1.0,0.75,0.5]:
		lab.court_half_width = 4.5*scale
		lab.court_half_depth = 9.0*scale
		for away in [false,true]:
			var side := -1.0 if away else 1.0
			var receive: Vector3 = bots.receive_target(index,away)-center
			var target: Vector3 = bots.set_delivery_target(index,away)-center
			check(receive.is_equal_approx(Vector3(1.5,0,1)*scale*side),"Receive target scales from right sideline/net offsets and mirrors team-relative sides")
			check(target.is_equal_approx(Vector3(-4.5+diagonal,0,diagonal)*scale*side),"Set target scales from a one-metre diagonal inside left pin")
	bots.receive_targets["%d:false"%index] = center+Vector3(-1,0,2)
	bots.set_targets["%d:false"%index] = center+Vector3(1,0,2)
	lab.court_half_width = 2.5
	lab.court_half_depth = 5
	check(bots.receive_target(index,false) == center+Vector3(-1,0,2),"Manual receive marker remains explicit")
	check(bots.set_delivery_target(index,false) == center+Vector3(1,0,2),"Manual set marker remains explicit")
	lab.queue_free()
	await process_frame
	print("DEFAULT BOT TARGETS: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
