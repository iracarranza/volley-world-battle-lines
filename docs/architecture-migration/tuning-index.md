# Tuning index

Migration stage MS-03. Constants stay with the law that owns them (SADR-21). This index lists the timing constants that more than one module reads, with owner, unit and status. It is documentation with a lint: `tests/tuning_index_test.gd` reads every `const` row below and fails when the code value differs from the documented one. Nothing is moved or renamed.

Status: `rule` (a gameplay constant: changing it is a gameplay change), `provisional` (named provisional in code), `coupled` (read by another law, see the note).

| Owner | Name | Value | Unit | Status | Note |
|---|---|---|---|---|---|
| contact_execution.gd | SWEET_DELAY | 0.20 | s | rule | ideal age of a Set or Block contact |
| contact_execution.gd | SWEET_SECONDS | 0.18 | s | rule | Set and Block sweet window length |
| contact_execution.gd | SWEET_CENTER | 0.245 | s | coupled | read by `swing_clock.gd` `PEAK`: the Serve swing peak is coupled to the Set/Block sweet centre |
| contact_execution.gd | CONTACT_SECONDS | 0.55 | s | rule | live window of Receive, Set, Block |
| contact_execution.gd | SPIKE_SWEEP_SECONDS | 0.2 | s | rule | Attack sweep length after the windup |
| contact_execution.gd | SPIKE_POWER_HALF | 0.06 | s | rule | half-width of the Attack power window around the peak |
| contact_execution.gd | SPIKE_SWEET_SECONDS | 0.06 | s | rule | Attack sweet window length |
| contact_execution.gd | RECEIVE_SWEET_SECONDS | 0.32 | s | rule | Receive sweet window length |
| contact_execution.gd | RECEIVE_SWEET_CENTER | 0.28 | s | rule | Receive sweet window centre |
| swing_clock.gd | POWER_HALF_WINDOW | 0.14 | s | provisional | Serve power window half-width |
| swing_clock.gd | LOADED_PHASE | -0.30 | phase | coupled | duplicated as `spike_stage.gd` `LOADED` |
| swing_clock.gd | SWEET_HALF_WINDOW | 0.09 | s | rule | Serve sweet window half-width |
| contact/block_response.gd | PRESS_SECONDS | 0.5 | s | rule | Block press pulse length; Block has no age-based sweet window |
| moment_of_contact.gd | TUNED_DURATION | 0.2 | s | rule | Tuned slowdown window |
| moment_of_contact.gd | DURATION_EXTENSION | 0.100 | s | rule | added to a slowdown duration |
| moment_of_contact.gd | SLOW_SCALE | 0.60 | scale | rule | Current slowdown speed |
| moment_of_contact.gd | TUNED_SLOW_SCALE | 0.10 | scale | rule | Tuned slowdown speed |
| moment_of_contact.gd | SWEET_BONUS | 0.040 | s | rule | added for a sweet contact |
| moment_of_contact.gd | CHAIN_BASE_LIMIT | 0.18 | s | rule | chain limit before the extension |
| moment_of_contact.gd | CHAIN_RECOVERY | 0.08 | s | rule | gap before a new chain |
| receive_plant.gd | DURATION | 0.85 | s | rule | pose, hurtbox offset and aim lock; the movement lock is shorter (BDR-06) |

## Session-editable knobs

| Knob | Default | Owner | Status |
|---|---|---|---|
| `spike_windup_seconds` | 0.25 s | `session_settings.gd` (one shared instance; `Execution.spike_windup_seconds` reads and writes through it) | rule default, session-wide, edited from the MoC menu, not persisted |
| `spike_windup_enabled` | true | same | same |

Other session-wide statics (`vision_focus.gd`, `voli_visual.gd` `rig_mode`, `rig_skeleton.gd`) are presentation settings; they are left where they are and are not rule-bearing.
