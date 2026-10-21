extends "res://tests/support/test_case.gd"
const Target := preload("res://scripts/bot_attack_target.gd")
const Field := preload("res://scripts/block_field.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var origin := Vector3(0,3.8,2)
	var left := Target.choose(origin,Vector3.ZERO,4.5,9,[Vector3(-0.7,0,-0.4)],[])
	var right := Target.choose(origin,Vector3.ZERO,4.5,9,[Vector3(0.7,0,-0.4)],[])
	check(left.x > 0 and right.x < 0,"Attack chooses the lane opposite visible block placement")
	var split := Target.choose(origin,Vector3.ZERO,4.5,9,[Vector3(-0.7,0,-0.4),Vector3(0.7,0,-0.4)],[])
	check(absf(split.x) < absf(left.x),"Two separated blockers leave a different best lane")
	for depth in [5.0,9.0]:
		var target := Target.choose(Vector3(0,3.8,-2),Vector3.ZERO,2.5,depth,[],[])
		check(target.z > 0 and target.z < depth and absf(target.x) < 2.5,"Target respects opposite side and provisional court bounds")
	var field := Field.definition(1.86,2.26)
	check(not Field.contains(field,Vector3(0.58,field.palm,field.center.z),0.13125),"Old lateral padding no longer blocks")
	check(not Field.contains(field,Vector3(0,field.palm,field.center.z+0.32),0.13125),"Old depth padding no longer blocks")
	check(Field.contains(field,Vector3(field.hand_x,field.palm,field.center.z),0),"Actual palm remains covered")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var bots = lab.training_bots
	bots.settings[7].enabled = true
	bots.settings[7].action_type = 3
	bots.actors[7].position = Vector3(-0.7,0,-0.4)
	bots._plan(2,origin,1.2,2)
	var chosen: Vector3 = bots.attack_targets[2]
	check(chosen.x > 0,"Runtime chooses open court against opposing blocker")
	bots.tick_motion(0.9)
	var yaw: float = bots.actors[2].rotation.y
	bots.actors[7].position.x = 0.7
	lab.ball.position = origin
	bots._launch(2,2)
	check(bots.attack_targets[2] == chosen,"Blocker movement after takeoff cannot change chosen target")
	check(absf(wrapf(atan2(-lab.ball_velocity.x,-lab.ball_velocity.z)-yaw,-PI,PI)) <= deg_to_rad(15.01),"Swing stays within committed facing cone")
	lab.queue_free()
	await process_frame
	print("OPEN COURT ATTACKS: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
