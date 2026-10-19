class_name CourtConstants
extends RefCounted

## Normalized tactical-board coordinates. X runs left-to-right; Y runs from the
## opponent baseline (0.0) to the home baseline (1.0). The net is at Y = 0.5.

const NET_Y: float = 0.5
## Not the end line, despite the name: the end lines are Y = 0.0 and Y = 1.0
## (see the frame described above, and `_court_to_local`, which maps that range
## onto the drawn court). This is the deepest position a player is placed at,
## inset from the line, and it is read as such everywhere it is used.
const HOME_BASELINE_Y: float = 0.96
## Full-court dimensions, used to convert normalised offsets into real distances.
const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0
## Height of the tape. Nothing consulted this before ball flight was solved from
## a contact height -- with the landing point chosen first and the arc
## back-solved to reach it, no ball could fail to clear the net, so there was
## nothing to consult it with.
const NET_HEIGHT_METERS: float = 2.43
## Each half court is 9 m deep. The attack line is 3 m from the net, leaving a
## 3 m front zone and 6 m back zone (a 1:2 depth ratio).
const HOME_ATTACK_LINE_Y: float = 0.653333
const OPPONENT_ATTACK_LINE_Y: float = 0.346667

## The serve is struck from the service zone, which is behind the end line.
##
## Both origins used to be `Vector2` literals repeated at six call sites, and
## both sat 1.44 m *inside* their own baseline -- the server standing in their
## own back zone, on the court, which is a fault before it is anything else. It
## also shortened every serve by the depth of the service zone, so serve flight
## time, the receiver's reading angle and the reception's difficulty were all
## measured from a contact point that cannot occur.
##
## A metre back from the line is an ordinary standing-serve contact point. It is
## deliberately modest: the tactical board reserves a 34 px margin outside the
## court rect, which at typical board sizes is about one metre, so the server
## stays visible rather than being drawn into the panel edge. Run-up depth for
## jump serves is a separate thing to model, not a bigger number here.
const SERVE_DEPTH_BEHIND_BASELINE_METERS: float = 1.0


## Where a serve is struck from, given the server's lateral position.
##
## `x` stays a caller's choice because the two sides do not currently agree on
## it -- home serves from 0.82 and the opponent from 0.80, a drift that survived
## precisely because each side had its own literal. Unifying it would move both
## sides' serve angles, which is a calibration change and not this one.
static func serve_origin(x: float, home_side: bool) -> Vector2:
	var depth := SERVE_DEPTH_BEHIND_BASELINE_METERS / COURT_LENGTH_METERS
	return Vector2(x, 1.0 + depth if home_side else -depth)

const LANES: Array[String] = [
	"Left Pin", "Front Quick", "Right Quick", "Right Pin", "Pipe",
]

const LANE_X := {
	"Left Pin": 0.12,
	"Front Quick": 0.40,
	"Right Quick": 0.60,
	"Right Pin": 0.88,
	"Pipe": 0.50,
}

