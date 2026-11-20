extends RefCounted
## Immutable record of the clock scales at one point of a step, computed once by MomentOfContact.clock_record().
## Domains: world time is the physics dt itself and is never scaled; ball() is the ball-wide scale; actor(id) is the acting
## athlete's own scale (1 for everyone else); bot(id) is the slower of ball and actor, which is what helpers plan in.
## real_now() is monotonic real seconds for the MoC window, DI sampling and render-rate steering, which cannot be derived from a physics step.
## A reader asks for a record at the moment it used to ask MoC for a scale, so nothing is evaluated earlier or later than before.
var _ball: float
var _acting_actor: String
var _actor: float
var _real_now: float

func _init(ball_scale: float, acting_actor: String, actor_scale: float, real_now: float) -> void:
	_ball = ball_scale
	_acting_actor = acting_actor
	_actor = actor_scale
	_real_now = real_now

func ball() -> float:
	return _ball

func actor(actor_id: String) -> float:
	return _actor if actor_id == _acting_actor else 1.0

func bot(actor_id: String) -> float:
	return minf(_ball, actor(actor_id))

func real_now() -> float:
	return _real_now
