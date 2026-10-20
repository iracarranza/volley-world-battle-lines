extends "res://tests/support/test_case.gd"
const Response := preload("res://scripts/contact/receive_response.gd")
const Request := preload("res://scripts/contact/contact_request.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Platform := preload("res://scripts/receive_platform.gd")
const Charge = preload("res://scripts/receive_charge.gd")
const Prep = preload("res://scripts/bot_preparation.gd")
const Execution = preload("res://scripts/contact_execution.gd")
func flight(controlled: Vector3, incoming: Vector3, assessment: Dictionary) -> Vector3:
	var request := Request.new()
	request.athlete = Athlete.new()
	request.shape = Platform.definition(1.86, false)
	request.local_point = request.shape.center
	request.origin = request.local_point
	request.incoming = incoming
	request.charge = float(assessment.charge_match.input_charge)
	request.confirmation_age = float(assessment.get("confirmation_age", 0.22))
	return Response.resolve(request, assessment, controlled).velocity

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var shot := Charge.shot("attack", 0.6, "test")
	for value in [0.6, 0.675, 0.75]:
		check(Charge.match_charge(shot, value).matched, "Inclusive clean charge band")
	check(Charge.match_charge(shot, 0.59999).status == "undercharged", "No lower charge leeway")
	check(Charge.match_charge(shot, 0.75001).status == "overcharged", "Upper charge bound")
	check(Charge.match_charge(Charge.shot("serve", 1, "test"), 1).matched, "Band capped at full charge")
	check(not Charge.match_charge(Charge.shot("set", 0.6, "test"), 0).required, "Scope is serves and attacks")
	var spatial := {"hit": true, "quality": 1.0, "zone": "SWEET SPOT"}
	for action in range(4):
		var start := 0.12 if action == 0 else 0.155
		var end := 0.44 if action == 0 else 0.335
		check(is_equal_approx(Execution.sweet_start(action), start) and is_equal_approx(Execution.sweet_end(action), end), "Doubled window expands equally before and after its former bounds")
		check(not Execution.assess(spatial, start - 0.001, false, action).sweet, "Windup precedes new sweet start")
		check(Execution.assess(spatial, start, false, action).sweet, "New start is inclusive")
		check(Execution.assess(spatial, end, false, action).sweet, "New end is inclusive")
		check(not Execution.assess(spatial, end + 0.001, false, action).sweet, "Precision ends after new boundary")
	var clean := Execution.assess(spatial, 0.22, false, 0)
	var under := Charge.assess(clean, shot, 0.4)
	var over := Charge.assess(clean, shot, 0.9)
	check(not under.sweet and not over.sweet, "Timing cannot erase charge mismatch")
	check(not Charge.assess(Execution.assess(spatial, 0.46, false, 0), shot, 0.65).sweet, "Match cannot upgrade late timing")
	var controlled := Vector3(0, 7, -8)
	var incoming := Vector3(0, -3, 20)
	check(flight(controlled, incoming, Charge.assess(clean, shot, 0.65)) == controlled, "Match preserves controlled pass")
	var shank := flight(controlled, incoming, under)
	check(shank != controlled and shank.z <= 0, "Central undercharge deflects without passing through the athlete")
	var overhit := flight(controlled, incoming, over)
	check(overhit.y < controlled.y and Vector2(overhit.x, overhit.z).length() > 8, "Overcharge drives a flatter overhit")
	for boundary in [0.6, 0.75]:
		var previous_error := -1.0
		for gap in [0.00001, 0.01, 0.05, 0.15, 0.30]:
			var amount: float = boundary - gap if boundary == 0.6 else boundary + gap
			var assessed := Charge.assess(clean, shot, amount)
			var output := flight(controlled, incoming, assessed)
			var error := output.distance_to(controlled)
			check(error >= previous_error, "Mismatch error grows gradually with disparity")
			previous_error = error
			if gap <= 0.01:
				check(error < 0.1 and assessed.quality > 0.99, "Near-miss charge causes only a tiny penalty")
			check(not assessed.sweet, "Near mismatch remains outside strict sweet band")
	var prep := Prep.new()
	var random := RandomNumberGenerator.new()
	random.seed = 7
	prep.tick(0, 0.1)
	check(prep.state_for(0).charge > 0 and prep.state_for(0).charge < 0.65, "Real charge accumulation")
	prep.tick(0, 1)
	prep.begin(0, 0, shot, 1, 100, random)
	prep.tick(0, 0.79)
	check(prep.state_for(0).phase != "confirmed", "No premature confirmation")
	prep.tick(0, 0.21)
	check(absf(prep.state_for(0).confirmation_age - 0.2) < 0.0001, "Release leads contact by 200ms")
	check(Charge.match_charge(shot, prep.state_for(0).locked_charge).matched, "Accurate prepared bot matches")
	prep.begin(1, 0, shot, 0.21, 100, random)
	prep.tick(1, 0.21)
	check(not Charge.match_charge(shot, prep.state_for(1).locked_charge).matched, "Too little preparation genuinely undercharges")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await physics_frame
	var origin := Vector3(0,1,5)
	check(lab._shot_velocity(origin, 0, 0.1).is_equal_approx(lab._shot_velocity(origin, 0, 1.0)), "Receive charge no longer controls range")
	check(lab.training_bots.settings.size() == lab.training_bots.MAX_PER_TEAM*2 and lab.pepper.settings.size() == 3, "Independent charge controls for all bots")
	for amount in [0.4, 0.675, 0.9]:
		lab._reset()
		lab.moc.enabled = false
		lab.selected = 0
		lab.locked_action = 0
		lab.locked_charge = amount
		lab.armed = true
		lab.ball_active = true
		lab.ball_shot = shot
		lab.ball.position = lab.player.position + lab._raw_hurtbox_definition(0).center
		lab.ball_velocity = incoming
		lab._confirm_action()
		lab.confirm_window = lab.confirm_duration - 0.22
		lab._contact()
		check(lab.last_contact_result.charge_match.matched == (amount == 0.675), "Player uses same charge resolver")
		check(lab.last_contact_result.incoming_shot == shot and lab.last_contact_result.outgoing_shot.kind == "receive", "Player contact preserves incoming and outgoing metadata")
		if amount != 0.675:
			check(not lab.last_contact_result.sweet, "Perfect player timing cannot hide mismatch")
	var bots = lab.training_bots
	bots.settings[0].enabled = true
	for amount in [0.4, 0.675, 0.9]:
		lab._reset()
		lab.ball_active = true
		lab.ball_shot = shot
		lab.ball.position = Vector3(0, 1.0, 5)
		lab.ball_velocity = incoming
		bots._plan(0, lab.ball.position, 0.2)
		# Seed the actual accumulated preparation for each controlled scenario.
		bots.preparation.state_for(0).charge = amount
		check(bots.tick(0.2), "Physical bot receive resolves")
		check(bots.last_receive_match.matched == (amount == 0.675), "Bot uses the shared strict match resolver")
		check(absf(float(lab.ball_shot.action_charge) - amount) < 0.0001 and lab.ball_shot.kind == "receive" and lab.ball_shot.charge >= 0, "Bot distinguishes action charge from resultant ball charge")
		check(absf(float(bots.last_preparation.confirmation_age) - 0.2) < 0.0001, "Bot actual contact occurs after preparation lead")
		if amount < 0.6:
			check(bots.last_receive_match.status == "undercharged" and lab.ball_velocity.length() < incoming.length(), "Bot undercharge resolves through the shared damped response")
	bots.set_charge_accuracy(0, 25)
	bots.reset()
	check(bots.settings[0].charge_accuracy == 25 and bots.settings[0].aiming_accuracy == 100 and bots.settings[0].tracking_accuracy == 100, "Charge slider persists independently")
	var low_under := false
	var low_over := false
	for index in range(80):
		prep.finish(index)
		prep.begin(index, 0, shot, 1, 0, random)
		low_under = low_under or prep.state_for(index).target < 0.6
		low_over = low_over or prep.state_for(index).target > 0.75
	check(low_under and low_over, "Low charge accuracy can produce both mismatch types")
	lab._reset()
	lab.station.start()
	lab.station.force_next_feed = 0
	lab.station.serve()
	lab.station.tick(lab.station.TOSS_SECONDS)
	check(lab.ball_shot.kind == "serve" and lab.ball_shot.charge == lab.station.CHARGES[0], "Drill feeds carry charge metadata")
	lab.station.on_contact(0, false)
	check(lab.station.state == lab.station.State.RETURNING and lab.station.points == 0, "Shank stays live pending landing")
	print("RECEIVE CHARGE: %d / %d passed" % [checks-failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
