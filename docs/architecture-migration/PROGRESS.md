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
