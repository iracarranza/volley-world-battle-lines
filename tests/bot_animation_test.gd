extends SceneTree
const BotAnimation := preload("res://scripts/bot_animation.gd")
const Library := preload("res://scripts/pose_library.gd")
const SetStage := preload("res://scripts/set_stage.gd")
const SpikeStage := preload("res://scripts/spike_stage.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var bots = lab.training_bots
	var animation := BotAnimation.new()
	var setter: Dictionary = bots.rigs[1]
	var original: Vector3 = bots.actors[1].position
	animation.update(setter, 0.1, {"action": 1, "planned": true, "remaining": 0.1})
	check(animation.state_for(setter.body).source == "set" and animation.state_for(setter.body).phase < 0, "Setter gathers before impact")
	animation.contact(setter, 1, Vector3(0, 2.25, 0))
	animation.update(setter, 0, {"action": 1, "planned": false})
	var actual := Library.read_rig(setter.body)
	var expected := SetStage.data_pose(SetStage.follow_phase(0.0))
	check(absf(float(actual["shoulder_pitch:Left"]) - float(expected["shoulder_pitch:Left"])) < 0.001, "Bot Set contact starts from the authored gather pose and blends into the follow-through")
	var contact_elbow := float(actual["elbow:Left"])
	animation.update(setter, 0.22)
	check(animation.state_for(setter.body).phase > 0.3 and absf(float(Library.read_rig(setter.body)["elbow:Left"]) - contact_elbow) > 1, "Set extension continues after the ball leaves")
	var receiver: Dictionary = bots.rigs[0]
	var receive_animation := BotAnimation.new()
	receive_animation.update(receiver, 0.1, {"action": 0, "planned": true, "posture": "planted"})
	var planted := Library.flatten(Library.load_pose("planted_receive"))
	check(absf(float(Library.read_rig(receiver.body)["shoulder_pitch:Left"]) - float(planted["shoulder_pitch:Left"])) < 0.001, "Bot planted receive uses current authored data")
	for posture in ["moving", "reaching", "off-axis"]:
		receive_animation.update(receiver, 0.3, {"action": 0, "planned": true, "posture": posture, "contact_point": Vector3(0.6, 0.95, -1), "speed": 2.0})
		check(receive_animation.state_for(receiver.body).source == "receive:" + posture, "Receive variant is applied: " + posture)
	var attacker: Dictionary = bots.rigs[2]
	var spike_animation := BotAnimation.new()
	spike_animation.update(attacker, 0.1, {"action": 2, "planned": true, "airborne": true, "remaining": 0.3, "rise": 0.4})
	check(spike_animation.state_for(attacker.body).phase < 0, "Spike uses shared windup stage")
	spike_animation.contact(attacker, 2, Vector3(0.2, 3, 0))
	spike_animation.update(attacker, 0, {"action": 2, "airborne": true})
	var spike_contact := SpikeStage.pose_for(0, 1, 0.65,"Power swing",{"ball_local":Vector3(0.2,3,0),"shot_yaw":0.0})
	check(absf(float(Library.read_rig(attacker.body)["elbow:Right"]) - float(spike_contact["elbow:Right"])) < 0.001, "Spike animation reaches actual contact phase")
	spike_animation.update(attacker, 0.3, {"action": 2, "airborne": true})
	check(spike_animation.state_for(attacker.body).phase > 0.3, "Shared spike follow-through continues")
	check(bots.actors[1].position == original, "Presentation does not move actor or hurtbox origin")
	var avi: Dictionary = lab.pepper.rigs[0]
	var wing := BotAnimation.new()
	wing.update(avi, 0.1, {"action": 3, "planned": true, "airborne": true})
	check(absf(avi.body.get_node("LeftArm/WingShoulder").rotation.z) > 0.01, "Avi bots use wing action poses")
	wing.update(avi, 0.2, {"dive_phase": 0.2, "dive_direction": Vector2(1, 0)})
	check(wing.state_for(avi.body).source == "dive", "Shared bot layer supports dive stages when behavior requests a dive")
	wing.update(avi, 0.2, {"dive_recovery_time": 0.2, "dive_direction": Vector2(1, 0)})
	check(wing.state_for(avi.body).source == "dive", "Shared bot layer supports authored dive recovery")
	print("BOT SHARED ANIMATIONS: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
