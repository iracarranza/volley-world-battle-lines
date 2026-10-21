extends "res://scripts/ball_carts.gd"
## Drill Lab ball bins: one beside each Setup, refilled every 20 s (the map's 180 s clock would make a practice room tedious).
const BIN_REFILL_SECONDS := 20.0
var spots: Array = []

func setup(host: Node3D) -> void:
	lab = host
	for spot in spots:
		_add("bin", "blue", spot)
	tick(0.0)

func tick(dt: float) -> void:
	clock += dt
	if clock >= BIN_REFILL_SECONDS:
		clock = fmod(clock, BIN_REFILL_SECONDS)
		for cart in carts:
			cart.balls = CAPACITY
	_redraw -= dt
	if _redraw <= 0.0:
		_redraw = 0.2
		_refresh_visuals()

func fill_fraction() -> float:
	return clampf(clock / BIN_REFILL_SECONDS, 0.0, 1.0)

func team_empty(_lane: String, _team: String) -> bool:
	return false
