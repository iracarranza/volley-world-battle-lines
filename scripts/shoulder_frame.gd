extends RefCounted
## The one shoulder reference of the Attack volume (G-08, MS-19): the idle-rig shoulder of the actor's own rig, captured when the rig is built
## and used for every actor kind (player, court bot, Pepper). The Attack hurtbox no longer follows the live arm pose (lean, dive, recovery).
## Values are in rig units; `scaled` converts to world metres for a body height.

static func idle(arms: Array) -> Vector2:
	if arms.size() < 2:
		return Vector2(-1.0, -1.0)
	return Vector2(arms[1].position.y, absf(arms[1].position.x))

## (shoulder height, shoulder offset) in world metres, or (-1, -1) (Geometry's proportional defaults) when the rig has no arms.
static func scaled(frame: Vector2, scale_to_world: float) -> Vector2:
	if frame.x < 0.0:
		return Vector2(-1.0, -1.0)
	return frame * scale_to_world
