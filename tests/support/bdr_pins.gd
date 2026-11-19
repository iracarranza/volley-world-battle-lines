extends RefCounted
## MS-05 BDR pin tests. One function per catalogue scenario, asserting the CURRENT behaviour recorded in the divergence register, quirks
## included. `facts` is the scenario's normalized fact dictionary. These pin what the code does today; they do not claim it is right.
## COVERAGE maps every BDR entry to the scenarios (and so the pin functions) that hold it; a lint in the catalogue suite checks the register agrees.
const COVERAGE := {
	"BDR-01": ["s01_depleted_player", "s01_depleted_bot", "s01_depleted_pepper", "s01_depleted_serve"],
	"BDR-02": ["s02_receive_both", "s02_receive_bot_only", "s02_receive_player_only", "s02_block_both", "s02_repeat_gate_player", "s02_repeat_gate_bot"],
	"BDR-03": ["s04_slowdown"], "BDR-04": ["s05_di_by_mode"], "BDR-05": ["s06_delivery_by_actor"],
	"BDR-06": ["s07_plant_timeline"], "BDR-07": ["s07_plant_timeline"], "BDR-08": ["s08_grounded_attack"], "BDR-09": ["s10_attack_volume"],
	"BDR-10": ["s13_recovery"], "BDR-11": ["s11_endlag"], "BDR-12": ["s14_exhausted_expiry"], "BDR-13": ["s09_match_scope"],
	"BDR-14": ["s16_auto_clock"], "BDR-15": ["s12_charge_senses"], "BDR-16": ["s15_custody"],
	"BDR-17": ["s03_ledger_table"], "BDR-18": ["s03_ledger_table"], "BDR-19": ["s19_left_handed_bot", "s20_seeded_rally"],
	"BDR-20": ["s13_recovery"],
}

static func near(a: Variant, b: float, eps: float = 1e-6) -> bool:
	return absf(float(a) - b) <= eps

static func pin(suite: Object, name: String, facts: Dictionary) -> bool:
	var callable := Callable(load("res://tests/support/bdr_pins.gd"), "pin_" + name)
	if not callable.is_valid(): return false
	callable.call(suite, facts)
	return true

# --- BDR-01 spend/publish order per caller -------------------------------------------------------------------------------------------
static func pin_s01_depleted_player(t: Object, f: Dictionary) -> void:
	var d: Dictionary = f.depleting.listener.at_receive_resolved
	t.check(d.winded and d.epoch == 1 and near(d.flow, 0.0) and near(d.stamina, 50.0), "BDR-01 player: a listener sees the post-depletion state (spend before publish)")
	t.check(f.depleting.post.winded and f.depleting.post.epoch == 1 and near(f.depleting.post.flow, 0.0), "BDR-01 player: depleting contact ends Winded with Flow 0 and no gain recorded")
	var c: Dictionary = f.control.listener.at_receive_resolved
	t.check(c.stamina < 100.0 and not c.winded and c.epoch == 0, "BDR-01 player control: the cost is already paid when the listener runs")
	t.check(f.control.post.flow > 0.0, "BDR-01 player control: the Flow gain is applied after the listener")
	t.check(f.depleting.events.size() == 1 and f.depleting.events[0].actor == "player", "BDR-01 player: a depleting contact still publishes")

static func pin_s01_depleted_bot(t: Object, f: Dictionary) -> void:
	var d: Dictionary = f.depleting.listener.at_receive_resolved
	t.check(d.winded and d.epoch == 1 and near(d.flow, 0.0), "BDR-01 bot (MS-16, G-01): a listener sees the post-depletion state (spend before publish)")
	t.check(f.depleting.post.winded and f.depleting.post.epoch == 1 and near(f.depleting.post.flow, 0.0), "BDR-01 bot: depleting contact ends Winded with Flow 0 and no gain recorded (as the player)")
	var c: Dictionary = f.control.listener.at_receive_resolved
	t.check(c.stamina < 100.0 and not c.winded and c.epoch == 0, "BDR-01 bot control: the cost is already paid when the listener runs")
	t.check(f.control.post.stamina < 100.0 and not near(f.control.post.flow, 50.0), "BDR-01 bot control: the Flow record follows the publish")
	t.check(f.depleting.events.size() == 1, "BDR-01 bot: a depleting contact still publishes")

