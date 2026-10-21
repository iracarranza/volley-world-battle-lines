extends RefCounted
## What the player holds. With `enabled` off (the practice lab) nothing changes: the player has endless serves. With it on (the map economy) a
## Toss needs a held ball, a ball is held one at a time, and an unstruck tossed ball that lands can be picked up by anyone for a few seconds.
const PICKUP_RADIUS := 1.6
const DESPAWN_SECONDS := 5.0
var enabled := false
var held := false
# The cart (index) the held ball came from, or -1; used to return a ball an opponent wastes to its cart.
var origin_cart := -1
# Set when a Toss starts, read when the unstruck ball lands: the cart it came from and whether the tosser is on the opposing team of that cart.
var pending_origin := -1
var pending_opposing := false

func give() -> void:
	held = true

# The ball leaves the hand (a Toss starts, a pass is thrown). Returns whether there was one.
func consume() -> bool:
	if not held:
		return false
	held = false
	return true

# Which cart the ball that just left the hand came from (once): remembered with the loose ball so it can go back.
func release_origin() -> int:
	var origin := origin_cart
	origin_cart = -1
	return origin

# Interact (I) with empty hands picks up a loose ball or takes one from a cart. Returns true when the key press was used.
func try_pickup(lab: Node3D) -> bool:
	if not enabled or held:
		return false
	if lab.ground_balls.take_near(lab.player.global_position, PICKUP_RADIUS):
		held = true
		origin_cart = lab.ground_balls.last_origin
		lab._message("BALL / picked up / E to charge a toss, release to toss, E again to serve")
		return true
	if is_instance_valid(lab.ball_carts) and lab.ball_carts.take_nearby(lab.player.global_position):
		held = true
		lab._message("BALL / taken from a cart / E to charge a toss, release to toss, E again to serve")
		return true
	return false