## The region of court each lane actually covers -- along the net and off it.
##
## `LANE_X` is one point per lane and was being used as though it were the lane
## itself: `lane_target` returned it, the setter aimed at it, and the only reason
## two attacks ever landed in different places was execution scatter around a
## constant. Measured over 300 rallies that produced four bands about 1.5 m wide
## with dead net between them, and a 3.1 m stretch where no ball was ever struck.
##
## Depth belongs here for the same reason x does. Holding one shared depth
## constant for every lane meant the pipe's four metres and a pin's half metre
## were the same field, so the only way to summarise contact depth was to pool
## lanes that have nothing to do with each other -- which is exactly what made
## the first tightness sweep unreadable. A zone owns both of its axes.
##
## `depth_m` is metres from the tape on the hitter's own side. Quicks live tight
## because that is what makes them quick; the pins have room to be set off the
## net; the pipe is a back-row ball and sits behind the attack line.
##
## Every range is centred on the constant it replaced -- 0.54 m for the front
## lanes, 4.00 m for the pipe -- so that changing the near-net tail does not
## also move the ordinary ball back into the forgiving, block-avoiding depth
## this model was introduced to remove. A pin may ask for a ball 32 cm off the
## tape and a quick 25 cm off it, but neither asks for the 18-25 cm tail that
## puts the ball radius and the hitter's reaching hand effectively in the net.
const LANE_ZONE := {
	"Left Pin": {"x": Vector2(0.02, 0.24), "depth_m": Vector2(0.32, 0.76)},
	"Front Quick": {"x": Vector2(0.28, 0.50), "depth_m": Vector2(0.25, 0.83)},
	"Right Quick": {"x": Vector2(0.50, 0.72), "depth_m": Vector2(0.25, 0.83)},
	"Right Pin": {"x": Vector2(0.76, 0.98), "depth_m": Vector2(0.32, 0.76)},
	## Behind the three-metre line with room to spare, because delivery scatter
	## reaches +/-1.4 m and a zone edge is not a legality guarantee while the
	## delivery can cross it -- measured at 3 back-row swings in 124 struck in
	## front of the line from a zone starting at 3.20 m.
	"Pipe": {"x": Vector2(0.35, 0.65), "depth_m": Vector2(3.40, 4.60)},
}


static func lane_range(lane_name: String) -> Vector2:
	return Vector2(LANE_ZONE.get(lane_name, {}).get("x", Vector2(0.40, 0.60)))


## How far off the net this lane may be set, in metres, as a min/max pair.
## The nearest a set to this lane may be *delivered*, as normalised y on the
## hitter's own half.
##
## A zone edge is not a legality guarantee. Delivery scatter reaches about
## +/-1.4 m, so a back-row zone starting behind the three-metre line still puts
## balls in front of it -- measured at 3 back-row swings in 124 from a zone
## starting at 3.20 m, and 2 in 119 from one starting at 3.40 m. Moving the zone
## back again only trades legality for a pipe nobody would set. The floor belongs
## on the delivered point, where the rule actually applies.
##
## Front-row lanes keep the general floor: they have no attack line to respect.
static func lane_delivery_min_y(lane_name: String, general_min_y: float) -> float:
	if lane_name != "Pipe":
		return general_min_y
	return maxf(
		general_min_y,
		NET_Y + (ATTACK_LINE_METERS + BACK_ROW_TAKEOFF_MARGIN_METERS)
			/ COURT_LENGTH_METERS,
	)


## Where the attack line sits, and how much room behind it a back-row set is
## placed so the hitter takes off legally rather than exactly on the line.
const ATTACK_LINE_METERS: float = 3.0
const BACK_ROW_TAKEOFF_MARGIN_METERS: float = 0.35


static func lane_depth_range_meters(lane_name: String) -> Vector2:
	return Vector2(
		LANE_ZONE.get(lane_name, {}).get("depth_m", Vector2(0.30, 0.90))
	)


## The middle of a lane's region, which is what a caller wanting one
## representative point should get.
static func lane_target(lane_name: String) -> Vector2:
	var span := lane_range(lane_name)
	var depth := lane_depth_range_meters(lane_name)
	return Vector2(
		(span.x + span.y) * 0.5,
		NET_Y + (depth.x + depth.y) * 0.5 / COURT_LENGTH_METERS,
	)





const TEMPOS: Array[int] = [0, 1, 2, 3]

## Rotation-order reference grid: two rows of three, used to verify overlap
## legality at the moment of serve contact. This is NOT a tactical formation and
## must not be used to position players during live play. For serve reception use
## `serve_receive_formation()`; each phase owns its own real formation.
const ROTATION_SLOT_POSITIONS := {
	1: Vector2(0.82, 0.84), # back-right / serving position
	2: Vector2(0.82, 0.57), # front-right
	3: Vector2(0.50, 0.56), # front-middle
	4: Vector2(0.18, 0.57), # front-left
	5: Vector2(0.18, 0.84), # back-left
	6: Vector2(0.50, 0.87), # back-middle
}

