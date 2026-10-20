# The POW tree, as a set of subtrees

Draft revised 2026-10-19 after the Flow notes, written into `data/trait_tree.json` (page POW, 36 nodes). A first draft of one page, to be argued with; numbers are provisional.

## How it is organised

- **A subtree is a starter that branches into better ones.** A *starter* (a component: one stat or one verb, cheap) grows into *epics* (specialisations, often a fork) and ends in a *legendary* (a passive or a rule bend).
- **Subtrees are not exclusive; capacity limits them** (6, 8 with Deep Bag). Forks inside a subtree are exclusive: one child per node. Only the end of a line takes capacity; deepening costs AP and ratings, not slots. Legendaries weigh 2 or 3, everything else 1 (Model C: a deeper node incorporates what it builds on).
- **A node can be reachable from several lines** (`alt_parents`): any one is enough. Rhythm Hitter is reachable from Big Hitter and from Tough Arms. A node with several parents is a child of each, so it is a branch of each parent's fork. Its reach cost is the cheapest route.
- **Access without building on a line is `requires`** (all of them needed, each keeping its own slot). Tooler is the example.
- **Vertical and supplementary are shapes of the cost curve.** A vertical path has more steps, close together, and a high peak. A supplementary path has a cost-effective start, then a flatter, lower-peaking climb.
- **Not every line is a stat.** Flow lines and the Pepper line change how the game is played, not only what the athlete's numbers are.

## The subtrees (AP is reach cost; w is capacity weight)

| Subtree | Steps |
|---|---|
| **Serving** | Power Serve (3) → fork: Topspin Serve (9) → Jump Topspin (12) → Siege Serve (22, w2); or Rattling Serve (7, more knockback on a charge mismatch) → Draining Serve (17, and more Stamina drain on a mismatch) |
| **Hitting** (vertical) | Big Hitter (3) → Rhythm Hitter (7) → fork: Heavy Arm (11) → Sledgehammer (15) → Terminal Hitter (26, w3); or Spring Legs (11) → Skyhook (15) → Apex Hitter (26, w3) → Never Stay Down (39, w3); or Keep in Time (12) → Drop the Bass (20, w2) |
| **Transition and Flow** | Tough Arms (4) → fork: Rhythm Hitter (7, shared with Hitting) → Keep in Time (12) → Drop the Bass (20, w2); or Scramble (6) → Jungle Ball (9) → Back Attacker (12) |
| **Range** | Wide Arm (4) → Edge Contact (11) → Max Extension (20) |
| **Spotter** | Eyes Up (4) → Read the Block (10) → Spotter (16) |
| **Burst** | Coil (4) → Quick Plant (12) → Burst Attacker (22, w2) |
| **Jackknife** | Utility Arm (4) → Stand Tall (10) → Jackknife (18, w2) → Revenger (22, w2) |
| **Tooler** (advanced) | needs Big Hitter, Edge Contact and Read the Block owned, POW 80 and ACC 78 (28, w3) |

## Flow in the tree

- **Rhythm Hitter** (POW 72): "Flow 100: Your next attack consumes all Flow and gains +8 Spike Velocity. +5 Flow State." Reachable from Big Hitter or Tough Arms.
- **Keep in Time** (POW 72, SPD 70): "Flow 100: Your next receive consumes all Flow and gains Platform Quality +10, and your next attack gains +10 Spike Velocity. +8 Flow State."
- **Drop the Bass** (POW 76, SPD 74, w2): "Flow 100: Your next receive consumes 80 Flow and gains Platform Quality +15, your next jump gains +5 Jump Power, and your next attack gains +12 Spike Velocity."
- **Flow State** is an auxiliary that raises the rate Flow is gained. It is meant to be reachable from many pages, not only POW. It has no runtime mechanic yet and its unit is undefined.

## The two shapes, measured

| Shape | Path | Reach at each step | Peak |
|---|---|---|---|
| Vertical | Hitting to Terminal Hitter | 3, 7, 11, 15, 26 | 26 (39 with Never Stay Down) |
| Vertical | Serving to Siege Serve | 3, 9, 12, 22 | 22 |
| Supplementary | Transition: Tough Arms, Scramble, Jungle Ball, Back Attacker | 4, 6, 9, 12 | 12 |
| Supplementary | Flow: Tough Arms, Rhythm Hitter, Keep in Time, Drop the Bass | 4, 7, 12, 20 | 20 |
| Supplementary | Burst: Coil, Quick Plant, Burst Attacker | 4, 12, 22 | 22 |
| Supplementary | Jackknife: Utility Arm, Stand Tall, Jackknife, Revenger | 4, 10, 18, 22 | 22 |

The vertical Hitting line has the most steps and the highest peak; its steps are close together until the last (15 to 26, which adds END). The supplementary lines peak between 12 and 22 and are cheap to enter (4 AP).

## Rules added in this revision

