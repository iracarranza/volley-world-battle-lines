extends RefCounted
## Custody record (MS-08): where every ball is, read from the owners that already hold them. Nothing here moves a ball.
## census() counts carts, the player's hand, the live ball and the loose ground balls; total() is their sum. Conservation holds across
## cart -> hand -> live -> ground except at the registered leaks, which CURRENT behaviour keeps (BDR-16, G-15: the economy rules are unchanged):
##   GROUND_EVICTION  a fourth loose ball evicts the oldest without a cart return (the ball is gone from custody).
##   BENCH_KEEPS_HAND the Bench drops the live ball but keeps inventory.held (the hand still counts).
##   TEAM_EMPTY       ball_carts.team_empty has no reader, so an empty cart threatens nothing.
const GROUND_EVICTION := "ground_eviction"
const BENCH_KEEPS_HAND := "bench_keeps_hand"
const TEAM_EMPTY := "team_empty_unread"
const REGISTERED_LEAKS := [GROUND_EVICTION, BENCH_KEEPS_HAND, TEAM_EMPTY]

static func census(lab) -> Dictionary:
	return {
		"carts": lab.ball_carts.total_balls() if is_instance_valid(lab.ball_carts) else 0,
		"hand": 1 if lab.inventory.held else 0,
		"live": 1 if lab.ball_active else 0,
		"ground": lab.ground_balls.balls.size(),
	}

static func total(lab) -> int:
	var count := census(lab)
	return int(count.carts) + int(count.hand) + int(count.live) + int(count.ground)
