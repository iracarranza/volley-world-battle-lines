# Trait tree against League of Legends' item system: outcomes, not a model

A comparison of what each system *produces* in play and in the shape of a build, using the item system (components become epics become legendaries; components introduce stats and some stats arrive only with epics; some epics and most legendaries carry passives; almost any combination can be bought, with exclusivity only between items that share a passive family; Doran starters left out) as a reference for the questions to ask. It does not propose reshaping the tree into that model. Figures come from `data/trait_tree.json` as of 2026-10-19 (23 live nodes, rules: capacity 6, Deep Bag +2, exclusive forks) and `docs/laning-and-objectives.md`.

## 1. What the reference system produces

1. **Reactive, repeated decisions.** Items are bought many times in a match, in response to the game (who is ahead, what the enemy builds). The decision is tactical as well as strategic.
2. **A steady power curve with spikes at completions.** Components give small, even gains; a finished item is a spike that also adds a passive.
3. **Stat efficiency that is nearly linear in price.** More gold is more stats, with passives as the premium on top.
4. **Slot pressure all game.** Six slots mean something is always being sold or skipped.
5. **A very large but navigable build space.** Almost anything is buildable, yet a handful of builds dominate each role. The meta, not the rules, narrows it.
6. **Counter-building.** Whole item classes exist because other items do.
7. **Cheap undo.** Selling refunds most of the price, so a bad purchase is a small loss.
8. **Identity by purchase.** A character's kit biases what is worth buying; nothing forbids anything.

## 2. What the tree produces

Evidence in brackets.

**A permanent, identity-level decision, not a tactical one.** Traits are chosen once and dropped only by lowering ratings. A trait cannot be sold for most of its cost, because the AP that unlocked it went into a rating. The decision happens at creation and in level-ups, with Net falls as the in-match income. So a trait choice answers "what kind of athlete am I", where an item choice answers "what do I need now". The tree has no reactive loop of its own; the reactive loop lives elsewhere (Flow, Directional Influence, charge matching).

**The cost of a Trait is not its own.** Ratings are shared thresholds, so the second Trait at a threshold is free. [Power Serve and Big Hitter are both POW 68 and cost 3 AP together; END has six parentless nodes at 68 and 70; before capacity existed, 12 AP bought 11 Traits.] The effect is the opposite of the item system's per-item price: **wide is cheap and deep is dear**, whatever the tiers intend.

**Stat efficiency falls with depth, then jumps on conditions.** Serve and Spike Velocity per marginal AP along each line:

| Line | Step | Marginal AP | Gain | Per AP |
|---|---|---:|---|---:|
| Serve | Power Serve | 3 | +12 SV | 4.0 |
| Serve | Topspin Serve | +6 | +6 SV and a technique | 1.0 |
| Serve | Jump Topspin | +3 | +6 SV and a technique | 2.0 |
| Hitter | Big Hitter | 3 | +10 SpV | 3.3 |
| Hitter | Rhythm Hitter | +4 | +20 SpV when Flow is present | 5.0 conditional |
| Hitter | Back Attacker | +5 over Transition | +8 SpV by depth, +4 PQ | about 2.4 |

The cheapest, most efficient AP in the tree is the first step of every line. Deeper steps buy techniques and conditions at a worse rate, apart from Rhythm Hitter, whose unconditional-looking +20 is the best number on the page once Flow exists. In the item system the finished item is usually no better value per gold than its parts; here the first node is the bargain and later nodes are paid for in something other than efficiency.

**Ratings are a sawtooth, so AP has dead zones.** A band holds one stat value, so a point between two band edges does nothing on its own. [Trait thresholds sit at 66, 68, 70, 71, 72, 75, 76, 82 and 87; five nodes sit at exactly 70.] The result is that players cluster their ratings on trait thresholds and band edges and skip the points between. Stats in the item system are smooth, so a purchase is never wasted; here a purchase can be.

