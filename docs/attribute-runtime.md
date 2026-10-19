# Attribute and trait runtime — 2026-10-19

All six audit steps are implemented against the designer's latest definitions. This is the current implementation record; older handoff proposals that put Stability on receive charge or Recovery in END are superseded.

| Attribute | Subattributes |
|---|---|
| POW | Explosiveness, Jump Power, Swing Power |
| SPD | Acceleration, Lateral Speed, Transition Speed |
| ACC | Ball Control, Timing, Stability |
| END | Cushioning, Work Rate, Capacity |

## Bands and reference

50–55 harsh negative; 56–60 negative; 61–65 neutral; 66–69 T1; 70–79 T2; 80–89 T3; 90–98 T4; 99 T5. Within a band the relevant mechanical effect is constant. Raw points still matter for authored trait eligibility. Runtime stat ratings are bounded to 50–99. The neutral 65 approach timing, four-step rhythm and reference jump baseline are preserved.

| Capability | Harsh | Negative | Neutral | T1 | T2 | T3 | T4 | T5 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Explosiveness/Acceleration/Transition pace | .70 | .90 | 1.00 | 1.08 | 1.16 | 1.24 | 1.32 | 1.40 |
| Jump/Swing charge multiplier | .80 | .92 | 1.00 | 1.04 | 1.08 | 1.12 | 1.16 | 1.20 |
| Strafe speed fraction | .50 | .65 | .75 | .79 | .83 | .87 | .91 | .95 |
| Maximum Stamina | 70 | 90 | 100 | 110 | 120 | 130 | 140 | 150 |
| Cushioning additive charge points | -8 | -4 | 0 | 4 | 8 | 12 | 16 | 20 |
| Work Rate/Stability penalty multiplier | 1.50 | 1.15 | 1.00 | .85 | .70 | .55 | .40 | .25 |

Positive pace means speed, not a direct percentage subtraction from duration: a 1.40 pace has duration baseline/1.40. Tuning beyond the explicitly requested 8%/4% increments is provisional.

Explosiveness scales approach progress and step speeds together to retain run-up distance. Its ascent gravity is world gravity times pace squared; upward takeoff velocity is increased proportionally, preserving resolved height while shortening time to apex. Descent and ball gravity remain world gravity. Dive horizontal speed also scales. Momentum-to-height conversion is normalized against preparation pace so Explosiveness does not become another Jump Power stat. Jump Power multiplies the available jump charge; it does not speed preparation. The approach's action-specific/full-run bonuses remain separate.

Acceleration changes velocity convergence, not the speed cap. Lateral Speed reduces a real strafe penalty measured relative to athlete facing, independent of camera mode. Transition Speed scales post-contact follow-through, receive pose recovery, rescue swings, rolling/get-up clocks, explicit action endlag, landing endlag and the minimum repeat-contact interval. It does not move the 200 ms sweet delay, change confirmation windows or speed ball flight. Nominal input/movement recovery budgets: receive .16 s, set .12 s, attack .22 s, block .16 s, serve .22 s, landing .12 s; existing animation follow-through and floor recovery durations remain their separate base budgets.

Low-Stamina performance decreases smoothly below 30% of actual capacity, with a neutral maximum 20% loss at zero. Work Rate scales that loss; it does not raise fresh output. Jump performance, dive speed, receive charge availability and outgoing contacts use this layer. Explicit Exhausted movement/leap penalties and the 7 s / 10.5 s status rules remain independent. Never Stay Down bypasses jump deterioration above its authored 15% Stamina threshold.

Stability reduces execution loss on weaker sets without upgrading their quality-zone label or sweet eligibility. Ball Control governs set-column width and ordinary receive/set fidelity; Timing independently amplifies sweet-contact effects. Their effective values use band anchors. Platform Quality owns the receiving fan's graded-zone overlaps; it does not expand outer reach, change charge or timing, or substitute for Ball Control's set column.

## Charge and traits

Effective attack charge = input charge × available low-Stamina output × Swing Power multiplier + additive Spike Velocity points/100. Big Hitter, depth-dependent Back Attacker, pending Revenger and Flow Hitter contributions are additive. Multipliers run before additive bonuses, so a +10 trait always contributes .10 charge. Serve charge uses its own additive Serve Velocity traits. Cushioning similarly adds to the receiver's available charge. Effective charge and shot metadata have no 100% ceiling.

