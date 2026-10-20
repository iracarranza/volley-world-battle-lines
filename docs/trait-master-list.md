# Trait master list and tree logic

State of `data/trait_tree.json` and the runtime on 2026-10-19, with an audit and proposals. **Nothing in the data was changed by this note.** Proposals are marked *(proposal)*; names and numbers in them are placeholders for the designer to accept or change. AP means reach cost: the highest requirement in each Attribute along the path from the branch's first node, above 65, summed. A base athlete has 12 AP.

## 0. Rules decided 2026-10-19 (implemented)

These come from the designer and replace the earlier proposals about a flat trait limit. They live in `data/trait_tree.json` under `rules`, per node (`weight`, `requires`, `standalone`), and in `scripts/trait_book.gd`.

- **Model C.** A deeper Trait incorporates the Traits it builds on. The ancestors' effects stay active; they just stop taking capacity. The data stores each node's effect as an *increment* (Topspin Serve +6 on top of Power Serve +12), and the runtime sums along the path, so Jump Topspin's total is +24 Serve Velocity. Read a node's cumulative effect off its path.
- **Capacity is 6, 8 with Deep Bag (+2).** Only the *frontier* counts: picked nodes that are not a prerequisite of another picked node, each at its `weight` (1 to 3). Depth costs progression; breadth costs capacity. Deeper nodes may weigh 2 or 3; the two capstones weigh 3.
- **Every fork is exclusive.** Of the children of one node, one branch only. Of the roots on a page, one start only. A `standalone` node (a capstone) is outside the start choice. `rules.forks` can be set to `"open"` to turn this off and compare.
- **Extra prerequisites.** `requires` lists other nodes, from any page, that must also be taken (Hybrid Server and the capstones). Reach cost counts what every required node needs.
- **Three reasons a Trait is unavailable**, in the order the picker checks them: ratings and prerequisites; an exclusive fork already taken the other way; no capacity left.

### What exclusive forks cost, counted on the saved tree

`tests/trait_math.gd` enumerates every structurally valid set of picks (prerequisites taken, no two branches of a fork), ignoring ratings:

| | All forks exclusive | Forks open |
|---|---:|---:|
| Valid builds | 3,200 | 98,304 |
| Of those within capacity 6 | 1,897 | 15,891 |
| Within capacity 8 (Deep Bag) | 2,569 | 38,757 |
| Most Traits one build can own | 11 | 19 |
| At creation (12 AP, capacity 6): builds | 217 | 1,972 |
| At creation: most Traits owned | 5 | 9 |

Exclusive forks remove about 97% of the combinations and bring the creation maximum from the earlier 11 owned Traits down to 5. Capacity then removes 41% of the remaining builds at 6 (and 20% at 8). Only 1,897 distinct builds fit in 6; at creation, 217. With so few starts per page, capacity will rarely bind at weight 1; it starts to matter once deeper nodes weigh 2 and 3 (today, with the two weight 3 capstones, valid builds use up to 10 capacity). Pages offer very different numbers of lines: POW has 6 line ends, END 6, ACC 2, SPD 1.

## 1. Rating bands and subattributes

50–55 harsh negative, 56–60 negative, 61–65 neutral, 66–69 T1, 70–79 T2, 80–89 T3, 90–98 T4, 99 T5. A band holds one effect value; raw points still gate traits.

