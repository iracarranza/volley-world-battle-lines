# Ball lease, hook contract and custody (MS-08, written before the code)

CURRENT behaviour only. The lease changes no value and no order; G-15 (economy rules) and the cap fix (MS-21) are not in this stage.

## Write trace of the live ball by activity (what maps to which operation)

| Writer | Writes | Operation now |
|---|---|---|
| Transition Set, Balance Ball Setting (extends it) | feed: position, velocity, shot, active; basket step: position and velocity; stops | `LiveBall.launch`, `commit_step`, `release` (MS-08c, d) |
| Spike Trainer (`map_drills.gd`) | spike load (position, zero velocity, empty shot, active), parked-ball restore, stops | `launch`, `place`, `release` (MS-08e) |
| Serve Machine (`serve_receive_station.gd`) | toss, strike feed, stops | `launch`, `release` (MS-08f) |
| Player serve (`interactive_serve.gd`) | toss, hold, strike velocity and shot, cancels | cancels use `release` (MS-08g); the toss, hold and strike writes stay (see residual) |
| Court bots, Pepper | pre-resolver velocity shaping, contact placement | commit through `LiveBall.commit_contact` (MS-07); shaping stays in the providers (SADR-03) |
| `contact_lab.gd` | flight, net, contact, swept contact point, landing, debug feed, reset | `integrate`, `commit_step`, `commit_contact`, `release`; the rest residual |
| `moment_of_contact.gd` | trajectory steering | `LiveBall.steer` (real-time exception, SADR-11) |
| Bench (`bench_status.gd`) | drops the live ball | `release` |

## Lease terms (CURRENT)
Holder = whichever of `station.running()`, `drills.running()`, `pepper.active()` is true (`BallLease.holder`). Ledger access NONE for every holder: no counter, renewal or last-touch change from a held ball's contacts (`BallLease.ledger_open`, the old three-way guard spelled once). Pepper resets its own and the lab's counters at start and at each contact (policy `counter_reset: both`). Per-frame position writes: a drill that returns true from `holding_ball()` owns the ball position (`drills.holding_ball()` short-circuits `_tick_ball`).

## Hook contract (`ball_lease.gd`, checked by `tests/ball_lease_test.gd`)
Drill slot: `running, holding_ball, on_contact, sweep_ball, tick_setup, in_zone`; optional (called behind `has_method`): `drill_input, drill_motion, terrain_motion, apply_drill_pose`. Station: `running, on_contact, tick_setup, in_zone`. Pepper: `active`. Every activity in the Drill Lab row and the station implements its surface.

## Custody (`ball_custody.gd`, `tests/ball_custody_test.gd`)
Read-only census (carts, hand, live, ground) with conservation across cart, hand, live and ground, and the registered leaks reproduced: ground eviction (the fourth loose ball is dropped, no cart return), the Bench keeps the held ball, `team_empty` has no reader.

## Residual writers (declared exceptions, not routed here)
`interactive_serve.gd` (toss, hold and strike: Serve builds its own velocity and shot, SADR-16), `contact_lab.gd` (debug feed, swept contact point placement, landing placement, player pre-resolver velocity), `training_bots.gd` and `pepper_partners.gd` (pre-resolver velocity shaping and the contact point), `map_bot_roster.gd` (delivery velocity solved for a bot setter), `bot_pads.gd` (its own pad ball), `ball_carts.gd` and `setup_rack.gd` (cart and rack ball meshes, not the live ball). Baseline: `tests/golden/writer_ratchet.json`.
