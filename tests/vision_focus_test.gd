extends "res://tests/support/test_case.gd"
const Vision := preload("res://scripts/vision_focus.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(not Vision.enabled, "Vision focus is off by default")
	check(Vision.beam_radius(0.0) > Vision.beam_radius(0.5) and Vision.beam_radius(0.5) > Vision.beam_radius(1.0), "A stronger action tunnels the beam harder")
	check(is_equal_approx(Vision.beam_radius(1.0), Vision.width_full) and is_equal_approx(Vision.beam_radius(0.0), Vision.width_none), "The beam spans the two width settings")
	check(Vision.clarity_time(95.0) < Vision.clarity_time(65.0) and Vision.clarity_time(65.0) < Vision.clarity_time(50.0), "Higher Accuracy clears the beam faster")
	check(Vision.clarity(0.0, 65.0) == 0.0 and Vision.clarity(10.0, 65.0) == 1.0 and Vision.clarity(0.2, 65.0) > 0.0, "The beam clears from nothing to fully")
	check(Vision.clarity(0.3, 95.0) > Vision.clarity(0.3, 50.0), "...and sooner at high Accuracy")
	check(Vision.core_fraction(0.0) < Vision.core_fraction(1.0) and is_equal_approx(Vision.core_fraction(1.0), 1.0) and Vision.core_fraction(0.0) > 0.0, "The sharp centre line widens to fill the beam")
	check(Vision.fatigue(1.0, 65.0) == 0.0 and Vision.fatigue(0.0, 65.0) > 0.9, "Fatigue is none when fresh and near full when empty")
	check(Vision.fatigue(0.2, 90.0) < Vision.fatigue(0.2, 50.0), "Endurance softens the fatigue")
	check(Vision.blur_for(1.0) > Vision.blur_for(0.0) and Vision.blur_for(0.0) > 0.0, "The outside is always a little blurred, more when tired")
	check(Vision.darkness_for(1.0) > Vision.darkness_for(0.0), "...and darker")
	Vision.fatigue_obscuration = false
	check(Vision.fatigue(0.0, 65.0) == 0.0, "Fatigue obscuration can be switched off")
	Vision.fatigue_obscuration = true
	# The preview
	var hint := {"points": [Vector3.ZERO, Vector3.UP, Vector3(0, 2, 0), Vector3(0, 3, 0), Vector3(0, 4, 0), Vector3(0, 5, 0), Vector3(0, 6, 0), Vector3(0, 7, 0), Vector3(0, 8, 0), Vector3(0, 9, 0)], "duration": 0.7}
	check(Vision.shape_preview(hint, 50.0, false).size() == hint.size(), "With vision focus off the preview is untouched")
	Vision.enabled = true
	check(Vision.shape_preview(hint, 50.0, false).is_empty(), "With it on, the preview waits for the Moment of Contact")
	var low := Vision.shape_preview(hint, 50.0, true)
	var high := Vision.shape_preview(hint, 99.0, true)
	check(low.points.size() < high.points.size() and high.points.size() == hint.points.size(), "Ball Control lengthens the preview")
	check(float(low.opacity) < float(high.opacity) and float(high.opacity) == 1.0 and float(low.opacity) >= 0.45, "...and makes it more opaque, with a readable floor for everyone")
	Vision.preview_by_ball_control = false
	check(Vision.shape_preview(hint, 50.0, true).points.size() == hint.points.size(), "Ball Control shaping can be switched off")
	Vision.preview_by_ball_control = true
	Vision.preview_only_in_moc = false
	check(not Vision.shape_preview(hint, 99.0, false).is_empty(), "...and so can waiting for the Moment of Contact")
	Vision.preview_only_in_moc = true
	Vision.enabled = false
	# In the lab
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	lab.auto_feed = false
	await physics_frame
	var vision = lab.vision
	lab.ball_active = true
	lab.armed = true
	lab.locked_action = 2
	lab.locked_charge = 0.9
	lab.ball.position = lab.player.position + Vector3(0.5, 2.2, -3.0)
	vision.tick(0.1)
	check(not vision.quad.visible, "Switched off, there is no effect even with an action released")
	Vision.enabled = true
	vision.tick(0.05)
	check(vision.quad.visible and vision.strength > 0.0, "Switched on, releasing an action brings the beam in")
	for i in range(10): vision.tick(0.05)
	var width: float = vision.material.get_shader_parameter("half_width")
	check(absf(width - Vision.beam_radius(lab.prepared_output_charge())) < 0.001, "The beam's width is the action's charge (%.2f)" % width)
	var core_before: float = vision.material.get_shader_parameter("core")
	lab.athlete.build.accuracy = 99.0
	for i in range(30): vision.tick(0.05)
	var core_after: float = vision.material.get_shader_parameter("core")
	check(core_after >= core_before - 0.0001 and core_after > 0.95, "The beam has cleared by the end")
	var apex: Vector2 = vision.material.get_shader_parameter("apex")
	var target: Vector2 = vision.material.get_shader_parameter("target")
	check(apex.distance_to(target) > 0.04, "The beam is directed from the athlete to the ball, not a space around it")
	lab.athlete.stamina = lab.athlete.max_stamina() * 0.1
	vision.tick(0.05)
	check(float(vision.material.get_shader_parameter("blur_amount")) > Vision.blur_for(0.0), "A tired athlete's edges are blurrier")
	lab.armed = false
	for i in range(12): vision.tick(0.05)
	check(not vision.quad.visible, "The beam fades once the action is done")
	Vision.enabled = false
	lab.queue_free()
	await process_frame
	print("VISION FOCUS: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
