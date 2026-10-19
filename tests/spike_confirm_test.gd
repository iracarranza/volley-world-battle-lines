extends "res://tests/support/test_case.gd"
# Holding a jump with an attack charged plays the approach, the windup and the lead-arm point -- and then waits.
# The swing itself belongs to the click.
const Stage := preload("res://scripts/spike_stage.gd")
const Library := preload("res://scripts/pose_library.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab._reset()
	lab.armed = true
	lab.locked_action = 2
	lab.selected = 2
	lab.locked_charge = 0.7
	lab.motion.jumped = true
	lab.motion.airborne_action = 2
	lab.motion.jump_charge = -1
	lab.animation.spike_flight_time = 0.6
	var strike_shoulder := func() -> float:
		return float(Library.read_rig(lab.body)["shoulder_pitch:Right"])
	var guide_shoulder := func() -> float:
		return float(Library.read_rig(lab.body)["shoulder_pitch:Left"])
	var poses := {}
	for t in [0.0, 0.1, 0.2, 0.3, 0.45, 0.58]:
		lab.animation.spike_air_time = t
		lab.animation.update()
		poses[t] = [strike_shoulder.call(), guide_shoulder.call(), lab.animation.spike_swing_time]
	var loaded := Stage.pose_for(Stage.LOADED, 1.0, 0.7)
	check(absf(float(poses[0.45][0]) - float(loaded["shoulder_pitch:Right"])) < 1.0 and absf(float(poses[0.58][0]) - float(loaded["shoulder_pitch:Right"])) < 1.0, "late in the jump with no click the striking arm is still cocked, not swinging (%.0f vs %.0f)" % [float(poses[0.58][0]), float(loaded["shoulder_pitch:Right"])])
	check(float(poses[0.0][0]) != float(poses[0.3][0]), "the windup builds through the takeoff on its own")
	check(absf(float(poses[0.58][1]) - float(loaded["shoulder_pitch:Left"])) < 1.0 and float(poses[0.58][1]) > 100.0, "the other arm points at the ball (%.0f)" % float(poses[0.58][1]))
	check(float(poses[0.58][2]) < 0.0 and lab.animation.spike_hit_time < 0.0, "nothing has started the swing")
	# The click starts it.
	lab.animation.spike_air_time = 0.3
	lab._confirm_action()
	check(is_equal_approx(lab.animation.spike_swing_time, 0.0), "the click starts the swing clock")
	lab.animation.spike_swing_time = Stage.STRIKE_SECONDS * 0.5
	lab.animation.update()
	var half: float = strike_shoulder.call()
	half = half - 360.0 if half > 0.0 else half
	lab.animation.spike_swing_time = Stage.STRIKE_SECONDS
	lab.animation.update()
	var contact: float = strike_shoulder.call()
	# The rig reports angles within +-180, and the swing travels through -180 on its way over the top.
	contact = contact - 360.0 if contact > 0.0 else contact
	var at_contact := Stage.pose_for(0.0, 1.0, 0.7)
	check(half > contact and half < float(loaded["shoulder_pitch:Right"]) + 1.0 and absf(contact - float(at_contact["shoulder_pitch:Right"])) < 12.0, "after the click the arm comes through to contact (%.0f -> %.0f -> %.0f)" % [float(loaded["shoulder_pitch:Right"]), half, contact])
	# The swing holds at contact until the ball is struck, then follows through.
	lab.animation.spike_swing_time = 0.5
	lab.animation.update()
	var waiting: float = strike_shoulder.call()
	waiting = waiting - 360.0 if waiting > 0.0 else waiting
	check(absf(waiting - contact) < 1.0, "it waits at contact for the ball")
	lab.animation.spike_hit_time = 0.5
	lab.animation.spike_swing_time = 0.5 + Stage.FOLLOW_SECONDS
	lab.animation.update()
	var followed: float = strike_shoulder.call()
	followed = followed - 360.0 if followed > 0.0 else followed
	check(followed < contact - 20.0, "once the ball is struck the arm follows through")
	# Aimed by the ball: a ball out to the arm's side opens the arm further than a ball across the body.
	lab.animation.spike_hit_time = -1.0
	lab.animation.spike_swing_time = Stage.STRIKE_SECONDS
	lab.ball_active = true
	lab.ball.position = lab.player.position + lab.body.global_basis * Vector3(0.5, 2.3, -0.3)
	lab.animation.update()
	var roll_out: float = float(Library.read_rig(lab.body)["shoulder_roll:Right"])
	lab.ball.position = lab.player.position + lab.body.global_basis * Vector3(-0.5, 2.3, -0.3)
	lab.animation.update()
	var roll_across: float = float(Library.read_rig(lab.body)["shoulder_roll:Right"])
	check(roll_out > roll_across + 20.0, "the arm reaches to where the ball is (%.0f toward vs %.0f across)" % [roll_out, roll_across])
	print("SPIKE CONFIRM CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
