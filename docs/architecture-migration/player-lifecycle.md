# Player lifecycle table (MS-10)

Records where the player's action is TODAY. Nothing here is a design; every row is a fact of the current code (G-06, G-07: the table records CURRENT).
The code form is `scripts/player_lifecycle.gd` (`TABLE`, `legal`, `phase`) and is pinned by `tests/player_lifecycle_test.gd`.

| Phase | Derived from (first match wins) | Reached from | Leaves to |
| --- | --- | --- | --- |
| CONFIRMED | `confirm_window > 0` | PREPARED (confirm click), IDLE (swept Block bypasses `_can_contact`, FC-04) | CONTACTED, MISSED, IDLE (cancel) |
| PREPARED | `armed` | CHARGING (release), IDLE (dive, passive Block, jump with a charge), RECOVERY | CONFIRMED, IDLE, RECOVERY |
| CHARGING | `charging` | IDLE (press), RECOVERY | PREPARED, IDLE |
| RECOVERY | `action_endlag > 0` or a roll/dive/floor recovery | CONTACTED, MISSED, locks | IDLE, CHARGING, PREPARED |
| IDLE | none of the above | any cancel | CHARGING, PREPARED, CONFIRMED |
| CONTACTED, MISSED | transient inside the confirm step (`_contact`, the miss branch of the window decay); never observed between ticks | CONFIRMED | IDLE, RECOVERY |

Facts the table keeps as they are
- A grounded Attack is legal by age (FC-14): a named rescue spike.
- The receive plant is two things: a 0.85 s timeline and a movement lock of at most the 0.55 s window (FC-13). The table does not merge them.
- The swept Block bypasses `_can_contact` (FC-04); the Block has a passive field (`block_state`) without a confirm window.
- Bench is entered before the receive resolves (INV-15).
- Bot phase strings map onto the same names on paper only; bots keep their own lifecycle (bot unification is deferred, SADR-06):
  `idle`->IDLE, a prepared jump or approach->PREPARED, a swing in the window->CONFIRMED, `recover`/dive recovery->RECOVERY.

Writers
- `armed` and `confirm_window` are written only by `PlayerLifecycle.arm/disarm/set_window`; the fields stay on the lab (accessor stage), tests keep reading them.
- Bench entry calls `PlayerLifecycle.cancel(lab)` (the old 28-field reset, same order; `tests/player_lifecycle_test.gd` checks the field sets are equal).
- Locks: `PlayerLocks` (read-only facade; the locks themselves stay in the animation controller until MS-12).

Not done here
- Storing the phase enum and deriving the legacy flags from it (blueprint step 3). The flags carry combinations the enum cannot (an armed action inside an open window, a charge during a lock), so the enum is derived, not stored; moving storage is not provably behaviour-identical from the characterization traces alone.