**Capacity does almost nothing today.** With every fork exclusive and one start per page, a build has at most one current Trait per page plus any standalone capstone: four frontier slots at weight 1 against capacity 6. Capacity only starts to bind once weights above 1 exist (today only the two capstones, at 3). The slot pressure that runs through the whole item game is absent. [With weights as they are, valid builds use up to 10 capacity, so capacity binds only at the top.]

**The build space is small and mostly decided by the rules.** [3,200 structurally valid builds, 1,897 within capacity 6, 217 at creation; with forks open 98,304.] The item system's space is huge and narrowed by players; here it is narrowed by the forks before anyone plays. Fewer builds means each is easier to solve, so the question to ask is how many of the 217 are actually different athletes.

**Position growth pre-pays pages.** A Wall gains +2 END a level and reaches END 70 around level 4, 80 around level 9. [The position table in `docs/trait-master-list.md`.] So the page a position grows into is unlocked without spending, where the item system makes every character pay for every item. The result is strong positional identity, at the price that a growth page contains few real decisions for that position.

**Income is bursty, and the strongest nodes depend on it.** [A team that takes all three Primaries, three Secondaries and the Tertiary earns up to 19 AP per member in one match; the capstones cost 28 and 39 AP.] Gold in the item system trickles. Here the late tree is reached on Net falls, which go to the team that is winning, so a capstone is likelier for the team that already holds the lanes. That is a snowball by construction.

**Passives sit where the item system puts them, mostly.** [Both capstones are conditional passives; Rhythm Hitter and Topspin Serve add a spender and a technique at the middle; the components are mostly a stat or a single verb.] The exceptions: Second Wind is a passive at the component price, and Guided Dig, the deepest ACC node, adds only a stat.

**Stats arrive by tier, loosely.** Receive Control, Absorption and Redirection are only in the middle and deep nodes, which is the same shape as epic-only stats. Platform Quality appears at the component, the epic and the legendary, so it is a stat that grows rather than one that is introduced.

**Counters are structural, not item-shaped.** Spike and Serve Velocity are additive on the attacker's side and Cushioning and Charge Tolerance on the receiver's, so the arms race is built into the stats rather than into counter-traits. The tree has no Trait whose only job is to answer another Trait.

**Reversal is expensive.** There is no sell. [Dropping a pick keeps the AP in the rating.] A wrong early choice costs more than a wrong item.

## 3. Side by side

| Outcome | Item system | Trait tree now |
|---|---|---|
| When decisions happen | Constantly, reactively | At creation and level-ups, with Net AP as in-match income |
| Price of one piece | Its own | Shared through ratings (wide is cheap) |
| Value per cost | Roughly constant, passives on top | Highest at the first node, falling, then conditional spikes |
| Smoothness | Smooth | Banded, with dead points |
| Slot pressure | Constant | Close to none (one slot per page at weight 1) |
| Space of builds | Huge, narrowed by the meta | Small, narrowed by the rules |
| Undo | Cheap | Expensive |
| Who gets the late game | Whoever farms | The team holding the lanes |
| Free stats from the character | Base stats and growth | Position growth, strong enough to pre-pay a page |
| Counters | Counter items | Stats on both sides |

## 4. Questions this comparison raises

These are questions, not changes.

1. Is a Trait choice meant to be an identity decision, or should some of it be reactive within a match? The tree cannot be both without a way to undo.
2. Should wide be cheap? Today it is, and exclusivity is what hides it. Is that the intended pressure?
3. Where should power be paid for: in AP, in slots, or in both? Today deep nodes pay AP and (at weight 2 or 3) slots as well, while the item system makes price the single brake.
4. Is the dead-zone sawtooth meant to produce clustering on thresholds, or is it a side effect?
5. Is a snowballing late tree acceptable, or does the team behind need a way to reach it?
6. Are 217 starting builds the right size of space, given how few are distinct?
