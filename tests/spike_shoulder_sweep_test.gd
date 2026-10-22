extends "res://tests/support/test_case.gd"
const Stage := preload("res://scripts/spike_stage.gd")
const Execution := preload("res://scripts/contact_execution.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var back := Stage.shoulder_at(-0.22)
	var extension := Stage.shoulder_at(0.0)
	var follow := Stage.shoulder_at(0.45)
	var start := Execution.SPIKE_WINDUP
	var peak := Execution.SPIKE_PEAK
	var end := Execution.SPIKE_END
	check(absf(Stage.shoulder_at(Stage.swing_phase(start)) - back) < 0.01, "The shoulder is cocked back as the sweep starts, with the slice behind the athlete")
	check(absf(Stage.shoulder_at(Stage.swing_phase(peak)) - extension) < 0.01, "It is at its extension at the peak, with the slice overhead")
	check(absf(Stage.shoulder_at(Stage.swing_phase(end)) - follow) < 0.01, "It has turned through to the follow-through as the slice reaches the front")
	# An even rate on each half of the sweep: the angle is the clock.
	var half := (end - start) * 0.5
	var rates := []
	for step in range(1, 10):
		var before := Stage.shoulder_at(Stage.swing_phase(start + half * float(step - 1) / 9.0))
		var after := Stage.shoulder_at(Stage.swing_phase(start + half * float(step) / 9.0))
		rates.append((before - after) / (half / 9.0))
	var even := true
	for rate in rates: even = even and absf(rate - rates[0]) < 1.0
	check(even and float(rates[0]) > 0.0, "The shoulder turns at an even rate up to the peak (%.0f degrees per second)" % rates[0])
	var late_rates := []
	for step in range(1, 10):
		var before := Stage.shoulder_at(Stage.swing_phase(peak + half * float(step - 1) / 9.0))
		var after := Stage.shoulder_at(Stage.swing_phase(peak + half * float(step) / 9.0))
		late_rates.append((before - after) / (half / 9.0))
	var late_even := true
	for rate in late_rates: late_even = late_even and absf(rate - late_rates[0]) < 1.0
	check(late_even and float(late_rates[0]) > 0.0, "...and at an even rate after it (%.0f degrees per second)" % late_rates[0])
	# The slice and the shoulder agree about when each part of the sweep is
	var previous := 1000.0
	var falling := true
	for step in range(0, 41):
		var angle := Stage.shoulder_at(Stage.swing_phase(start + (end - start) * float(step) / 40.0))
		falling = falling and angle <= previous + 0.0001
		previous = angle
	check(falling, "The shoulder only ever turns forward through the sweep")
	check(is_equal_approx(Stage.swing_phase(end + 0.3), 0.45), "After the sweep the arm holds its follow-through")
	print("SPIKE SHOULDER SWEEP: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
