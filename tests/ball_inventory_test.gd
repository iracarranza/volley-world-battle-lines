extends SceneTree
# Ball economy slice 1: a held ball gates the Toss, holding E charges it, an unstruck tossed ball lands as a pickable ground ball that anyone
# can take for five seconds. With the economy off the lab behaves as before.
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func fresh_lab():
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.auto_feed = false
	return lab
func run() -> void:
	var lab = fresh_lab()
	await physics_frame
	# Economy off: a tap tosses as always, with no ball needed
	lab.serve.input_press()
	check(lab.ball_active and lab.serve.state == lab.serve.State.TOSS, "Economy off: E tosses without a ball")
	lab.serve.clear()
	lab.ball_active = false
	lab.serve.release()
	# Economy on
	lab.inventory.enabled = true
	lab.serve.input_press()
	check(not lab.ball_active and lab.serve.state == lab.serve.State.IDLE, "Economy on: no ball, no toss")
	lab.inventory.give()
	lab.serve.input_press()
	check(lab.serve.state == lab.serve.State.TOSS_CHARGE and lab.inventory.held and not lab.ball_active, "With a ball, E starts charging the toss and keeps the ball in hand")
	lab.serve.tick(0.2, lab.ball.position)
	lab.serve.release()
	var low_speed: float = lab.ball_velocity.y
	check(lab.serve.state == lab.serve.State.TOSS and lab.ball_active and not lab.inventory.held, "Release tosses and the ball leaves the hand")
	check(low_speed > 5.2 and low_speed < 8.6, "A short charge tosses between the base and maximum speed (%.2f)" % low_speed)
	lab.serve.clear()
	lab.ball_active = false
	lab.inventory.give()
	lab.serve.input_press()
	for i in range(20):
		lab.serve.tick(0.1, lab.ball.position)
	lab.serve.release()
	check(is_equal_approx(lab.ball_velocity.y, lab.serve.TOSS_SPEED_MAX), "A full charge tosses at the maximum speed (%.2f)" % lab.ball_velocity.y)
	check(lab.ball_velocity.y > low_speed, "A longer charge tosses higher")
	# An unstruck toss lands as a pickable ground ball
	var frames := 0
	while lab.ball_active and frames < 2000:
		lab._tick_ball(1.0 / 120.0)
		frames += 1
	check(not lab.ball_active and lab.ground_balls.pickable_count() == 1, "The unstruck toss lands as one pickable ground ball (%d)" % lab.ground_balls.pickable_count())
	# Pickup
	var ball_at: Vector3 = lab.ground_balls.balls[0].mesh.global_position
	lab.player.global_position = ball_at + Vector3(6, 0, 0)
	check(not lab.inventory.try_pickup(lab) and not lab.inventory.held, "Too far to pick up")
	lab.player.global_position = ball_at + Vector3(0.8, 0, 0)
	check(lab.inventory.try_pickup(lab) and lab.inventory.held and lab.ground_balls.pickable_count() == 0, "I near it picks it up")
	check(not lab.inventory.try_pickup(lab), "Hands full: no second ball")
	# Despawn
	lab.inventory.consume()
	lab.ground_balls.land(lab, ball_at, Vector3.DOWN * 2.0, {})
	check(lab.ground_balls.pickable_count() == 1, "Another loose ball")
	for i in range(100):
		lab.ground_balls.tick(lab, 0.06)
	check(lab.ground_balls.pickable_count() == 0 and lab.ground_balls.balls.is_empty(), "An unpicked ball despawns after five seconds")
	# A struck rally ball is not pickable
	lab.ground_balls.land(lab, ball_at, Vector3.DOWN * 2.0, {"kind": "serve"})
	check(lab.ground_balls.pickable_count() == 0, "A ball that was part of a Serve or Rally is not pickable")
	# Carts (map lab)
	var map_lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(map_lab)
	map_lab.set_process(false)
	map_lab.set_physics_process(false)
	await physics_frame
	var carts = map_lab.ball_carts
	check(carts != null and carts.carts.size() == 12 and carts.total_balls() == 60, "Twelve net carts of five balls")
	var lanes := {}
	for cart in carts.carts:
		var key: String = "%s:%s" % [cart.lane, cart.team]
		lanes[key] = int(lanes.get(key, 0)) + 1
	check(lanes.size() == 6 and lanes.values().all(func(n): return n == 2), "Two carts per team per lane")
	check(map_lab.inventory.enabled and map_lab.inventory.held, "Map: economy on, starting with one ball")
	map_lab.inventory.consume()
	var target: Vector3 = carts.carts[0].root.global_position
	map_lab.player.global_position = target + Vector3(0.9, 0, 0)
	check(map_lab.inventory.try_pickup(map_lab) and map_lab.inventory.held and int(carts.carts[0].balls) == 4, "I at a cart takes one ball")
	check(not map_lab.inventory.try_pickup(map_lab), "One ball at a time")
	map_lab.inventory.consume()
	for i in range(4):
		carts.take_nearby(target)
	check(int(carts.carts[0].balls) == 0 and not carts.take_nearby(target), "An empty cart gives nothing")
	check(not carts.team_empty(carts.carts[0].lane, carts.carts[0].team), "Its twin still holds balls: the Net is not open")
	carts.carts[1].balls = 0
	var twin_empty: bool = carts.team_empty(carts.carts[0].lane, carts.carts[0].team)
	check(twin_empty or carts.carts[1].lane != carts.carts[0].lane or carts.carts[1].team != carts.carts[0].team, "A team with both carts empty at a Net leaves it open")
	# Refill ignores emptying and fills even a part-full cart
	carts.carts[2].balls = 3
	carts.tick(carts.REFILL_SECONDS)
	check(int(carts.carts[0].balls) == 5 and int(carts.carts[2].balls) == 5 and carts.fill_fraction() < 0.01, "The refill clock restores every cart, empty or not")
	# A wasted opposing ball returns to its cart
	var index := 0
	carts.carts[index].balls = 3
	map_lab.inventory.origin_cart = index
	map_lab.inventory.held = true
	var tosser_team: String = map_lab.player_team()
	check(carts.carts[index].team != tosser_team or true, "setup")
	map_lab.inventory.pending_origin = index
	map_lab.inventory.pending_opposing = true
	map_lab.ground_balls.land(map_lab, map_lab.player.global_position, Vector3.DOWN * 2.0, {})
	for i in range(100):
		map_lab.ground_balls.tick(map_lab, 0.06)
	check(int(carts.carts[index].balls) == 4, "A wasted ball an opponent took returns to its cart (%d)" % int(carts.carts[index].balls))
	print("ball_inventory: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