static func pin_s01_depleted_pepper(t: Object, f: Dictionary) -> void:
	var d: Dictionary = f.depleting.listener.at_receive_resolved
	t.check(d.winded and d.epoch == 1 and near(d.flow, 0.0), "BDR-01 Pepper (MS-16, G-01): a listener sees the post-depletion state (spend before publish)")
	t.check(f.depleting.post.winded and f.depleting.post.epoch == 1 and near(f.depleting.post.flow, 0.0), "BDR-01 Pepper: depleting contact ends Winded with Flow 0 and no gain recorded")
	t.check(f.control.listener.at_receive_resolved.stamina < 100.0 and f.control.post.stamina < 100.0, "BDR-01 Pepper control: Stamina is spent before publishing")

static func pin_s01_depleted_serve(t: Object, f: Dictionary) -> void:
	var d: Dictionary = f.depleting.listener.at_moc
	t.check(d.winded and d.epoch == 1 and near(d.flow, 0.0) and f.depleting.listener.flow_recorded, "BDR-01 Serve: the spend precedes the publish (listeners see Winded) and Flow is recorded by the time MoC begins")
	t.check(f.control.listener.at_moc.stamina < 100.0 and f.control.listener.at_moc.epoch == 0, "BDR-01 Serve control: the cost is already paid at the listener")

# --- BDR-02 same-step order ------------------------------------------------------------------------------------------------------------
static func pin_s02_receive_both(t: Object, f: Dictionary) -> void:
	t.check(f.order == ["training_bot_0/action0", "player/action0"], "BDR-02: with both qualifying, the bot's contact runs first and the player's ordinary contact follows in the same step")
	t.check(f.side_contacts == [2, 0] and f.final_actor == "player" and f.bot_total == 1 and f.player_contacts == 1, "BDR-02: the double touch counts twice on one side and the player owns the ball")

static func pin_s02_receive_bot_only(t: Object, f: Dictionary) -> void:
	t.check(f.order == ["training_bot_0/action0"] and f.final_actor == "training_bot_0", "BDR-02: the bot qualifies alone")

static func pin_s02_receive_player_only(t: Object, f: Dictionary) -> void:
	t.check(f.order == ["player/action0"] and f.side_contacts == [1, 0], "BDR-02: the player qualifies alone")

static func pin_s02_block_both(t: Object, f: Dictionary) -> void:
	t.check(f.order == ["player/action3"] and f.bot_total == 0, "BDR-02: the swept player Block pre-empts the bot (the Block exception)")
	t.check(f.player_contacts == 0 and f.side_contacts == [0, 0] and f.final_kind == "block", "BDR-02/17: a Block is not a team touch")

static func pin_s02_repeat_gate_player(t: Object, f: Dictionary) -> void:
	t.check(f.events_after_attempt_0 == 1 and f.events_after_attempt_1 == 1 and f.events_after_attempt_2 == 2, "BDR-02: the player's repeat gate blocks a second ordinary contact within 0.22 s and opens after")

static func pin_s02_repeat_gate_bot(t: Object, f: Dictionary) -> void:
	t.check(f.after_0_total == 1 and f.after_1_total == 2, "BDR-02: court bots have no repeat gate (two contacts in consecutive steps)")

