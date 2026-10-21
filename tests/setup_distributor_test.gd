extends SceneTree
# The Setup distributor (pure rules) and the Spike Trainer as a Setup in the map ball economy.
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Distributor = load("res://scripts/setup_distributor.gd")
	var d = Distributor.new()
	check(d.ready() and d.balls == 10 and d.min_reps == 5, "A fresh Setup is active with 10 balls and needs 5 reps")
	check(d.activate("a") and d.running() and not d.activate("b"), "Giving up a ball starts it once")
	for i in range(5):
		check(d.send(), "A ball is sent")
		var result: String = d.record(true, "a" if i < 4 else "thief")
		check(result == ("complete" if i == 4 else "rep"), "Rep %d is %s" % [i + 1, result])
	check(d.pile == 6 and d.pile_owner == "thief" and d.phase == d.Phase.COOLDOWN, "A clean run earns 6 balls (5 left + the one given up), taken by whoever lands the last rep")
	check(not d.claim("a") and d.claim("thief") and d.pile == 5, "Only the completer claims the pile, one ball at a time")
	d.tick(44.0)
	check(not d.ready(), "Still cooling down at 44 s")
	d.tick(1.5)
	check(d.ready() and d.pile == 0 and d.balls == 10, "Reactivates after 45 s and an unclaimed pile is lost")
	# Errors cost reward balls
	d.activate("a")
	for i in range(2):
		d.send()
		d.record(false, "a")
	for i in range(5):
		d.send()
		d.record(true, "a")
	check(d.last_result == "complete" and d.pile == 4 and d.errors == 2, "Two errors cost two reward balls (4 earned)")
	d.tick(60.0)
	# Running out of balls fails it
	d.activate("a")
	var last := ""
	for i in range(10):
		if d.send():
			last = d.record(false, "a")
	check(last == "failed" and d.pile == 0 and d.phase == d.Phase.COOLDOWN, "Ten wasted balls fail the Setup with no reward")
	# The map Spike Trainer
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var drill = lab.activities.courses[0]
	check(drill.economy() and drill.distributor.ready(), "The map Spike Trainer is a Setup")
	lab.inventory.consume()
	drill._interact_setup()
	check(drill.distributor.ready(), "Without a ball it does not start")
	lab.inventory.give()
	lab.player.global_position = drill.spike_start_world()
	drill._interact_setup()
	check(drill.distributor.running() and not lab.inventory.held and lab.ball_active and drill.distributor.balls == 9, "Giving up a ball starts it and hangs the first ball")
	# Walking away does not fail it
	lab.player.global_position = drill.spike_start_world() + Vector3(60, 0, 0)
	drill.tick(0.1)
	check(drill.distributor.running() and lab.ball_active, "Leaving the area does not fail the Setup")
	# A ball nobody hits is used up, and the next is sent
	drill.timer = 0.0
	drill.tick(0.1)
	check(drill.distributor.errors == 1 and drill.distributor.balls == 8 and lab.ball_active, "An unhit ball is an error and the next one hangs")
	# Complete five reps directly
	for i in range(5):
		drill.spike_state = drill.State.RETURNING
		lab.ball.position = Vector3(drill.spike_anchor.x + drill.SPIKE_GOAL.x, 0.1, drill.spike_anchor.z + drill.SPIKE_GOAL.z)
		drill._economy_ball_down()
	check(drill.distributor.last_result == "complete" and drill.distributor.pile == 5 and drill.distributor.pile_owner == "player", "Five rep landings complete it: 3 balls left + 1 given up + ... = pile %d" % drill.distributor.pile)
	lab.player.global_position = drill.spike_start_world()
	drill._interact_setup()
	check(lab.inventory.held and drill.distributor.pile == 4, "I takes one reward ball")
	drill._interact_setup()
	check(drill.distributor.pile == 4, "Hands full: no second reward ball")
	print("setup_distributor: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
