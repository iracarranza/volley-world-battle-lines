extends "res://tests/support/test_case.gd"
## Seed hooks (MS-02): a seed makes bot rallies reproducible; the default path still draws fresh seeds.
const RngSeed := preload("res://scripts/rng_seed.gd")

func _initialize() -> void: call_deferred("run")

## A generic bot rally (receive, set, attack) after the serve; returns every ball velocity at each bot contact.
func rally(lab: Node3D) -> Array:
	var bots = lab.training_bots
	lab.select_net(0)
	var receiver: int = bots.summon_generic(true, 0, {1: 0}, false)
	var setter: int = bots.summon_generic(true, 0, {2: 1}, false)
	var attacker: int = bots.summon_generic(true, 0, {3: 2}, false)
	for slot in [receiver, setter, attacker]:
		bots.set_aiming_accuracy(slot, 20.0) # scatter makes the draws visible in the ledger
	bots._place(receiver, lab.court_center + Vector3(0, 0, -5))
	bots._place(setter, lab.court_center + Vector3(-1, 0, -2))
	bots._place(attacker, lab.court_center + Vector3(-3, 0, -3))
	lab.player.position = lab.court_center + Vector3(0, 0.03, lab.court_half_depth + 0.4)
	lab.camera_rig.view_yaw = 0
	lab.camera_rig.facing_yaw = 0
	lab.camera_rig.update_aim()
	lab.animation.update()
	lab.serve.press()
	lab.serve.basic_strike()
	var ledger: Array = []
	var previous := 0
	for frame in range(1800):
		if not lab.ball_active: break
		lab._tick_ball(1.0 / 120)
		if bots.total_contacts > previous:
			previous = bots.total_contacts
			ledger.append([bots.last_action, lab.ball_velocity, lab.ball.position])
			if ledger.size() == 3: break
	return ledger

func session() -> Node3D:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	return lab

func run() -> void:
	var first := session()
	await physics_frame
	var default_seeds := [first.training_bots.random.seed, first.training_bots.aim_random.seed, first.training_bots.charge_random.seed]
	var second := session()
	await physics_frame
	check(second.training_bots.aim_random.seed != first.training_bots.aim_random.seed, "The default path draws a fresh seed for every session")
	check(RngSeed.used.size() >= 6 and RngSeed.used[0].seed == default_seeds[0], "Every seed used is logged")
	second.queue_free()
	first.training_bots.reseed(7)
	check(first.training_bots.random.seed == 7 and first.training_bots.aim_random.seed == 8 and first.training_bots.charge_random.seed == 9, "A base seed gives each generator its own derived seed")
	var a := rally(first)
	check(a.size() == 3, "The seeded rally completes receive, set and attack (%d contacts)" % a.size())
	first.queue_free()
	await process_frame
	var again := session()
	await physics_frame
	again.training_bots.reseed(7)
	var b := rally(again)
	check(a == b, "The same seed reproduces the rally ledger exactly")
	again.queue_free()
	await process_frame
	var other := session()
	await physics_frame
	other.training_bots.reseed(1234)
	var c := rally(other)
	check(c.size() == 3 and a != c, "A different seed changes the rally")
	other.pepper.reseed(5)
	check(other.pepper.aim_random.seed == 5 and other.pepper.charge_random.seed == 6, "Pepper partners take the same hook")
	other.queue_free()
	await process_frame
	print("SEED HOOKS: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
