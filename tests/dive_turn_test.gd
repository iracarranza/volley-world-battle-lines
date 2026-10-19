extends SceneTree
# A backward dive: the crouching step, the body turns to face where it is going, then a forward dive,
# recovery and the body gives its facing back.
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
	lab.auto_feed = false
	lab._reset()
	# Facing forward (-Z), going backward (+Z).
	lab.facing_yaw = 0.0
	lab.view_yaw = 0.0
	lab.aim = lab.player.position + Vector3(0, 0, -9)
	lab.approach_direction = Vector3.BACK
	lab.approach_action = 0
	lab.selected = 0
	lab.jumped = false
	var yaw_at := func(charge: float) -> float:
		lab.jump_charge = charge
		lab._update_pose()
		return lab.body.rotation.y
	var start: float = yaw_at.call(0.0)
	var crouched: float = yaw_at.call(0.1)
	var crouch_lead: float = lab.dive_turn_spine
	var stepped: float = yaw_at.call(0.2)
	var step_lead: float = lab.dive_turn_spine
	# The torso leads: the chest and neck are turning before the hips have moved.
	check(crouch_lead > 10.0 or crouch_lead < -10.0, "the upper body starts the turn first, in the crouch (%.0f deg)" % crouch_lead)
	check(absf(wrapf(crouched - start, -PI, PI)) < 0.05, "the hips have not turned yet in the crouch")
	check(absf(step_lead) > absf(crouch_lead) and absf(wrapf(stepped - start, -PI, PI)) > 0.3, "by the end of the step the torso is well round and the hips are following (%.0f deg lead, %.2f rad hips)" % [step_lead, absf(wrapf(stepped - start, -PI, PI))])
	var pivot_foot: int = lab._dive_pivot_foot()
	check(pivot_foot == (1 if lab.dive_turn_total < 0.0 else 0), "the foot on the inside of the turn is the pivot (and trails)")
	check(absf(lab.dive_turn_total) > 3.0, "the turn is planned from the dive direction")
	# No jump-approach windup for a dive: the legs are not swinging through the approach steps.
	lab.jump_charge = 0.3
	lab._update_pose()
	check(absf(lab.legs[0].rotation.y) < 0.01 and absf(lab.legs[1].rotation.y) < 0.01, "a dive charge does not use the jump approach footwork")
	# In the air it faces the dive, so the dive itself reads as a forward dive.
	lab.jumped = true
	lab.airborne_action = 0
	lab.jump_charge = -1
	lab.dive_world_direction = Vector3.BACK
	lab.dive_flight_time = 0.5
	lab.dive_air_time = 0.2
	lab._update_pose()
	var facing_back := Vector3(-sin(lab.body.rotation.y), 0, -cos(lab.body.rotation.y))
	check(facing_back.dot(Vector3.BACK) > 0.9, "in the air the body faces the way it is diving")
	# Forward and sideways dives do not turn.
	for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		lab.jumped = false
		lab.approach_direction = direction
		lab.jump_charge = 0.2
		lab._update_pose()
		check(absf(lab.dive_turn_total) < 0.01, "a dive %s does not turn the body" % [direction])
	# The turn pivots on the trailing foot: whatever the hips do, a point on that foot stays where it is.
	lab.body.scale = Vector3.ONE
	lab.dive_base_yaw = 0.3
	lab.dive_turn_total = -3.0
	lab.dive_applied_yaw = 0.0
	lab.body.rotation.y = lab.dive_base_yaw
	lab._pivot_dive_turn()
	var foot_local := Vector3(lab.visual_hip_x, 0.0, 0.0)
	var foot_before: Vector3 = lab.body.to_global(foot_local)
	for turned in [-0.6, -1.5, -2.8]:
		lab.dive_applied_yaw = turned
		lab.body.rotation.y = lab.dive_base_yaw + turned
		lab._pivot_dive_turn()
		var foot_now: Vector3 = lab.body.to_global(foot_local)
		check(Vector2(foot_now.x - foot_before.x, foot_now.z - foot_before.z).length() < 0.001, "the right foot stays put as the body turns right on it (%.4f m at %.1f rad)" % [Vector2(foot_now.x - foot_before.x, foot_now.z - foot_before.z).length(), turned])
	lab.dive_turn_total = 3.0
	lab.dive_applied_yaw = 0.0
	lab.body.rotation.y = lab.dive_base_yaw
	lab._pivot_dive_turn()
	var left_local := Vector3(-lab.visual_hip_x, 0.0, 0.0)
	var left_before: Vector3 = lab.body.to_global(left_local)
	lab.dive_applied_yaw = 1.9
	lab.body.rotation.y = lab.dive_base_yaw + 1.9
	lab._pivot_dive_turn()
	var left_now: Vector3 = lab.body.to_global(left_local)
	check(Vector2(left_now.x - left_before.x, left_now.z - left_before.z).length() < 0.001, "turning left pivots on the left foot")
	# Landing: the recovery faces forward (relative to the turned body), and facing is given back at the end.
	lab.jumped = false
	lab.jump_charge = -1
	lab.approach_direction = Vector3.BACK
	lab.jumped = true
	lab.airborne_action = 0
	lab.dive_launched = true
	lab.dive_quality_value = 0.7
	lab.dive_world_direction = Vector3.BACK
	lab.dive_turn_total = lab._dive_turn_for(Vector3.BACK, 0.0)
	lab.dive_air_time = 0.5
	lab._update_pose()
	lab.player.velocity = Vector3.BACK * 5.0
	lab.jumped = false
	lab._begin_dive_recovery()
	check(lab.dive_recovery_dir.y > 0.9, "after the turn the recovery is a forward-dive recovery")
	lab.dive_recovery_time = 0.05
	lab._update_pose()
	var down_yaw: float = lab.body.rotation.y
	check(absf(wrapf(down_yaw, -PI, PI)) > 2.5, "the body stays turned while it is down")
	lab.dive_recovery_time = lab.DiveRecovery.duration(0.7)
	lab._update_pose()
	check(absf(wrapf(lab.body.rotation.y, -PI, PI)) < 0.2, "the facing is given back by the end of the recovery")
	print("DIVE TURN CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
