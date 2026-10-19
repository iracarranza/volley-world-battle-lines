extends SceneTree
const Execution = preload("res://scripts/contact_execution.gd")
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
	var station = lab.station
	lab.player.position = station.START
	station.start()
	station.tick(0)
	lab.player.position = Vector3(23, 0, 8)
	station.tick(1.6)
	station.tick(station.TOSS_SECONDS)
	check(station.state == station.State.SERVING and lab.ball_active, "Leaving area still launches next scheduled serve")
	var ball_position: Vector3 = lab.ball.position
	lab.player.position = station.START
	station.tick(0)
	check(station.state == station.State.SERVING and lab.ball_active and lab.ball.position == ball_position, "Reentering does not cancel active serve")
	lab.player.position = Vector3(23, 0, 8)
	station.tick(0)
	for frame in range(300):
		if not lab.ball_active:
			break
		lab._tick_ball(1.0 / 120)
	check(station.state == station.State.FAILED, "Unreceived serve ends drill normally while outside")
	lab.player.position = station.START
	station.start()
	station.serve()
	station.tick(station.TOSS_SECONDS)
	station.on_contact(0)
	lab.player.position = Vector3(23, 0, 8)
	station.on_ball_down(Vector3(14, 0.105, 2))
	check(station.state == station.State.WAITING and station.points == 1, "Leaving after receive preserves progress")
	station.tick(1.1)
	station.tick(station.TOSS_SECONDS)
	check(station.state == station.State.SERVING, "Next serve proceeds without requiring reentry")
	lab._reset()
	lab.locked_action = 0
	lab.armed = true
	lab.ball_active = true
	lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(0).center
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration - 0.34
	lab._update_hurtbox_visual(0)
	var result: Dictionary = lab._contact_assessment(0)
	check(result.sweet and not result.rescue and not lab.sweet_visual_expired, "Receive at 340 ms remains sweet with matching debug display")
	lab.confirm_window = lab.confirm_duration - 0.38
	check(lab._contact_assessment(0).rescue, "Receive becomes rescue after 360 ms")
	check(Execution.assess({"hit": true, "zone": "SWEET SPOT", "quality": 1.0}, 0.34, false, 2).forgiving_spike, "Attack retains its 90 ms sweet window before forgiving contact")
	print("RECEIVE WINDOW / DRILL BOUNDS: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
