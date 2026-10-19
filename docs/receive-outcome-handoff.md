> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Receive outcome handoff

Gameplay rules live in `scripts/receive_outcome.gd`. Animation files, recovery playback, and recovery movement locks are deliberately left to Claude. Flow UI is a subsequent task.

## Animation contract

Connect to `contact_lab.receive_resolved(event: Dictionary)`. It fires once per resolved receive for the player, training bots, and Pepper partners. `event.actor` is `player`, `training_bot_<slot>`, or `pepper_<index>` (the same actor IDs as MoC). The player's immutable `last_contact_result` also retains these fields; external contacts retain them in `moc.last_event`.

- `event.recovery`: `""`, `knee`, `fall_roll`, `fall_slide`, `blown_away`, or `shrug`.
- `event.recovery_seconds`: canonical animation length: Knee 0.55, both Falls 0.95, Blown Away 1.35. Shrug has a provisional 0.25 s gameplay budget; its animation is pending.
- `event.receive_outcome`: evidence including `posture`, normalized `platform_coord`, `central`, `bottom_third`, `height_fraction`, `di_axes`, `correction`, `di_alignment`, `penalty_factor`, raw/effective charge severity, canonical `recovery_seconds`, and `recovery_penalty_seconds` (canonical duration times DI penalty factor).

Keep the existing planted/moving/reaching/off-axis arm contact posture separate from recovery selection. Contact side is `sign(event.receive_outcome.platform_coord.x)` in the athlete's facing coordinates; use this for Fall Roll direction, with handedness fallback when centered. Do not recompute recovery selection from speed/quality using the old `floor_recovery.choose()` heuristic: the new event is authoritative. No global pause or delayed ball release should be introduced by playback.

The resolver does not start recovery playback, displace the athlete, or apply a movement lock. It supplies the chosen recovery and penalty data for Claude's controller/animation wiring. Ball flight changes below already happen immediately at contact.

## Rules and priority

Geometry uses athlete-scaled platform dimensions. Bottom third is contact height <= one third of the platform's vertical range, clamped conceptually to the actual contact volume. Provisional central footprint: absolute side offset <= 40% of side reach and forward offset <= 68% of forward reach. Center classification is horizontal, so a low central ball can still blow the receiver away.

1. Undercharged shot whose original charge severity is >= 0.5: central -> Blown Away; outside center -> Fall Roll for planted/off-axis, Fall Slide for moving/reaching. This takes priority over Knee.
2. Milder central undercharge plus positive backward correction -> Shrug.
3. Other valid contacts in bottom third -> Knee.
4. Other contacts retain ordinary posture with no forced floor recovery.

Overcharge does not trigger the underpowered Fall/Blown Away rules. Existing gradual charge matching is preserved (full severity at a 35-point charge gap); a tiny deficit never becomes a dramatic shank. Misses do not earn a recovery.

## Directional influence

Use the existing trailing 80 ms input sample, interpreted relative to athlete facing rather than camera or momentum. Match the side of a reaching/off-axis contact; for a precisely centered reaching ball either lateral input is helpful. Knee is helped by forward input. Central undercharge is helped by backward input. Severe off-center undercharge uses the lateral rule when reaching/off-axis. Opposite input worsens the penalty; perpendicular or absent input leaves it unchanged; diagonals contribute proportionally.

Full matching DI gives penalty factor 0.65; full contrary DI gives 1.35. This scales geometric quality loss, platform-induced deflection/lift penalties, charge-shank severity, and the exposed recovery penalty budget. A Knee also loses 18% of outgoing upward speed at neutral input (11.7% with full helpful DI; 24.3% with full contrary DI). Existing aimed DI remains in place. Assistance never changes matched status or turns an undercharged ball into a sweet receive. Sweet/timing and biomechanical reach remain independently required.

Bots use the same resolver with neutral corrective DI for now; their tracking movement is not silently treated as intentional DI. Training and Pepper event dispatch carry the exact same evidence. Preview incorporates the geometry-based outcome and DI, while still assuming an ideal charge match as before.

## Validation

`tests/receive_outcome_test.gd`: outcome priority, mirrored Fall mapping, moving/reaching variants, near-miss charge continuity, DI benefit/penalty and facing invariance, charge mismatch cannot become sweet, Knee flight correction, physique scaling, and real player/external-bot event publication.
