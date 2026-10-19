extends "res://tests/support/test_case.gd"
const Execution = preload("res://scripts/contact_execution.gd")
const Geometry = preload("res://scripts/contact_geometry.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var shape: Dictionary = lab._raw_hurtbox_definition(2)
	var point: Vector3 = shape.center + Geometry.sector_point(shape, 0.74, 67.5, 0)
	var spatial := Geometry.evaluate(shape, point)
	var previous_speed := INF
	for age in [0.22, 0.31, 0.36, 0.40, 0.48]:
		var assessment := Execution.assess(spatial, age, false, 2)
		var output := Execution.velocity(2, Vector3(2, -3, -24) * float(assessment.strength), Vector3.ZERO, Vector3.FORWARD, assessment, 65)
		check(output.length() <= previous_speed + 0.001, "Spike strength decreases gradually with timing")
		previous_speed = output.length()
		if age > 0.29 and age < 0.42:
			check(not assessment.sweet and not assessment.rescue and output.length() > 17, "Moderate mistiming remains a driven spike")
		if age >= 0.42:
			check(assessment.rescue and output.length() < 5, "Very late contact becomes rescue push")
	for depth in [0.65, 1.05]:
		var extended: Vector3 = shape.center + Geometry.sector_point(shape, 0.74, 67.5, depth)
		var assessment := Execution.assess(Geometry.evaluate(shape, extended), 0.22, false, 2)
		check(assessment.hit and not assessment.sweet, "Extra reach cannot award sweet contact")
		check(assessment.rescue == (depth > 1), "Only extreme depth turns into rescue push")
	print("GRADUATED SPIKES: %d / %d passed" % [checks - failures, checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
