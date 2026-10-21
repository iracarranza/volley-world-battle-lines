extends "res://tests/support/test_case.gd"
const Basket := preload("res://scripts/drill_basket.gd")
const Tape := preload("res://scripts/net_response.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var basket := Basket.new()
	root.add_child(basket)
	basket.build(Color.GOLD)
	basket.place(Vector3(4,3.5,-7),Vector3(0,0.8,0.6))
	var center: Vector3 = basket.global_position
	var n: Vector3 = basket.normal
	var across := Vector3.RIGHT
	var clean := basket.step(center+n,center-n,-n*10,0.2)
	check(clean.scored and not clean.contact,"Descending front entry through the aperture scores")
	check(not basket.step(center-n,center+n,n*10,0.2).scored,"Backside entry never scores")
	check(not basket.step(center+n,center-n,Vector3(0,2,-10),0.2).scored,"Rising entry never scores")
	check(not basket.step(center+n,center-n,Vector3(10,-1,0),0.2).scored,"A near-tangent incoming angle does not score")
	check(not basket.step(center+Vector3.DOWN*2+n,center+Vector3.DOWN*2-n,-n*10,0.2).scored,"A pass beneath the elevated opening does not score")
	for speed in [5.0,25.0,60.0]:
		var rim_center: Vector3 = center+across*Basket.RADIUS
		var hit := basket.step(rim_center+n, rim_center-n,-n*speed,2/speed)
		check(hit.contact and not hit.scored,"Rim sweep catches a %.0f m/s ball without scoring"%speed)
		check(Vector3(hit.velocity).distance_to(Tape.tape_velocity(-n*speed,n)) < 0.01,"Rim uses exactly the tape normal/tangent response")
		check(basket.rim_distance(hit.position,center) > 0,"Rim response separates the ball from its collision volume")
	# An off-centre ball can clip the ring and deflect; it is not an automatic drill failure.
	var glance := basket.step(center+across*(Basket.RADIUS-0.1)+n,center+across*(Basket.RADIUS-0.1)-n,-n*15,0.1)
	check(glance.contact and not glance.scored and Vector3(glance.velocity).length()>0,"Glancing touches retain a physical outgoing trajectory")
	var drop := basket.step(center+across*(Basket.RADIUS-0.15)+n,center+across*(Basket.RADIUS-0.15)-n,-n*10,0.2)
	check(drop.contact and drop.scored,"A soft inner-rim deflection can drop in during the same frame")
	basket.queue_free()
	await process_frame
	# Exercise the actual lab ball step, not only the target's pure response.
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.inventory.enabled = false # this suite exercises the drills' original single-ball flow; the economy has its own suite
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.player.position = lab.Layout.drill_marker("transition_set_blue").position+Vector3.UP*0.03
	lab.activities.select_nearby()
	var drill = lab.drills
	drill.interact()
	drill.feed()
	var old_index: int = drill.target_index
	drill.feed()
	check(drill.target_index != old_index,"Basket changes position between feeds without immediately repeating")
	drill.on_contact(1)
	n = drill.basket.normal
	center = drill.target_world()
	lab.ball.position = center+n*0.3
	lab.ball_velocity = -n*8
	lab._tick_ball(0.075)
	check(drill.progress == 1 and drill.waiting and not lab.ball_active,"Real ball flight through the basket scores once before floor handling")
	drill.feed()
	drill.on_contact(1)
	center = drill.target_world()
	n = drill.basket.normal
	var side: Vector3 = drill.basket.global_basis.x
	lab.ball.position = center+side*Basket.RADIUS+n*0.3
	lab.ball_velocity = -n*8
	lab._tick_ball(0.075)
	check(drill.running() and drill.progress == 1 and lab.ball_active and lab.ball_velocity.dot(n)>0,"A real rim bounce keeps the drill live and reverses normal velocity")
	drill.on_ball_down()
	check(drill.spike_state == drill.State.FAILED,"Floor landings no longer count as successful sets")
	lab.queue_free()
	await process_frame
	print("DRILL BASKET: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