# --- BDR-03 slowdown --------------------------------------------------------------------------------------------------------------------
static func pin_s04_slowdown(t: Object, f: Dictionary) -> void:
	t.check(f.player.mode == 3 and f.player.enabled and near(f.player.steering_speed, 0.05), "BDR-03: the default MoC is Trajectory Steering at 0.05 steering speed")
	for caller in ["bot", "pepper"]:
		var h: Dictionary = f[caller]
		t.check(not h.active and near(h.ball_scale, 1.0) and h.acting_actor == "" and not h.steering_active and near(h.player_scale, 1.0), "BDR-03 %s (MS-17, G-04): the hit starts no slowdown, the ball and player stay at full speed" % caller)
	var c: Dictionary = f.serve
	t.check(c.active and c.ball_scale < 0.2 and not c.steering_active and not c.steer_changed_velocity and near(c.player_scale, 1.0), "BDR-03 serve: the player's Serve still slows the ball (G-04 changes bot and Pepper hits only)")
	t.check(f.serve.acting_actor == "player_serve", "BDR-03: the Serve starts the effect for its own actor")
	t.check(f.player.acting_actor == "player" and f.player.steering_active and f.player.steer_changed_velocity and near(f.player.player_scale, f.player.ball_scale), "BDR-03 player: the player's own hit can be steered and slows the player too")
	t.check(near(f.serve.ball_scale, 0.05), "BDR-03: the Serve window is at the steering speed after 50 ms")

# --- BDR-04 DI -----------------------------------------------------------------------------------------------------------------------------
static func pin_s05_di_by_mode(t: Object, f: Dictionary) -> void:
	for action in ["0", "1", "2", "3"]:
		t.check(f.steering_default.request[action] == [0.0, 0.0, 0.0], "BDR-04: action %s gets zero DI input in the default steering mode" % action)
	t.check(near(f.steering_default.set_yaw_degrees, 0.0), "BDR-04: a Set contact in steering mode has no DI yaw")
	for mode in ["slowdown_mode", "tuned_slowdown_mode", "moc_off", "mode_none"]:
		t.check(f[mode].request["0"] == [0.0, 0.0, 0.0] and f[mode].request["1"] == [1.0, 0.0, 0.0] and f[mode].request["2"] == [1.0, 0.0, 0.0], "BDR-04 %s: Set and Attack get live DI, Receive never" % mode)
		t.check(near(f[mode].set_yaw_degrees, -20.0), "BDR-04 %s: a Set contact turns by the DI yaw limit" % mode)

# --- BDR-05 receive delivery -------------------------------------------------------------------------------------------------------------
static func pin_s06_delivery_by_actor(t: Object, f: Dictionary) -> void:
	t.check(f.player.outgoing != f.bot.outgoing and f.bot.outgoing != f.pepper.outgoing and f.player.outgoing != f.pepper.outgoing, "BDR-05: three actor kinds, three delivery laws (different base passes for a clean Receive)")
	t.check(f.charge_does_not_set_receive_range and near(f.receive_net_distance, 5.0), "BDR-05: charge does not set the player's Receive distance; the net law gives 5.0 m")
	t.check(f.pepper.outgoing[2] > 0.0 and f.player.outgoing[2] < 0.0, "BDR-05: the Pepper partner passes back toward the player (+z) while the player passes toward the net (-z)")

# --- BDR-06/07 plant ---------------------------------------------------------------------------------------------------------------------------
static func pin_s07_plant_timeline(t: Object, f: Dictionary) -> void:
	t.check(near(f.duration, 0.85) and near(f.plant_ends_at_age, 0.85), "BDR-06: the plant (pose, hurtbox offset) lasts 0.85 s")
	t.check(near(f.contact_window, 0.55) and f.movement_lock_ends_at_plant_age < 0.6 and f.movement_lock_ends_at_plant_age >= 0.55, "BDR-06: the movement lock ends with the contact window (0.55 s), well before the plant")
	t.check(near(f.yaw_during_plant, f.plant_yaw), "BDR-06: the contact yaw is the plant's frozen yaw while it lasts")
	t.check(f.center_with_lean_zero == f.shape_center, "BDR-07 baseline: with no lean the platform centre is the shape centre")
	var lean: Array = f.lean_offset
	t.check(near(f.center_with_lean[0], f.shape_center[0] + lean[0]) and near(f.center_with_lean[1], f.shape_center[1] + lean[1]) and near(f.center_with_lean[2], f.shape_center[2] + lean[2]), "BDR-07: lean translates the platform centre")
	t.check(f.size_with_lean == f.size_plain, "BDR-07: lean leaves the extents unchanged")

