extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	await physics_frame
	var meter = lab.perf_meter
	check(meter != null and meter.visible, "The performance readout is on by default")
	for frame in range(30):
		await process_frame
	var text: String = meter.report()
	for part in ["FPS", "frame", "draw calls", "nodes", "memory"]:
		check(text.contains(part), "The readout shows %s" % part)
	check(meter.label.anchor_left == 1.0 and meter.label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "It sits in the top right")
	var key := InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	lab._unhandled_input(key)
	check(not meter.visible, "F3 hides it")
	lab._unhandled_input(key)
	check(meter.visible, "F3 shows it again")
	lab.queue_free()
	await process_frame
	print("PERF METER: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
