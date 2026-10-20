# ACC outcomes: a preliminary pass

Outcomes only, no tree. Meant for the designer to react to, add auxiliary traits and builds to, and prune. Nothing is in the data.

## What ACC has to work with

- **Actions:** ACC is primary for Set and secondary for Attack.
- **Subattributes:** Ball Control (set-column width and ordinary receive and set fidelity), Timing (amplifies sweet-contact effects), Stability (less execution loss on weaker sets).
- **Already in the tree:** Platform Quality, Steady Platform (Receive Control), Guided Dig (Receive Redirection), Shoot Set, a planned Back Set.
- **Positions:** a Setter grows +2 ACC a level and has minimal HP cost on Sets. A Libero grows +2 SPD, with END as the other receiving attribute, and pays minimal HP and Stamina on Receives. So a Setter's ACC outcomes are nearly pre-paid, and a Libero's ACC outcomes cost real AP.
- **Known intentions:** Tricky (an ACC-first deception path with POW behind it), Float Serve and Hybrid Server (which needs Jump Topspin and a float serve), Trickster's Sense (a Setter Flow Trait that disrupts opponents).

## The outcomes

| Outcome | Shape | Typical positions | Identity | Main stats |
|---|---|---|---|---|
| **Playmaker** | vertical | S | A Setter's craft: tempo sets, set quality, hitters made cheaper to feed | Set quality, Stability, Shoot Set and Back Set |
| **Pass Master** | vertical (receiving) | L, OH | Clean receives, then a capstone where a clean pass gives the next ally contact a bonus | Platform Quality, Receive Control, Receive Redirection |
| **Distributor** | supplemental, ACC and SPD | L, S | The receiver as the team's first setter: placement of the pass and an ally Flow or Timing bonus | Receive Redirection, a new ally effect |
| **Reader** | supplemental, ACC and SPD | L, OH | Anticipation: a first-step bonus and an early read of the incoming ball's direction | a new Anticipation stat, Acceleration |
| **Stabilizer** | supplemental, ACC and END | L, MB, any | Execution quality that holds up when tired | Stability, Stamina interaction |
| **Tricky** | hybrid, ACC first | S, OH | Deception, and an attack that is a credible threat, so a setting opportunity may not be a set | set disguise (new), dump, a little POW |
| **Float Server** | secondary | S, OP | The ACC counterpart to Big Server: an unpredictable serve with no Spin | Float (new) |
| **Hybrid Server** | advanced | OP, S | Needs Jump Topspin and a float serve owned | Spin and Float |
| **Disruptor** | support | S, L | Disrupts opponents: Charge Tolerance debuffs, slowed block reactions | opponent-affecting effects (new) |
| **Clutch Timer** | supplemental | any | Exceptional access to Timing: bigger sweet-contact effects for any action | Timing bands |

**Libero-supportive outcomes:** Pass Master, Distributor, Reader and Stabilizer. Each is cheap to enter and flat to deepen (the supplementary shape), with requirements that lean on SPD and END, which a Libero grows for free.

## Investment relationships

- **Setter:** Playmaker, Tricky and Float Server are pre-paid by ACC growth, which is why they should not also be cheap in AP. Big Server, a POW path, is the Setter's expensive secondary identity.
- **Libero:** Pass Master is the natural vertical, and the cheap early nodes (Platform Quality at ACC 68) are the best AP a Libero can spend on ACC. Reader and Distributor use their free SPD.
- **POW and ACC:** both lines may grant Broad Range and Court Vision. POW lines add power-focused attacking improvements; ACC lines add passing and setting improvements, and should also carry independent offensive utility and potency. What separates them is the attribute requirement, which enforces the use case: a standard setter rarely uses power but constantly uses accuracy, so Tricky is the natural pick over Spotter because their growth reaches it far more cheaply.
- **Serving:** Big Server (POW) is a steady, Spin-curved serve; Float Server (ACC) is an unpredictable one. Hybrid Server needs both lines owned.

## Where this could go wrong

- **Ally effects.** Pass Master's capstone, Distributor and Disruptor rely on an ally- or opponent-affecting effect. The set-to-attack bonus (pending, not in the game; the contact docs call it 'Set/Attack transfer' and 'setter-granted attack efficiency', and the registry profile is 'Attack Transfer') is intended as the main vector for ally support, so ACC ally effects should be designed around it.
- **Quiet payoffs.** ACC has the fewest direct damage outcomes. Each outcome needs a payoff a player can see in a rally.
- **Libero's AP.** A Libero's ACC outcomes cost AP while their SPD and END come free; if their ACC outcomes are the only strong ones, the position is pushed into a page it does not grow in.
- **Overlap with POW:** not a risk; requirements decide who takes which line (see above).

## Opportunities for auxiliary traits and builds (for the designer)

