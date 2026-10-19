extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func exhaust(lab: Node3D) -> void:
	lab.athlete.spend(100)
	lab.athlete.recover(1,true)
	lab.athlete.spend(100)
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	await physics_frame
	exhaust(lab)
	lab.serve.press()
	check(lab.athlete.exhausted and not lab.ball_active and not lab.serve.tossing(), "Exhausted player cannot toss")
	lab.serve.input_press()
	check(not lab.serve.input_held and not lab.serve.channeling(), "Exhausted player cannot channel")
	check(not lab.is_benched(), "Exhaustion outside live play does not bench")
	lab.serve.state = lab.serve.State.FLIGHT
	lab.ball_active = true
	lab.ball.position = lab.pepper.SPOTS[1]+Vector3.UP
	check(not lab.pepper.try_start(lab.ball.position) and not lab.pepper.active(), "Exhausted player cannot initiate Pepper")
	lab._reset()
	lab.auto_feed = false
	exhaust(lab)
	lab.player.position = Vector3(20,0,20)
	lab.ball_active = true
	lab.ball.position = Vector3(0,8,3)
	lab.ball_velocity = Vector3(0,1,0)
	check(not lab._check_bench(), "Exhausted bystander outside live court can stay in exploration")
	lab.training_bots.toggle(0)
	lab.training_bots.toggle(1)
	lab.training_bots.toggle(0,true)
	lab.player.position = Vector3(0,0.03,5)
	lab.armed = true
	lab.charging = true
	lab.motion.jump_charge = 0.2
	var layer: int = lab.player.collision_layer
	var mask: int = lab.player.collision_mask
	lab._physics_process(0.01)
	check(lab.is_benched() and lab.bench.remaining < 5, "Entering rally while Exhausted immediately benches")
	check(lab.ball_active, "Benching preserves live team rally")
	check(not lab.armed and not lab.charging and lab.motion.jump_charge < 0 and lab.confirm_window == 0, "Bench cancels all prepared inputs")
	check(lab.player.collision_layer == 0 and lab.player.collision_mask == 0, "Dragged athlete is removed from collision")
	var paused_remaining: float = lab.bench.remaining
	lab.paused = true
	lab._physics_process(1)
	check(lab.bench.remaining == paused_remaining, "Pause stops bench countdown")
	lab.paused = false
	var duration: float = lab.bench.remaining
	lab._check_bench()
	check(lab.bench.remaining == duration, "Repeated checks cannot restart bench timer")
	lab.bench.tick(0.49)
	check(lab.player.position.y > 5 and lab.player.position.z > 10 and lab.player.position.z < 48, "Athlete travels through air toward Home Base")
	lab.bench.tick(0.5)
	lab.animation.update()
	check(lab.player.position.distance_to(lab.bench.HOME) < 0.001, "Return reaches home bench after one second")
	check(absf(lab.legs[0].rotation.x - PI*0.5) < 0.001 and absf(lab.legs[0].get_node("Knee").rotation.x + PI*0.5) < 0.001, "Athlete sits with bent knees on bench")
	check(lab.bench.teammates() == [0,1], "Only enabled Home bots can be spectated")
	var key := InputEventKey.new()
	key.keycode = KEY_V
	key.pressed = true
	lab._unhandled_input(key)
	check(lab.bench.spectator == 0, "V starts optional teammate spectating")
	key.keycode = KEY_R
	lab._unhandled_input(key)
	check(lab.bench.spectator == 1, "R cycles enabled Home teammate")
	lab.camera_rig.update(2)
	check(lab.camera.position.distance_to(lab.training_bots.actors[1].position) < 8, "Spectator camera follows teammate")
	lab.training_bots.toggle(1)
	lab.bench.refresh_ui()
	check(lab.bench.spectator == 0, "Disabled spectator target switches to remaining teammate")
	lab.training_bots.toggle(0)
	lab.bench.refresh_ui()
	check(lab.bench.spectator == -1 and lab.bench.watch.disabled, "No active Home bots returns view to bench")
	key.keycode = KEY_E
	lab._unhandled_input(key)
	lab.motion.begin_jump()
	var count: int = lab._contact_event_serial
	lab._contact()
	check(not lab.serve.tossing() and lab.motion.jump_charge < 0 and lab._contact_event_serial == count, "Benched athlete cannot serve, jump or contact")
	var ball_before: Vector3 = lab.ball.position
	lab._tick_benched(0.01)
	check(lab.ball.position != ball_before, "Rally simulation continues while Benched")
	lab.bench.tick(lab.bench.remaining - 0.01)
	check(lab.is_benched(), "Bench lasts full five seconds")
	lab.bench.tick(0.01)
	check(not lab.is_benched() and lab.player.position == lab.bench.EXIT, "Five-second bench returns controls at Home Base")
	check(lab.player.collision_layer == layer and lab.player.collision_mask == mask, "Original collision restored")
	check(lab.athlete.exhausted and lab.athlete.exhaustion_remaining < 2.01, "Fatigue timer continues while Benched")
	check(not lab._check_bench(), "Off-bench athlete at Home Base is not retriggered by distant rally")
	lab._reset()
	exhaust(lab)
	lab.pepper.partner = 1
	lab.ball_active = true
	check(lab._check_bench() and not lab.pepper.active() and not lab.ball_active, "Exhaustion in existing Pepper benches and ends solo exchange")
	lab._reset()
	check(not lab.is_benched() and not lab.bench.panel.visible and lab.player.collision_layer == layer, "Reset clears bench, UI and collision lock")
	lab.athlete.spend(100)
	lab.ball_active = true
	check(lab.athlete.winded and not lab._check_bench(), "Winded player can enter rallies")
	lab._reset()
	exhaust(lab)
	lab.station.state = lab.station.State.SERVING
	lab.ball_active = true
	check(not lab._check_bench(), "Drills are excluded from rally bench penalty")
	lab._reset()
	lab.moc.enabled = false
	lab.athlete.spend(100)
	lab.athlete.recover(0.1,true)
	lab.ball_active = true
	lab.locked_action = 0
	lab.selected = 0
	lab.locked_charge = 0.65
	lab.armed = true
	lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(0).center
	lab.ball_velocity = Vector3(0,-3,5)
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration-0.22
	lab._contact()
	check(lab.is_benched() and lab.last_contact_result.physical_hit, "Contact that causes Exhaustion resolves then benches immediately")
	print("BENCH STATUS: %d / %d passed" % [checks-failures,checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