## Three-passer serve-receive arc. The middle passer sits deeper to cover the
## long seam; the outside passers stay marginally shallower so they can play
## forward through the ball rather than backpedalling.
const SERVE_RECEIVE_PASSER_POSITIONS := {
	"left": Vector2(0.19, 0.80),
	"middle": Vector2(0.50, 0.86),
	"right": Vector2(0.81, 0.80),
}

## Where front-row attackers who are NOT passing wait for the ball. They stage
## off the passing lanes, already turned toward their approach.
const SERVE_RECEIVE_STAGING_POSITIONS := {
	2: Vector2(0.84, 0.68),
	3: Vector2(0.46, 0.60),
	4: Vector2(0.14, 0.68),
}

## A shielded setter stands close to the net so the serve travels past them to
## the passers. They are never a primary receiver, in either row.
##
## 0.63 was not close to the net. The net is at 0.50, the front-row slots sit at
## 0.56-0.57, and `HOME_ATTACK_LINE_Y` is 0.6533 -- so the old value put a
## front-row setter *behind* their own front row, essentially on the attack
## line. A back-row setter, placed at their partner's depth plus 0.09, landed at
## roughly 0.655. The two rows were 0.025 apart, about 45 cm on an 18 m court:
## the front/back branch below was structurally right and produced two
## positions nobody could tell apart, which is why a front-row setter read as
## starting in the back row.
const SETTER_SHIELD_Y: float = 0.545

const BACK_ROW_SLOTS: Array[int] = [1, 5, 6]

## Rotational front/back partners. A back-row player must stay behind their
## front-row partner at the moment of serve contact, so a shielded back-row
## setter hides directly behind this teammate: legal and screened at once.
const BACK_FRONT_SLOT_PAIRS := {1: 2, 6: 3, 5: 4}

## Realistic serve-receive presets. `lanes` are the lateral passing seams,
## `depth` is the deepest passer's Y, and `outside_depth_lift` pulls the wide
## passers marginally shallower so they play forward through the ball instead of
## backpedalling. Passers are assigned to seams left-to-right.
const SERVE_RECEIVE_FORMATIONS := {
	## Two deep passers splitting the court. The elite default: fewest seams,
	## but it demands two genuinely good passers and leaves short serves to a
	## dedicated short-coverage player.
	"two_passer": {
		"passer_count": 2,
		"lanes": [0.33, 0.67],
		"depth": 0.84,
		"outside_depth_lift": 0.0,
	},
	## Three-passer arc. The modern standard and this project's default.
	"three_passer": {
		"passer_count": 3,
		"lanes": [0.19, 0.50, 0.81],
		"depth": 0.86,
		"outside_depth_lift": 0.06,
	},
	## Four passers, used against a big server when seam risk outweighs the cost
	## of pulling an attacker out of their approach.
	"four_passer": {
		"passer_count": 4,
		"lanes": [0.15, 0.38, 0.62, 0.85],
		"depth": 0.83,
		"outside_depth_lift": 0.04,
	},
	## Legacy five-passer W. Retained deliberately so the tactical board can show
	## why it is not the default: every front-row passer is a hitter who cannot
	## start their approach on time.
	"five_passer_w": {
		"passer_count": 5,
		"lanes": [0.14, 0.32, 0.50, 0.68, 0.86],
		"depth": 0.82,
		"outside_depth_lift": 0.10,
	},
}

const DEFAULT_SERVE_RECEIVE_FORMATION: String = "three_passer"

## Where a back-row player who is not passing covers the short serve.
const SHORT_COVERAGE_POSITION := Vector2(0.50, 0.70)

## Slot promoted into the passing trio when the setter occupies the back row.
## Front-left is the conventional step-back passer. A roster-aware version could
## instead pick the best available `reception` rating.
const PROMOTED_PASSER_SLOT: int = 4


static func is_valid_lane(lane_name: String) -> bool:
	return lane_name in LANES