Float (serve unpredictability), set disguise, Anticipation, Receive Distribution (the ally bonus), a Stamina-neutral Stability trait, a Timing-band Trait (like Terminal Hitter's access to Swing Power), setter Flow Traits beyond Trickster's Sense, and which ACC outcomes should require a Flow-effect slot given the one-Flow-effect limit.

## ACC structure as specified (2026-10-20; not in the data)

Placement is the name for the set-to-attack buff (the 'Attack Transfer' stage). Names and numbers are the designer's unless marked.

**Broad Range (starter), three paths**
- *Setting:* Broad Range → One Handed Set → Fingertip Set. Each step reduces edge-hurtbox penalties on sets, until they are nearly nullified.
- *Receiving:* a Broad Range receiver path (unspecified).
- *Trickster (dotted):* also requires the Anticipation line. Trickster = some more Broad Range + the earlier Flow effect.

**Anticipation** (formerly Flow Setter): "Flow 30: Your Sets gain +10 Placement. You lose all Flow upon Rescuing a Set, or when an Attack from your Set is Blocked." Its own Flow line follows; the first step converts part of the Placement buff into a passive additive. No ACC receiving-Flow path: that belongs to SPD.

**Steady Arms (starter)**
- *Setting:* Safe Hands → fork: Back Set, or In the Pocket (grants Placement like the Flow line, passively; redundancy with Anticipation is accepted).
- *Receiving:* a path using the three receive auxiliaries (Receive Absorption, Receive Control, Receive Redirection). Soft Platform (+12% Receive Absorption, END 70) is an existing END node, not a new one; the auxiliaries can sit in both pages.

**Back Set → lines**
- *Playmaker:* the main source of non-Placement buffs. Shot Caller: SPD aura to the first two allies who charge an Attack. Capstone Motion Offense: three allies, plus some END.
- *Sniper:* Shoot Set (Charge Tolerance to attackers hitting your sets), capstone Bullet Set (more Charge Tolerance). Requires Ball Control. Rule noted: higher charge on any contact adds aim variance, penalised further by Directional Influence; Ball Control combats it.
- *Trickster (conditional):* Dump, an active, input like Quick Step, midair and only holding a Set; makes the Setting hurtbox act as an Attack in the movement direction (Swing Power affects Dumps less than Attacks). Capstone Endless Options (effect undecided).
- *Join:* Trickster connects dotted to a node already on the Back Set line. Running totals mean it restates Back Set's effects, so it gains them without owning Back Set.

**Open:** Placement's unit and stacking with In the Pocket; how much of Anticipation's buff becomes passive; Dump cooldown/cost; Endless Options; Broad Range receiver path contents; whether Anticipation counts as a Flow effect against the one-per-build limit (it should).

## Revisions, 2026-10-20 (second pass)

- **SPD's planned Dump is removed** (`speed_dump` in the data, `PLANNED` in `athlete_store.gd`). Dump now exists only as the ACC Trickster-line active.
- **Trickster requires both Broad Range and Anticipation** (two `requires`, each keeping its own slot).
- **Setting has a floor and a ceiling.** A setter who avoids Back Set must still succeed; their options are narrower and they seek other solutions (Broad Range setting line, Anticipation, Safe Hands/In the Pocket).
- **Parallel lines are legal.** Broad Range's short vertical line (One Handed Set, Fingertip Set) is separate from Back Set, and a player may also take the Anticipation line and the Safe Hands line. Taking all of them is possible. A Back Set player may take them too: branching logic makes that safe.
- **Trickster is the exclusion.** Taking Trickster consumes Broad Range and Anticipation as current Traits, so the full standard Flow line and the full Broad Range line are no longer available alongside it. A Trickster build also keeps the Steady Arms tree only up to the Trickster line.
- **Supplementary lines are guarded by sub-attributes.** They are separated from the vertical line and require specific sub-attribute values on top of the ACC threshold, so natural sub-attribute development cannot reach an early keystone.
- **The cost of a supplementary line is space and rules, not AP.** Collecting every setting node in parallel is possible, but it spends capacity and the one-Flow-effect limit, and leaves no room for anything else.
- **Serving: needs an ACC Serve Velocity starter**, leading to Float Serve and Hybrid Serve (Hybrid also needs the POW serve line owned).

## Revisions, 2026-10-20 (third pass)

- **Broad Range receiver path:** uses Broad Range (edge of the hurtbox) and also Receive Redirection.
- **Anticipation's line:** Anticipation, then **Foresight**: "Your sets gain +10 Placement. Flow x (same as the other one). Your next sets consume Flow to gain t power." The text as given is incomplete ("t power", the Flow cost); not yet in the data.
- **Placement is an additive stat.** Anticipation and the later Flow nodes on its path stack Placement and Flow State along the line (written as running totals). **In the Pocket** (mostly Placement, passive) stacks with them because it starts from a different tree with no shared adjacency, so a build can own both.

## Revisions, 2026-10-20 (fourth pass)

- Trickster is a **merge** of Broad Range ACC and Anticipation (new `merges` field); Dump branches off Back Set and requires Trickster.
- Foresight costs Flow 30 and does what Anticipation does, plus a passive (built as +10 Placement on Flow and +4 always; the +4 is provisional).
- ACC serve starter (name open, built as "Steady Serve", +8 Serve Velocity, slightly under Power Serve's +12) → Float Serve, or Hybrid Serve (requires Power Serve owned).
