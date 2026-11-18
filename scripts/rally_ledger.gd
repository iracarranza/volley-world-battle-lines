extends RefCounted
## Rally ledger operations (MS-06): the named ways the team-touch counters, the personal counter, last touch and renewal change.
## State stays where readers find it (lab.contacts is the player's personal count, lab.side_contacts the per-side team count,
## rally_rules.last_touch_side the last toucher); every write goes through here, and nothing here changes a value or an order.
## Reset scope is per caller, as today: bots clear the personal count only, Pepper and the drills clear both.

## The player's personal count rises on every contact but a Block, before the fault check.
static func count_player_touch(lab, is_block: bool) -> void:
	if not is_block:
		lab.contacts += 1

## Pepper counts the player's contacts itself (pepper.player_contacts); otherwise the personal and team counts are both limited.
static func player_fault(lab, is_block: bool, side: int) -> bool:
	if is_block:
		return false
	return lab.pepper.player_contacts >= 3 if lab.pepper.active() else (lab.contacts > 3 or lab.side_contacts[side] >= 3)

## After the fault check: Pepper counts its own, a Block adds nothing, any other contact adds to the team count.
static func record_player_touch(lab, is_block: bool, side: int) -> void:
	if lab.pepper.active():
		lab.pepper.player_contacts += 1
	elif not is_block:
		lab.side_contacts[side] += 1

## A helper's fourth team touch is a fault; its check reads the count before this contact is added.
static func bot_at_limit(lab, side: int) -> bool:
	return lab.side_contacts[side] >= 3

static func count_bot_touch(lab, side: int) -> void:
	lab.side_contacts[side] += 1

## A helper's contact clears only the personal count.
static func clear_personal(lab) -> void:
	lab.contacts = 0

## An opponent's touch renews the team's allowance (even when a block reverses the ball before it clears the net), the personal
## count is cleared when the toucher is not on the player's side, and the toucher becomes the last touch.
static func renew_opponent(lab, touching_side: int) -> void:
	lab.side_contacts[1 - touching_side] = 0
	if touching_side != lab.side_index(lab.player.position.z):
		lab.contacts = 0
	lab.rally_rules.touch(touching_side)

## The ball crossing the net clears the side it is now on, and the personal count.
static func reset_on_crossing(lab) -> void:
	lab.side_contacts[lab.side_index(lab.ball.position.z)] = 0
	lab.contacts = 0

## Both counts to zero: a new feed, a Pepper start or a Pepper contact, a drill or station, a full reset.
static func clear_all(lab) -> void:
	lab.contacts = 0
	lab.side_contacts.fill(0)

static func begin_rally(lab, serving_side: int = -1) -> void:
	lab.rally_rules.begin(serving_side)
