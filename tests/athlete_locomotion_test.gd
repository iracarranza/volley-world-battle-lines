extends SceneTree
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func ctx(facing: float, velocity: Vector3, wish: Vector3, enabled := true) -> Dictionary:
	return {"facing_yaw": facing, "velocity": velocity, "wish": wish, "enabled": enabled, "hips": {"left": 10.0, "right": -10.0}}
# Direction in the world for an angle where 0 is -Z (forward) and positive turns left.
func dir(angle: float) -> Vector3:
	return Vector3(-sin(angle), 0, -cos(angle))
func run_for(L, seconds: float, c: Dictionary) -> Dictionary:
	var out := {}
	for i in range(int(seconds * 60.0)):
		out = L.update(1.0 / 60.0, c)
	return out
func run() -> void:
	var Loco = load("res://scripts/lab/athlete_locomotion.gd")
	# Standing: nothing turned
	var L = Loco.new()
	var out: Dictionary = run_for(L, 0.5, ctx(0.0, Vector3.ZERO, Vector3.ZERO))
	check(absf(float(out.hip_yaw)) < 0.01 and out.mode == "idle", "Standing still leaves the hips on the cursor")
	# Running forward: no turn, launch step first
	L = Loco.new()
	out = L.update(1.0 / 60.0, ctx(0.0, Vector3.ZERO, dir(0.0)))
	out = L.update(1.0 / 60.0, ctx(0.0, Vector3.ZERO, dir(0.0)))
	check(out.mode == "launch", "Pressing a direction from standing starts with a launch step")
	var legs: Dictionary = L._legs()
	out = run_for(L, 0.12, ctx(0.0, dir(0.0) * 1.5, dir(0.0)))
	legs = out.legs
	check(legs.has(out.lead) and legs.has(1 - int(out.lead)), "Both legs are posed in the launch")
	check(float(legs[out.lead].hip) > 0.0 and float(legs[1 - int(out.lead)].hip) < 0.0, "The lead leg steps forward and the other pushes off behind")
	out = run_for(L, 0.5, ctx(0.0, dir(0.0) * 5.0, dir(0.0)))
	check(out.mode == "run" and absf(float(out.hip_yaw)) < 1.0, "Running along the cursor keeps the hips square")
	# Sideways travel: hips turn to the movement direction, head counter-turns
	L = Loco.new()
	out = run_for(L, 0.8, ctx(0.0, dir(deg_to_rad(90.0)) * 5.0, dir(deg_to_rad(90.0))))
	check(absf(float(out.hip_yaw) - 90.0) < 3.0, "Moving sideways turns the hips toward the movement (%.1f)" % float(out.hip_yaw))
	var total: float = float(out.hip_yaw) + float(out.lumbar_twist) + float(out.thoracic_twist) + float(out.neck_twist)
	check(absf(total) < 0.01, "The spine and neck turn exactly back: the head faces the cursor (%.3f)" % total)
	check(absf(float(out.lumbar_twist)) <= 15.001 and absf(float(out.thoracic_twist)) <= 40.001 and absf(float(out.neck_twist)) <= 70.001, "No joint passes its range of movement")
	check(absf(float(out.heading)) < 0.2, "The legs run forward along the turned hips")
	# Backwards: backpedal with the hips facing the cursor
	L = Loco.new()
	out = run_for(L, 0.8, ctx(0.0, dir(PI) * 5.0, dir(PI)))
	check(out.backpedal and absf(float(out.hip_yaw)) < 20.0, "Moving straight away from the cursor is a backpedal, hips on the cursor (%.1f)" % float(out.hip_yaw))
	check(absf(absf(float(out.heading)) - PI) < 0.3, "The legs run backwards along the hips")
	# Diagonal back: hips never pass the limit
	L = Loco.new()
	out = run_for(L, 0.8, ctx(0.0, dir(deg_to_rad(150.0)) * 5.0, dir(deg_to_rad(150.0))))
	check(absf(float(out.hip_yaw)) <= 95.001, "Hips never turn past the limit (%.1f)" % float(out.hip_yaw))
	# A fast cursor swing: the hips lag, the head does not
	L = Loco.new()
	run_for(L, 0.4, ctx(0.0, Vector3.ZERO, Vector3.ZERO))
	out = L.update(1.0 / 60.0, ctx(PI, Vector3.ZERO, Vector3.ZERO))
	check(absf(float(out.hip_yaw)) > 60.0 and absf(float(out.hip_yaw)) <= 95.001, "A 180 degree cursor swing drags the hips only as far as the spine allows (%.1f)" % float(out.hip_yaw))
	out = run_for(L, 1.0, ctx(PI, Vector3.ZERO, Vector3.ZERO))
	check(absf(float(out.hip_yaw)) < 1.0, "The hips settle back onto the cursor")
	# Reversal: brace on the grounded leg, then launch the new way
	L = Loco.new()
	run_for(L, 0.6, ctx(0.0, dir(0.0) * 6.0, dir(0.0)))
	out = L.update(1.0 / 60.0, ctx(0.0, dir(0.0) * 6.0, dir(PI)))
	check(out.mode == "brake", "Asking for the opposite direction at speed brakes first")
	out = run_for(L, 0.08, ctx(0.0, dir(0.0) * 5.0, dir(PI)))
	var trailing := 1   # the harness reports the right hip as the trailing one
	check(int(out.brake_leg) == trailing and out.legs.has(trailing), "The grounded (trailing) leg takes the brace")
	check(float(out.legs[trailing].hip) > 0.0 and float(out.legs[1 - trailing].hip) < 0.0, "It plants ahead while the other leg reaches for the new direction")
	check(float(out.lean) < 0.0, "The body leans back against the momentum")
	check(absf(float(out.hip_yaw)) < 5.0, "The hips hold the old line while braking")
	out = run_for(L, 0.35, ctx(0.0, dir(0.0) * 0.5, dir(PI)))
	check(out.mode in ["launch", "run"], "Once the momentum is gone the athlete launches the new way (%s)" % out.mode)
	check(int(out.lead) != trailing or out.mode == "run", "The braced leg pushes off and the other leads")
	out = run_for(L, 0.6, ctx(0.0, dir(PI) * 5.0, dir(PI)))
	check(out.backpedal or absf(float(out.hip_yaw)) <= 95.001, "And ends up running the new way with the head still forward")
	# Disabled: no effect and hips follow the cursor
	L = Loco.new()
	run_for(L, 0.8, ctx(0.0, dir(deg_to_rad(90.0)) * 5.0, dir(deg_to_rad(90.0))))
	out = run_for(L, 0.5, ctx(0.0, dir(deg_to_rad(90.0)) * 5.0, dir(deg_to_rad(90.0)), false))
	check(float(out.weight) == 0.0 and float(out.hip_yaw) == 0.0, "The layer lets go in the air, dives and receives")
	# Lab: head faces the cursor with the hips turned
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.animation.pose_smoothing = false
	await process_frame
	lab.animation.pose_frame_dt = 1.0 / 60.0
	lab.player.velocity = Vector3(5.0, 0, 0)
	for i in range(40):
		lab.directional_input.sample(Vector3.RIGHT, 1.0 / 60.0)
		lab.animation.update()
		await process_frame
	var angles: Dictionary = lab.body.get_meta("spine_angles", {})
	check(float(angles.get("hip_yaw", 0.0)) < -60.0, "In the lab, sidestepping right turns the hips right (%.1f)" % float(angles.get("hip_yaw", 0.0)))
	var head := lab.body.get_node("Head") as Node3D
	var head_forward: Vector3 = head.global_transform.basis * Vector3(0, 0, -1)
	var body_forward: Vector3 = lab.body.global_transform.basis * Vector3(0, 0, -1)
	var head_error := rad_to_deg(Vector2(head_forward.x, head_forward.z).angle_to(Vector2(body_forward.x, body_forward.z)))
	check(absf(head_error) < 6.0, "The head still faces the cursor direction (off by %.1f degrees)" % head_error)
	var left_leg := lab.body.get_node("LeftLeg") as Node3D
	var leg_forward: Vector3 = left_leg.global_transform.basis * Vector3(0, 0, -1)
	var leg_error := rad_to_deg(Vector2(leg_forward.x, leg_forward.z).angle_to(Vector2(body_forward.x, body_forward.z)))
	check(absf(leg_error) > 45.0, "The legs face the way they are going (off the cursor by %.1f degrees)" % leg_error)
	lab.player.velocity = Vector3.ZERO
	for i in range(50):
		lab.directional_input.clear()
		lab.animation.update()
		await process_frame
	check(absf(float(lab.body.get_meta("spine_angles", {}).get("hip_yaw", 0.0))) < 2.0, "Standing again settles the hips back")
	print("athlete_locomotion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
