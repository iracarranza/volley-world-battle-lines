# Gameplay runtime contract v1 — 2026-10-20

This is the interface between trait information and gameplay. Codex owns runtime
mechanics and this contract; Claude owns tree data, selection, editor and the
adapter described below. Numbers in tree definitions remain the designer's.
Validation status and reproducible checks are recorded at the end.

## Adapter boundary

`LabAthlete.gameplay_effects` is an additional flat numeric effect dictionary.
`LabAthlete.gameplay_rules` is an array of structured rules (below). Tests and
non-tree providers can set these directly. Existing numeric tree effects continue
through `TraitBook.active_effects(picks, via)`. If the tree implements
`active_gameplay_rules(picks, via)`, gameplay reads its returned rules as well.
The adapter must return **current traits only**, respecting consumption, merges,
running totals and source selection, just as active_effects does. Do not sum
consumed ancestor rules. Rule IDs must be unique within the effective build.

The tree may store rules as each node's `gameplay` array, but storing, cleaning,
editing and aggregating that field belong to the tree. Runtime never parses text,
trait names or particular node IDs to discover gameplay behavior.

## Numeric keys and recipients

Percentages below are authored as whole numbers: 10 means 10%, and charge points
10 means +.10 charge. Rating points are different: +6 Cushioning means +6 to its
rating, which then resolves through the normal bands. Use `receive_charge_bonus`
for a direct additive receive-charge bonus instead.

| Keys | Unit | Recipient / ownership |
|---|---|---|
| `explosiveness`, `jump_power`, `swing_power`, `acceleration`, `reaction_speed`, `transition_speed`, `ball_control`, `timing`, `stability`, `cushioning`, `work_rate`, `capacity` | rating points | Self, effective subattribute only |
| `power`, `speed`, `accuracy`, `endurance` | rating points | Temporary parent bonus: applies to its three effective subattributes; speed also affects movement cap |
| `explosiveness_band`, `jump_power_band`, `swing_power_band` | bands | Self; optional corresponding `_band_cap` is a tier number (-2..5). A capped upgrade never lowers an already higher band |
| `spike_velocity`, `serve_velocity`, `receive_charge_bonus`, `back_attack_velocity` | charge points | Self; additives after multipliers. Back attack is depth-scaled |
| `platform_quality` | overlap points | Self receive geometry; does not enlarge outer reach |
| `broad_range`, `vertical_reach` | % | Self lateral / vertical hurtbox stretch; Broad Range also reduces outer-zone penalties. It does not grant an unreachable spike sweetspot |
| `court_vision` | % | Self directional-influence angular authority |
| `receive_control`, `receive_absorption`, `receive_redirection`, `charge_tolerance`, `recovery`, `stamina_recovery`, `exertion_efficiency`, `stride_speed` | % | Existing self mechanics |
| `flow_state` | % | Self positive Flow gains; does not increase the 100 cap or multiply losses |
| `placement` | percentage points of transfer efficiency | Carried by a Set to the next allied Attack; improves intended charge transfer, capped at 100% efficiency |
| `ally_attack_charge_tolerance` | % | Carried by a Set to its allied attacker; never changes the setter's own receive tolerance |
| `mismatch_knockback`, `mismatch_stamina_drain` | % | Serve-carried modifiers, applied to the receiver on a charge mismatch |
| `transition_speed_penalty` | rating points | Serve-carried temporary Transition Speed penalty on an inflicted recovery |
| `inflicted_recovery_duration` | seconds | Duration for that serve-carried temporary penalty; defaults to the recovery outcome's duration when omitted |
| `charge_aim_variance` | degrees at 100% input charge | Self contact dispersion, increased by DI and reduced by Ball Control; zero means no added dispersion |
| `di_stamina_cost`, `di_hp_cost` | resource points at full DI | Self costs on actual contact, zero by default |
| `di_cost_reduction` | % | Reduces those explicitly configured DI costs; 100 makes them free |
| `flow_attack_velocity`, `revenge_spike_velocity`, `revenge_jump_power`, `second_wind`, `jump_stamina_threshold` | existing units | Compatibility hooks for old definitions. Prefer structured rules for new Flow behavior |

`spin` and `float` are intentionally not claimed by this contract: their flight
models/units require separate design. Back Set, Dump and other active techniques
are also separate implementation work, not enabled by prose or dummy effects.

## Structured rules

Example contact spender:

```json
{"id":"rhythm-release","trigger":"attack","threshold":100,"consume":"all",
 "effects":{"spike_velocity":8}}
```

Example receive spender with deferred benefits:

```json
{"id":"bass-release","trigger":"receive","threshold":100,"consume":80,
 "effects":{"platform_quality":15},
 "pending":{"jump":{"jump_power":5},"attack":{"spike_velocity":12}}}
```

Example conditional set support:

