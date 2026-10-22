extends RefCounted
## One clock for the striking swing. The arm reaches its forward-and-up-most extension at PEAK seconds after the swing starts; that is the centre
## of the sweet window, and everything that cares about timing (the contact grade, the animation, the hurtbox's active region) reads it from here
## instead of keeping its own number.
##
## A Spike is a power swing while the arm is within POWER_HALF_WINDOW of its extension. Earlier than that the arm has not got there: a roll shot.
## Later, it has gone past: a reach/push. (POWER_HALF_WINDOW is provisional.)
const Execution := preload("res://scripts/contact_execution.gd")
const PEAK := Execution.SWEET_CENTER
const POWER_HALF_WINDOW := 0.14
const LOADED_PHASE := -0.30

static func power_start() -> float:
	return PEAK - POWER_HALF_WINDOW

static func power_end() -> float:
	return PEAK + POWER_HALF_WINDOW

# "roll" (early), "power", or "push" (late) for a contact `age` seconds into the swing.
static func form_at(age: float) -> String:
	if age < power_start():
		return "roll"
	return "power" if age <= power_end() else "push"

# How far the arm has travelled toward its extension: 0 at the start of the swing, 1 at PEAK (accelerating, as the arm does), and held at 1.
static func extension_at(age: float) -> float:
	var t := clampf(age / PEAK, 0.0, 1.0)
	return t * t
