extends "res://tests/support/test_case.gd"
const Carry := preload("res://scripts/ball_carry_animation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.inventory.enabled = true
	lab.inventory.give()
	lab.animation.pose_smoothing = false
	var carry = lab.animation.carry
	for hand in ["Right","Left"]:
		lab.dominant_hand = hand
		lab.player.velocity = Vector3(0,0,-3)
		lab.animation.update()
		check(carry.visual.visible and carry.evidence.state == "moving","Possession draws a moving two-hand carry for "+hand)
		for side in ["Left","Right"]:
			var wrist: Node3D = lab.body.get_node(side+"Arm/Elbow/Wrist")
			check(wrist.global_position.distance_to(carry.evidence[side.to_lower()]) < 0.025,"Actual "+side+" palm reaches its moving ball grip")
		lab.player.velocity = Vector3.ZERO
		carry.moving = false
		carry.idle_age = Carry.SETTLE+1
		lab.animation.update()
		var local: Vector3 = lab.body.to_local(carry.visual.global_position)
		check(local.x*(1 if hand == "Right" else -1)>0.15,"Underarm hold follows dominant handedness")
		carry.idle_age = Carry.SETTLE+4
		lab.animation.update()
		var hips_y: float = carry.visual.global_position.y
		carry.idle_age = 0
		lab.player.velocity = Vector3(0,0,-2)
		lab.animation.update()
		check(carry.visual.global_position.y > hips_y+0.1,"Moving hold is at mid torso, above hip hold")
		check(carry.idle_age == 0,"Moving immediately breaks and resets the idle sequence")
	lab.player.velocity = Vector3.ZERO
	carry.moving = false
	var floors := []
	for bounce in range(2):
		carry.idle_age = Carry.SETTLE+Carry.DRIBBLE_START+0.4+bounce*0.8
		lab.animation.update()
		floors.append(carry.visual.global_position.y)
	check(absf(floors[0]-lab.player.global_position.y-Carry.RADIUS)<0.002 and absf(floors[1]-floors[0])<0.002,"Both dribbles reach the athlete's floor exactly")
	check(lab.inventory.held and lab.ground_balls.balls.is_empty(),"Cosmetic dribbles neither release possession nor create ground balls")
	# Sample either side of every transition and the wrap: positions must not jump.
	for boundary in [Carry.SETTLE,Carry.SETTLE+2.5,Carry.SETTLE+3.35,Carry.SETTLE+5.35,Carry.SETTLE+Carry.DRIBBLE_START,Carry.SETTLE+Carry.DRIBBLE_END,Carry.SETTLE+8.45,Carry.SETTLE+Carry.CYCLE]:
		carry.idle_age = boundary-0.0001
		lab.animation.update()
		var before: Vector3 = carry.visual.global_position
		carry.idle_age = boundary+0.0001
		lab.animation.update()
		check(carry.visual.global_position.distance_to(before)<0.004,"Ball position is continuous through idle boundary %.2f"%boundary)
	lab.inventory.consume()
	lab.animation.update()
	check(not carry.visual.visible,"Consuming possession hides the carry visual immediately")
	lab.inventory.give()
	lab.player.velocity = Vector3.ZERO
	carry.moving = false
	var point: Vector3 = lab.player.global_position+Vector3(0.2,0.105,-0.45)
	lab.inventory.record_pickup("ground",point)
	lab.animation.update()
	carry.pickup_age = 1.05*0.42
	lab.animation.update()
	check(carry.visual.global_position.distance_to(point)<0.002,"Ground pickup begins at the actual source ball location")
	check(float(lab.body.get_meta("spine_angles",{}).get("hip_hinge",0))>25,"Ground pickup procedurally bends toward a low ball")
	carry.pickup_age = 1.05+0.01
	lab.animation.update()
	check(carry.pickup_age < 0 and lab.inventory.held,"Pickup completes into carry without changing inventory")
	# Adaptive swing uses the immutable event point, never the ball's outgoing position.
	lab.motion.jumped = true
	lab.motion.airborne_action = 2
	lab.animation.spike_contacted = true
	lab.animation.spike_swing_time = 0.3
	lab.animation.spike_hit_time = 0.14
	var impact := Vector3(0.4,2.6,-0.5)
	lab.last_contact_result = {"physical_hit":true,"action":2,"point":impact}
	lab.animation.spike_impact_latched = false
	lab.ball.position = Vector3(20,5,20)
	lab.animation.update()
	check(lab.animation.spike_impact_latched and lab.animation.spike_impact_world == impact,"Spike follow-through latches the published impact point")
	lab.ball.position = Vector3(-20,9,20)
	lab.animation.update()
	check(lab.animation.spike_impact_world == impact,"Outgoing ball cannot pull the swing's contact target around")
	lab.queue_free()
	await process_frame
	# Pickups publish their actual source and only acquire one ball.
	var map = load("res://map_graybox.tscn").instantiate()
	root.add_child(map)
	map.set_process(false)
	map.set_physics_process(false)
	map.inventory.enabled = true
	map.inventory.held = false
	var cart: Dictionary = map.ball_carts.carts[0]
	map.player.position = cart.root.global_position
	var count: int = cart.balls
	var source: Vector3 = cart.ball_nodes.get_child(count-1).global_position
	check(map.inventory.try_pickup(map) and map.inventory.pickup_kind == "cart" and map.inventory.pickup_point.is_equal_approx(source),"Cart acquisition supplies the exact removed ball position to the animation")
	check(cart.balls == count-1 and not map.inventory.try_pickup(map),"Presentation cannot acquire a second cart ball while already holding one")
	map.animation.update()
	check(map.animation.carry.pickup_kind == "cart","Cart pickup gesture starts on normal inventory acquisition")
	map.queue_free()
	await process_frame
	print("BALL CARRY: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