static func is_valid_tempo(tempo: int) -> bool:
	return tempo in TEMPOS


static func is_front_row_slot(slot_number: int) -> bool:
	return slot_number in [2, 3, 4]


## Returned for a slot number this rotation does not have -- most commonly -1,
## the result of `slot_for_player()` failing to find a player who has been
## removed from the lineup. The old default, `Vector2(0.5, 0.85)`, was chosen
## as "somewhere plausible near the back row" and landed 0.02 short of slot 6's
## real position, `Vector2(0.50, 0.87)`. On a normalized 0-1 court that is
## visually indistinguishable, so a player whose slot could not be resolved
## rendered on top of whoever actually occupies slot 6 -- reported as one
## player "attached" to another. This sentinel sits off the normalized court
## entirely so an unresolved slot fails visibly instead of coinciding with a
## real one.
const UNRESOLVED_SLOT_POSITION := Vector2(-1.0, -1.0)


static func slot_position(slot_number: int) -> Vector2:
	return ROTATION_SLOT_POSITIONS.get(slot_number, UNRESOLVED_SLOT_POSITION)



## Which lane a contact at this x belongs to.
##
## The inverse of `lane_target`, and it exists because one side of the net was
## reading a lane it never had. `_choose_opponent_attack` returns a hitter, a
## contact point and a shot -- it has never returned a lane -- so every caller
## asking it for one got the `"Left Pin"` default, and every opponent swing in
## the game was resolved as a left-pin swing no matter where the hitter was
## standing. Nothing noticed while the lane only labelled an event; it started
## to matter the moment the lane began deciding the ball's natural course.
static func lane_at_x(contact_x: float) -> String:
	var nearest := "Front Quick"
	var best := INF
	for lane_name in LANES:
		## The pipe is a back-row lane, not a place on the net. Choosing it from
		## an x alone would put a front-row hitter on a pipe every time they
		## contacted near the middle.
		if lane_name == "Pipe":
			continue
		var distance := absf(float(LANE_X[lane_name]) - contact_x)
		if distance < best:
			best = distance
			nearest = lane_name
	return nearest


static func is_normalized(point: Vector2) -> bool:
	return point.x >= 0.0 and point.x <= 1.0 \
		and point.y >= 0.0 and point.y <= 1.0


static func is_valid_serve_receive_formation(formation_name: String) -> bool:
	return formation_name in SERVE_RECEIVE_FORMATIONS


## Single canonical home-to-opponent mirror. Every system that needs an opponent
## position routes through here so both sides are guaranteed to be generated by
## identical logic; any change to home behaviour shows up on the opponent side in
## the same rally rather than drifting apart.
static func mirror_to_opponent(point: Vector2) -> Vector2:
	return Vector2(point.x, 1.0 - point.y)


## Which slots actually pass the serve, in priority order. The setter is never a
## primary passer. When the setter occupies the back row, a front-row passer is
## promoted to keep the seam count intact.
static func serve_receive_passer_slots(
	setter_slot: int,
	passer_count: int,
	libero_slot: int = -1,
) -> Array[int]:
	var candidates: Array[int] = []
	## The libero passes first whenever they are on court.
	if libero_slot in BACK_ROW_SLOTS and libero_slot != setter_slot:
		candidates.append(libero_slot)
	for slot_number in [5, 6, 1]:
		if slot_number != setter_slot and slot_number not in candidates:
			candidates.append(slot_number)
	## First front-row promotion is the setter's own rotational partner: they
	## already stand on the side the setter vacated, and the setter is shielded
	## behind them, so the step-back is the shortest possible adjustment. The one
	## exception is the front-middle, whose quick approach we protect if we can.
	var promotion_order: Array[int] = []
	var partner_slot := int(BACK_FRONT_SLOT_PAIRS.get(setter_slot, PROMOTED_PASSER_SLOT))
	if partner_slot != 3:
		promotion_order.append(partner_slot)
	for slot_number in [PROMOTED_PASSER_SLOT, 2, 3]:
		if slot_number not in promotion_order:
			promotion_order.append(slot_number)
	for slot_number in promotion_order:
		if slot_number != setter_slot and slot_number not in candidates:
			candidates.append(slot_number)
	var chosen: Array[int] = []
	for slot_number in candidates:
		if chosen.size() >= passer_count:
			break
		chosen.append(slot_number)
	return chosen