Charge Tolerance widens the severity ramp (provisional +10%), while preserving the exact matched/undercharged/overcharged classification. It cannot turn an undercharge into a sweet contact. Actual output and metadata use the same charge resolver for player attacks and court/Pepper bots. Held safe serving retains its legal-target/net-clearance solve; extra serving capability adjusts the legal target depth rather than breaking that guarantee. Tap serving retains physical hand/toss geometry and applies the speed benefit at the existing launch angle.

Machine-readable trait `effects` are saved in `data/trait_tree.json`. The editor exposes numeric effect fields with units; adding a custom named trait with a supported effect works through the same runtime path. Descriptions remain authored prose. Save invalidates the cached book so subsequent gameplay reads the new values. Claude's authored node IDs, branches, picks and exclusive groups are preserved.

Recovery, Stamina Recovery and Exertion Efficiency are now tree traits: +12% recovery rate, +15% regeneration and -12% Stamina cost provisionally. They combine with, rather than replace, Transition Speed, Work Rate and Capacity. Second Wind restores 23% of actual max Stamina on entering Winded, with a 30 s cooldown and no fatigue-status bypass.

## Flow and reactive traits

The existing 14 s hold, eight-second half-life, fatigue clears, aura and bar are retained. Provisional ordinary Flow effects at cap: 12% receive redirection stabilization toward ideal output, 25% lower residual set error, 12% more spike speed, and additional block absorption/downward return. Serves also gain an output benefit. These effects do not rewrite quality-zone labels, charge match or sweet eligibility; rescue contacts retain their rescue behavior.

Flow Hitter requires some Flow and a physical attack. It consumes the old meter once for +20 Spike Velocity, then the resulting contact earns/loses Flow normally. Preview and confirmation do not consume resources. Revenger triggers only when an Attack receive actually decreases Flow; it independently arms +10 Jump Power and +15 Spike Velocity. Bonuses do not stack on repeated triggers and are consumed by the respective next jump/attack. A dive leaves the jump bonus intact. Actor state is independent for the player, court helpers and Pepper partners.

These audit steps do not implement unrelated specialized abilities merely described by other tree nodes (for example the airborne serving technique of Jump Topspin, spin simulation, Tool, Dump, Back Set or Pancake). Their additive/stat effects, where applicable, are distinct from those techniques.

## Saves and UI

`athlete_store.gd` defines twelve canonical names, a versioned schema, and synchronized named `statistics`, labelled offsets and parent values. New roster/UI edits and lab apply all use that schema; the debug creator preserves it. Parents retain eligibility/progression roles; legacy direct POW boosts to tap charge and base shot speed no longer bypass the named charge/stat layers.

Old allocations are copied losslessly into `legacy_statistics`. Only equivalent names (including Jump Explosiveness -> Explosiveness and Stamina Capacity -> Capacity) are candidates for migration. Removed stats are not renamed into unrelated abilities. If retaining only equivalent offsets would give free statistical points because the old balancing negatives belonged to removed stats, that category resets to its parent baseline for respec, with the complete old allocation still archived. Explicit canonical named stats and trait picks are preserved; migration is idempotent. Loading normalizes in memory; the existing save action persists the new schema. Tests use temporary save files rather than the user's live roster.

The roster shows the current subattribute names and tier tooltips. Stamina bars, regeneration, drill replenishment and reset use actual Capacity instead of hard-coded 100.

## Validation

New suites cover tier boundaries and within-band identity; real approach pacing/rhythm/distance and independent jump height; acceleration and strafing; save migration/round trip; trait-effect editing/round trip; charge ordering and >100% matching; Flow output effects and consumption; Revenger/Second Wind; and actual recovery/controller/HUD behavior.

Relevant regression suites cover prototype behavior, serving, charge matching, receive outcomes, set geometry, contact execution, Flow/knockback, bot rally motion, Pepper, fatigue, blocking, previews and MoC continuous motion. Graphical captures verify the roster and effect inspector; the real Compatibility-renderer contact profile verifies no reintroduced contact stall. Provisional values should be playtested against controlled 65 reference builds before balancing across the full range.
