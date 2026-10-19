extends "res://tests/support/test_case.gd"
# Every animation that lives in data/poses must reach the lab: changing the pose data changes the body.
const Library := preload("res://scripts/pose_library.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const Receive := preload("res://scripts/receive_pose.gd")
const Visual := preload("res://scripts/voli_visual.gd")
func _initialize() -> void:
	call_deferred("run")
# Pretend the file on disk says `channels` (a mirrored change), without touching the file.
func _edit(name: String, channels: Dictionary) -> void:
	var pose := Library.read_file(name)
	for channel in channels:
		Library.set_value(pose, channel, "", float(channels[channel]))
	Library._cache[name] = pose
func _restore(name: String) -> void:
	Library.forget(name)
func run() -> void:
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	var body: Node3D = Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"}).body
	# Standing still is ready_stance.
	Pose.base(body, 0.0, 0.0, 0.0, false)
	var knee_before := (body.get_node("LeftLeg/Knee") as Node3D).rotation_degrees.x
	_edit("ready_stance", {"knee": -40.0})
	Pose.base(body, 0.0, 0.0, 0.0, false)
	var knee_after := (body.get_node("LeftLeg/Knee") as Node3D).rotation_degrees.x
	check(absf(knee_after - (-40.0)) < 0.5 and absf(knee_after - knee_before) > 10.0, "editing ready_stance changes how the athlete stands (%.1f -> %.1f)" % [knee_before, knee_after])
	_restore("ready_stance")
	# A receive that is ready is planted_receive: the stance the shuffle walks out of, and the pose itself.
	_edit("planted_receive", {"knee": -90.0, "hip_shift": 0.0})
	Pose.base(body, 0.0, 0.0, 0.0, true, 1.0)
	var stance_knee := (body.get_node("LeftLeg/Knee") as Node3D).rotation_degrees.x
	check(absf(stance_knee - (-90.0)) < 0.5, "planted_receive is the receive stance the gait starts from (%.1f)" % stance_knee)
	Receive.apply(body, "planted", Vector3(0, 1, -1), 1.0)
	check(absf((body.get_node("LeftLeg/Knee") as Node3D).rotation_degrees.x - (-90.0)) < 0.5, "and the planted receive pose itself")
	_restore("planted_receive")
	# The set: gather while armed, jump set in the air, follow-through after contact.
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.auto_feed = false
	game._reset()
	game.armed = true
	game.locked_action = 1
	game.selected = 1
	game.animation.update()
	check(is_equal_approx(game.animation.set_phase(), -0.16), "an armed set holds the gather")
	var gather := Library.read_file("set_gather")
	var rig := Library.read_rig(game.body)
	check(absf(float(rig["shoulder_pitch:Left"]) - Library.value(gather, "shoulder_pitch", "Left")) < 1.0 and absf(float(rig["elbow:Right"]) - Library.value(gather, "elbow", "Right")) < 1.0, "the lab's set shows the set_gather pose (%.1f vs %.1f)" % [float(rig["shoulder_pitch:Left"]), Library.value(gather, "shoulder_pitch", "Left")])
	_edit("set_gather", {"shoulder_pitch": 70.0, "elbow": 120.0})
	game.animation.update()
	var edited := Library.read_rig(game.body)
	check(absf(float(edited["shoulder_pitch:Left"]) - 70.0) < 1.0 and absf(float(edited["elbow:Left"]) - 120.0) < 1.0, "editing set_gather changes the lab's set (%.1f, %.1f)" % [float(edited["shoulder_pitch:Left"]), float(edited["elbow:Left"])])
	_restore("set_gather")
	game.last_contact = game.elapsed - 0.25
	game.last_contact_result = {"action": 1}
	game.armed = false
	var follow: float = game.animation.set_phase()
	check(follow > 0.2 and follow < 0.8, "after contact the set pushes through and recovers (phase %.2f)" % follow)
	game.last_contact = -10.0
	game.last_contact_result = {}
	check(game.animation.set_phase() < -1.5, "with nothing armed there is no set pose")
	game.armed = true
	game.locked_action = 1
	game.motion.jumped = true
	game.motion.airborne_action = 1
	game.animation.set_flight_time = 0.5
	game.animation.set_air_time = 0.25
	game.animation.update()
	var jump_rig := Library.read_rig(game.body)
	var jump_contact := Library.read_file("set_jump_contact")
	check(absf(float(jump_rig["knee:Left"]) - Library.value(jump_contact, "knee", "Left")) < 3.0 and game.animation.pose_source(false, false, false) == "set", "a jump set at the top of the jump shows set_jump_contact and draws as the set (knee %.1f)" % float(jump_rig["knee:Left"]))
	game.armed = false
	game.motion.jumped = false
	game.motion.airborne_action = -1
	print("POSE WIRING CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
