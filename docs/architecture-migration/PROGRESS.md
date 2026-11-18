# Architecture migration progress log

Branch `migration/architecture-ms00-14`, stages MS-00..MS-04 (group 1). Behaviour-preserving only: no gameplay constant, order or output changes. Godot 4.7.2, headless, `python3 tools/test.py`.

## Cleanups (before MS-00)

| Item | Commit | Evidence |
|---|---|---|
| Live-doc edits D-01..D-08, D-10..D-16 (study file 17) | a701d63 | docs only. D-09 skipped (needs the designer: tertiary set size). D-11, D-14, D-15: CURRENT-state notes only, rewrites wait for MS-12 / MS-17. D-17 is code (MS-21), not authorized. |
| `contact_zones_test` fixture scans the sweep from `Execution.SPIKE_WINDUP` (was a literal 0.4) | 55407cc | 60/60 checks pass; no shipped constant changed. |
| `tools/test.py` isolation (in the snapshot) | n/a | Verified: runs write nothing to `~/Library/Application Support/volley-checks`; HOME/XDG_DATA_HOME point at the temp dir. |

## MS-00 Baseline hygiene (no production code)

- Full suite on the branch at 55407cc: **155/155 passed**, 516 s (the study counted 154; the designer's WIP snapshot adds `action_timeline_test`).
- The study's five failures are classified: `contact_zones_test` stale fixture (fixed above); `six_step_completion_test`, `trait_book_test`, `trait_effect_editor_test` environment (unwritable `user://`; pass with the runner's isolated user dir); `trait_effect_cache_test` load-dependent timeout (not reproducing). All pass here.
- Slowest suites: `map_traversal_test` 100 s, `box_jump_routes_test` 40.6 s, `map_drills_test` 11.1 s, `prototype_test` 10.5 s, `station_approach_test` 9.5 s; all others under 7 s. Per-suite timings: `results.json` of the run (scratch `logs-ms00`).
- **Baseline for later stages: 155/155 (plus the new suites each stage adds).** Every suite may gate.
- Weak assertions to treat as not-a-pin (study): `spike_stage_test.gd:31`, `trait_book_test.gd:59`, `ball_inventory_test`.
- Doc reconciliations (blueprint MS-00 step 5): README MoC default, Second Wind and set-target figures done under D-01..D-16; `docs/fatigue-status.md:5` and `docs/net-response.md` constants not in the D list and left for the designer.

## MS-01 Governance documents (extract/doc only)

