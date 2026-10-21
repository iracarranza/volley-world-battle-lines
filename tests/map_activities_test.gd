extends "res://tests/support/test_case.gd"
const Layout := preload("res://scripts/map_layout.gd")
func score_basket(drill: Node3D,lab: Node3D) -> void:
	var normal: Vector3 = drill.basket.normal
	var previous: Vector3 = drill.target_world()+normal*0.5
	lab.ball.position = drill.target_world()-normal*0.5
	lab.ball_velocity = -normal*8
	drill.sweep_ball(previous,0.125)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.auto_feed = false
	lab.moc.enabled = false
	await physics_frame
	var manager = lab.activities
	check(is_equal_approx(lab.bench.home.z,Layout.BASE_Z) and lab.bench.exit.z < lab.bench.home.z,"Home bench and exit follow the expanded base")
	check(lab.pepper.actors[0].position.is_equal_approx(manager.courses[0].course_top_world(2)),"Box Pepper partner stands on the actual third deck")
	check(manager.stations.size() == 4 and manager.courses.size() == 7,"Every marker has an activity: four receives, four spikes, two towers and two transition sets")
	check(Layout.HALF == 104 and is_equal_approx(Layout.BASE_Z,75.4),"Horizontal map extent and base spacing grow by thirty percent")
	check(is_equal_approx(Layout.net_by_id("top").width,7.2) and Layout.BASE_SIZE == Vector2(14,8),"Net courts and base objects retain their dimensions")
	for marker in Layout.drill_markers():
		lab._reset()
		lab.player.position = marker.position+Vector3.UP*0.03
		manager.select_nearby()
		if marker.type == "receive":
			check(lab.station.in_zone() and lab.station.origin.distance_to(marker.position-Vector3(16,0,4.5)) < 0.001,"Receive marker selects its own station")
			lab.station.start()
			lab.station.force_next_feed = 0
			lab.station.serve()
			lab.station.strike_feed()
			var arrival: Vector3 = lab.ball.position+lab.ball_velocity*lab.station.serve_duration+Vector3.DOWN*lab.GRAVITY*pow(lab.station.serve_duration,2)*0.5
			check(arrival.distance_to(lab.station.target_world(0)) < 0.01,"Each remote serve actually lands on its own drill target")
		else:
			check(lab.drills.in_zone(),"Marker %s selects its live course"%marker.id)
			lab.drills.interact()
			if marker.type == "box":
				check(lab.drills.box_state == lab.drills.State.ACTIVE,"Both towers can start at their physical decks")
			elif marker.type == "spike":
				check(lab.drills.holding_ball() and absf(lab.ball.position.x-marker.position.x) < 0.01,"Every spike marker suspends a local practice ball")
			else:
				var drill = lab.drills
				drill.tick(1.01)
				check(lab.ball_active and lab.ball_shot.kind == "receive" and lab.ball.position.distance_to(marker.position)<10,"Transition partner passes a real receive toward the setter")
				var shape: Dictionary = lab._raw_hurtbox_definition(1)
				lab.ball.position = lab.player.position+shape.center
				lab.camera_rig.facing_yaw = 0
				lab.camera_rig.view_yaw = 0
				lab.camera_rig.update_aim()
				lab.locked_action = 1
				lab.locked_charge = 0.61
				lab.armed = true
				lab._confirm_action()
				lab.confirm_window = lab.confirm_duration-0.2
				lab.elapsed += 1
				lab._contact()
				check(drill.spike_state == drill.State.RETURNING and lab.ball_shot.kind == "set","Normal player contact resolver advances Transition Set")
				score_basket(drill,lab)
				check(drill.progress == 1 and drill.waiting,"A descending set through the target scores and queues the next partner receive")
				for attempt in range(2):
					drill.feed()
					drill.on_contact(1)
					score_basket(drill,lab)
				check(drill.spike_state == drill.State.COMPLETE,"Three sets complete the provisional transition drill")
	lab._reset()
	var receiving_marker: Dictionary = Layout.drill_marker("receive_0")
	lab.player.position = receiving_marker.position+Vector3(2,0.03,0)
	manager.select_nearby()
	check(lab.station.in_zone() and not lab.drills.in_zone(),"Receive marker selects its station independently of the other courses")
	lab._reset()
	var drink: Dictionary = manager.drinks[0]
	lab.player.position = drink.root.position
	lab.athlete.hp = 37
	lab.athlete.stamina = 10
	manager.tick(0)
	check(lab.athlete.stamina == 10,"Walking near a drink does not consume it")
	var input := InputEventKey.new()
	input.keycode = KEY_I
	input.pressed = true
	lab._unhandled_input(input)
	manager.tick(0)
	check(lab.athlete.stamina == 50 and lab.athlete.hp == 37 and not drink.can.visible,"I consumes a drink for forty Stamina and no HP")
	manager.consume_nearby()
	check(lab.athlete.stamina == 50,"A consumed drink cannot be used repeatedly")
	manager.tick(30)
	check(drink.can.visible and drink.remaining == 0,"Drink respawns after thirty seconds")
	lab.athlete.stamina = lab.athlete.max_stamina()
	manager.consume_nearby()
	check(drink.remaining == 0,"Full Stamina does not waste a drink")
	lab.athlete.stamina = 0
	lab.athlete.exhausted = true
	manager.consume_nearby()
	check(drink.remaining == 0 and lab.athlete.stamina == 0,"Exhaustion does not waste a drink during its regeneration lock")
	lab.athlete.reset_fatigue()
	var athlete: LabAthlete = lab.athlete
	athlete.build = {"height":1.86,"span":1.86,"power":65,"speed":65,"accuracy":65,"endurance":65}
	athlete.gameplay_effects.clear()
	athlete.trait_ids.clear()
	check(athlete.movement_stamina_rate(false,false) == 1.5 and athlete.movement_stamina_rate(true,false) == 10,"Exploration uses the lower total movement/Sprint rates")
	check(athlete.movement_stamina_rate(false,true) == 3 and athlete.movement_stamina_rate(true,true) == 15,"Rallies retain calibrated movement/Sprint rates")
	var previous_top: Vector3 = manager.courses[0].course_top_world(2)
	lab.athlete.build.statistics = {"jump_power":99}
	lab._reset()
	check(not manager.courses[0].course_top_world(2).is_equal_approx(previous_top) and lab.pepper.actors[0].position.is_equal_approx(manager.courses[0].course_top_world(2)),"Changing the athlete rebuilds both tower courses and keeps the box partner on its deck")
	lab.player.position = Vector3(100,0.03,70)
	lab.player.velocity = Vector3.ZERO
	for frame in range(10):
		lab.motion.tick(1.0/60,1)
		await physics_frame
	check(lab.player.is_on_floor() and lab.player.position.x > 99, "Expanded physical floor and movement bounds support its outer thirty percent")
	lab.queue_free()
	await process_frame
	print("MAP ACTIVITIES: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