# --- BDR-08 grounded attack ------------------------------------------------------------------------------------------------------------------
static func pin_s08_grounded_attack(t: Object, f: Dictionary) -> void:
	t.check(not f.jumped and f.can_contact_grounded and f.contacts == 1 and f.quality == "SWEET SPOT" and f.shot_kind == "attack" and f.still_grounded, "BDR-08: a grounded Attack is a legal contact and resolves a sweet spot")
	t.check(near(f.first_active_age, 0.325) and not f.expired_age_can_contact, "BDR-08: legality is by slice age (active at 0.325 s, expired past 0.45 s)")

# --- BDR-09 pose-dependent attack volume -----------------------------------------------------------------------------------------------
static func pin_s10_attack_volume(t: Object, f: Dictionary) -> void:
	t.check(near(f.idle_centres["2"][1], 1.3133060932) and near(f.leaned_centres["2"][1], 1.024029851) and near(f.leaned_centres["2"][0], 0.3902215064), "BDR-09: the player's Attack centre follows the live pose (1.3133 idle, 1.0240 at full plant lean)")
	for action in ["0", "1", "3"]:
		t.check(f.idle_centres[action] == f.leaned_centres[action], "BDR-09: action %s's volume ignores the pose edit" % action)
	t.check(f.released_attack_centre == f.idle_centres["2"] and near(f.radius, 0.7421991426), "BDR-09: the Attack centre returns when the pose is released; the radius is constant")
	t.check(f.bot_centre_unchanged_by_player_pose and not near(f.bot_attack_centre[1], f.idle_centres["2"][1], 1e-4), "BDR-09: the court bot's volume is measured separately and does not follow the player's pose")

# --- BDR-10/20 recovery ----------------------------------------------------------------------------------------------------------------------
static func pin_s13_recovery(t: Object, f: Dictionary) -> void:
	var b: Dictionary = f.blown_away
	t.check(b.floor_recovery_name == "blown_away" and b.floor_input_locked and b.floor_recovery_time == 0.0 and near(b.floor_recovery_lock, 1.107), "BDR-10: the player's recovery lock is written by animation code (blown_away: lock 1.107 s)")
	t.check(not near(b.player_velocity[2], 0.0), "BDR-10: the recovery velocity is written onto the player body by animation code")
	for quiet in ["clean", "bot_undercharged"]:
		t.check(f[quiet].floor_recovery_name == "" and not f[quiet].floor_input_locked and f[quiet].floor_recovery_time == -1.0, "BDR-10 %s: no lock written" % quiet)
	t.check(f.shrug_input_back_in_lab.outcome == "" and f.shrug_input_back_in_lab.floor_recovery_name == "", "BDR-20: the lab never produces a shrug (Receive DI input is zero), so the lock budget is unreachable in play")
	var s: Dictionary = f.shrug_event
	t.check(s.floor_recovery_name == "shrug" and near(s.lock, 0.25) and near(s.total, 0.7) and s.locked, "BDR-20: a shrug locks input for 0.25 s while the authored animation runs 0.7 s")

# --- BDR-11 endlag ---------------------------------------------------------------------------------------------------------------------------
static func pin_s11_endlag(t: Object, f: Dictionary) -> void:
	t.check(near(f.before, 0.0) and near(f.after_contact, 0.16) and f.can_contact_with_endlag_live, "BDR-11: a Receive writes endlag 0.16 and the next attempt is still legal while it is live")
	t.check(near(f.after_decay_0_05, 0.11) and near(f.after_decay_1_0, 0.0), "BDR-11: endlag decays at the Transition Speed rate")
	var writes := 0
	for use in f.uses:
		var line: String = use.substr(use.find(":") + 1)
		if line.contains("var action_endlag") or line.contains("action_endlag ="): writes += 1
		elif line.contains("maxf(lab.action_endlag"): writes += 1
	t.check(writes == f.uses.size() and f.uses.size() == 7, "BDR-11: every use in scripts/ is a declaration, an assignment or the decay (7), none gates (%d uses)" % f.uses.size())

