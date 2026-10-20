> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Charge, velocity and trait layers: decisions

Updated runtime record, 2026-10-19. The later designer revisions place Stability on weak set execution and Cushioning under END as the additive receive stat. See `attribute-runtime.md` for implementation and tuning.

## Layers

| Layer | Source | What it changes |
|---|---|---|
| Charge level (additive) | Spike Velocity, Serve Velocity (traits); Cushioning (END sub-attribute, the receiver's equivalent) | the charge percentage the other side has to match, and the shot's speed, without changing its trajectory |
| Match tolerance | Charge Tolerance (trait) | how steeply a charge mismatch turns into severity |
| Geometry | Platform Quality (trait) | only the overlap of the hurtboxes in a receive. It does not touch charge or charge interactions |
| Multipliers | Swing Power, Jump Power (sub-attributes) | scale the charge level of the action (Swing Power) or the jump |
| Consequence | Flow, recovery traits | what the next contact or a poor contact leaves behind |

## Decisions

- **Additive charge:** Spike Velocity and Serve Velocity add percentage points to the action's own charge. A 68% charge with Big Hitter (+10) is always a 78% spike; a 100% spike becomes 110%. A receiver at 100% may be unable to cushion it fully if their attributes do not allow it.
- **Order:** multiply, then add. Each additive is worth the same number of points whatever the multipliers.
- **Serve Velocity** gains +12 where Spike Velocity gains +10, because a Serve always starts further away. Serve traits are designed with caution.
- **Swing Power** multiplies the charge level of a spike. The 61–65 neutral band gives 1.00x; positive tiers give 1.04/1.08/1.12/1.16/1.20x, with the maximum at 99. That is late enough that blowing up an under-developed receiver is the point, a well-developed receiver has other tools (Cushioning, Charge Tolerance, Platform Quality, DI), and a min-maxed hitter may still blow people up.
- **Jump Power** will scale the same way as Swing Power.
- **No ceiling** on effective charge (decided: it is addressed by the late maximum and by the receiver's tools).
- **Cushioning vs Charge Tolerance:** Cushioning raises the receiver's own charge by a flat amount. Charge Tolerance softens the severity curve; a receive that is short is still short.
- **Forgiving Edges** is not a trait. Platform Quality covers the edges.
- **Flow** improves the next contact's effects, not its quality (zone).

## Implemented layers

Structured numeric `effects` in `data/trait_tree.json` are authoritative and editable in the trait-tree inspector. Authored branches, requirements, picks and exclusive groups are preserved.

- Big Hitter: +10 Spike Velocity. Power Serve: +12 Serve Velocity. Topspin Serve and Jump Topspin contribute their authored +6 Serve Velocity each; their specialized spin/airborne serving techniques are separate from these charge-layer effects.
- Rhythm Hitter (POW 72, Big Hitter branch): when Flow is present, the next physical attack consumes the old Flow and adds +20 Spike Velocity. The new contact can then earn Flow. Aim previews do not consume it.
- Revenger: an Attack receive that actually lowers Flow arms +10 Jump Power and +15 Spike Velocity, independently consumed by the next jump and attack. A dive does not consume the jump bonus.
- Second Wind (END 68): entering Winded restores 23% of actual maximum Stamina, with a 30 s cooldown. It does not clear Winded or bypass Exhaustion.
- Platform Quality: +6 quality-zone overlap points. Transition Hitter and Back Attacker contribute their authored +6/+4 Platform Quality; Back Attacker also supplies its provisional depth-scaled attack charge bonus.
- Charge Tolerance: 10% gentler charge-severity progression, without changing matched status or the charge band.
- Fast Recovery: 12% faster receive/dive get-up. Stamina Recovery: 15% more regeneration. Exertion Efficiency: 12% lower Stamina expenditure. They do not replace END subattributes.

Flow also provides provisional contact-effect benefits on receives, sets, spikes and blocks without changing the resolved zone or charge-match classification. Timing and Ball Control have independent runtime accessors.