## Which players should form the default passing unit for this lineup.
##
## Rotation slots describe where a player must stand at serve contact; they do
## not describe that player's job.  The slot-only fallback above is useful when
## no roster is available, but using it for a real team routinely enrolled an
## opposite or a middle while an outside hitter waited out of the pattern.  A
## three-passer receive should begin with the roles trained to pass -- libero
## and outsides -- and only recruit another position when the lineup does not
## contain enough of them.  Attributes break ties and choose any required
## replacement; they do not let a marginal rating difference hide a specialist.
static func roster_serve_receive_passer_slots(
	lineup: RotationLineup,
	players: Array,
	passer_count: int,
) -> Array[int]:
	if lineup == null or passer_count <= 0:
		return []
	var by_id := {}
	for raw_player in players:
		var player := raw_player as VolleyballPlayer
		if player != null:
			by_id[int(player.id)] = player
	if by_id.is_empty():
		return serve_receive_passer_slots(
			lineup.slot_for_player(lineup.active_setter_id()), passer_count
		)

	var specialists: Array[Dictionary] = []
	var replacements: Array[Dictionary] = []
	var setter_id := int(lineup.active_setter_id())
	for slot_number in range(1, 7):
		var player_id := int(lineup.player_at_slot(slot_number))
		if player_id < 0 or player_id == setter_id:
			continue
		var player := by_id.get(player_id) as VolleyballPlayer
		if player == null:
			continue
		var row := {
			"slot": slot_number,
			"score": _serve_receive_player_score(player),
		}
		if str(player.position_role) in ["Libero", "Outside Hitter"]:
			specialists.append(row)
		else:
			replacements.append(row)

	var strongest_first := func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return int(a.get("slot", 7)) < int(b.get("slot", 7))
	specialists.sort_custom(strongest_first)
	replacements.sort_custom(strongest_first)

	var chosen: Array[int] = []
	for row in specialists:
		if chosen.size() >= passer_count:
			break
		chosen.append(int(row.slot))
	for row in replacements:
		if chosen.size() >= passer_count:
			break
		chosen.append(int(row.slot))
	return chosen


## A stable player-lane ordering for audits and authored systems that explicitly
## request one.
##
## This is deliberately not the live default. Holding Outside 1/libero/Outside 2
## to the same left-middle-right lanes erased the rotation ace spread, but also
## kept the receiving outside in the same deep corner after first contact and
## suppressed a trusted hitter's attack availability. Production therefore uses
## the same roster-selected passing unit with minimum-travel seam assignment;
## this stable ordering remains as the paired counterfactual that exposed the
## trade-off. Ids are only a deterministic fallback for generic position codes.
static func roster_serve_receive_seam_slots(
	lineup: RotationLineup,
	players: Array,
	passer_count: int,
) -> Array[int]:
	var selected := roster_serve_receive_passer_slots(lineup, players, passer_count)
	if selected.size() <= 1:
		return selected
	var by_id := {}
	for raw_player in players:
		var player := raw_player as VolleyballPlayer
		if player != null:
			by_id[int(player.id)] = player
	if by_id.is_empty():
		return selected
	var outsides: Array[Dictionary] = []
	var liberos: Array[Dictionary] = []
	var replacements: Array[Dictionary] = []
	for slot_number in selected:
		var player := by_id.get(lineup.player_at_slot(slot_number)) as VolleyballPlayer
		if player == null:
			continue
		var row := {
			"slot": slot_number,
			"id": int(player.id),
			"code": str(player.position_code),
			"score": _serve_receive_player_score(player),
		}
		if player.position_role == "Outside Hitter":
			outsides.append(row)
		elif player.position_role == "Libero":
			liberos.append(row)
		else:
			replacements.append(row)
	outsides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var code_a := str(a.code)
		var code_b := str(b.code)
		if code_a != code_b:
			return code_a < code_b
		return int(a.id) < int(b.id)
	)
	liberos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.id) < int(b.id)
	)
	replacements.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.score)
		var score_b := float(b.score)
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return int(a.id) < int(b.id)
	)

	var ordered: Array[int] = []
	## Three-passer receive is the live default: outside/libero/outside. A
	## missing specialist is filled below without changing anybody else's lane.
	if not outsides.is_empty():
		ordered.append(int(outsides[0].slot))
	if not liberos.is_empty():
		ordered.append(int(liberos[0].slot))
	elif not replacements.is_empty():
		ordered.append(int(replacements[0].slot))
	if outsides.size() >= 2:
		ordered.append(int(outsides[1].slot))
	for group in [outsides, liberos, replacements]:
		for row in group:
			var slot_number := int(row.slot)
			if slot_number not in ordered:
				ordered.append(slot_number)
	for slot_number in selected:
		if slot_number not in ordered:
			ordered.append(slot_number)
	var result: Array[int] = []
	for slot_number in ordered:
		if result.size() >= passer_count:
			break
		result.append(slot_number)
	return result