- Added `behavioural-divergence-register.md` (20 BDR entries, 20 defined FC facts, each entry with citation, status, pin placeholder and gate or none), `event-field-registry.md` (both senses of `event.charge`, no rename), `unenforced-state-register.md` (`action_endlag`, `preview_velocity`, `team_empty`, Winded-bar model), `vocabulary.md` (BallState vs LiveBall etc.).
- Lint: `tests/governance_docs_test.gd` 150/150 (every cited FC id defined, every entry has citation/status/pin/gate-or-none).
- Behaviour evidence: no code touched. Citations use file and symbol, not line numbers (lines drift).
- Deviation: BDR-19 (left-handed bots) cites no FC id (single-source item of the study's section 4).

## MS-02 Seed hooks (extract, additive)

- New `scripts/rng_seed.gd` (`seed_generators`): no base seed calls `randomize()` exactly as before; a base seed gives each generator `base + index`. Every seed used is logged (`RngSeed.used` and a stdout line).
- Hooked: `training_bots.gd` (random, aim, charge; `rng_seed`, `reseed()`), `pepper_partners.gd` (aim, charge; same), `transition_set_drill.gd` (target), `weighted_balancing.gd` (sway). `dominant_sign = 1` and the unseeded default are unchanged (G-19 not answered).
- Not hooked: `map_drills.gd` `spike_rng` and `serve_receive_station.gd` `rng` (never call `randomize()`; Godot seeds a new generator randomly). `title_rally_backdrop.gd` already uses a fixed seed 7. Left alone to keep default behaviour byte-identical.
- Tests: new `seed_hooks_test` 7/7 (default draws fresh seeds per session and logs them; same seed reproduces the three-contact bot rally ledger exactly; a different seed changes it; Pepper takes the hook). Existing `bot_aim`, `bot_generic_rally`, `bot_rally_motion`, `pepper_sequence`, `pepper_move_set`, `bot_interaction`, `drill_mechanics`, `drill_lab`, `map_drills`, `map_bot_rally`, `map_activities`, `serve_pepper` green.
- Deviation: the ledger test lowers bot aiming accuracy to 20 so that RNG draws are visible (default accuracy shows no scatter in this rally).

## MS-03 Settings instance, tuning index, ActionTable mirror, clock record

### MS-03a Shared settings instance and tuning index (extract)
- New `scripts/session_settings.gd`: one `shared` instance. `Execution.spike_windup_seconds/enabled` keep their names and now read and write through it (old reads and writes still resolve; the menu and tests are untouched). Process-wide semantics preserved (a static instance).
- `docs/architecture-migration/tuning-index.md` lists the shared timing constants (owner, unit, status); `tests/tuning_index_test.gd` checks every row against the code (and that a write on the shared instance is seen by `Execution`).
- Tests: `tuning_index_test`, `action_timeline`, `contact_execution`, `graduated_spike`, `spike_sweep_timing`, `spike_confirm`, `moc_spike_window`, `swing_lead_in`, `swing_clock`, `moc_menu`, `contact_zones`, `trajectory_preview` all green.
- `SWEET_CENTER` coupling to `swing_clock.gd` `PEAK` is recorded in the index as a cross-action constant.

### MS-03b ActionTable mirror and contract test (additive, before any consumer)
- New `scripts/action_table.gd`: read-only rows for Receive, Set, Attack, Block, read live (windup is a session setting). The Block row is a press pulse (`BlockResponse.PRESS_SECONDS`) with no age window, so its sweet fields are -1 (FC-12: a table built from `Execution` would invent one).
- `tests/action_table_test.gd` (28/28) samples `ContactResolver.assess` across confirmation ages 0-0.62 s for each action at windup 0.25 and 0.4, and checks that the resolver's live and sweet windows equal the row; Block: sweet at pulse 0, not at `PRESS_SECONDS`, never rescue. Observed windows: Receive 0.12-0.44 sweet, Set 0.155-0.335 sweet, Attack windup 0.25 + sweep 0.20.

### MS-03c Consumers migrate to the table (extract, parity per consumer)
- `action_timeline.gd` regions and windup, `trajectory_preview.gd` ideal age, `training_bots.gd` and `pepper_partners.gd` live-window ends now read `ActionTable.row()`. Same values by construction (the row reads `Execution`) and by `action_table_test`.
- Tests: `action_timeline`, `trajectory_preview`, `bot_interaction`, `bot_generic_rally`, `bot_rally_motion`, `bot_intended_charge`, `pepper_sequence`, `pepper_move_set`, `bot_self_set_block`, `bot_block_fallback`, `serve_pepper`, `action_table` green.
- Deviation (scope): not migrated, still reading `Execution` directly: bot and Pepper `sweet_active` (the row has no per-age predicate), `contact_lab.gd` hurtbox visual phases and `confirm_window`, `spike_stage.gd` and `swing_clock.gd` (pose timing owned by the animation/serve laws), `receive_response.gd` (resolver internals), `lab/moc_menu.gd` (edits the knob). `hurtbox_view.gd` does not exist in this tree. The drift guard for these is `action_table_test` + `tuning_index_test`.

### MS-03d Per-step clock record
- New `scripts/step_clock.gd` (immutable: world time is the unscaled physics dt; `ball()`, `actor(id)`, `bot(id)`, `real_now()`) and `MomentOfContact.clock_record()`, the only place `_effect_scale()` is turned into scales. `simulation_scale()/actor_scale()/bot_scale()` stay as thin wrappers (tests and tools keep using them).
- Design note: a record is created at the moment a reader used to ask MoC for a scale, not once at step start. A single start-of-step record would change behaviour (a contact mid-step starts MoC and later readers in the same step see the new scale today). The Auto-vs-manual difference stays as two declared domains (FC-29): Auto ticks on `world_dt`, manual charge on `actor`; Flow decay stays on world time. `real_now` is exposed but the existing real-time readers (camera frame dt, DI sampling, steering) stay on `Time` (declared real-time exceptions; routing them via the injectable MoC clock would change test-time behaviour).
- Tests: `step_clock_test` (every mode x ball/actor toggle: record equals the pre-record formula, wrappers read the record, immutability), `moc_bot_clock`, `moc_slowdown`, `moc_steering`, `moc_modes`, `moc`, `moc_charge_ground` green.

### MS-03e..g Scale readers migrate one module at a time
- contact_lab (3 readers), court bots + bot_return + map_bot_roster, Pepper + ground_ball now call `moc.clock_record()`. Direct readers of `actor_scale(`/`simulation_scale(`/`bot_scale(` outside `moment_of_contact.gd`: 14 before, 0 now (pinned by `step_clock_test`).
- Per-module tests green: auto_charge, moc_* (bot_clock, slowdown, steering, modes, charge_ground), confirmation_movement, block_contact_regression, bot_* rally/return/move suites, map_bot_*, pepper_*, serve_pepper, ball_inventory, drill_mechanics.
- MS-03 exit: mirror contract test green for all four actions; one settings instance; clock readers migrated; windup edit seen by collision, animation, preview, bots, timeline (`action_timeline_test`, `tuning_index_test`, `action_table_test`). No behaviour diff beyond the full-suite result recorded at the end.

## MS-04 Event/evidence contract and consumer order (docs and tests only)
- `event-schema.md`: 32-field schema per actor kind, the seven-step consumer order, order-sensitive pairs, idempotence by id, `event.charge` reader audit (one reader: the MoC `charge_duration` fallback; no rename made).
- `tests/event_contract_test.gd` 28/28: documented fields exist (no more, no fewer) for player, bot, Pepper and Serve events; `receive_resolved` fires before the Flow record, Flow before MoC begin; the written order of `_publish_impact` equals the documented list; a duplicate event is idempotent.
- Existing `contact_flow`, `moc`, `receive_response`, `impact_visual`, `cleanup_contracts`, `directional_influence` green. No production code touched.
- Deviation: animation vs Flow order is pinned by the source-order check only (no observable hook between them).

## MS-05 Characterization harness (tests and tools only; no production file changed)

Commits: MS-05a `60a79de` (catalogue, recorder, comparator, goldens, tools), MS-05b `a09dd69` (pins, shards, coverage lint, register), MS-05c `f90b9d6` (writer ratchet, scheduler order trace). `git diff 61deabe HEAD -- scripts project.godot` is empty.

- **Scenario catalogue** (`tests/support/scenarios.gd`): 28 scenarios covering S-01..S-20 (S-01 for player, bot, Pepper, Serve each with a depleting and a control contact; S-02 as six variants incl. both repeat gates; S-03 as a seven-case ledger table; S-04 for four callers). Each builds a fresh session, injects the MoC clock, seeds bots and Pepper (`reseed(1234)`, rally seed 7), and returns a consequence-ledger trace plus named facts.
- **Consequence ledger** (`recorder.gd`, `characterization.gd`): ordered snapshots of ball position/velocity, shot metadata, Stamina, HP, Flow (field and store), fatigue epoch, rally counters, last touch, locks, endlag and MoC scale, plus the published event log. Read-only.
- **Dual-run comparator**: inside each shard (two fresh runs must agree, then the first must equal the golden, 1e-9) and `tools/dual_run.py BASE [CHANGED|WORKTREE]` (two builds, same harness overlaid, traces diffed). Evidence: `dual_run.py 61deabe WORKTREE` = 28 scenarios, 0 differences (traces produced in separate processes also equal the goldens, so the traces are process-stable).
- **Goldens**: `tests/golden/*.json` (28 + `writer_ratchet.json`, about 0.7 MB), recorded from the unmodified MS-04 head. Regeneration only through `tools/regen_golden.py` per `tests/golden/README.md` (refactor stages must not regenerate).
- **BDR pins**: `tests/support/bdr_pins.gd`, one function per scenario, run by `characterization_catalogue_{a,b,c}_test` (sharded to stay under the 120 s per-suite timeout; about 40 s each). `characterization_coverage_test` lints that all 20 BDR entries have pin functions and that the register rows name them (placeholders removed). Also pinned: INV-02 preview non-consumption (S-17), INV-15 Bench in the confirm window (S-18), seed reproducibility (S-20, plus dual-run itself).
- **Writer ratchet** (`writer_ratchet_test`): write-line patterns for `ball_velocity`, `ball.position`, `ball_shot`, `ball_active`, `side_contacts`, `contacts`, last touch, per file with counts, baseline `tests/golden/writer_ratchet.json`. Fails when a new file appears or a count grows (verified with a temporary extra writer file), notes shrinkage so the baseline can be tightened. Baseline `ball_velocity` equals the FC-05 file set exactly (10 files plus `bot_pads.gd`; 28 + 3 lines); `ball_active` is the study's 7 files.
- **Scheduler one-tick trace** (`scheduler_order_test`, 39 checks): first-token order of `_physics_process` and `_tick_ball` and the `map_lab`/`drill_lab` re-entry of `super._physics_process`. Runtime order evidence is S-02.
- **Flakiness**: the six new suites run three times: normalized output byte-identical in all three (RNG seed log lines of unseeded sessions excluded; they are the MS-02 log, not trace data).

- **Full suite** (`python3 tools/test.py --logs <scratch>/logs-ms05` at `f90b9d6`): **167/167 passed** (161 + 6 new: three catalogue shards, coverage lint, writer ratchet, scheduler order). No suite deleted or loosened.

### Observations from pinning (CURRENT behaviour, nothing changed)
- BDR-01 now VER for all four callers: player and Serve show post-depletion state to listeners; bots and Pepper show pre-depletion state (and bots end Winded, Flow 0, `pending_attacks` cleared).
- FC-05 undercounts `side_contacts` writers: `lab.side_contacts.assign([0, 0])` (not caught by the study's `=`/`+=`/`-=`/`fill` pattern) is also written by `balance_ball_setting.gd`, `map_drills.gd`, `transition_set_drill.gd`. The ratchet baseline has 8 files for `side_contacts`, not the study's 5. For the designer's information only; MS-06 will route all of them.
- Receive DI input is zero in `contact_request` for action 0, and `ReceiveOutcome.assess` reads that same input, so the `shrug` outcome (corrective back input) cannot occur in the lab: the 0.25 s shrug budget versus the 0.7 s animation (BDR-20) is pinned through a synthetic event to the animation only. A designer-visible side of FC-28.
- Pepper's and bots' receive outputs in the fixture are low-charge (bot prepared charge is accumulated by the bot, not forced); the pins use each caller against its own control, as probe A did.
- S-04 serve and Pepper: Pepper slowdown is now VER (the study had it SRC only): scale 0.05 after 50 ms, not steerable.

### Not pinnable headlessly, or pinned only in part
- BDR-02 tunnelling at play speeds (30/60/120 Hz sweep): not pinned (study: INCONCLUSIVE); only order and gate asymmetry are. Needs a frame-rate sweep with realistic ball speeds, a design decision about what counts as a defect.
- BDR-09 Pepper's per-call re-measure of the Attack volume and the player/bot/Pepper shoulder disagreement: the player-versus-bot difference is pinned (values differ, bot cached); Pepper's rig is a separate rig and its value is in the golden only.
- BDR-10 recovery velocity is pinned for `blown_away` only; the other recoveries (knee, fall_roll, fall_slide, knocked_away, collapse) are covered by `floor_recovery_*` suites already in the baseline.
- BDR-14 under real-time frame variation is not pinned (the MoC clock is injected, per the declared real-time exception).
- BDR-16 `team_empty`, 3-ball eviction and the 100 cap are pinned; "Bench keeps inventory" is pinned through `bench.enter` with a held ball.
- Animation-versus-Flow order inside `_publish_impact` (MS-04 deviation) is still a source-order check; the scheduler trace is source-order plus runtime S-02.

### Deviations
- Pin functions live in one support file run by the catalogue shards instead of one test file per BDR entry, to keep the sessions count inside the suite timeout; the register names the function and shard for every entry.
- The ratchet allows shrinkage silently (a printed note) rather than failing on it, so a routing stage can land before the baseline is tightened in the same commit; tightening is `tools/regen_golden.py --ratchet-only`.

## Final full suite (MS-00..MS-04, branch head)
`python3 tools/test.py --logs <scratch>/logs-ms04`: **161/161 passed** (155 baseline + 6 new: governance_docs, seed_hooks, tuning_index, action_table, step_clock, event_contract). Matches the MS-00 baseline plus the new suites; no suite deleted or loosened.

## For the designer
- D-09 (tertiary set size in `docs/laning-and-objectives.md`) skipped: depends on how "Tertiary unchanged" is read.
- D-17 / MS-21 (Serve Receive Stamina cap) and all CHANGE stages MS-16..MS-21 untouched.
- `docs/fatigue-status.md:5` and `docs/net-response.md` constants (MS-00 step 5) not edited: not in the D list.

## MS-06 Rally ledger and court context (extract)

Commits: MS-06a `6f65888` (ledger module; player path, net crossing, publish renewal, rally begin), MS-06b `12d8992` (bots), MS-06c `4707467` (Pepper, serve, station, drills, Setup, Transition, lab resets; ratchet tightened).
- New `scripts/rally_ledger.gd` (static operations over the lab: `count_player_touch`, `player_fault`, `record_player_touch`, `bot_at_limit`, `count_bot_touch`, `clear_personal`, `renew_opponent`, `reset_on_crossing`, `clear_all`, `begin_rally`). State stays on the lab and `rally_rules`; values and order unchanged. `rally_rules.gd` untouched.
- Ratchet: `contacts` and `side_contacts` writers are now none outside the ledger (declared operation owner, `OPERATION_OWNERS` in `writer_ratchet_test`); `last_touch` only `rally_rules.gd` itself. Test `rally_ledger_test` (16 checks): sequence table (block, receive, set, attack, fourth-touch fault, opponent renewal, crossing), reset scope per caller.
- `event_contract_test` source-order token updated to the renamed publish step (same position).
- Evidence: dual run after each commit 0 differences (28 scenarios), catalogue shards, `rally_rules`, `block_*`, `bot_*`, `net_response`, `map_court_play`, `pepper_*`, drill and station suites green.

## MS-07 ContactCommit and LiveBall operations (extract)

Commits: MS-07a `0261b0d` (LiveBall, ContactCommit, player), 07b `845bda1` (bots), 07c `d4751a8` (Pepper), 07d `ba5707a` (Serve, partial; commit test), 07e `b7be710` (steering, integrate, net step; ratchet tightened).
- `scripts/contact_commit.gd`: `outgoing_shot` (shot build, Flow decoration, attack consumption; the shot is written once) and `run(lab, policy, steps)` with sequence [spend if before_publish] prepare, publish, present [spend if after_publish], counter reset, settle. Policies hold TODAY'S values: PLAYER and SERVE `before_publish`, BOT and PEPPER `after_publish`; counter reset NONE / NONE / PERSONAL / BOTH. Two policy fields (cap five, tested). G-01 stays CURRENT: MS-16 flips `spend_position` for bots and Pepper in one commit.
- `scripts/live_ball.gd` (distinct from `contact/ball_state.gd`): `commit_contact`, `commit_shot`, `integrate`, `commit_step`, `steer` (MoC trajectory steering stays driven from the render-rate path, the declared real-time exception).
- Order notes (no behaviour change): the bot and Pepper counter reset now runs right after the spend instead of after the bookkeeping lines that follow it (total_contacts, trail clear, `last_delivery`); none of those read the counters. The player's cost computation moved inside the spend step but still runs first. `attack_charge` still reads the incoming `ball_shot` because the shot is written after it is built.
- Tests: `contact_commit_test` (15: order per policy, cap, reset scope, every caller routes through `run`), plus prototype, contact_flow, moc_*, block_contact_regression, impact_visual, exploration_rally, serve_modes_moc, bot_* and pepper_* suites; scheduler-order and event-contract tokens updated to the renamed calls.
- Evidence: dual run 0 differences after each sub-step (28 scenarios, goldens untouched).
- Deviations: (1) cutover by dual run against the pre-stage commit instead of an in-process test-only flag (the flag would need both paths alive in one build; the dual run compares builds directly, and every sub-step was a separate commit that can be reverted per caller). (2) Only `spend_position` and `counter_reset` are policy fields; contact-memory reset style (cosmetic) stays in the callers. (3) Callers pass steps as callables (lambdas capture locals by value in GDScript, so nothing captured is reassigned after creation).

## MS-08 Lease, hook contract, custody (extract)

Commits: MS-08a `8506283` (S-21 scenario and golden, recorded before routing), 08b+c `81beb76` (lease; Transition Set), 08d `046c377` (Balance Ball), 08e `269f0c5` (Spike Trainer), 08f `2931269` (Serve Machine), 08g `8ff79d9` (serve/Bench/lab releases), custody and docs in the closing commit.
- `ball_lease.gd` (holder from the activities' own hooks, ledger-access term replacing the repeated three-way guard in `contact_lab.gd`), hook contract constants, `ball_custody.gd` (read-only census, three registered leaks reproduced), paper trace in `ball-lease.md` (written first).
- New scenario S-21 `s21_activity_feeds` (balance ball, transition set, spike load, serve machine toss and strike from dirty counters); the golden was recorded from the pre-routing head and the dual run stayed at 0 differences through every routing commit (29 scenarios from this point).
- Tests: `ball_lease_test` (14), `ball_custody_test` (7); drill_lab, drill_mechanics, map_drills, spike_trainer, box_jump_routes, setup_distributor, ball_inventory, station_approach, serve_receive_*, map_activities green.
- Ratchet now: `ball_active` contact_lab 1, interactive_serve 1; `ball_velocity` bot_pads 3, contact_lab 3, interactive_serve 4, map_bot_roster 1, pepper 4, training_bots 4; `ball_shot` contact_lab 2, interactive_serve 5; `ball_position` ball_carts, bot_pads, contact_lab 6, interactive_serve 3, pepper 1, setup_rack, training_bots 1.
- Residual writers outside the new operations (declared, listed in `ball-lease.md`): Serve's own toss and strike (SADR-16), lab debug feed and landing and swept contact placement, player/bot/Pepper pre-resolver velocity shaping (SADR-03), bot-setter delivery velocity, pad ball, cart and rack meshes. The exit criterion "every activity ball write maps to commit, integrate, steer or lease" holds for the four activities and the Bench; Serve and the debug feed remain exceptions.
- Not done here (not authorized): eviction refund, cart-empty threat, cap fix, G-15 economy changes.

## Final full suite (MS-06..MS-08, head 370e212)
`python3 tools/test.py --logs <scratch>/logs-ms08`: **171/171 passed** (167 + rally_ledger, contact_commit, ball_lease, ball_custody). `tools/dual_run.py d6d2373 WORKTREE` (MS-05 head vs head): 29 scenarios, 0 differences. No stage stopped.

## MS-09 Athlete mutators and one Flow store (extract)

Commits: MS-09a `19cc69f` (mutators; Stamina and HP writers), 09b `9504158` (Flow writes, modifier adds), 09c `1a65025` (Flow direction pinned, ratchet).
- `athlete.gd` gains `restore(amount, cap)`, `add_stamina`, `heal`, `refill`, `award_flow`, `set_flow`, `lose_flow`, `add_modifier` beside the existing `spend`, `spend_resolved`, `recover`. Every outside write of `.stamina`, `.hp`, `athlete.flow` in `scripts/` now goes through them (map_drills, map_activities, serve_receive_station, contact_flow, contact_lab reset, bot_vitals). The Serve Receive reward keeps its literal cap through `restore(15, 100.0)` (G-15 stays for MS-21).
- Flow store direction (PRB-13): `athlete.flow` is the authoritative cell for the player (`amount("player")` reads it); `values["player"]` is a write-only shadow, kept because the characterization trace records the `values` dictionary and removing the entry would change goldens. Pinned in `athlete_mutator_test`. `fatigue_epoch` polling stays in `ContactFlow` (coherence C5).
- Tests: `athlete_mutator_test` (every row of the status machine including Exhausted expiry clearing Flow, caps, the source lint). Ratchet: new `athlete_vitals` category at zero (athlete.gd is a declared owner).
- Deviation: no event replaced epoch polling; the `values["player"]` shadow was not removed (trace parity).

## MS-10 Player lifecycle record, Bench cancel(), locks facade (extract)

Commits: MS-10a `9e1741c`/`9ebb02e` (table doc, data, derived phase, `PlayerLocks`), 10b `27bb986` (lab and motor writers), 10c `d342b90` (drills, station, serve), 10d `3d054a6` (Bench `cancel()`, ratchet), 10e `16a20c5` (lock readers through the facade).
- `docs/architecture-migration/player-lifecycle.md` (table of CURRENT legality), `scripts/player_lifecycle.gd` (`TABLE`, `legal`, derived `phase`, `arm`, `disarm`, `set_window`, `cancel`), `scripts/player_locks.gd` (read-only: `input_locked`, `recovering`, `recovery`). `armed` and `confirm_window` have no writers outside the operations (new `lifecycle_fields` ratchet category at zero); fields stay on the lab so tests keep reading them.
- Bench entry calls `cancel()`; `player_lifecycle_test` runs the old hand-written sequence and `cancel()` on the same dirty lab and compares 25 fields (PRB-15), and checks that Bench, rally end and a lab reset clear `armed` and the window.
- Found by the dual run: the S-11 scenario scans source for readers of `action_endlag`; the derived phase therefore does not read it (it gates nothing).
- Deviations: step 3 (store the enum, derive the flags) NOT done: the legacy flags carry combinations the enum cannot represent (armed inside an open window, a charge during a lock), so it cannot be shown behaviour-identical from the traces; the accessor stage is the declared stable intermediate. Step 5 (bot phase strings on paper) is in the doc table notes. Step 6: the facade exists and the two input-lock readers use it; the animation controller itself still reads its own fields.

## MS-11 Scheduler as numbered order, layering lint (extract)

Commits: MS-11a `03d8839` (`scripts/tick_order.gd`), 11b `970d3ab` (stages), 11c `abea7c6` (layering lint).
- `tick_order.gd` lists ten numbered stages (pause gate, clock, pre-motion, bench gate, player, activities, ball or feed, idle actors, confirm window, present) with first tokens and the line budgets (contact_lab 1600, map_lab 260, drill_lab 60; orchestrator 30 lines). `LabSession._physics_process` is now a list of calls to `_tick_*` stage functions laid out in numbered order; no statement was reordered. `scheduler_order_test` pins the call order against the list, each stage's token order, the layout and the budgets; the old whole-step token check still passes unchanged.
- `layering_test`: layer table (pure rules, state, orchestration, presentation), upward preloads fail; 7 existing upward references (orchestrators naming `athlete_pose`, `impact_visual`, `bot_animation`) are registered and may only shrink.
- Not done: `_tick_ball` stays one function (pinned by the BALL token list; many early returns and shared locals); step 4 (session profiles) skipped as the blueprint allows (no initialization-order characterization test exists). Dual run for 11a was folded into 11b (11a adds an unreferenced data file).

## Final full suite (MS-09..MS-11)
`python3 tools/test.py`: **174/174 passed** (171 + athlete_mutator, player_lifecycle, layering). `tools/dual_run.py b327fe7 WORKTREE`: 29 scenarios, 0 differences. Goldens and BDR pins unchanged; the writer ratchet only gained zero-baseline categories (`athlete_vitals`, `lifecycle_fields`). MS-16..MS-21 untouched; no constant or ordering changed.
