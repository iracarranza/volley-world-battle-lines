extends RefCounted
## How far a matched receive travels. A receive that matches the hit sends the ball where a setter should be: the distance follows from how far the
## receiver is from the net (the ball is passed to a point SETTER_OFFSET metres off the net), wherever they are on or off the court. With no net (a
## Pepper) the distance is absolute. Charge beyond the clean band carries the ball farther, up to an overpass; that overshoot is deterministic.
const SETTER_OFFSET := 2.0     # metres from the net the matched pass is aimed at
const MIN_DISTANCE := 1.5      # a receive right at the net still travels this far
const PEPPER_DISTANCE := 7.0   # with no net the pass is this far
const OVERPASS_MARGIN := 3.0   # an overpass clears the net by at least this far

# `net_distance` is the receiver's distance from the net, or a negative number when there is no net.
static func matched_distance(net_distance: float) -> float:
	if net_distance < 0.0:
		return PEPPER_DISTANCE
	return maxf(net_distance - SETTER_OFFSET, MIN_DISTANCE)

# The factor on a matched pass's horizontal pace at full overcharge severity: enough to carry it over the net and a little beyond.
static func overpass_factor(net_distance: float) -> float:
	var matched := matched_distance(net_distance)
	if net_distance < 0.0:
		return 2.2
	return clampf((net_distance + OVERPASS_MARGIN) / matched, 1.5, 6.0)