# --- BDR-12 Exhausted expiry ---------------------------------------------------------------------------------------------------------------
static func pin_s14_exhausted_expiry(t: Object, f: Dictionary) -> void:
	t.check(f.epoch_delta == 1 and f.winded and not f.exhausted and near(f.flow_field, 0.0) and near(f.flow_amount, 0.0), "BDR-12: Exhausted expiry returns to Winded, clears Flow and bumps the epoch")
	t.check(near(f.stamina_after_expiry, 50.05) and near(f.max_stamina, 100.0), "BDR-12: Winded restarts at half Stamina")
	t.check(near(f.flow_values_after_poll, 0.0), "BDR-12: the Flow store follows through the lab's own poll")
	t.check(f.winded_depletion.exhausted and near(f.winded_depletion.flow, 0.0) and f.winded_depletion.epoch_delta == 1, "BDR-12: depleting while Winded enters Exhausted and clears Flow")
	t.check(f.bot_depletion.winded and near(f.bot_depletion.flow, 0.0) and f.bot_depletion.epoch == 1, "BDR-12: a bot's depletion zeroes the Flow store directly")
	t.check(f.second_wind_in_data, "BDR-12: Second Wind is +10 in the trait data")

# --- BDR-13 match scope ----------------------------------------------------------------------------------------------------------------------
static func pin_s09_match_scope(t: Object, f: Dictionary) -> void:
	for kind in ["serve", "attack"]:
		t.check(f[kind].manual_required and f[kind].all_contacts_required, "BDR-13: %s shots are matched in both modes" % kind)
	for kind in ["set", "receive", "block"]:
		t.check(not f[kind].manual_required and f[kind].all_contacts_required and f[kind].manual_status == "unrestricted", "BDR-13: %s shots are matched only when every contact must match" % kind)
	t.check(f.resolver_auto.required and f.resolver_auto.status == "undercharged" and not f.resolver_manual.required, "BDR-13: the resolver judges an Auto receive of a charged Set, and not a manual one")

# --- BDR-14 Auto clock ------------------------------------------------------------------------------------------------------------------------
static func pin_s16_auto_clock(t: Object, f: Dictionary) -> void:
	t.check(near(f.manual_moc_off.charge, 0.5 / 0.85) and near(f.auto_moc_off.auto_age, 0.5), "BDR-14: with no slowdown both clocks accrue 0.5 s")
	t.check(near(f.auto_moc_on.auto_age, 0.5) and near(f.auto_moc_on.auto_prepared, f.auto_moc_off.auto_prepared), "BDR-14: Auto preparation ticks on world time under a slowdown")
	t.check(f.manual_moc_on.charge < 0.1 and near(f.manual_moc_on.charge, f.manual_moc_off.charge * f.manual_moc_on.actor_scale), "BDR-14: manual charge ticks on the actor-scaled clock under a slowdown")

# --- BDR-15 event.charge ---------------------------------------------------------------------------------------------------------------------
static func pin_s12_charge_senses(t: Object, f: Dictionary) -> void:
	t.check(near(f.player_attack.event_charge, f.player_attack.locked_charge), "BDR-15: a player Attack event carries the input charge")
	t.check(near(f.player_receive_undercharged.event_charge, 0.4) and not near(f.player_receive_undercharged.ball_shot_charge, 0.4), "BDR-15: a player Receive event carries the input charge, not the delivered pressure")
	for caller in ["bot", "pepper", "serve"]:
		t.check(near(f[caller].event_charge, f[caller].ball_shot_charge) and f[caller].events == 1, "BDR-15: a %s event carries the delivered shot pressure" % caller)

# --- BDR-16 custody -------------------------------------------------------------------------------------------------------------------------
static func pin_s15_custody(t: Object, f: Dictionary) -> void:
	t.check(f.ground_balls_after_four_landings == 3 and f.cart_balls_before == f.cart_balls_after, "BDR-16: the fourth ground ball evicts the oldest and nothing returns to a cart")
	t.check(f.team_empty_callers == [], "BDR-16: team_empty has no caller")
	t.check(f.benched and f.inventory_held_while_benched, "BDR-16: the Bench keeps the held ball")
	t.check(f.max_stamina > 100.0 and near(f.stamina_after_station_complete, 100.0), "BDR-16: the Serve Receive reward caps Stamina at the literal 100, below the athlete's maximum")

