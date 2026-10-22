extends "res://tests/support/test_case.gd"
const Pass := preload("res://scripts/receive_pass.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Pass.matched_distance(9.0) > Pass.matched_distance(4.5) and Pass.matched_distance(4.5) > Pass.matched_distance(2.5), "A matched pass flies farther the farther the receiver is from the net")
	check(is_equal_approx(Pass.matched_distance(9.0), 9.0 - Pass.SETTER_OFFSET), "It is aimed at a point just off the net")
	check(Pass.matched_distance(0.5) == Pass.MIN_DISTANCE, "A receiver at the net still passes a short distance")
	check(Pass.matched_distance(-1.0) == Pass.PEPPER_DISTANCE and Pass.matched_distance(-1.0) == Pass.matched_distance(-5.0), "With no net the distance is absolute")
	for distance in [3.0, 5.0, 9.0]:
		var carried: float = Pass.matched_distance(distance) * Pass.overpass_factor(distance)
		check(carried >= distance + Pass.OVERPASS_MARGIN - 0.001 or Pass.overpass_factor(distance) == 6.0, "Full overcharge clears the net from %.0f m" % distance)
	check(Pass.overpass_factor(5.0) > 1.0, "Overcharge carries the ball farther")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	lab.player.position.z = 6.0
	check(is_equal_approx(lab.receive_net_distance(), 6.0), "The lab measures the receiver's distance to the net")
	var origin := Vector3(lab.player.position.x, 1.0, 6.0)
	var near: Vector3 = lab._loft_velocity(origin, 0, 0.65, Vector3.FORWARD)
	lab.player.position.z = 10.0
	var far: Vector3 = lab._loft_velocity(Vector3(origin.x, 1.0, 10.0), 0, 0.65, Vector3.FORWARD)
	var near_range: float = Vector2(near.x, near.z).length() * (near.y + sqrt(near.y * near.y + 2.0 * lab.GRAVITY * (1.0 - 0.105))) / lab.GRAVITY
	var far_range: float = Vector2(far.x, far.z).length() * (far.y + sqrt(far.y * far.y + 2.0 * lab.GRAVITY * (1.0 - 0.105))) / lab.GRAVITY
	check(absf(near_range - Pass.matched_distance(6.0)) < 0.05 and absf(far_range - Pass.matched_distance(10.0)) < 0.05, "A matched receive lands the matched distance away (%.2f and %.2f m)" % [near_range, far_range])
	var same: Vector3 = lab._loft_velocity(origin, 0, 1.0, Vector3.FORWARD)
	lab.player.position.z = 6.0
	check(lab._loft_velocity(origin, 0, 0.3, Vector3.FORWARD).is_equal_approx(lab._loft_velocity(origin, 0, 0.9, Vector3.FORWARD)), "The matched pass does not depend on how hard the receive was swung")
	lab.queue_free()
	await process_frame
	print("RECEIVE PASS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
