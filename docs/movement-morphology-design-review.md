# Movement, morphology and momentum: design review (Claude), 2026-10-20

Accepted as the design direction: the handoff of 2026-10-20 and Codex's gap review (`movement-morphology-handoff-review.md`). Nothing here is implemented; no coefficient is adopted. This review judges whether each change is good for the game and whether it is feasible on the current model.

## Verdicts

| Change | Good? | Feasible? | Verdict |
|---|---|---|---|
| Stability mitigates momentum | Yes: gives ACC's weakest subattribute a job | Medium: needs a shared momentum layer | Adopt, but fix the attribute mismatch (below) |
| SPD raises the Sprint modifier, not base speed | Yes: SPD becomes a commitment stat | Medium: `speed()` feeds approach, bounds, dives | Adopt, with Libero safeguards |
| Height sets base speed; Stride adds | Risky: height becomes the best free stat unless low Height is paid back | Medium | Adopt only with measured parity |
| Relative Wingspan/Stride Length at creation | Risky: a new creation axis with no budget | Hard: schema, migration, UI, visuals | Defer until the exchange rate and bounds exist |
| Work Rate as additive post-mitigation cost cut | Doubtful as written (floor, units, stacking) | Medium | Redesign before building |
| Sprint-state action modifiers | Good if reduced to one rule | Medium | Adopt as one rule |
| Receive aim transformation (forward, up, back) | Yes: backward bumps are real volleyball | Medium | Adopt, blended with the shank model by quality |
| Impulse, Twitch Dive | Yes: cheap, uses existing hooks | Easy | Adopt |
| Quick Takeoff | Interesting | Hard: a new pre-contact phase | Last |

## Critical findings

1. **Stability does not match the actions that suffer most.** The action matrix gives Receive SPD and END, Block END and POW; Stability is ACC. Momentum hits Dives and Receives hardest, which are the Libero's and Wall's actions, yet the mitigator belongs to a Setter's attribute. A Libero (Anchor grows SPD) would pay AP in ACC to fix its main penalty. Either name an SPD/END mitigator for receives and blocks (Transition Speed or Reaction Speed are the nearest), or accept Stability as universal and price it into the Libero path.
2. **A Libero becomes a Stamina hog.** Short athletes are slow at base speed, SPD now only helps while sprinting, and Sprint costs 10 Stamina/s in a rally. The position that most needs coverage pays the most to get it. The compensation (low-Height geometry, Work Rate) is unquantified. This is the biggest balance risk.
3. **"Asymmetrically powerful low-Height benefits" is a promise with no value.** Until it has numbers, tall is simply better at reach and base speed. Set an acceptance test first: across the Height range, at equal AP, no body type is strictly dominant on coverage per Stamina, contact quality by contact height, or low-receive success.
4. **Work Rate has four problems.** (a) Additive cuts are proportionally strongest on cheap actions, so a small, high-Work-Rate athlete can approach free actions; a floor is needed. (b) Continuous drains need a per-second adjustment times dt (Codex's point). (c) It stacks with Exertion Efficiency (multiplicative), Stamina Recovery and Second Wind, so "never tired" builds appear; keep subattribute and traits from covering the same ground. (d) Its current job (softening low-Stamina output loss) must be kept or deliberately replaced.
5. **Sprint semantics should be one rule.** Receive suppresses input, Approach gains range, Jump Set and Block Jump keep or drop momentum: four meanings of one key. Reduce to "Sprint held at initiation commits momentum (more reach, less control); released is controlled", applied uniformly. Today set and block jumps key off movement-input presence (85% versus 15% carry), so this changes existing feel and needs a reference check.
6. **Momentum on every receive adds noise to the most frequent contact.** Make it deterministic and visible in the existing trajectory preview, and use alignment (along versus across the intended direction), as proposed, so a player can learn it. Keep it behind a switch until bots and the preview agree.
7. **Confirmation currently erases grounded momentum.** Sample a committed pre-lock velocity for ground actions and actual velocity for air actions, as Codex recommends; do this before anything depends on it.
8. **Three new morphology numbers need a budget.** Height, Wingspan and Stride Length: if Wingspan versus Stride is a free slider it will be pushed to a corner. Bound the range (a few percent either way), make it AP-neutral, and let the cost differences (arm versus leg Stamina) be the price. Tiny and Giant already cost 10 AP, so do not let them be bypassed through proportions.
9. **Receive aim mapping must blend with failure.** On a quality contact use the intended mapping; as quality falls, blend into the existing shank reflection. A hard switch would make poor contacts feel arbitrary. Keep Platform Quality, Receive Control, Redirection and Court Vision meaning what they do now.
10. **Quick Takeoff is a different subsystem.** MoC today starts at impact and steers the ball; a takeoff window steers the athlete before contact. It needs its own phase, actor clock and a decision on slowdown, HP cost and carried momentum. It is the highest risk item and the one least needed to test the rest.

## Costs the handoff does not mention

- Every contact path exists for the player, bots, Pepper partners and the preview; each new layer must be wired through all four. About 105 test suites exist and several assert speeds, stamina and receive output; changing `speed()` will invalidate some.
- Saves: relative morphology needs a versioned migration that keeps the old absolute span.
- Bots use configured speed, not measured travel; momentum needs measured velocity for them.

## What the tree can do now

Impulse (Explosiveness and Acceleration rating points), Twitch Dive (dive travel and speed) and the fork can be authored with the existing effect keys. They need only values, requirements and capacity weights, and these are open. Quick Takeoff and any momentum or Sprint effect keys must wait for Codex's contract revision. SPD has one node, so the SPD page (Quick Step, Impulse and its fork, Graceful Steps and its Flow line) still needs a layout pass.

## Recommended order (agrees with Codex, with two additions)

1. Freeze reference behaviour: an athlete at the neutral band must play exactly as today. Write that test first.
2. Typed stamina costs and Work Rate redesign, with a 30/60/120 Hz test.
3. Base speed versus sprint modifier, with the Libero stamina simulation.
4. Sprint-state rule.
5. Momentum layer, Stability and (if chosen) the SPD/END mitigator.
6. Receive aim transformation with the low-contact morphology effects.
7. Relative morphology at creation (after the budget exists).
8. Impulse and Twitch Dive (can be done early, independent of the rest). Quick Takeoff last.

Acceptance for the whole package: no strictly dominant body, a Libero can cover a rally on the same Stamina as other positions with sensible play, and every new effect is readable in the preview before contact.
