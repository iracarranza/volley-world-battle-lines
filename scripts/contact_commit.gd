extends RefCounted
## The one commit of a resolved contact (MS-07): the shared steps in one place and the differences between callers as named policy.
## Sequence: [spend, if before_publish] -> prepare -> publish -> present -> [spend, if after_publish] -> counter reset -> settle.
## The caller supplies the steps as callables (what is spent and how, the follow-up, the publish call, the presentation); the commit
## fixes only their order and the two policy values below. CURRENT per caller, reproduced exactly (FC-01, FC-04, FC-30):
##   every caller spends before the event is published (listeners see post-depletion Stamina): G-01, MS-16 moved court bots and Pepper (they spent after it).
##   counters: the player's and Serve's reset happens in the publish renewal, a bot clears the personal count, Pepper clears both.
## The spend_position field was the migration switch for G-01 (flipped in MS-16; all four policies now share one value). The cap is five fields (SADR-03).
const RallyLedger := preload("res://scripts/rally_ledger.gd")
const ReceiveCharge := preload("res://scripts/receive_charge.gd")
const LiveBall := preload("res://scripts/live_ball.gd")
const Action := preload("res://scripts/contact/action.gd").Type
enum Spend { BEFORE_PUBLISH, AFTER_PUBLISH }
enum Counters { NONE, PERSONAL, BOTH }
const MAX_POLICY_FIELDS := 5
const SHOT_KINDS := ["receive", "set", "attack", "block"]

const PLAYER := {"spend_position": Spend.BEFORE_PUBLISH, "counter_reset": Counters.NONE}
const SERVE := {"spend_position": Spend.BEFORE_PUBLISH, "counter_reset": Counters.NONE}
const BOT := {"spend_position": Spend.BEFORE_PUBLISH, "counter_reset": Counters.PERSONAL}
const PEPPER := {"spend_position": Spend.BEFORE_PUBLISH, "counter_reset": Counters.BOTH}

## The outgoing shot of a resolved contact (the ball's velocity has already been committed): built from the action's charge, replaced by
## the resolver's shot when it made one, decorated by Flow, and an Attack's pending bonus is consumed on a hit. Written to the ball once.
static func outgoing_shot(lab, request, result, actor_id: String, action: int, charge: float) -> void:
	var assessment: Dictionary = result.assessment
	var shot := ReceiveCharge.shot(SHOT_KINDS[action], lab.contact_flow.attack_charge(charge, actor_id, lab.ball.position, assessment) if action == Action.ATTACK else charge, actor_id)
	if not result.outgoing_shot.is_empty():
		shot = result.outgoing_shot
	LiveBall.commit_shot(lab, lab.contact_flow.decorate_shot(shot, request.incoming_shot, actor_id, action, assessment))
	if action == Action.ATTACK and assessment.hit:
		lab.contact_flow.consume_attack(actor_id)

## Steps: "spend" and "publish" (required), "prepare", "present" and "settle" (optional), each a Callable taking no arguments.
static func run(lab, policy: Dictionary, steps: Dictionary) -> void:
	var before_publish: bool = int(policy.spend_position) == Spend.BEFORE_PUBLISH
	if before_publish:
		steps.spend.call()
	if steps.has("prepare"):
		steps.prepare.call()
	steps.publish.call()
	if steps.has("present"):
		steps.present.call()
	if not before_publish:
		steps.spend.call()
	match int(policy.counter_reset):
		Counters.PERSONAL: RallyLedger.clear_personal(lab)
		Counters.BOTH: RallyLedger.clear_all(lab)
	if steps.has("settle"):
		steps.settle.call()
