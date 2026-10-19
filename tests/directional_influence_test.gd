extends SceneTree
const DI := preload("res://scripts/directional_influence.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func resolve(v: Vector3, action: int, input: Vector3, quality: float = 1.0) -> Dictionary:
	return DI.resolve(v, action, input, Vector3.FORWARD, quality)
func run() -> void:
	var base := Vector3(0, 6, -8)
	for action in range(4):
		check(resolve(base, action, Vector3.ZERO).velocity == base, "Neutral input exactly preserves original flight")
	for action in range(3):
		var right := resolve(base, action, Vector3.RIGHT)
		var left := resolve(base, action, Vector3.LEFT)
		check(right.velocity.x > 0 and left.velocity.x < 0, "Left/right steer in intuitive directions")
		check(absf(right.yaw_degrees + DI.YAW_LIMITS[action]) < 0.001, "Action-specific steering cap")
		check(absf(left.velocity.x + right.velocity.x) < 0.001 and absf(left.velocity.z - right.velocity.z) < 0.001, "Steering is mirrored")
		check(absf(resolve(base, action, Vector3.RIGHT, 0.4).yaw_degrees / right.yaw_degrees - 0.4) < 0.001, "Weak contact reduces influence authority")
		var away := DI.resolve(base.rotated(Vector3.UP, PI), action, Vector3.RIGHT.rotated(Vector3.UP, PI), Vector3.BACK, 1.0)
		check(away.velocity.distance_to(Vector3(right.velocity).rotated(Vector3.UP, PI)) < 0.0001, "Away court behaves as rotated home court")
		var diagonal := resolve(base, action, Vector3(1, 0, -1))
		check(diagonal.axes.length() <= 1.00001 and absf(diagonal.yaw_degrees) < absf(right.yaw_degrees), "Diagonals share influence budget")
	for action in [0, 1]:
		var forward := resolve(base, action, Vector3.FORWARD)
		var back := resolve(base, action, Vector3.BACK)
		check(forward.velocity.y == base.y and back.velocity.y == base.y, "Receive/Set influence preserves arc height")
		check(absf(forward.range_factor - (1 + DI.RANGE_LIMITS[action])) < 0.0001 and absf(back.range_factor - (1 - DI.RANGE_LIMITS[action])) < 0.0001, "Range adjustments are capped")
	var drive := resolve(base, 2, Vector3.FORWARD)
	var roll := resolve(base, 2, Vector3.BACK)
	check(drive.velocity.y < base.y and roll.velocity.y > base.y, "Attack forward drives flatter, back rolls higher")
	check(absf(Vector3(drive.velocity).length() - base.length()) < 0.0001 and absf(Vector3(roll.velocity).length() - base.length()) < 0.0001, "Attack influence preserves resolved speed")
	check(resolve(Vector3(0, -9, -1), 2, Vector3.FORWARD).pitch_degrees >= 0, "Attack cannot drive below downward angle cap")
	check(resolve(base, 3, Vector3(1, 0, -1)).velocity == base, "Block receives no directional influence")
	var history := DI.new()
	history.sample(Vector3.RIGHT, 0.016)
	check(absf(history.value().x - 0.2) < 0.001, "Single frame cannot produce full influence")
	history.sample(Vector3.RIGHT, 0.08)
	check(history.value().distance_to(Vector3.RIGHT) < 0.0001, "Held input reaches full influence")
	history.sample(Vector3.ZERO, 0.04)
	check(absf(history.value().x - 0.5) < 0.001, "Releasing input fades it over the window")
	history.sample(Vector3.ZERO, 0.08)
	check(history.value() == Vector3.ZERO, "Old input expires")
	for rate in [60, 120]:
		history.clear()
		for frame in range(rate):
			history.sample(Vector3.RIGHT, 1.0 / rate)
		check(history.value().distance_to(Vector3.RIGHT) < 0.0001, "Input window is stable across frame rates")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	for action in range(3):
		var velocities: Array[Vector3] = []
		for input in [Vector3.ZERO, Vector3.RIGHT]:
			lab._reset()
			lab.elapsed = 0.15
			lab.selected = action
			lab.locked_action = action
			lab.locked_charge = 0.6
			lab.armed = true
			lab.ball_active = true
			lab.facing_yaw = 0
			var shape: Dictionary = lab._hurtbox_definition(action)
			var contact: Vector3 = shape.center
			if action == 1:
				contact += Vector3.UP * float(shape.radius) * 0.55
			elif action == 2:
				contact += lab.Geometry.sector_point(shape, 0.74, 67.5, 0)
			lab.ball.position = lab.player.position + contact
			lab.ball_velocity = Vector3(0, -3, -2)
			lab.aim = lab.ball.position + Vector3.FORWARD * 7
			lab._confirm_action()
			lab.confirm_window = lab.confirm_duration - 0.22
			var intent: Dictionary = lab.committed_intent
			lab.directional_input.sample(input, 0.08) # Late input after confirmation.
			lab.player.velocity = Vector3(-50, 0, 0) # Momentum must not control DI.
			lab._contact()
			velocities.append(lab.ball_velocity)
			check(lab.last_contact_result.physical_hit, "Real influenced contact remains geometry-valid")
			check(lab.last_contact_result.intent == intent and intent.directional_influence.axes == Vector2.ZERO, "Late influence preserves immutable intended flight")
			check(lab.last_contact_result.directional_influence.is_read_only(), "Resolved influence is immutable event evidence")
			var shot: Vector3 = lab.ball_velocity
			lab.directional_input.sample(Vector3.LEFT, 0.08)
			lab._rotate_view(Vector2(150, 20))
			check(lab.ball_velocity == shot, "Input and camera cannot steer the ball after impact")
		check(velocities[1].x > velocities[0].x, "Late right input affects actual Receive/Set/Attack flight")
	lab._reset()
	check(lab.directional_input.value() == Vector3.ZERO, "Reset clears influence history")
	print("DIRECTIONAL INFLUENCE: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
