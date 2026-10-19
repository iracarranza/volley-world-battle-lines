> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# MoC slice implementation and parallel-work boundary

Implemented: player and bot Receive, Set, Attack and Block impacts, player Serve, drill-feed strikes, and sweet-contact bonuses. Trajectory option menus, team visibility and Spike Points remain subsequent work.

## Behavior

- Real physical overlap on a legal contact starts shared impact slowdown. Preparation, confirmation by itself, misses, cancellations and the legacy overlap-memory fallback outside current geometry do not start MoC.
- Duration now follows actual incoming and outgoing velocity: impact pace = 0.25 × incoming speed + 0.25 × outgoing speed + 0.5 × magnitude of velocity change. It maps to 18–140ms of real time, capped at 30m/s of impact pace; negligible motion below 0.5m/s adds no velocity duration. A sweet hit independently adds 40ms, including for a low-speed sweet contact. These contributions add, for up to 180ms on one sweet impact. Charge matters indirectly through the resolved velocity, rather than assigning duration by action/charge. The measure is provisional visual tuning, not a force or energy claim. Global simulation time runs at 0.25 of its prior scale during that interval. The ball, CharacterBody movement, resource accounting, bots and drill timers share the engine clock; camera following uses real elapsed time and mouse input remains unscaled.
- Real-time expiration restores the prior engine scale. Pause, reset, ball-down, return to title and scene exit also clear slowdown. Genuine distinct impacts add their duration to the remaining interval, up to 180ms per chain, followed by an 80ms normal-speed recovery if the cap was reached. Repeated delivery of the same contact ID is ignored.
- Confirmation stores immutable neutral intent (actor/team, action, charge, origin, target/direction, intended velocity, simulation timestamp). The preview and eventual shot target retain that choice even if camera direction changes. The result stores incoming/outgoing velocity and physical contact zone separately. Existing charge/height/distance curves and zone-strength calculations are retained.
- `moc.impact_started`, `moc.impact_ended`, `moc.last_event` and `lab.last_contact_result` expose integration points. No new title/menu layout, roster persistence, attribute allocation, trait definitions, art or input bindings were added.

## Files owned by this slice

New: `scripts/moment_of_contact.gd`, `scripts/contact_intent.gd`, `tests/moc_test.gd`, this note.

Narrow shared integration: `scripts/contact_lab.gd` adds the controller, real-time camera delta, intent capture at confirmation, immutable preview/target, result emission after contact, and cleanup hooks. Existing Quick Step, Rolling Receive, Power Serve, title navigation and athlete-store code were retained. Training bots and Pepper partners publish the same physical/sweet evidence after their final contact resolution; serves and the drill feeder also publish actual strike events.

## Validation

`godot --headless --path . --script tests/moc_test.gd` exercises impact-only triggers; no impact on failed confirmations or illegal contacts; immutable intent/preview; duplicate suppression; real-time expiry; capped chains; camera response; shared CharacterBody/ball/bot/drill clocks; restoring a pre-existing time scale; and pause/reset/title/scene cleanup.

Existing prototype, contact-zone, approach, creator, stance, exploration and map-drill suites were run. The current `traits_test.gd` also passes all 23 checks. An initial run exposed a timing-sensitive four-frame settling fixture before Quick Step: the athlete was not yet grounded. A temporary twelve-frame version passed, followed by a successful rerun of the current source test. The source trait test was not edited by this slice. MoC has not activated before those initial assertions.

## Known boundary

The current forgiving overlap-memory contact behavior is retained to avoid retuning gameplay in this slice. Such a fallback cannot create a physical-impact MoC if current geometry misses. Replacing it with swept, timestamped physical evidence belongs to the contact-timing phase. Camera orientation during impact affects subsequent decisions, never the already emitted outgoing velocity. No networking synchronization is claimed; the local prototype now has one shared simulation clock.

Airborne player Attack speed now uses a 1.50 multiplier (50% above the original curve); bot Attack flight time is divided by 1.50 while retaining its destination. Standing attacks and bump/set curves are unchanged. The Spike Trainer target moves from z=-1 to z=-4, with the pad extended, so its standard charged jump hits remain viable with the faster flight.

## Current additive interactions

1. Incoming pace contributes 25% of incoming speed to the impact measure.
2. Outgoing pace contributes 25% of outgoing speed.
3. Redirection contributes 50% of the magnitude of the velocity change. Those three sum before the 18–140ms duration mapping.
4. A geometry/timing/charge-valid sweet hit adds 40ms independently. Manual serves use central physical hand contact for their sweet assessment.
5. A distinct contact during an active MoC adds its duration to the remaining real time. The total chain stays capped at 180ms, followed by 80ms normal-speed recovery if capped. Re-delivering the same event ID never adds twice.

Charge, Timing and other attributes do not add separate arbitrary MoC terms: they affect resolved velocity and sweet eligibility. No separate sourspot or shank bonus exists. All supported contacts use the same global 25% simulation speed; camera/mouse remain responsive in real time. Pause/reset/exit restore the previous time scale. `last_event` exposes velocity and sweet duration contributions separately.

The Contact Lab now offers an A/B toggle between this original slowdown and a short Impact Hold adaptation. See [moc-comparison.md](moc-comparison.md) for controls and tuning. The original mode remains the default.
