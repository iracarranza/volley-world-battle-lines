extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func key(code: int, down: bool) -> void:
	var input := InputEventKey.new()
	input.keycode = code
	input.physical_keycode = code
	input.pressed = down
	Input.parse_input_event(input)
func settle(lab: Node3D) -> void:
	for frame in range(12):
		lab._physics_process(1.0/60)
		await physics_frame
func approach(lab: Node3D, rating: float) -> Dictionary:
	lab._reset()
	lab.athlete.build.statistics = {"explosiveness":rating}
	await settle(lab)
	key(KEY_W,true)
	await process_frame
	lab.selected = 2
	lab._begin_approach()
	var frames := 0
	var steps := []
	while lab.jump_charge >= 0 and frames < 160:
		var step: int = lab.Approach.step_index(lab.jump_charge)
		if not steps.has(step): steps.append(step)
		lab._physics_process(1.0/60)
		frames += 1
		await physics_frame
	key(KEY_W,false)
	await process_frame
	return {"frames":frames,"steps":steps,"distance":lab.approach_distance,"height":lab.last_jump_height}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.auto_feed = false
	var baseline: Dictionary = await approach(lab,65)
	var fast: Dictionary = await approach(lab,99)
	check(baseline.frames > fast.frames,"Explosiveness speeds actual approach to takeoff")
	check(baseline.steps == [0,1,2] and fast.steps == [0,1,2],"Both approaches retain long bound, short step, inward plant")
	check(absf(float(fast.frames)/baseline.frames-1.0/1.4) < 0.08,"Approach speedup follows tier pace")
	check(absf(fast.distance-baseline.distance) < 0.6,"Faster approach preserves run-up distance")
	check(absf(fast.height-baseline.height) < 0.15,"Explosiveness does not create a separate jump-height bonus")
	var velocities := []
	for rating in [65,99]:
		lab._reset()
		lab.athlete.build.statistics = {"acceleration":rating}
		await settle(lab)
		key(KEY_W,true)
		await process_frame
		for frame in range(6):
			lab._physics_process(1.0/60)
			await physics_frame
		velocities.append(absf(lab.player.velocity.z))
		key(KEY_W,false)
		await process_frame
	check(velocities[1] > velocities[0],"Acceleration reaches moving speed sooner in live movement")
	var strafes := []
	for rating in [65,99]:
		lab._reset()
		lab.athlete.build.statistics = {"lateral_speed":rating}
		await settle(lab)
		key(KEY_D,true)
		await process_frame
		for frame in range(30):
			lab._physics_process(1.0/60)
			await physics_frame
		strafes.append(absf(lab.player.velocity.x))
		key(KEY_D,false)
		await process_frame
	check(strafes[1] > strafes[0] and strafes[0] < lab.athlete.speed(),"Lateral Speed reduces actual strafe penalty")
	lab.queue_free()
	await process_frame
	print("STAT MOVEMENT / APPROACH: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
