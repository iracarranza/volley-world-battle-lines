extends SceneTree
const Stage := preload("res://scripts/dive_stage.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func pose_at(lab: Node3D, air_time: float, direction: Vector3) -> Dictionary:
	lab.jumped = true
	lab.airborne_action = 0
	lab.jump_charge = -1
	lab.dive_world_direction = direction
	lab.dive_flight_time = 0.5
	lab.dive_air_time = air_time
	lab.body.rotation.y = 0.0
	lab._update_pose()
	return {"pitch": lab.body.rotation.x, "left": lab.legs[0].rotation, "right": lab.legs[1].rotation,
		"lknee": lab.legs[0].get_node("Knee").rotation.x, "rknee": lab.legs[1].get_node("Knee").rotation.x}
func run() -> void:
	var right := Stage.resolve(-0.1, Vector2(1, 0))
	var left := Stage.resolve(-0.1, Vector2(-1, 0))
	check(bool(left.trail_right) and not bool(right.trail_right), "leg away from the ball must trail")
	check(signf(float(right.hip_yaw)) == -signf(float(left.hip_yaw)), "hip yaw must mirror")
	var early := Stage.resolve(-0.52)
	check(float(early.weight) > 0.2 and absf(float(early.protraction)) < 0.001, "legs load before any upper-body lean")
	var mid := Stage.resolve(-0.30)
	check(float(mid.weight) > 0.9 and float(mid.protraction) < Stage.resolve(0.0).protraction, "lean arrives after legs")
	check(float(Stage.resolve(0.0).trunk_pitch) > Stage.OLD_FLIGHT_PITCH + 0.3, "trunk at contact is well above the old -0.8 block pitch")
	check(float(Stage.resolve(0.34).trunk_pitch) < float(Stage.resolve(0.0).trunk_pitch) - 0.4, "layout comes after contact")
	check(Stage.phase_for(0.0, 0.0, 0.5, true) == Stage.TAKEOFF and is_equal_approx(Stage.phase_for(0.0, 0.35, 0.5, true), 0.0), "phase clock hits contact at 70% of flight")
	# The dive is posed through the spine and joints, not by tipping the whole body.
	var Library = load("res://scripts/pose_library.gd")
	var base: Dictionary = Library.builtin("planted_receive")
	var prep_pose: Dictionary = Stage.pose_for(Stage.resolve(-0.30, Vector2(1, 0)), base)
	var contact_pose: Dictionary = Stage.pose_for(Stage.resolve(0.0, Vector2(1, 0)), base)
	check(Library.value(prep_pose, "hip_shift") < -5.0, "legs load first: hips go back before takeoff")
	check(Library.value(prep_pose, "thoracic_flexion") < Library.value(prep_pose, "lumbar_flexion") + 3.0 and Library.value(contact_pose, "thoracic_flexion") < Library.value(contact_pose, "lumbar_flexion"), "the waist bends more than the chest, so the upper body stays up")
	check(Library.value(contact_pose, "lumbar_twist") < 0.0 and Library.value(contact_pose, "thoracic_twist") < 0.0, "a dive to the right turns the waist and chest right")
	check(Library.value(Stage.pose_for(Stage.resolve(0.0, Vector2(-1, 0)), base), "thoracic_twist") > 0.0, "a dive to the left turns the other way")
	check(Library.value(contact_pose, "hip_shift") > Library.value(prep_pose, "hip_shift"), "hips drive forward again at takeoff, off the ground")
	# The arms reach out through the flight, to the pose they hold on the floor.
	var Rec = load("res://scripts/dive_recovery.gd")
	var Lib = load("res://scripts/pose_library.gd")
	# A platform with the arms tucked in, as a player might author it.
	var side_base: Dictionary = Lib.builtin("planted_receive")
	Lib.set_value(side_base, "elbow", "", 45.0)
	Lib.set_value(side_base, "shoulder_roll", "", 1.0)
	Lib.set_value(side_base, "shoulder_pitch", "", 45.0)
	var at_takeoff: Dictionary = Stage.pose_for(Stage.resolve(-0.42, Vector2(1, 0)), side_base)
	var at_contact_side: Dictionary = Stage.pose_for(Stage.resolve(0.0, Vector2(1, 0)), side_base)
	var landing_side: Dictionary = Rec.stage_flat(Rec.plan().stages[0], Vector2(1, 0))
	for arm in ["Left", "Right"]:
		var key := "shoulder_pitch:%s" % arm
		var elbow := "elbow:%s" % arm
		check(absf(Lib.value(at_contact_side, "shoulder_pitch", arm) - float(landing_side[key])) < 1.0 and absf(Lib.value(at_contact_side, "elbow", arm) - float(landing_side[elbow])) < 1.0, "a side dive reaches its arms out by contact, as they are on the floor (%s)" % arm)
		check(Lib.value(at_contact_side, "shoulder_pitch", arm) > Lib.value(at_takeoff, "shoulder_pitch", arm) + 40.0 and Lib.value(at_contact_side, "elbow", arm) < Lib.value(at_takeoff, "elbow", arm) - 15.0, "the arms are extending through the flight, not tucked until the floor (%s)" % arm)
	var mid_flight: Dictionary = Stage.pose_for(Stage.resolve(-0.2, Vector2(1, 0)), side_base)
	check(Lib.value(mid_flight, "shoulder_roll", "Right") > Lib.value(side_base, "shoulder_roll", "Right") + 5.0, "the arms are opening outward mid-flight")
	# A side dive banks toward the ball through the flight, to the lean the landing starts from.
	var banked_right := Stage.resolve(0.0, Vector2(1, 0))
	var banked_left := Stage.resolve(0.0, Vector2(-1, 0))
	var landing_roll: float = float(Rec.plan().stages[0].root.roll_side)
	check(is_equal_approx(float(banked_right.layout_roll), landing_roll) and is_equal_approx(float(banked_left.layout_roll), -landing_roll), "a side dive reaches the landing's lean by contact, mirrored for the other side")
	check(absf(float(Stage.resolve(0.0, Vector2(0, 1)).layout_roll)) < 0.001 and absf(float(Stage.resolve(-0.42, Vector2(1, 0)).layout_roll)) < 0.001, "forward dives do not bank and a side dive starts level")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var to_right := pose_at(lab, 0.17, Vector3.RIGHT)
	var to_left := pose_at(lab, 0.17, Vector3.LEFT)
	var ahead := pose_at(lab, 0.17, Vector3.FORWARD)
	check(not is_equal_approx(float(to_right.left.z), float(to_left.left.z)) or not is_equal_approx(float(to_right.lknee), float(to_left.lknee)), "left and right dives pose the legs differently")
	check(float(to_right.right.z) > float(to_right.left.z), "right dive: right foot steps toward the ball")
	check(float(to_left.left.z) < float(to_left.right.z), "left dive: left foot steps toward the ball")
	var contact := pose_at(lab, 0.35, Vector3.FORWARD)
	check(float(contact.pitch) > -0.5, "body pitch at contact stays below the old -0.8 (%.2f)" % float(contact.pitch))
	var takeoff := pose_at(lab, 0.0, Vector3.FORWARD)
	check(absf(float(takeoff.pitch)) < 0.25 and float(takeoff.lknee) < -0.2, "takeoff: legs loaded, trunk still upright")
	var landing := pose_at(lab, 0.5, Vector3.FORWARD)
	check(float(landing.pitch) < float(contact.pitch) - 0.4, "laid out after contact")
	# Repeated frames must not accumulate rotation, and landing must return the body level.
	var yaw_start: float = lab.body.rotation.y
	pose_at(lab, 0.5, Vector3.RIGHT)
	var roll_once: float = lab.body.rotation.z
	for i in range(120):
		pose_at(lab, 0.5, Vector3.RIGHT)
	check(absf(wrapf(lab.body.rotation.y - lab.dive_applied_yaw - yaw_start, -PI, PI)) < 0.001 and absf(lab.body.rotation.z - roll_once) < 0.001, "repeated dive frames do not accumulate rotation")
	lab.jumped = false
	lab.airborne_action = -1
	lab.dive_air_time = 0.0
	lab._update_pose()
	check(absf(lab.body.rotation.z) < 0.0001 and absf(lab.body.rotation.x) < 0.0001 and absf(lab.dive_applied_yaw) < 0.0001, "body returns level after landing")
	var yaw_after: float = lab.body.rotation.y
	lab._update_pose()
	check(is_equal_approx(lab.body.rotation.y, yaw_after), "no yaw drift once on the ground")
	print("DIVE STAGE CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