- **Successors do not inherit.** A node that builds on another *consumes* it: only current Traits apply and take capacity, and a consumed Trait's own bonuses and behaviors stop. So a successor's `effects` and text are written as **running totals** (Topspin Serve is +18 Serve Velocity, not +6 on top of Power Serve's +12), and restates everything it keeps ("Your serves fall more sharply" is repeated through Topspin Serve, Jump Topspin and Siege Serve). A Trait owned only as a prerequisite still counts as owned for `requires`.
- **A node with two sources is split in two.** Rhythm Hitter shows two sections, Big Hitter and Tough Arms. The section under the mouse is highlighted, the one clicked is the parent that claiming consumes, and the panel says what it keeps from that parent. If only one parent is taken the other section is not a choice. What is kept is the node's `carried` data: `{parent: effects}`. Anything further down the line (Heavy Arm, Terminal Hitter, Never Stay Down) carries the same by source, so it keeps Big Hitter's +10 Spike Velocity or Tough Arms' +4 Platform Quality according to the route taken.
- **Spin** (auxiliary, no runtime mechanic yet). At lower values it raises the penalty of edge-hurtbox blocks and receives, like a Charge Tolerance reduction on the defender; at serve distances it also bends the ball laterally. Jump Topspin's drop is innate and separate from Spin, and its successors restate it. Spin is granted by Topspin Serve (+6), Jump Topspin (+10), Siege Serve (+16), Edge Contact (+4), Broad Range (+6), Read the Block (+4), Spotter (+6) and Tooler (+8).
- **Tooler requires Spin.** It still needs Big Hitter, Edge Contact and Read the Block owned, and 8 Spin from the build's *current* Traits (`needs_stats`). Edge Contact (4) and Read the Block (4) give exactly that. A serving line can supply Spin too, which opens a Tooler route through a serve. If a player consumes Edge Contact into Broad Range, Broad Range's running total carries its own Spin (6), so the requirement stays satisfiable.
- **One Flow effect per build, three with the Open Mind innate.** Nodes marked as Flow effects (every Rhythm Hitter node and its successors, Keep in Time, Drop the Bass, Revenger) count against it; only the current Trait of a line counts. Open Mind is a new innate, provisionally 6 AP.

## Notes for the other pages

These came with the Flow discussion and are not in the data yet.

- **END, Deep Breath** (a Flow starter, END only): "Flow 80: Whenever Stamina drops below 30%, consume all Flow and regain 30% Stamina", with a 60 s cooldown. Its drawback is a short, prohibitively expensive upgrade tree with diminishing value (END-only, which makes Stamina less valuable per capita), and the one-Flow-effect limit. Circular Breathing: Flow requirement 60, and three independently consumed uses. Zen Mode (capstone): an aura that improves all attributes slightly upon consuming Flow and restoring Stamina, not influencing Trait eligibility. The base effect may still be too strong; check it against base regeneration.
- **ACC, Trickster's Sense** (in a "deceptive" path, not under a Flow starter): "Flow 100: Your next Set consumes all Flow to afflict up to two nearby opposing players with Charge Tolerance -10." Setter Traits tend to support allies or disrupt opponents.

## What I had to invent in this revision

Tough Arms (+4 Platform Quality, POW 66 and SPD 68); Jungle Ball is the old Transition Hitter (+6 Platform Quality) renamed because no text was given; Sledgehammer and Skyhook (+5 Spike Velocity each) are extra vertical steps; the earlier Transition Attacker capstone is removed (Drop the Bass and Back Attacker are the third steps); Never Stay Down moves under Apex Hitter; Revenger is repriced to POW 78 and END 74.

## Open points

- Drop the Bass's text as given has no Flow State, so under running totals it keeps none (Keep in Time gives +8). Intended?
- Spin has no numbers or units beyond the grants above.

- Does a Flow line's release stack across its nodes (+8 then +10) or does the deepest node set it?
- Does Flow State add or multiply, and in what unit?
- Cooldown or price for Deep Breath, so it does not make a skilled player never tired.
- Opponent debuffs (Trickster's Sense) need a duration and an overlap rule.
- Most effects in this tree have no runtime mechanic. Supported and used: Serve Velocity, Spike Velocity, Platform Quality, Receive Absorption, Recovery, Receive Control, Charge Tolerance, Flow Attack Velocity. Everything else is text.

## Naming (2026-10-20)

Flow Hitter, Flowing Transition and Flowing Finisher are now **Rhythm Hitter**, **Keep in Time** and **Drop the Bass**. SPD's Flow line starts with **Graceful Steps** (not in the data yet).

## Serving revision (2026-10-20)

The Pepper line (Com-Pepp-Itor, Pepper Patroller, Lane Bully) is removed. In its place: **Rattling Serve** (knockback on charge mismatches) then **Draining Serve** (Stamina drain on mismatches). Both names are provisional. ACC mirrors the drain one step earlier: Steady Serve → Lockdown Serve (drain) → Pinned Down (inflicted recovery poses last longer); or Steady Serve → Float Serve → Jump Float → Hybrid Serve (requires Power Serve).

## Hitting restructure (2026-10-20, supersedes the Hitting rows above)

Rhythm Hitter, Heavy Arm and Spring Legs are now three alternatives under Big Hitter (Rhythm Hitter is also reachable from Tough Arms). Each runs down its own column, side by side:

| Level | Heavy Arm line | Spring Legs line | Rhythm line (Flow) |
|---|---|---|---|
| 1 | Heavy Arm | Spring Legs | Rhythm Hitter |
| 2 | Sledgehammer | Skyhook | Keep in Time |
| 3 | Terminal Hitter | Apex Hitter | Drop the Bass |
| 4 | | Never Stay Down | |

Only the Rhythm line uses Flow (Flow cost, Flow State, the release rules). The Heavy Arm and Spring Legs lines are stat and band lines: Spike Velocity as running totals (Big Hitter's 10, then 15, then 25) and Swing Power / Jump Power band upgrades, with no Flow mechanic.
