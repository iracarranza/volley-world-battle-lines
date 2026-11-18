# Register of declared, written, never enforced state

Migration stage MS-01. State that is written (or documented) but changes no outcome. The constitution rule: a write-only variable may not be cited as a rule in an explanation. Nothing here is deleted or enforced by the migration; enforcement is a gameplay change behind its own gate.

| State | Where it is written | Reader | Documented source | Evidence of absence | Gate |
|---|---|---|---|---|---|
| `action_endlag` | `contact_lab.gd` (`_emit_contact_impact` per-action values, serve 0.22, resets in `_reset` paths); `lab/athlete_motor.gd` (decay, floor) | `tests/stat_tuning_test.gd` only (pins the decay) | `docs/trait-master-list.md` and `docs/movement-morphology-handoff-review.md` ("Transition Speed controls endlag") | repo-wide search of `scripts/` finds no conditional read; dynamic access (`get("action_endlag")`) searched for in MS-01: none | G-10 (decided: enforced as lock data at defaults in MS-12; see BDR-11) |
| `ContactIntent.preview_velocity` | `contact_intent.gd` (`preview_velocity` key in the intent dictionary) | none | n/a | no reader in `scripts/` or `tests/` | none |
| `team_empty` | n/a (query function) in `ball_carts.gd`; stub in `ball_bin.gd` | only `tests/ball_inventory_test.gd` | `docs/ball-economy-rework-review.md` (cart-empty threat) | no caller in gameplay code | G-15 (economy backlog) |
| Winded-bar fatigue model | not implemented | n/a | `docs/ball-economy-rework-review.md` (Winded bar) | the timer model in `athlete.gd` is what runs | G-11 (decided: timer model governs) |

Absence-by-search has a limit: dynamic string access is not excluded by a grep for the identifier. Re-run the search before relying on any row.
