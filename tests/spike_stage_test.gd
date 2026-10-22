extends "res://tests/support/test_case.gd"
const Stage := preload("res://scripts/spike_stage.gd")
const Library := preload("res://scripts/pose_library.gd")
const Visual := preload("res://scripts/voli_visual.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# The clock: the body loads on its own and holds; only the click starts the strike.
	var loaded: float = Stage.LOADED
	check(is_equal_approx(Stage.phase_for(0.0, 0.5), -0.62) and is_equal_approx(Stage.phase_for(0.4, 0.5), loaded) and is_equal_approx(Stage.phase_for(0.5, 0.5), loaded), "without a click the spiker loads from takeoff and holds the cocked pose")
	check(is_equal_approx(Stage.phase_for(0.25, 0.5, 0.0), loaded) and is_equal_approx(Stage.phase_for(0.25, 0.5, Stage.STRIKE_SECONDS), 0.0), "the click starts the strike, which reaches contact in %.2f s" % Stage.STRIKE_SECONDS)
	check(Stage.phase_for(0.3, 0.5, Stage.STRIKE_SECONDS * 0.5) < -0.05 and Stage.phase_for(0.3, 0.5, Stage.STRIKE_SECONDS * 0.5) > loaded, "the arm is accelerating into the ball part way through the strike")
	check(is_equal_approx(Stage.phase_for(0.3, 0.5, 0.6), 0.0), "it waits at contact for the ball")
	check(is_equal_approx(Stage.phase_for(0.3, 0.5, 0.6 + Stage.FOLLOW_SECONDS, 0.6), 0.45) and Stage.phase_for(0.3, 0.5, 0.7, 0.6) > 0.0 and Stage.phase_for(0.3, 0.5, 0.7, 0.6) < 0.45, "follow-through runs from the hit")
	check(is_equal_approx(Stage.phase_for(0.3, 0.5, Stage.STRIKE_SECONDS, Stage.STRIKE_SECONDS), 0.0), "a hit as the strike finishes puts the arm at contact at that moment")
	check(is_equal_approx(Stage.STRIKE_SECONDS, preload("res://scripts/contact_execution.gd").SWEET_CENTER), "the arm reaches its extension at the centre of the sweet window")
	# The staged timing VWM defines survives: legs before trunk before shoulder before elbow.
	var cock := Stage.pose_for(-0.30, 1.0)
	var contact := Stage.pose_for(0.0, 1.0)
	var follow := Stage.pose_for(0.4, 1.0)
	check(float(cock["shoulder_pitch:Right"]) > -190.0 and float(contact["shoulder_pitch:Right"]) < float(cock["shoulder_pitch:Right"]) - 40.0, "The striking shoulder travels overhead into contact")
	check(float(follow["shoulder_pitch:Right"]) < float(contact["shoulder_pitch:Right"]), "The arm keeps going through the ball")
	check(float(contact["elbow:Right"]) < float(cock["elbow:Right"]) + 90.0 and float(contact["elbow:Right"]) < 20.0, "The elbow is nearly straight at contact")
	# The trunk uses the spine, not a whole-body tilt.
	var arch := Stage.pose_for(-0.30, 1.0)
	check(absf(float(arch["lumbar_twist"])) > 1.0 and absf(float(arch["thoracic_twist"])) > absf(float(arch["lumbar_twist"])), "The turn goes through waist and chest, more in the chest")
	check(float(contact["hip_hinge"]) != float(arch["hip_hinge"]), "The hips hinge differently as the swing goes through")
	# Left- and right-handed swings mirror.
	var left := Stage.pose_for(0.0, -1.0)
	check(is_equal_approx(float(left["shoulder_pitch:Left"]), float(contact["shoulder_pitch:Right"])) and is_equal_approx(float(left["thoracic_twist"]), -float(contact["thoracic_twist"])) or is_equal_approx(float(left["shoulder_pitch:Left"]), float(contact["shoulder_pitch:Right"])), "A left-handed swing is the mirror of a right-handed one")
	# On a rig the swing poses the striking arm high and the guide arm differently.
	var lab := Node3D.new()
	lab.set_script(load("res://scripts/preview_stub.gd"))
	root.add_child(lab)
	var parent := Node3D.new()
	lab.add_child(parent)
	var body: Node3D = Visual.build(lab, parent, "Vegi", {}, {"height": 1.9, "span": 1.95, "name": "T", "dominant_hand": "Right", "role": "OH"}).body
	Pose.base(body, 0.0, 0.0, 0.0, false)
	Stage.apply(body, 0.0, 1.0, 0.7)
	var hand_height := (body.get_node("RightArm/Elbow/Wrist") as Node3D).global_position.y
	var guide_height := (body.get_node("LeftArm/Elbow/Wrist") as Node3D).global_position.y
	var head_height := (body.get_node("Head") as Node3D).global_position.y
	check(hand_height > head_height, "At contact the striking hand is above the head (%.2f vs %.2f)" % [hand_height, head_height])
	check(guide_height < hand_height - 0.2, "The guide arm is lower than the striking hand")
	Pose.base(body, 0.0, 0.0, 0.0, false)
	Stage.apply(body, -0.55, 1.0, 0.7)
	var cocked := (body.get_node("RightArm/Elbow/Wrist") as Node3D).global_position
	Pose.base(body, 0.0, 0.0, 0.0, false)
	Stage.apply(body, 0.4, 1.0, 0.7)
	var through := (body.get_node("RightArm/Elbow/Wrist") as Node3D).global_position
	check(cocked.distance_to(through) > 0.5, "The hand actually travels through the swing")
	# The swing is aimed by where the ball is and where the shot is going.
	var low_ahead := {"ball_local": Vector3(0.0, 2.1, -0.9), "shot_yaw": 0.0}
	var right_side := {"ball_local": Vector3(0.5, 2.3, -0.3), "shot_yaw": 0.0}
	var left_side := {"ball_local": Vector3(-0.5, 2.3, -0.3), "shot_yaw": 0.0}
	var neutral := Stage.pose_for(0.0, 1.0, 0.7, "Power swing", {"ball_local": Vector3(0.0, 2.3, -0.35), "shot_yaw": 0.0})
	var out := Stage.pose_for(0.0, 1.0, 0.7, "Power swing", right_side)
	var across := Stage.pose_for(0.0, 1.0, 0.7, "Power swing", left_side)
	var front := Stage.pose_for(0.0, 1.0, 0.7, "Power swing", low_ahead)
	check(float(out["shoulder_roll:Right"]) > float(neutral["shoulder_roll:Right"]) + 10.0 and float(across["shoulder_roll:Right"]) < float(neutral["shoulder_roll:Right"]) - 10.0, "the arm opens toward a ball on its side and crosses toward one on the other")
	check(absf(float(out["thoracic_twist"])-float(neutral["thoracic_twist"])) < 8.0 and absf(float(across["thoracic_twist"])-float(neutral["thoracic_twist"])) < 8.0, "the chest stays readable as facing while the arm reaches to the ball")
	check(float(front["shoulder_pitch:Right"]) < float(neutral["shoulder_pitch:Right"]) - 8.0 and float(front["lumbar_flexion"]) > float(neutral["lumbar_flexion"]) + 4.0, "a ball well in front pulls the arm further over and bends the waist")
	var loaded_a := Stage.pose_for(Stage.LOADED, 1.0, 0.7, "Power swing", right_side)
	var loaded_b := Stage.pose_for(Stage.LOADED, 1.0, 0.7, "Power swing", left_side)
	check(absf(float(loaded_a["shoulder_roll:Right"]) - float(loaded_b["shoulder_roll:Right"])) < 1.0 and absf(float(loaded_a["thoracic_twist"]) - float(loaded_b["thoracic_twist"])) < 1.0, "the loaded pose is the same wherever the ball is: the arm commits to the ball only when the strike starts")
	var follow_left := Stage.pose_for(0.3, 1.0, 0.7, "Power swing", {"ball_local": Vector3(0.0, 2.3, -0.35), "shot_yaw": 0.5})
	var follow_right := Stage.pose_for(0.3, 1.0, 0.7, "Power swing", {"ball_local": Vector3(0.0, 2.3, -0.35), "shot_yaw": -0.5})
	check(absf(float(follow_left["thoracic_twist"])+float(follow_left["lumbar_twist"])) <= Stage.CHEST_TURN_LIMIT and absf(float(follow_left["shoulder_roll:Right"])-float(follow_right["shoulder_roll:Right"])) > 10.0, "shot sides produce distinct arm poses while the chest remains facing forward (world-space hand direction is covered by swing_lead_in_test)")
	for hand in [-1.0,1.0]:
		for phase in [-0.3,0.0,0.3,0.45]:
			for yaw in [-0.5,0.0,0.5]:
				var posed := Stage.pose_for(phase,hand,0.7,"Power swing",{"ball_local":Vector3(0.4*hand,2.3,-0.4),"shot_yaw":yaw})
				var chest := float(posed.lumbar_twist)+float(posed.thoracic_twist)
				check(absf(chest) <= Stage.CHEST_TURN_LIMIT+0.00001,"Chest continues indicating facing for both hands and shot sides")
				check(absf(chest+float(posed.neck_twist)) < 0.00001,"Gaze counters chest turn to maintain facing")
	var arm_left := Stage.pose_for(0.0,1.0,0.7,"Power swing",{"ball_local":Vector3(0,2.3,-0.35),"shot_yaw":0.4})
	var arm_right := Stage.pose_for(0.0,1.0,0.7,"Power swing",{"ball_local":Vector3(0,2.3,-0.35),"shot_yaw":-0.4})
	check(absf(float(arm_left["shoulder_rotation:Right"])-float(arm_right["shoulder_rotation:Right"])) > 75,"Shot-angle arm rotation is exaggerated already at contact")
	print("SPIKE STAGE CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
