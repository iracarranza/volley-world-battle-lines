extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	var blocker: int = bots.summon_generic(true,1,{1:0,2:1,3:2},true)
	bots._place(blocker,Vector3(0,0,-0.42))
	lab.player.position = Vector3(0,0,2)
	lab.player.rotation.y = 0
	lab.ball_active = true
	lab.ball.position = Vector3(0,3.6,2)
	lab.ball_velocity = Vector3(0,0,-6)
	lab.ball_shot = {"kind":"set","actor":"player"}
	for frame in range(180): bots.blocks.update(bots,1.0/60)
	check(bots.blocks.committed.is_empty(),"A high set or crossing flight alone never triggers a block")
	bots.set_execution_action(blocker,1)
	bots.motion.begin(blocker,bots.actors[blocker],Vector3(0,0.6,-2),0.8,true,lab.GRAVITY,6,NAN,1,1)
	bots.motion.plans[blocker].phase = "approach"
	bots.blocks.update(bots,0.01)
	check(bots.blocks.committed.is_empty() and int(bots.motion.plans[blocker].action) == 1,"A self-set preparation cannot replace itself with a block")
	bots.motion.plans.clear()
	lab.motion.approach_action = 2
	lab.motion.jump_charge = 0.5
	lab.motion.generic_jump = false
	lab.ball_shot = {"kind":"serve","actor":"player_serve"}
	bots.blocks.update(bots,0.01)
	check(bots.blocks.committed.is_empty(),"Serve flight suppresses even an attack approach block cue")
	lab.ball_shot = {"kind":"attack","actor":"player"}
	bots.blocks.update(bots,0.01)
	check(bots.blocks.committed.has(blocker),"An observed opposing attack approach authorizes a block")
	var expected := 2.0/6.0
	check(is_equal_approx(float(bots.motion.plans[blocker].contact),expected),"100% tracking adds no timing error")
	bots.motion.plans.clear()
	bots.blocks.update(bots,0.01)
	check(not bots.motion.plans.has(blocker),"Finishing a jump does not retrigger the same approach")
	lab.motion.jump_charge = -1
	bots.blocks.update(bots,0.01)
	lab.motion.jump_charge = 0.4
	bots.settings[blocker].tracking_accuracy = 0
	bots.random.seed = 773
	bots.blocks.update(bots,0.01)
	check(bots.motion.plans.has(blocker),"A new opposing approach permits a new attempt")
	check(absf(float(bots.motion.plans[blocker].contact)-expected) > 0.001,"Tracking accuracy affects block timing")
	# The player and the bot use the same serve-block fault rule on contact.
	lab.locked_action = 3
	lab.ball_shot = {"kind":"serve","actor":"player_serve"}
	lab._contact()
	check(not lab.ball_active and "SERVE BLOCK FAULT" in lab.feedback,"Player blocking a serve ends the rally as a fault")
	lab.ball_active = true
	lab.ball_shot = {"kind":"serve","actor":"player_serve"}
	bots.set_execution_action(blocker,3)
	bots.actors[blocker].position = Vector3(0,0,-0.42)
	bots.actors[blocker].rotation.y = PI
	lab.ball.position = bots.actors[blocker].position+bots.contact_anchor(blocker).rotated(Vector3.UP,PI)
	bots.active_action = 3
	bots.active_slot = blocker
	bots.intercept = lab.ball.position
	bots.remaining = 0
	var state: Dictionary = bots.preparation.state_for(blocker)
	state.phase = "confirmed"
	state.confirmation_age = 0.2
	state.locked_charge = 0.65
	check(bots.tick_contact(0.01) and not lab.ball_active and "SERVE BLOCK FAULT" in lab.feedback,"Bot physically blocking a serve incurs the same fault")
	check(bots.total_contacts == 0,"A serve block fault does not award a successful contact")
	lab.queue_free()
	await process_frame
	print("BLOCK APPROACH POLICY: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