```json
{"id":"anticipation","trigger":"set","threshold":30,"consume":0,
 "effects":{"placement":10},"clear_on":["set_rescue","set_attack_blocked"]}
```

- Contact triggers: `receive`, `set`, `attack`, `block`. Their effects participate
  in that contact; resources/cooldowns commit once on an actual physical hit.
  Preparing, confirming, missing, and previewing do not consume Flow or uses.
- `jump` participates in a real jump; `effects.jump_power` modifies that jump.
- Consequence triggers: `attack_receive_flow_loss`, `inflicted_recovery`.
- `low_stamina`: additionally specify `stamina_below` (fraction),
  `restore_stamina` (fraction of maximum), and optional `cooldown` (seconds).
  It respects the Exhausted regeneration lock; it cannot bypass Exhaustion.
- `ally_attack_charge`: reacts once per distinct allied athlete per rally, up to
  `max_allies` (default 4). `recipient` is `self` or `ally`; `effects` grants
  temporary stat/effect modifiers. Set `until:"net_cross"` for Endless Options,
  or `duration` in seconds for a support aura. Self is never counted as an ally.
- Optional `when` conditions: `incoming_kind`, `sweet`, `rescue`, `mismatch`,
  `quality_below`, `quality_at_least`. Conditions inspect the contact before
  their own bonuses; they cannot retroactively create physical reach. Author
  reach/geometry grants as preparation effects rather than outcome conditions.
- `consume` is a nonnegative Flow amount or `all`; default 0. Threshold and cost
  are checked against available Flow. Multiple eligible rules resolve in array
  order with reserved costs, so they cannot overspend the same Flow.
- Optional `cooldown` (seconds) and `uses` (maximum activations per rally).
- Optional `flow_gain` adds a fixed Flow amount on activation.
- `pending` grants bonuses to the named next `attack` / `jump` / `receive` / `set`
  / `block`. Repeated grants from the same rule replace rather than stack;
  independent rule IDs add. Taking a dive does not consume a pending jump bonus.
- `clear_on` applies while the rule is owned, independently of its threshold.
  Set attack/block attribution follows the ball's recorded setup owner.
- A profile with structured rules uses those for Flow spending; it does not also
  activate the old any-positive-Flow `flow_attack_velocity` spender.

## Effective stats and temporary modifiers

`athlete.modifiers.add(id, spec)` installs a replace-by-ID modifier. A spec has
`stats`, `effects`, optional `duration` (seconds), optional `until` (`net_cross`,
`rally`, `contact`, `jump`) and `source`. Effective ratings remain bounded 50–99.
Trait eligibility continues to use stored base ratings/allocations, never buffs,
debuffs, Flow or band upgrades. Reset/rally cleanup removes transient effects. Optional `bands` maps a subattribute
to `{amount, cap}` for independently capped temporary tier upgrades.

`jump_stamina_threshold` now also protects diminished jump charge above its
Stamina threshold, including the height portion of preparation. It does not skip
the approach animation or grant an earlier physical contact.

## Ball and recipient lifecycle

Set output records immutable setup ownership, team, Placement, attacker tolerance,
quality and source rule IDs. Only the next allied Attack can use the support.
Receive, opponent contact or a new Set replaces/clears that setup; an Attack
retains attribution so a later opposing Block can notify the original setter.
An attack's transfer efficiency is distinct from its own Swing Power and additive
Spike Velocity. Provisional Receive → Attack efficiency is 70–90%, according to
delivery quality. Set → allied Attack is 70–100%; Placement adds efficiency points
and allied attack tolerance reduces the quality penalty. Only the incoming-input
portion is attenuated, before Swing Power; additive velocity traits keep their
full point value. Free-ball/legacy shots without a conditioning payload retain
normal transfer. These are gameplay coefficients, not conservation-of-energy rules.

Serve consequences snapshot their modifiers at launch. Receiving them does not
look up a serving athlete's later trait state. Actor-local modifiers, pending
bonuses, cooldowns and charging-ally counts are independent for player, court bots
and Pepper partners. Gameplay is shared across real contacts and pure previews.

## Status

Implemented in `gameplay_rules.gd`, `gameplay_modifiers.gd`, `contact_flow.gd`
and the shared contact resolver. Player, court bots and Pepper use the same
profile rules. Pure preparation and immutable contact evidence are separate from
resource commitment. Modifier lifetimes advance in world time, independently of
MoC actor/ball slowdown. Rule and bot geometry caches avoid repeated tree
traversals and mesh rebuilding in intercept searches.

Behavioral coverage: `tests/gameplay_hooks_test.gd`; existing contact, direction,
fatigue, rally, drill and trait suites run through `python3 tools/test.py`.
`python3 tools/test.py render_gameplay_hooks --render` captures all four enlarged
hurtboxes in windup and sweet phases for visual inspection.

No trait data or selection/editor files are changed by this mechanics task.
Claude's tree adapter and definitions were separately exercised in integration.