| Attribute | Subattributes | What a point band changes |
|---|---|---|
| **POW** | **Explosiveness**: approach pace, takeoff speed, dive speed (.70 harsh to 1.40 T5). **Jump Power**: charge multiplier on jumps (.80 to 1.20). **Swing Power**: charge multiplier on a spike (.80 to 1.20) | pace .70 / .90 / 1.00 / 1.08 / 1.16 / 1.24 / 1.32 / 1.40; charge multiplier .80 / .92 / 1.00 / 1.04 / 1.08 / 1.12 / 1.16 / 1.20 |
| **SPD** | **Acceleration**: velocity convergence, not top speed. **Lateral Speed**: strafe speed fraction (.50 to .95). **Transition Speed**: post-contact follow-through, get-ups, endlag, repeat-contact interval | pace as above; strafe .50 / .65 / .75 / .79 / .83 / .87 / .91 / .95 |
| **ACC** | **Ball Control**: set-column width, ordinary receive and set fidelity. **Timing**: amplifies sweet-contact effects. **Stability**: less execution loss on weaker sets | penalty multiplier 1.50 / 1.15 / 1.00 / .85 / .70 / .55 / .40 / .25 (Stability) |
| **END** | **Cushioning**: additive charge points for the receiver (-8 to +20). **Work Rate**: scales low-Stamina loss. **Capacity**: maximum Stamina (70 to 150) | Cushioning -8 / -4 / 0 / 4 / 8 / 12 / 16 / 20; Capacity 70 / 90 / 100 / 110 / 120 / 130 / 140 / 150 |

Order of effects: multipliers first (Swing Power on charge, Stamina output), additives last (Spike Velocity, Serve Velocity, Cushioning), so a +10 trait is always worth .10 charge.

## 2. Auxiliary stats that traits feed

| Stat | Unit | Granted by (value) | Largest total a build can reach |
|---|---|---|---|
| Serve Velocity | charge points | Power Serve +12, Topspin Serve +6, Jump Topspin +6 | +24 (one 12 AP spine, POW 72 and ACC 70) |
| Spike Velocity | charge points | Big Hitter +10, Flow Hitter +20 (consumes Flow), Revenger +15 (armed), Back Attacker up to +8 by depth | +10 steady, +30 to +45 in bursts |
| Platform Quality | quality-zone overlap points | Platform Quality +6, Transition Hitter +6, Back Attacker +4 | +16 |
| Receive Control | % | Steady Platform +10 | 10 |
| Receive Redirection | % | Guided Dig +12 | 12 |
| Receive Absorption | % | Soft Platform +12 | 12 |
| Charge Tolerance | % slower severity | Charge Tolerance 10 | 10 |
| Recovery | % faster get-up | Fast Recovery 12 | 12 |
| Stamina Recovery | % regeneration | Stamina Recovery 15 | 15 |
| Exertion Efficiency | % less Stamina cost | Exertion Efficiency 12 | 12 |
| Second Wind | % of max Stamina on Winded, 30 s cooldown | Second Wind 23 | 23 |
| Jump Power (armed) | points | Revenger +10 | 10 |
| Jump stamina floor | % Stamina | Never Stay Down 15 | 15 |
| Flow | resource | gained on quality contacts, lost on poor ones; spent or scaled by Flow Hitter, Revenger | n/a |

## 3. The trees as they stand

Reach cost in AP. `needs` shows the primary requirement first; other attributes are "Also Requires". Exclusive groups: the two POW roots are alternatives.

### POW (page: 11 nodes)

| Node | Tier | Needs | AP | Parent | Effect |
|---|---|---|---:|---|---|
| Power Serve | intro | POW 68 | 3 | root, group `power_start` | +12 Serve Velocity |
| Big Hitter | intro | POW 68 | 3 | root, group `power_start` | +10 Spike Velocity |
| Topspin Serve | mid | POW 71, ACC 68 | 9 | Power Serve | +6 Serve Velocity, serves drop more sharply (technique) |
| Com-Pepp-Itor | mid | POW 72 | 7 | Power Serve | +5 HP stolen on a successful Pepper |
| Jump Topspin | late | POW 72, ACC 70 | 12 | Topspin Serve | +6 Serve Velocity, higher toss, Spike Approach after the toss |
| Pepper Patroller | late | POW 75, SPD 72 | 17 | Com-Pepp-Itor | +10 Acceleration after a successful Pepper |
| Flow Hitter | mid | POW 72 | 7 | Big Hitter | next attack consumes all Flow for +20 Spike Velocity |
| Transition Hitter | mid | POW 71, SPD 68 | 9 | Big Hitter | +6 Platform Quality |
| Back Attacker | late | POW 71, SPD 71 | 12 | Transition Hitter | +4 Platform Quality, up to +8 Spike Velocity from further back |
| Revenger | capstone | POW 82, END 76 | 28 | none | after an Attack receive that lowered Flow: next Jump +10 Jump Power, next Attack +15 Spike Velocity |
| Never Stay Down | capstone | POW 87, END 76, SPD 71 | 39 | none | jumps keep full height at low Stamina or Charge until 15% Stamina |

