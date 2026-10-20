extends "res://tests/support/test_case.gd"
const Clock := preload("res://scripts/moment_of_contact.gd")
func _initialize() -> void:
	call_deferred("run")
func event(action: int = 2, charge: float = 1.0) -> Dictionary:
	return {"action": action, "charge": charge, "physical_hit": true, "incoming_velocity": Vector3(0, -12, -14), "outgoing_velocity": Vector3(0, 0, -24)}
func wait_real(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1000000)
	while Time.get_ticks_usec() < until:
		await process_frame
func prepare(lab: Node3D, action: int) -> void:
	lab._reset()
	lab.locked_action = action
	lab.selected = action
	lab.locked_charge = 0.8
	lab.armed = true
	lab.ball_active = true
	lab.aim = Vector3(0, 0, -6)
	lab.camera_rig.facing_yaw = 0
	var shape: Dictionary = lab._raw_hurtbox_definition(action)
	lab.ball.position = lab.player.position + shape.center
	if action == 1:
		lab.ball.position += Vector3.UP * float(shape.radius) * 0.55
	if action == 2:
		lab.ball.position += lab.Geometry.sector_point(shape, 0.74, 67.5, 0)
	lab.ball_velocity = Vector3(0, -2, 1)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.moc.enabled = false
	for action in range(3):
		prepare(lab, action)
		var count: int = lab.moc.event_count
		lab._confirm_action()
		check(lab.moc.event_count == count and not lab.moc.active, "Confirmation alone must not trigger MoC")
		var chosen: Dictionary = lab.committed_intent
		check(chosen.is_read_only() and chosen.action == action and chosen.charge == 0.8, "Intent stores immutable action and charge")
		lab._update_preview()
		var before_vertices: PackedVector3Array = lab.preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		lab.aim = Vector3(9, 0, 6)
		lab._update_preview()
		var after_vertices: PackedVector3Array = lab.preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(before_vertices == after_vertices, "Camera/aim changes after confirmation cannot rewrite intended preview")
		lab._contact()
		check(lab.moc.event_count == count + 1 and lab.last_contact_result.physical_hit, "Physical contact emits exactly one impact")
		check(lab.last_contact_result.intent.target == chosen.target and lab.last_contact_result.outgoing_velocity == lab.ball_velocity, "Impact retains original intent separately from actual outgoing flight")
		var outgoing: Vector3 = lab.ball_velocity
		lab.camera_rig.rotate_view(Vector2(120, 30))
		lab.camera_rig.update_aim()
		check(lab.ball_velocity == outgoing, "Camera orientation cannot change a resolved shot")
		lab.moc.begin(lab.last_contact_result)
		check(lab.moc.event_count == count + 1, "Replaying the same event cannot duplicate MoC")
	prepare(lab, 0)
	var count: int = lab.moc.event_count
	lab.ball.position = Vector3(30, 20, 20)
	lab._confirm_action()
	lab.confirm_window = 0.001
	lab._physics_process(0.01)
	check(lab.moc.event_count == count and lab.committed_intent.is_empty(), "Expired/missed confirmation has no impact event")
	prepare(lab, 0)
	lab.ball.position = Vector3(30, 20, 20)
	lab.contact_memory[0] = 0.1
	lab._contact()
	check(lab.moc.event_count == count, "Legacy overlap-memory contact outside current geometry cannot trigger physical-impact MoC")
	prepare(lab, 0)
	lab.contacts = 3
	lab._contact()
	check(lab.moc.event_count == count, "Illegal fourth contact produces no MoC")
	var slow := Vector3(0, -3, -2)
	var fast := slow * 5
	var soft := Vector3(0, 4, 1)
	var hard := soft * 4
	check(Clock.duration_for(0, fast, soft) > Clock.duration_for(0, slow, soft), "A faster incoming ball increases MoC even with soft outgoing pace")
	check(Clock.duration_for(2, slow, hard) > Clock.duration_for(2, slow, soft), "Faster outgoing velocity increases MoC")
	check(Clock.duration_for(0, Vector3.RIGHT * 10, Vector3.LEFT * 10) > Clock.duration_for(0, Vector3.RIGHT * 10, Vector3.RIGHT * 10), "Stronger redirection increases impact emphasis at equal speeds")
	check(is_equal_approx(Clock.duration_for(0, fast, hard), Clock.duration_for(2, fast, hard)), "The same velocity exchange has the same MoC irrespective of action label")
	check(Clock.duration_for(2, Vector3.ZERO, Vector3.ZERO) == 0 and Clock.duration_for(2, fast * 100, hard * 100) <= 0.240001, "Motionless exchanges are skipped and high-speed impacts remain capped")
	lab.motion.jumped = false
	lab.athlete.hp = 100
	var standing: Vector3 = lab._shot_velocity(Vector3(0, 3.5, 5), 2, 0.7)
	lab.motion.jumped = true
	var spike: Vector3 = lab._shot_velocity(Vector3(0, 3.5, 5), 2, 0.7)
	check(absf(spike.length() / standing.length() - 1.50) < 0.001, "Airborne spikes gain 50 percent pace over the prior speed curve")
	lab.motion.jumped = false

	var clock = lab.moc
	clock.enabled = true
	clock.begin(event())
	check(clock.active and is_equal_approx(clock.simulation_scale(), 0.6) and Engine.time_scale == 1, "Impact slows simulation without changing engine clock")
	await wait_real(0.26)
	check(not clock.active and is_equal_approx(Engine.time_scale, 1), "MoC expires in real time and restores engine scale")
	clock.begin(event())
	lab.paused = true
	clock._process(0)
	check(not clock.active and Engine.time_scale == 1, "Pause clears slowdown")
	lab.paused = false
	clock.begin(event())
	lab._reset()
	check(not clock.active and Engine.time_scale == 1, "Reset clears slowdown")
	Engine.time_scale = 0.8
	clock.begin(event())
	clock.clear()
	check(is_equal_approx(Engine.time_scale, 0.8), "Cleanup restores the prior scale rather than hardcoding 1")
	Engine.time_scale = 1
	clock.begin(event())
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 160000:
		clock.begin(event())
		await process_frame
	await wait_real(0.14)
	check(not clock.active and Engine.time_scale == 1, "A dense contact chain is capped instead of stacking indefinite freezes")
	var recovered_under_pressure := false
	start = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 360000:
		clock.begin(event())
		if not clock.active:
			recovered_under_pressure = true
		await process_frame
	check(recovered_under_pressure, "Continuous impacts must include a normal-speed recovery after the chain cap")
	clock.clear()
	prepare(lab, 1)
	lab.camera_rig.camera_mode = lab.ViewMode.ATHLETE
	lab.camera_rig.update(2.0)
	lab.player.position.x += 1
	lab.camera_rig._camera_frame_usec = Time.get_ticks_usec() - 16000
	clock.begin(event())
	lab._process(0.004)
	check(lab.camera_rig.camera_anchor.x > 0.2 and lab.camera_rig.camera_anchor.x < 0.35, "Camera smoothing uses unscaled real time during MoC")
	clock.clear()
	# World scheduling stays live; only the contacting actor and ball slow down.
	prepare(lab, 1)
	lab.player.position = Vector3(0, 10, 5)
	lab.player.velocity = Vector3(2, 0, 0)
	lab.motion.jumped = true
	lab.motion.airborne_action = 1
	lab.ball.position = Vector3(0, 20, 5)
	lab.ball_velocity = Vector3(2, 0, 0)
	var initial_player: Vector3 = lab.player.position
	var initial_ball: Vector3 = lab.ball.position
	var initial_elapsed: float = lab.elapsed
	lab.training_bots.active_action = 0
	lab.training_bots.remaining = 1.0
	clock.begin(event())
	clock._end_usec = Time.get_ticks_usec() + 500000
	await physics_frame
	var step: float = lab.player.get_physics_process_delta_time()
	lab._physics_process(step)
	var simulated: float = lab.elapsed - initial_elapsed
	check(is_equal_approx(simulated, step), "World physics retains its unscaled delta")
	check(absf((lab.player.position.x - initial_player.x) - 2 * simulated * 0.6) < 0.01 and absf((lab.ball.position.x - initial_ball.x) - 2 * simulated * 0.6) < 0.01, "Contacting athlete and ball advance at 60% speed")
	check(absf((1.0 - lab.training_bots.remaining) - simulated*0.6) < 0.001, "Bot timers follow slowed ball flight")
	clock.clear()
	# A drill's waiting interval is simulation time, not impact wall time.
	prepare(lab, 0)
	lab.player.position = Vector3(13, 10, 6)
	lab.station.start()
	lab.station.zone_was_entered = true
	lab.station.timer = 2.0
	var before_sim: float = lab.elapsed
	clock.begin(event())
	lab.set_physics_process(true)
	await wait_real(0.05)
	lab.set_physics_process(false)
	check(absf((2.0 - lab.station.timer) - (lab.elapsed - before_sim)) < 0.001, "Drill timers use the same slowed simulation clock")
	clock.clear()
	# Leaving the lab must not slow the title or the other agent's UI.
	clock.begin(event())
	lab._return_to_title()
	check(Engine.time_scale == 1, "Title navigation immediately clears slowdown")
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://title.tscn", "Existing title still loads after MoC")
	clock.begin(event())
	root.remove_child(lab)
	check(Engine.time_scale == 1, "Removing lab/scene restores normal time")
	lab.queue_free()
	print("MOC CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