static func _serve_receive_player_score(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	return float(player.reception) * 0.65 \
		+ float(player.ball_control) * 0.20 \
		+ float(player.composure) * 0.15


## Where the setter waits for the serve. They are shielded in both rows: a
## front-row setter stands at the net so the serve passes them, and a back-row
## setter hides directly behind their rotational front-row partner.
static func setter_serve_receive_position(setter_slot: int) -> Vector2:
	if is_front_row_slot(setter_slot):
		var front_reference := slot_position(setter_slot)
		return Vector2(clampf(front_reference.x, 0.10, 0.90), SETTER_SHIELD_Y)
	var partner_slot := int(BACK_FRONT_SLOT_PAIRS.get(setter_slot, 2))
	var partner := slot_position(partner_slot)
	## Stay behind the partner (larger Y is deeper on the home side) so the
	## overlap rule holds at serve contact while the partner screens the setter,
	## and behind the attack line as well -- a back-row setter who starts level
	## with it has no release to run, and is indistinguishable from a front-row
	## one. The journey to the net after the serve is struck is the difference
	## between the two rows, so the starting depth has to leave room for it.
	return Vector2(
		clampf(partner.x, 0.10, 0.90),
		clampf(
			maxf(partner.y + 0.09, HOME_ATTACK_LINE_Y + 0.03), 0.53, 0.94
		),
	)


## Exhaustive minimum-travel matching of passer slots to seams. Returns the slot
## occupying each seam, indexed the same way as `seams`. Distances are measured in
## metres so the 9 m x 18 m court aspect is respected: a lateral error and a depth
## error of the same normalised size are not the same amount of running.
static func _best_seam_assignment(
	passer_slots: Array[int],
	seams: Array[Vector2],
) -> Array[int]:
	var usable := mini(passer_slots.size(), seams.size())
	if usable <= 0:
		return []
	var empty_order: Array[int] = []
	var best := {"order": empty_order, "cost": INF}
	var working: Array[int] = []
	_search_seam_assignment(passer_slots, seams, usable, working, 0.0, best)
	var winner: Array[int] = best["order"]
	if winner.is_empty():
		for index in range(usable):
			winner.append(passer_slots[index])
	return winner


## Depth-first branch and bound. `best` carries the incumbent order and cost so
## the search can prune any partial assignment that already costs more.
static func _search_seam_assignment(
	passer_slots: Array[int],
	seams: Array[Vector2],
	usable: int,
	working: Array[int],
	cost_so_far: float,
	best: Dictionary,
) -> void:
	if working.size() >= usable:
		if cost_so_far < float(best["cost"]):
			var snapshot: Array[int] = []
			snapshot.append_array(working)
			best["cost"] = cost_so_far
			best["order"] = snapshot
		return
	var seam_index := working.size()
	for slot_number in passer_slots:
		if slot_number in working:
			continue
		var origin := slot_position(slot_number)
		var seam: Vector2 = seams[seam_index]
		var travel := Vector2(
			(seam.x - origin.x) * COURT_WIDTH_METERS,
			(seam.y - origin.y) * COURT_LENGTH_METERS
		).length()
		if cost_so_far + travel >= float(best["cost"]):
			continue
		working.append(slot_number)
		_search_seam_assignment(
			passer_slots, seams, usable, working, cost_so_far + travel, best
		)
		working.remove_at(working.size() - 1)


## Full serve-reception formation keyed by rotation slot. This is the function
## `ROTATION_SLOT_POSITIONS` points callers toward: the rotation grid is only a
## legality reference and must never position players during live play.
static func serve_receive_formation(
	setter_slot: int,
	formation_name: String = DEFAULT_SERVE_RECEIVE_FORMATION,
	libero_slot: int = -1,
	opponent_side: bool = false,
	passer_slots_override: Array[int] = [],
	fixed_seam_order: bool = false,
) -> Dictionary:
	var preset: Dictionary = SERVE_RECEIVE_FORMATIONS.get(
		formation_name, SERVE_RECEIVE_FORMATIONS[DEFAULT_SERVE_RECEIVE_FORMATION]
	)
	var lanes: Array = preset["lanes"]
	var depth := float(preset["depth"])
	var lift := float(preset["outside_depth_lift"])
	var passer_slots: Array[int] = passer_slots_override.duplicate() \
		if not passer_slots_override.is_empty() \
		else serve_receive_passer_slots(
			setter_slot, int(preset["passer_count"]), libero_slot
		)

	## Build the seam positions. Lift is normalised against the widest seam in
	## this preset, so the outermost passers receive the full lift and the
	## three-passer arc reproduces SERVE_RECEIVE_PASSER_POSITIONS exactly.
	var widest_offset := 0.001
	for raw_lane in lanes:
		widest_offset = maxf(widest_offset, absf(float(raw_lane) - 0.5))
	var seams: Array[Vector2] = []
	for raw_lane in lanes:
		var lane_x := float(raw_lane)
		var lane_y := depth - lift * clampf(
			absf(lane_x - 0.5) / widest_offset, 0.0, 1.0
		)
		seams.append(Vector2(
			clampf(lane_x, 0.06, 0.94), clampf(lane_y, 0.53, 0.96)
		))

	## Assign passers to seams by exact minimum total travel rather than sorting
	## on X. Sorting breaks down whenever two passers share a rotational X (slots
	## 4 and 5 both sit at 0.18), which silently produced cross-court swaps: a
	## front-left passer sent to the deep middle while the back-middle passer ran
	## to the right seam. With at most five passers an exhaustive search is cheap
	## and always optimal.
	var assignment: Array[int] = []
	if fixed_seam_order:
		for index in range(mini(passer_slots.size(), seams.size())):
			assignment.append(passer_slots[index])
	else:
		assignment = _best_seam_assignment(passer_slots, seams)

	var formation := {}
	for lane_index in range(assignment.size()):
		formation[assignment[lane_index]] = seams[lane_index]

	formation[setter_slot] = setter_serve_receive_position(setter_slot)

	for slot_number in range(1, 7):
		if slot_number in formation:
			continue
		if is_front_row_slot(slot_number):
			formation[slot_number] = Vector2(SERVE_RECEIVE_STAGING_POSITIONS.get(
				slot_number, Vector2(0.5, 0.62)
			))
		else:
			formation[slot_number] = SHORT_COVERAGE_POSITION

	if opponent_side:
		for slot_number in formation:
			formation[slot_number] = mirror_to_opponent(formation[slot_number])
	return formation
