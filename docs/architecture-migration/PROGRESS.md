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
