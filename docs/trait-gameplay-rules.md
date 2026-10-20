# Gameplay rules in the trait tree (tree side of the runtime contract)

2026-10-20. The runtime contract is `docs/gameplay-runtime-contract.md` (Codex). This file records what the tree stores and supplies.

## Adapter

- Each node has a `gameplay` array of structured rules (stored, cleaned and validated in `TraitBook`; editable in the editor as JSON).
- `TraitBook.active_gameplay_rules(picks, via)` returns the rules of **current Traits only** (consumed predecessors and merged sources contribute nothing); a repeated rule id keeps the first. Successors restate their rules (running totals), so a line shares one id (`rhythm-release`).
- `TraitBook.problems(node)` flags a rule with no id, an unknown trigger or an effect key the contract does not claim (`GAMEPLAY_TRIGGERS`, `GAMEPLAY_KEYS` in `trait_book.gd` mirror the contract).
- Numeric `effects` are unchanged and still flow through `active_effects`. A rule's own effects must not be duplicated in `effects` (Anticipation's flow Placement is in its rule; only the always-on part is in `effects`).
- Compatibility: the old numeric hooks (`flow_attack_velocity`, `revenge_*`) are kept next to the rules on the nodes that have them, until the runtime confirms structured rules replace them. By the contract the old any-Flow spender is not activated when a profile has structured rules.

## Converted

| Node(s) | Rule |
|---|---|
| Rhythm Hitter and its line (Heavy Arm, Sledgehammer, Spring Legs, Skyhook, Terminal, Apex, Never Stay Down) | `rhythm-release`: attack, Flow 100, consume all, +8 Spike Velocity |
| Keep in Time | `keep-in-time`: receive, Flow 100, consume all, +10 Platform Quality, pending attack +10 Spike Velocity |
| Drop the Bass | `bass-release` (the contract's example) |
| Revenger | `revenge`: `attack_receive_flow_loss`, pending jump +10 Jump Power, pending attack +15 Spike Velocity |
| Anticipation, Anticipation II, Foresight, Trickster | `anticipation`: set, Flow 30, +10 Placement (Anticipation II +6 with +4 always, Foresight +10 with +4 always), cleared on set rescue or a blocked set attack |
| Endless Options | `endless-options`: ally_attack_charge, max 4, self, until net cross, Swing Power / Broad Range / Placement +2 per ally (provisional) |
| Shot Caller, Motion Offense | `shot-caller`: ally_attack_charge, allies 2 then 3, recipient ally, 8 s, SPD +3 (Motion Offense also END +2); provisional |
| Shoot Set, Bullet Set | `ally_attack_charge_tolerance` +5 / +10 (carried by a Set to its attacker), replacing `charge_tolerance` |
| Heavy Arm, Sledgehammer, Spring Legs, Skyhook, Terminal Hitter, Apex Hitter, Never Stay Down | `swing_power_band` / `jump_power_band` +1 with `_band_cap` as the text says |

## Not claimed by the contract (stay as text or numeric keys with no runtime)

- `spin` (eight nodes). `float` is not used as a key yet.
- Back Set, Dump and the other active techniques; Never Stay Down's diminished-charge protection beyond `jump_stamina_threshold`.
- Deep Breath, Circular Breathing, Zen Mode (not in the data).
- Mismatch/serve keys are claimed; `mismatch_*` are percentages, `transition_speed_penalty` is rating points. Pinned Down has no `inflicted_recovery_duration` yet.
