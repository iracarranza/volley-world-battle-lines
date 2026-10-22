extends "res://tests/support/test_case.gd"
const Execution := preload("res://scripts/contact_execution.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const Stage := preload("res://scripts/spike_stage.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var shape := Geometry.definition(2, 1.86, 2.4, false, 1)
	var center: Vector3 = shape.center + Geometry.sector_point(shape, 0.74, 67.5, 0)
	for depth in [-0.9, 0.0, 0.9]:
		check(not Geometry.spike_active(shape, center + Vector3(0, 0, depth), 0.399), "No part of the spike can hit during its windup")
	check(Geometry.spike_active(shape, center + Vector3(0, 0, 0.9), 0.405), "Rear rescue slice activates first")
	check(not Geometry.spike_active(shape, center, 0.405), "Windup completion does not activate the entire envelope")
	check(Geometry.spike_active(shape, center, 0.5), "Active slice reaches overhead contact at 0.5 seconds")
	check(Geometry.spike_active(shape, center + Vector3(0, 0, -0.9), 0.595), "Forward rescue slice activates last")
	check(not Geometry.spike_active(shape, center + Vector3(0, 0, -0.9), 0.601), "Sweep expires after 0.6 seconds")
	var spatial := Geometry.evaluate(shape, center)
	check(not Execution.assess(spatial, 0.39, false, 2).hit, "Resolver rejects contact during spike windup")
	check(Execution.assess(spatial, 0.41, false, 2).spike_form == "roll", "First portion is rescue roll")
	check(Execution.assess(spatial, 0.5, false, 2).sweet, "Extension coincides with sweet timing")
	check(Execution.assess(spatial, 0.59, false, 2).spike_form == "push", "Final portion is rescue push")
	check(is_equal_approx(Stage.phase_for(0, 1, 0.5), 0), "Animation reaches extension at the same instant")
	check(Execution.contact_seconds(1) == 0.55 and Execution.sweet_active(1, 0.245), "Set timing remains unchanged")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.ball_active = true
	lab.locked_action = 2
	lab.armed = true
	lab._confirm_action()
	check(is_equal_approx(lab.confirm_duration, 0.6), "Player confirmation accommodates the full sweep")
	lab.ball.position = lab.player.position + lab.hurtbox_center_local(center).rotated(Vector3.UP, lab._contact_yaw())
	lab.contact_memory[2] = 1
	lab.confirm_window = lab.confirm_duration - 0.2
	check(not lab._can_contact(), "Remembered contacts cannot bypass the windup")
	lab.confirm_window = lab.confirm_duration - 0.5
	check(lab._can_contact(), "Player can strike the central slice at extension")
	lab.queue_free()
	await process_frame
	print("SPIKE SWEEP TIMING: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
