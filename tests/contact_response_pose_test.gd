extends "res://tests/support/test_case.gd"
const Response := preload("res://scripts/contact_response_pose.gd")
const Library := preload("res://scripts/pose_library.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for action in [0, 3]:
		for age in [-1.0, 0.0, 0.6]:
			for value in Response.offsets(action, age).values():
				check(absf(value) < 0.00001, "Contact overlay is neutral before contact and after settling")
		var previous := Response.offsets(action, 0.0)
		for step in range(1, 601):
			var next := Response.offsets(action, step*0.001, {"charge_match": {"severity": 1.0}, "block_response": {"severity": 1.0}})
			for key in next:
				check(absf(float(next[key])-float(previous[key])) < 0.8, "Response has no discontinuity at phase boundaries")
			previous = next
	var soft := Response.offsets(3, 0.07)
	var hard := Response.offsets(3, 0.07, {"block_response": {"severity": 1.0, "side": 1.0}})
	var mirror := Response.offsets(3, 0.07, {"block_response": {"severity": 1.0, "side": -1.0}})
	check(float(hard["elbow:Left"]) > float(soft["elbow:Left"]), "Overpowered blocks visibly absorb more force")
	check(is_equal_approx(hard.thoracic_bend, -mirror.thoracic_bend), "Recoil mirrors the contact side")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.animation.pose_smoothing = false
	for action in [0, 3]:
		lab._reset()
		lab.selected = action
		lab.locked_action = action
		lab.armed = true
		lab.motion.jumped = action == 3
		lab.motion.airborne_action = action
		lab.animation.update()
		var shape: Dictionary = lab._raw_hurtbox_definition(action).duplicate(true)
		var actor_transform: Transform3D = lab.player.transform
		var velocity: Vector3 = lab.ball_velocity
		var shot: Dictionary = lab.ball_shot.duplicate(true)
		var ball_transform: Transform3D = lab.ball.transform
		var before := Library.read_rig(lab.body)
		lab.animation.on_contact({"actor":"player", "action":action, "physical_hit":true, "charge_match":{"severity":1.0}, "block_response":{"severity":1.0}})
		lab.animation.tick_action_clocks(0.07/lab.athlete.transition_rate())
		lab.animation.update()
		var after := Library.read_rig(lab.body)
		check(absf(after["elbow:Left"]-before["elbow:Left"]) > 3, "Resolved contact drives a visible response")
		var age: float = lab.animation.contact_age
		lab.animation.update()
		check(lab.animation.contact_age == age, "Pose composition does not advance the contact clock")
		check(absf(Library.read_rig(lab.body)["elbow:Left"]-after["elbow:Left"]) < 0.001, "Rebuilding a pose does not accumulate the overlay")
		check(lab._raw_hurtbox_definition(action) == shape, "Response does not change contact geometry")
		check(lab.player.transform == actor_transform and lab.ball.transform == ball_transform and lab.ball_velocity == velocity and lab.ball_shot == shot, "Presentation preserves actor and ball state")
		lab.animation.floor_recovery_time = 0.1
		lab.animation.floor_recovery_name = "shrug"
		lab.animation.contact_age = -1
		lab.animation.update()
		var floor_pose := Library.read_rig(lab.body)
		lab.animation.contact_age = age
		lab.animation.update()
		check(absf(Library.read_rig(lab.body)["elbow:Left"]-floor_pose["elbow:Left"]) < 0.001, "Existing floor recovery owns its pose")
		lab._reset()
		check(lab.animation.contact_age < 0 and lab.animation.contact_evidence.is_empty(), "Reset clears contact presentation")
	# Actor-local delta is supplied by the scheduler, not recomputed by the layer.
	for scale in [0.0, 0.25, 0.6, 1.0]:
		lab.animation.on_contact({"actor":"player", "action":0, "physical_hit":true})
		lab.animation.tick_action_clocks(0.1*scale)
		check(is_equal_approx(lab.animation.contact_age, 0.1*scale*lab.athlete.transition_rate()), "Contact clock honors supplied local time")
	var bot = lab.training_bots.animation
	var rig: Dictionary = lab.training_bots.rigs[0]
	bot.reset()
	bot.update(rig, 1.0, {"planned":true, "action":0})
	var evidence := {"charge_match":{"severity":1.0}}
	bot.contact(rig, 0, Vector3(0,1,-0.6), "planted", 0.0, false, evidence)
	evidence.charge_match.severity = 0.0
	check(bot.state_for(rig.body).contact_evidence.charge_match.severity == 1.0, "Bot response owns its evidence snapshot")
	bot.update(rig, 0.08, {"planned":true, "action":0})
	var receiving := Library.read_rig(rig.body)
	bot.update(rig, 0.0, {"planned":true, "action":1})
	var switching := Library.read_rig(rig.body)
	for key in ["elbow:Left", "shoulder_pitch:Right", "thoracic_flexion"]:
		check(absf(float(receiving[key])-float(switching[key])) < 0.001, "Switching actions retains the visible response at the smoothing seam")
	lab.queue_free()
	await process_frame
	print("CONTACT RESPONSE: %d/%d" % [checks-failures, checks])
	quit(1 if failures else 0)
