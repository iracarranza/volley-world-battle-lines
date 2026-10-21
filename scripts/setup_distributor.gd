extends RefCounted
## A Setup's ball distributor (the map ball economy). The player gives up their held ball to activate it; the distributor then sends balls out
## one at a time for the drill, and every ball sent is consumed whether the rep counts or not. Reaching the minimum number of reps completes
## the Setup: the completer is rewarded with the balls left in the distributor plus the one they gave up, so each error (a ball used without a
## rep) costs a reward ball. Running out of balls first fails the Setup. After either ending the Setup waits out its own reactivation timer.
## Leaving the area never fails a Setup, and anyone may take reps; the player who lands the final rep takes the reward.
enum Phase { READY, RUNNING, COOLDOWN }
const BALLS := 10
const MIN_REPS := 5
const REACTIVATE_SECONDS := 45.0
var balls_total := BALLS
var min_reps := MIN_REPS
var reactivate_seconds := REACTIVATE_SECONDS
var phase := Phase.READY
var balls := BALLS      # still in the distributor
var reps := 0
var errors := 0
var cooldown := 0.0
var starter := ""       # who gave up the ball
var completer := ""     # who landed the final rep
var pile := 0           # reward balls waiting for the completer
var pile_owner := ""
var last_result := ""

func ready() -> bool:
	return phase == Phase.READY

func running() -> bool:
	return phase == Phase.RUNNING

# The ball in hand is given up and the Setup starts. Returns false if it cannot.
func activate(actor: String) -> bool:
	if phase != Phase.READY:
		return false
	phase = Phase.RUNNING
	balls = balls_total
	reps = 0
	errors = 0
	starter = actor
	completer = ""
	pile = 0
	pile_owner = ""
	last_result = ""
	return true

# The distributor sends one ball out for the drill. False when it is empty (the Setup then fails).
func send() -> bool:
	if phase != Phase.RUNNING:
		return false
	if balls <= 0:
		_end("failed", "")
		return false
	balls -= 1
	return true

# A ball that was sent has been used: it counted as a rep, or it was an error. Returns "rep", "error", "complete" or "failed".
func record(success: bool, actor: String) -> String:
	if phase != Phase.RUNNING:
		return ""
	if success:
		reps += 1
		if reps >= min_reps:
			_end("complete", actor)
			return "complete"
		return "rep"
	errors += 1
	if balls <= 0:
		_end("failed", "")
		return "failed"
	return "error"

func _end(result: String, actor: String) -> void:
	phase = Phase.COOLDOWN
	cooldown = reactivate_seconds
	last_result = result
	if result == "complete":
		completer = actor
		# The balls left plus the one the starter gave up (if the completer is a thief, they still take it all).
		pile = balls + 1
		pile_owner = actor
		balls = 0

# Reward balls the completer can take, one hand-full at a time.
func claim(actor: String) -> bool:
	if pile <= 0 or actor != pile_owner:
		return false
	pile -= 1
	if pile <= 0:
		pile_owner = ""
	return true

func tick(dt: float) -> void:
	if phase != Phase.COOLDOWN:
		return
	cooldown = maxf(0.0, cooldown - dt)
	if cooldown <= 0.0:
		phase = Phase.READY
		balls = balls_total
		reps = 0
		errors = 0
		pile = 0 # an unclaimed pile is lost when the Setup reactivates
		pile_owner = ""

func status() -> String:
	match phase:
		Phase.READY:
			return "SETUP ACTIVE / give up a ball (I) to start"
		Phase.RUNNING:
			return "SETUP / rep %d of %d / %d errors / %d balls left" % [reps, min_reps, errors, balls]
		_:
			return "SETUP / reactivates in %ds%s" % [ceili(cooldown), " / %d reward balls" % pile if pile > 0 else ""]