### SPD (page: 2 nodes)

| Node | Tier | Needs | AP | Parent | Effect |
|---|---|---|---:|---|---|
| Quick Step | intro | SPD 66 | 1 | root | double-tap while an action is charged for one burst; 5 s cooldown exploring, 8 s in a rally |
| Dump | planned | SPD 73 | 8 | Quick Step | quick jump-set dump |

### ACC (page: 5 nodes)

| Node | Tier | Needs | AP | Parent | Effect |
|---|---|---|---:|---|---|
| Platform Quality | intro | ACC 68 | 3 | root | +6 Platform Quality |
| Steady Platform | mid | ACC 70 | 5 | Platform Quality | +10% Receive Control |
| Guided Dig | late | ACC 72 | 7 | Steady Platform | +12% Receive Redirection |
| Shoot Set | intro (priced mid) | ACC 72 | 7 | root | faster, flatter set for an immediate attack |
| Back Set | planned | ACC 73 | 8 | Shoot Set | concealed set behind the setter |

### END (page: 9 nodes)

| Node | Tier | Needs | AP | Parent | Effect |
|---|---|---|---:|---|---|
| Rolling Receive | intro | END 68 | 3 | root | dive receive that rolls out, cheaper recovery |
| Second Wind | intro | END 68 | 3 | root | on Winded, regain 23% of max Stamina (30 s cooldown) |
| Charge Tolerance | intro | END 68 | 3 | root | mismatch severity develops 10% more slowly |
| Soft Platform | mid | END 70 | 5 | Charge Tolerance | +12% Receive Absorption |
| Fast Recovery | root at mid price | END 70 | 5 | root | 12% faster get-up |
| Stamina Recovery | root at mid price | END 70 | 5 | root | 15% faster regeneration |
| Exertion Efficiency | root at mid price | END 70 | 5 | root | 12% lower action Stamina cost |
| Pancake | planned | END 73 | 8 | Rolling Receive | floor-sliding save |

## 4. Audit

**The finding that matters most: nothing limits how many traits a base athlete owns.** Ownership is by threshold and picks have no cap. A base athlete (12 AP) that puts 7 into ACC and 5 into END can own **eleven** traits: Shoot Set, Rolling Receive, Second Wind, Charge Tolerance, Platform Quality, Fast Recovery, Stamina Recovery, Exertion Efficiency, Steady Platform, Soft Platform and Guided Dig. The same 12 AP in POW reaches four. So the ACC and END pages are the best base investment by a wide margin, the opposite of the intent that a few lines are desirable and the choice means something. `Deep Bag` already promises a larger "claim limit", which only makes sense if one exists.

1. **Introductory balance.**
   - *Identity:* POW is the clearest (harass with serves, or fight with spikes, exclusive). ACC splits into receive control and set precision but has no exclusive choice, and END has seven roots.
   - *Novelty:* an introductory trait should add one new verb or rule, not only a number. Quick Step, Shoot Set, Rolling Receive, Second Wind and Charge Tolerance do. **Power Serve and Big Hitter are pure numbers** (+12 and +10), so the most important early choice is the least novel.
   - *Early importance:* intro prices run from 1 AP (Quick Step) to 7 AP (Shoot Set) with 3 AP the norm. Quick Step is underpriced for a new verb; Shoot Set is priced as a mid trait but sits at the root.
