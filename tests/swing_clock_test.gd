extends "res://tests/support/test_case.gd"
const Clock := preload("res://scripts/swing_clock.gd")
const Execution := preload("res://scripts/contact_execution.gd")
const Stage := preload("res://scripts/spike_stage.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Clock.PEAK == Execution.SWEET_CENTER and Stage.STRIKE_SECONDS == Execution.SPIKE_PEAK, "Grading, animation and the clock share one extension time")
	check(Clock.form_at(0.0) == "roll" and Clock.form_at(Clock.PEAK) == "power" and Clock.form_at(Clock.power_end() + 0.01) == "push", "Early is a roll, centre a power swing, late a push")
	check(is_equal_approx(Execution.SPIKE_END - Execution.SPIKE_WINDUP, 0.2), "The power window is the grading's window")
	check(Clock.extension_at(0.0) == 0.0 and is_equal_approx(Clock.extension_at(Clock.PEAK), 1.0) and Clock.extension_at(Clock.PEAK * 2.0) == 1.0, "The arm is fully extended at PEAK and holds there")
	check(Clock.extension_at(Clock.PEAK * 0.5) < 0.5, "The arm accelerates into the ball")
	check(Execution.sweet_active(2, Execution.SPIKE_PEAK) and not Execution.sweet_active(2, Execution.SPIKE_WINDUP), "The sweetspot is when the arm reaches its extension")
	print("SWING CLOCK: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
