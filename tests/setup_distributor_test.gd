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
		lab.ball.position = drill.spike_to_world(Vector3(drill.SPIKE_GOAL.x, 0.1, drill.SPIKE_GOAL.z))
		drill._economy_ball_down()
	check(drill.distributor.last_result == "complete" and drill.distributor.pile == 5 and drill.distributor.pile_owner == "player", "Five rep landings complete it: 3 balls left + 1 given up + ... = pile %d" % drill.distributor.pile)
	lab.player.global_position = drill.spike_start_world()
	drill._interact_setup()
	check(lab.inventory.held and drill.distributor.pile == 4, "I takes one reward ball")
	drill._interact_setup()
	check(drill.distributor.pile == 4, "Hands full: no second reward ball")
	# The other Setups
	var transition = null
	for course in lab.activities.courses:
		if course.has_method("feed"):
			transition = course
			break
	check(transition != null and transition.economy() and transition.distributor.ready(), "The Transition Set is a Setup")
	lab.inventory.consume()
	lab.player.global_position = transition.anchor + Vector3(0.5, 0, 0.5)
	transition._interact_setup()
	check(transition.distributor.ready(), "It needs a ball to start")
	lab.inventory.give()
	transition._interact_setup()
	check(transition.distributor.running() and not lab.inventory.held and transition.waiting and transition.distributor.balls == 9, "Giving up a ball starts it and queues the first pass")
	for i in range(5):
		transition.spike_state = transition.State.RETURNING
		transition._score()
	check(transition.distributor.last_result == "complete" and transition.distributor.pile == 6 and transition.distributor.pile_owner == "player", "Five baskets complete it (pile %d)" % transition.distributor.pile)
	var station = lab.activities.stations[1]
	check(station.economy() and station.distributor.ready(), "The Serve Machine is a Setup")
	lab.inventory.consume()
	station._interact_setup()
	check(station.distributor.ready(), "It needs a ball to start")
	lab.inventory.give()
	lab.player.global_position = station.start_world()
	station.interact()
	check(station.distributor.running() and not lab.inventory.held and station.state == station.State.WAITING, "Giving up a ball starts the Serve Machine")
	station.timer = 0.0
	station.tick(0.1)
	check(station.distributor.balls == 9 and station.state == station.State.TOSS, "The machine sends one ball per serve")
	station.state = station.State.RETURNING
	station.last_points = 0
	lab.ball.position = station.target_world(0)
	station.on_ball_down()
	check(station.distributor.errors == 1 and station.state == station.State.WAITING, "A return that does not score is an error and the next serve follows")
	for i in range(5):
		station.state = station.State.RETURNING
		station.cleared = true
		lab.ball.position = station.to_world(Vector3(14.5, 0.1, 2.0)) # inside the scoring half, in the station's own (turned) frame
		station.on_ball_down()
	check(station.distributor.last_result == "complete" or station.distributor.reps >= 1, "Scoring returns count as reps (%d)" % station.distributor.reps)
	# Parking and the rack on the Spike Trainer
	var spike = lab.activities.courses[0]
	spike.distributor.phase = spike.distributor.Phase.READY
	spike.distributor.pile = 0
	spike.distributor.balls = 10
	lab.ball_active = false
	spike.spike_state = spike.State.IDLE
	lab.inventory.give()
	lab.player.global_position = spike.spike_start_world()
	lab.drills = spike
	spike.tick_setup(0.1)
	check(spike.rack.visible_balls() == 10 and spike.rack.locked_bars() == 10, "The rack shows ten balls behind locked bars")
	spike._interact_setup()
	spike.tick_setup(2.0)
	check(spike.rack.visible_balls() == 9 and spike.rack.locked_bars() == 9, "Sending a ball releases one (9 left, 9 locked)")
	lab.player.global_position = spike.spike_start_world() + Vector3(60, 0, 0)
	spike.tick_setup(0.1)
	check(spike.parked and not lab.ball_active and not spike.running() and spike.parked_mesh.visible, "Walking off parks the hung ball and frees the live ball")
	lab.ball_active = true # another rally uses the live ball meanwhile
	lab.player.global_position = spike.spike_start_world()
	spike.tick_setup(0.1)
	check(spike.parked, "It does not resume while the live ball is busy")
	lab.ball_active = false
	spike.tick_setup(0.1)
	check(not spike.parked and spike.running() and lab.ball_active, "Back at the spot with the live ball free, the ball resumes")
	for i in range(5):
		spike.spike_state = spike.State.RETURNING
		lab.ball.position = spike.spike_to_world(Vector3(spike.SPIKE_GOAL.x, 0.1, spike.SPIKE_GOAL.z))
		spike._economy_ball_down()
	spike.tick_setup(3.0)
	var pile: int = spike.distributor.pile
	check(pile == 6 and spike.rack.visible_balls() == pile and spike.rack.locked_bars() == 0, "On completion all bars rise and the reward balls wait (%d)" % pile)
	var bar_up := true
	for slot in range(spike.rack.SLOTS):
		if spike.rack.balls[slot].visible and spike.rack.bars[slot].position.y < spike.rack.balls[slot].position.y + 0.3:
			bar_up = false
	check(bar_up, "The bars have risen clear of the balls")
	lab.inventory.consume()
	spike._interact_setup()
	spike.tick_setup(0.1)
	check(spike.rack.visible_balls() == pile - 1, "Claiming a reward ball takes it off the rack")
	print("setup_distributor: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