2. **Intermediate balance.** POW does this well: both spines add one technique or a related number to the intro (Topspin Serve is still a serve, Flow Hitter is still a spike), and Transition Hitter and Back Attacker leave the spike line toward receiving, which is the "approach specialization without wandering" the tier asks for, though a +6 and +4 Platform Quality on a hitter line stacks with the ACC intro to +16 total with no cap. END's mid traits are stat bumps sitting at the root, not intermediates. SPD has no intermediates.
3. **Capstones.** Both are strong and expensive (28 and 39 AP, T3 in the primary line) but both have **no parent**, so they are reached by thresholds alone, not by a path. A capstone should be earned through the lines that justify it. Revenger is a Flow-and-receive payoff with no Flow Hitter or receive trait before it; Never Stay Down is a Stamina payoff with no Stamina trait before it.
4. **Cost shape.** Clean ladders exist (ACC receive line 3, 5, 7 AP; Serve line 3, 9, 12; Hitter line 3, 9, 12). The two POW spines both end at exactly 12 AP, the base budget, which is a nice property and should be kept as a rule: **the deepest node a base athlete can reach costs exactly the base budget.**
5. **SPD is nearly empty.** One real trait, one planned.
6. **Unlinked ideas.** Soft Platform (END) and Steady Platform and Guided Dig (ACC) overlap in intent (a gentler poor receive), differing in the mechanism (absorption, control, redirection). That is fine as a family, but they should be recognisably one family, not three unrelated nodes.

## 5. Rules for each tier *(proposal)*

| | Introductory | Intermediate | Capstone |
|---|---|---|---|
| Thresholds | T1 top: 66–68 | T2: 70–75 | T3 in the primary line: 80+ |
| AP | at most 5 | 6 to 12 | 17 and up |
| Role | the identity of a line: one new verb or rule | specialises one aspect of its parent without leaving its family | turns the line into a build; a rule break or a conditional payoff |
| Power budget | about 10 charge points or one clear verb | up to about 20 if conditional | 20 to 30 conditional, or a unique rule |
| Cross-attribute | one attribute | a second attribute allowed, as a tag | two or three attributes, with prerequisites from each |
| Reached by | the root | its parent | at least two prior picks in different lines of its attributes |
| Cap on stacking | each auxiliary stat has a stated maximum | | |

Base-athlete rule: each attribute has at least two introductory lines that make sense with the other attribute at neutral, and every attribute's deepest base-reachable node costs 12 AP.

## 6. Proposed changes *(proposal, not applied)*

1. **Capacity (done).** Frontier capacity 6, Deep Bag +2, node weights 1 to 3, every fork exclusive (section 0). Supersedes the flat claim limit proposed first.
2. **Give the POW intros a hook.** Power Serve: a serve that forces a receiver into a recovery gives the server some Flow. Big Hitter: spikes that land clean give extra Flow. This also introduces Flow earlier than Flow Hitter does, and keeps +12 and +10 as the numbers.
3. **Restructure END** into two exclusive starts: *economy* (Second Wind, then Stamina Recovery and Exertion Efficiency beneath it) and *durable receiver* (Rolling Receive, with Fast Recovery and Pancake beneath it; Charge Tolerance and Soft Platform as a second step). The three trait roots at 70 become children.
4. **Fill SPD** with three introductory lines at 68: Quick Step (the burst verb, raised from 66 to 68), a *reaction* line (extra pace for a moment after an opposing contact, linking to Transition Speed), and a *rotation* line for the map (faster movement outside a rally). Dump stays a mid trait under Quick Step. One SPD capstone (for example an extra Quick Step charge with a shared cooldown).
5. **ACC set line:** add a cheaper introductory set trait at 68 that narrows the set column or lowers set error, make Shoot Set a mid trait at 72 under it, and make the receive-control and set-precision starts exclusive.
6. **Link the capstones.** *(The model now supports it: `requires`. The two capstones are still flagged standalone with no prerequisites, awaiting the archetype design.)* Revenger would require Flow Hitter and a receive Trait; Never Stay Down a Stamina Trait.
7. **Cap the stacks.** Platform Quality at +12 total; Serve Velocity at +24; a stated maximum for Spike Velocity bursts.
8. **Keep the 12 AP rule** for the deepest base-reachable node, and state expected AP by level so the capstone prices (28 to 39 AP) can be checked against the real progression.

