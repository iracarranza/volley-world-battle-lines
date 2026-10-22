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

# The striking arm's angle in the hurtbox's own plane (the same angle the sweetspot is defined in: 0 straight out to the striking side, 90 straight
# up, 180 across the body). It starts cocked at ANGLE_COCKED, reaches ANGLE_EXTENDED (inside the sweet band) at PEAK, and carries on to
# ANGLE_FOLLOW by the time the power window closes. A ball is struck when the arm has swept to its angle, so where the ball is decides when.
const ANGLE_COCKED := 150.0
const ANGLE_EXTENDED := 67.5
const ANGLE_FOLLOW := 20.0

static func arm_angle_at(age: float) -> float:
	if age <= PEAK:
		return lerpf(ANGLE_COCKED, ANGLE_EXTENDED, extension_at(age))
	return lerpf(ANGLE_EXTENDED, ANGLE_FOLLOW, smoothstep(0.0, 1.0, clampf((age - PEAK) / POWER_HALF_WINDOW, 0.0, 1.0)))

# The earliest swing age at which the arm has reached `angle` (in degrees), or -1 if it never does.
static func age_reaching(angle: float) -> float:
	if angle > ANGLE_COCKED:
		return 0.0
	if angle < ANGLE_FOLLOW:
		return -1.0
	if angle >= ANGLE_EXTENDED:
		return PEAK * sqrt(clampf((ANGLE_COCKED - angle) / (ANGLE_COCKED - ANGLE_EXTENDED), 0.0, 1.0))
	var low := PEAK
	var high := power_end()
	for step in range(24):
		var middle := (low + high) * 0.5
		if arm_angle_at(middle) > angle:
			low = middle
		else:
			high = middle
	return high