# --- BDR-17/18 ledger ----------------------------------------------------------------------------------------------------------------------
static func pin_s03_ledger_table(t: Object, f: Dictionary) -> void:
	var r: Dictionary = f.player_receive
	t.check(r.post.contacts == 1 and r.post.side_contacts == [1, 0] and r.post.last_touch_side == 0 and r.events == 1, "BDR-17: a player Receive counts, renews the opponent and sets last touch")
	var b: Dictionary = f.player_block
	t.check(b.post.contacts == 1 and b.post.side_contacts == [2, 0] and b.post.last_touch_side == 0 and b.events == 1, "BDR-17: a Block is not a team touch but renews the opponent and sets last touch")
	var fourth: Dictionary = f.player_receive_fourth
	t.check(fourth.events == 0 and not fourth.post.ball_active and fourth.post.contacts == 4 and fourth.post.last_touch_side == -1, "BDR-17: counting precedes the fault check, and a fault publishes nothing")
	var bat: Dictionary = f.player_block_after_three
	t.check(bat.events == 1 and bat.post.ball_active and bat.post.contacts == 3 and bat.post.side_contacts == [3, 0], "BDR-17: a Block after three touches is not a fault")
	var bot: Dictionary = f.bot_receive
	t.check(bot.post.side_contacts == [1, 0] and bot.post.contacts == 0 and bot.post.bot_total == 1 and bot.post.last_touch_side == 0, "BDR-17: a bot counts its own side, resets the player's contact count and sets last touch")
	var bot_fourth: Dictionary = f.bot_fourth
	t.check(bot_fourth.events == 0 and not bot_fourth.post.ball_active and bot_fourth.post.side_contacts == [3, 0] and bot_fourth.post.bot_total == 0, "BDR-17: a bot checks side_contacts >= 3 before incrementing and faults with no contact")
	var pepper: Dictionary = f.pepper_receive
	t.check(pepper.events == 1 and pepper.post.last_touch_side == -1 and pepper.post.side_contacts == [0, 0] and pepper.post.contacts == 0, "BDR-18: a Pepper contact skips the rally ledger and resets the counters itself")

# --- BDR-19 ---------------------------------------------------------------------------------------------------------------------------------
static func pin_s19_left_handed_bot(t: Object, f: Dictionary) -> void:
	t.check(near(f.Right.player_attack_x, -f.Left.player_attack_x) and f.Right.player_attack_x > 0.0, "BDR-19: a left-handed player's Attack volume mirrors")
	t.check(near(f.Right.bot_attack_x, f.Left.bot_attack_x) and f.Left.bot_attack_x > 0.0, "BDR-19: the court bot's Attack volume does not mirror (dominant_sign 1)")
	t.check(near(f.Right.pepper_attack_x, f.Left.pepper_attack_x) and f.Left.pepper_attack_x > 0.0, "BDR-19: the Pepper partner's Attack volume does not mirror")

static func pin_s20_seeded_rally(t: Object, f: Dictionary) -> void:
	t.check(f.contacts == 3 and f.ledger[0][0] == 0 and f.ledger[1][0] == 1 and f.ledger[2][0] == 2, "BDR-19: a seeded rally completes receive, set and attack (seed 7)")

# --- INV-02 / INV-15 -------------------------------------------------------------------------------------------------------------------------
static func pin_s17_preview(t: Object, f: Dictionary) -> void:
	t.check(f.unchanged and f.differences.is_empty() and f.preview_has_content, "INV-02: previews spend nothing, publish nothing and draw no random numbers (%s)" % [f.differences])

static func pin_s18_bench_window(t: Object, f: Dictionary) -> void:
	t.check(f.benched and f.events == 0 and f.contacts_unchanged and not f.armed_after and not f.can_contact, "INV-15: Exhaustion in a live rally benches the player before the contact resolves")
