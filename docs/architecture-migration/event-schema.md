# Contact event schema, consumer order and `event.charge` audit

Migration stage MS-04. Documents the contract as it is today; changes no field, no value and no order. Enforced by `tests/event_contract_test.gd`.

## 1. Fields (`ContactEvent.publish()`, a recursively read-only snapshot)

Every published event carries all 32 fields, for every actor kind. Actor kinds: player (`actor` = `player`), court bot (`training_bot_N`), Pepper partner (`pepper_N`), Serve (`player_serve`). The id is `actor:serial` (`_contact_event_serial`).

| Field | Meaning | Differs by actor kind |
|---|---|---|
| id, actor, team, action | identity; `action` 0 Receive, 1 Set, 2 Attack, 3 Block, 4 Serve | team: player and Serve from the player's side; bots from `slot_away`; others from the ball side |
| charge | see section 4 | player: input charge; bots, Pepper, Serve: delivered pressure |
| point, incoming_velocity, outgoing_velocity, simulation_time | contact point and ball velocities, lab time | no |
| incoming_shot, outgoing_shot | shot metadata dictionaries (`BallState` builder) | no |
| physical_hit, zone, quality, sweet, rescue, confirmation_age | resolver assessment summary | Serve is not resolved: defaults (`physical_hit` false unless supplied, zone "", quality 0.75) |
| mechanics, gameplay, steering, block_response, receive_response, charge_match, receive_outcome, posture | resolver evidence | empty for Serve and when the assessment lacks them |
| recovery, recovery_seconds, recovery_penalty_seconds, platform_band, platform_coord | receive recovery evidence | mostly Receive |
| intent, directional_influence | committed intent and DI evidence | player only; `{}` for the others |

MoC adds nine fields to the copy carried by `impact_started` (`moc_mode`, `velocity_duration_seconds`, `sweet_duration_seconds`, `duration_extension_seconds`, `contact_duration_seconds`, `duration_seconds`, `incoming_speed`, `outgoing_speed`, `velocity_change`); they are not part of the published event.

## 2. Consumer order of `_publish_impact` (CURRENT, shared by player, Serve, bots and Pepper)

1. timeline `contact(event)` (player events only act)
2. ledger renewal and `rally_rules.touch`, skipped when a station, drills or Pepper is running (opponent allowance reset, own counter reset when the toucher is not the player's side)
3. `clear_net_responses()`, net bounce flag reset, net `clear_side`
4. `receive_resolved` (Receive only; the player sets `receive_plant.contacted` first)
5. `animation.on_contact(event)`
6. `contact_flow.record(event)`
7. `moc.begin(event)`

Only the spend position differs by caller: player and Serve spend Stamina before step 1, bots and Pepper after step 7 (BDR-01, `spend_position` in MS-07).

Order-sensitive pairs:
- spend vs `record`: Flow `record` zeroes the gain when the fatigue epoch changed (player: spent first; bots: record sees pre-spend state).
- ledger renewal (2) before net clearing (3) and before the ball clears the net (source comment in `_publish_impact`); reordering breaks the block-then-receive scenario.
- Flow's DI HP spend (inside `record`, step 6) before steering's HP read (`moc.begin`/`steer`, step 7).
- `receive_resolved` (4) before animation (5): the recovery application reads the event; and before Flow (6): listeners see pre-record Flow state (probe A).

Moving Flow before animation or `receive_resolved` is a behaviour change and out of scope.

## 3. Idempotence by id

`ContactFlow.record` keeps the last 128 ids and ignores a repeat; `MomentOfContact.begin` keeps the last 64 and ignores a repeat. Timeline, ledger renewal and animation are not guarded by id (a duplicate publish repeats them; harmless today because they are idempotent in effect). Tested: a duplicate publish neither restarts MoC nor changes Flow.

## 4. `event.charge` reader audit (SADR-30)

Set by: `contact_lab.gd` `_emit_contact_impact` (`locked_charge`, input charge) and `_impact_event` (`ball_shot.charge`, delivered pressure). Readers of the published `event["charge"]` in `scripts/`: exactly one, `moment_of_contact.gd` `charge_duration`, which uses it only as the fallback when the shot dictionary has no `charge` (`shot.get("charge", event.get("charge", ...))`). No reader in Flow, animation, timeline, impact visuals, HUD or bots (bot and Pepper pose code read their own `context["charge"]` dictionaries, unrelated). `tests/render_contact_motion.gd` builds its own event dictionaries. So a rename or an additive `input_charge`/`delivered_pressure` pair would affect at most that fallback; no rename is made here (PRB-14 satisfied for the audit; the change itself stays a separate commit).