## 7. AP economy (from the designer) and what it does to the tree

Three sources feed an athlete after creation:

1. **Automatic attribute growth by position, per level.** Wall (MB) +2 END, Playmaker (S) +2 ACC, Anchor (L) +2 SPD, All-Rounder (OH) +1 to every attribute. These are free rating points, not AP.
2. **Freely allocable AP per level, which differs by position through its innate.** Fast Study (OP) gives +3 AP on level-up. The base amount for a position without such an innate is not yet fixed.
3. **AP from Nets falling** (`docs/laning-and-objectives.md`): every member of the winning team gets 2 (Primary), 3 (Secondary) or 4 (Tertiary), and allies near the fall share double the Net's value (4, 6 or 8; the first Net of the match adds 2). A team that takes all three Primaries, three Secondaries and the Tertiary earns up to 19 AP per member from global awards in one match, before local shares.

Level cap is 20, so there are 19 level-ups. Growth alone reaches these ratings by level 20 (rating 65 plus growth, capped at 99):

| Position | Automatic growth | Rating by level 5 / 10 / 20 | Level at which a T2 line (70) / T3 line (80) is reached free |
|---|---|---|---|
| MB | END +2 per level | 73 / 83 / 99 | 4 / 9 |
| S | ACC +2 per level | 73 / 83 / 99 | 4 / 9 |
| L | SPD +2 per level | 73 / 83 / 99 | 4 / 9 |
| OH | every attribute +1 per level | 69 / 74 / 84 | 6 / 16 |
| OP | none, +3 AP per level | 65 / 65 / 65 (plus 57 AP spent where wanted) | n/a |

**Consequences for the design**

- **AP reach cost overstates the real cost in a position's growth attribute.** A Wall's END 76 requirement (Revenger, Never Stay Down) is free by about level 7, and the whole END page is unlocked by level 9. So the END tree will be fully available to MBs and the ACC tree to Setters regardless of pricing, which makes a **claim limit** and exclusive branches more important, not less, and means a growth attribute's traits cannot be strong enough that owning all of them breaks the game.
- **Cross-attribute capstones decide position identity.** Pairing a requirement in the position's growth attribute with one in an attribute it must pay AP for gives each position a natural capstone: Revenger (END 76, POW 82) is a Wall's capstone, paid for in POW; a Playmaker or Anchor would reach it only by spending on both.
- **All-Rounder (OH) and OP are the two without a free lane.** OH is slow everywhere (80 in every attribute is level 16); OP buys exactly what it wants with 57 extra AP. Neither is hurt by a claim limit, which is also a reason to keep it low at first.
- **Creation AP (12) and the later economy are separate tools.** The rule "the deepest node a base athlete can reach costs exactly 12 AP" is about creation only. Later costs should be read as "AP-equivalent": growth points count as free, so the useful price of a capstone for a position is its AP cost minus what growth pays.
- **Net falls are a burst source (up to 19 AP per member per match), not a trickle.** Capstones priced at 28 to 39 AP are therefore a few matches of a winning team's rewards on top of levelling, which fits "late, build-defining", but a trait that is only reachable through Net AP will be unevenly available between winners and losers. Keep the ratings that carry the early and mid tree reachable from levelling.

## 8. Open numbers

- The base freely allocable AP per level for a position without an AP innate, and the other positions' AP innates.
- The experience curve (how many matches per level), to turn the per-match Net AP into a level estimate.
- The claim limit, and whether Deep Bag is +1 or +2.
- Whether auxiliary stats such as Platform Quality share a cap across traits, or each trait caps itself.
