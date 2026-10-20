# Volleyball MOBA — Attribute Trait Tree Design Handoff

**Status:** Design framework established; POW archetype planning in progress.  
**Scope:** Attribute Traits, specialization paths, auxiliary stats, investment identities, and position-specific build incentives.  
**Purpose:** Preserve current design decisions and provide a basis for developing the actual Trait trees.

---

# 1. Core Design Philosophy

The Attribute Trait Tree is intended to produce distinct athlete builds through combinations of attribute growth, subattribute specialization, and unlockable Traits.

The design process has shifted from **inventing individual Traits and arranging them into trees** toward **identifying the athletes and playstyles that should emerge from investment**, then working backward to determine which Traits and requirements produce those outcomes.

The fundamental progression relationship is:

**Attribute investment → Subattribute specialization + Trait access → Distinct athlete playstyles**

These are related but separate systems.

## 1.1 Attributes

There are four primary attributes:

- **POW — Power**
- **ACC — Accuracy**
- **SPD — Speed**
- **END — Endurance**

Attributes improve an athlete's underlying capabilities and provide access to Traits.

Each attribute has its own dedicated Trait page, rather than sharing a single unified visual tree.

A Trait is listed under its **primary attribute**, even when it requires investment in another attribute. Cross-attribute requirements should be displayed on the Trait itself, for example:

`Also Requires: 12 ACC`

The example value is illustrative, not an established threshold.

Cross-attribute Traits should not be duplicated on both pages.

## 1.2 Subattributes are not Traits

This distinction is fundamental.

The twelve subattributes represent competing avenues of further specialization within the four primary attributes.

They modify underlying performance characteristics, including:

- Action pace.
- Charge multipliers.
- Strafing and movement characteristics.
- Stamina behavior.
- Cushioning.
- Action penalty multipliers.

**Subattributes must not appear as Trait nodes.**

A Trait may exceptionally modify or enhance a subattribute, but that is a special privilege granted by the Trait rather than a reason to incorporate subattributes directly into the tree.

For example, Terminal Hitter is intended to gain exceptional access to improvements affecting Swing Power and Jump Power.

That does not mean Swing Power and Jump Power should themselves become ordinary Trait nodes.

The complete definitions and numerical bands for all twelve subattributes are documented in `docs/trait-master-list.md`, which is not currently available for direct inspection.

## 1.3 Traits

Traits are unique capabilities or improvements that arise naturally from attribute growth and specialization.

They can include:

- New techniques or actions.
- Modifications to existing techniques.
- Improvements to auxiliary gameplay properties.
- Exceptional access to mechanics or performance improvements normally associated with other attributes.
- Selective enhancements to subattributes that ordinary attribute progression cannot provide.

Traits are not merely another means of increasing the ordinary subattribute statistics.

Some Traits can be relatively straightforward numerical improvements, such as `Platform Quality +X`, provided that the improved property is an auxiliary gameplay statistic rather than a subattribute.

Other Traits can introduce entirely new gameplay interactions.

Both belong in the Trait system.

---

# 2. Established Introductory Traits

The first four nodes of the existing Trait tree correspond to the four attributes.

Each attribute has an introductory Trait.

| Attribute | Introductory Trait | Function |
|---|---|---|
| POW | Power Serve | Increases serve velocity per unit of charge |
| ACC | Shoot Set | Reduces the hitter's HP cost and power penalty on fast sets |
| SPD | Quick Step | Allows one eight-direction movement burst per prepared action |
| END | Rolling Receive | Enables a special receiving animation and contact at the edges of the receive hurtbox |

## 2.1 Power Serve — POW

Grants a fixed, relatively small velocity bonus per unit of serve charge.

The bonus stacks with ordinary POW-based serve performance.

This is a direct enhancement to an existing volleyball action rather than a new serving technique.

## 2.2 Shoot Set — ACC

Reduces the hitter's HP cost and power penalty when attacking fast sets.

This Trait has been designed but was identified as not yet implemented in the earlier audit.

Its purpose is to make faster offensive tempos more practical and effective.

## 2.3 Quick Step — SPD

Grants one burst of movement in any of eight directions per prepared action.

Established costs:

- 3 HP.
- Approximately half the Stamina cost of a jump.

Quick Step provides an additional positioning tool without simply increasing ordinary movement speed.

## 2.4 Rolling Receive — END

Activates when an athlete confirms a receive at the sour spots, located at the widest edges of the receiving hurtbox.

Established behavior:

- Costs 5 additional HP beyond the normal receive cost.
- Does not receive the Libero's normal discount on that additional cost.
- Sends the ball high in the athlete's facing direction.
- Locks the athlete out of further action until the rolling animation finishes.

Rolling Receive improves the athlete's ability to recover otherwise difficult balls, but requires an additional resource and recovery commitment.

---

# 3. Auxiliary Statistics

The latest Claude audit identifies the following auxiliary gameplay properties.

| Auxiliary property | General function |
|---|---|
| Serve Velocity | Velocity imparted to serves |
| Spike Velocity | Velocity imparted to spikes |
| Platform Quality | Quality of the receiving platform |
| Receive Control | Control over reception |
| Receive Redirection | Ability to redirect received balls |
| Receive Absorption | Ability to absorb incoming ball power |
| Charge Tolerance | Tolerance for charge-related demands |
| Recovery | Action recovery behavior |
| Stamina Recovery | Stamina regeneration |
| Exertion Efficiency | Efficiency of resource expenditure |
| Second Wind | Named resource-related auxiliary effect |
| Revenger's Jump Power | Named jump-related auxiliary effect |
| Never Stay Down's Stamina floor | Named minimum-Stamina effect |

These properties are not all equivalent.

Some are broadly applicable performance statistics, while others are associated with particular named effects.

The audit reportedly documents the source of each auxiliary and the largest total attainable by a build.

**The exact values and acquisition rules have not been supplied in this conversation and must not be reconstructed as established facts.**

Additional auxiliary concepts identified during POW archetype planning include:

- **Broad Range:** Improves the effective reach of Directional Influence and the efficacy of contact at the edges of the spiking hurtboxes.
- **Court Vision:** Improves the strength and cost-effectiveness of Directional Influence's trajectory modification.
- **Spin:** A serving specialization property associated with Big Server.

Their exact numerical implementation remains to be determined or recovered from the existing design.

---

# 4. Action–Attribute Matrix

The following relationships are established:

| Action | Primary attribute | Secondary attribute |
|---|---|---|
| Attack (ATK) | POW | ACC |
| Set (SET) | ACC | SPD |
| Receive (REC) | SPD | END |
| Block (BLO) | END | POW |

These relationships are central to Trait tree planning.

They establish why different positions naturally develop different attribute distributions and why the same Trait path can have very different investment costs depending on the athlete.

The matrix does not prescribe fixed attribute allocations by position.

It describes the attributes most directly associated with performing each volleyball action.

## 4.1 Position-specific demands

**Outside Hitter (OH)**

Typically has reasons to invest in both attacking and receiving performance, with possible blocking responsibilities.

This creates competing incentives across POW, ACC, SPD, and END.

OHs are particularly plausible users of hybrid paths because their responsibilities already encourage diversified investment.

**Opposite (OP)**

Often has strong incentives toward offensive specialization, making deep POW investment attractive.

Terminal Hitter, Big Server, and certain offensive hybrid paths are natural possibilities.

**Middle Blocker (MB)**

Has a significant END demand because blocking is END-primary.

POW also contributes to blocking and serves as the primary attacking attribute.

An MB pursuing POW/ACC specialization must divert investment into ACC while maintaining sufficient END to fulfill blocking responsibilities.

This makes the investment structure of offensive hybrid paths especially consequential for MBs.

**Setter (S)**

Naturally requires substantial ACC investment because setting is ACC-primary.

SPD is the secondary setting attribute.

A Setter may therefore access ACC-compatible POW paths at relatively low marginal cost compared with positions that do not already require ACC.

Big Server is an important example.

**Libero (L)**

Naturally prioritizes receiving capabilities, especially SPD and END.

Deep POW investment is not an expected default, although unusual builds should not necessarily be prohibited.

These are incentives, not positional restrictions.

---

# 5. POW Tree — Established Archetype Outcomes

POW currently has eight identified archetype outcomes.

They fall into four groups:

**POW Vertical**
- Terminal Hitter
- Big Server

**POW / ACC**
- Broad Range
- Spotter
- Tooler

**POW / SPD**
- Transition Attacker
- Burst Attacker

**POW / END**
- Jackknife

The archetypes represent intended build outcomes, not necessarily single Trait nodes.

Each may eventually consist of multiple Traits, auxiliary improvements, and attribute requirements.

---

# 6. POW Vertical Archetypes

## 6.1 Terminal Hitter

**Typical positions:** OP, some OH and MB.

**Investment identity:** Expensive vertical specialization.

Terminal Hitter prioritizes maximum attacking lethality through:

- Spike Velocity accumulation.
- Exceptional improvements to Swing Power.
- Exceptional improvements to Jump Power.
- Some minor END investment.

Its defining privilege is the ability to directly enhance subattributes beyond what ordinary attribute progression provides.

This makes Terminal Hitter an intentionally demanding path.

Its substantial POW requirements compete with the athlete's ability to develop other aspects of their game.

### Intended gameplay identity

Terminal Hitter is designed to maximize the quality and power of the eventual attacking contact.

It should excel when provided with favorable attacking opportunities.

Its ceiling in raw terminal offense should be extremely high.

### Investment tradeoff

The athlete pays for this exceptional offensive output through limited flexibility.

Deep specialization leaves fewer resources available for receiving, blocking, setting, or other specialized capabilities.

This is intentional.

Terminal Hitter should not be the automatic optimal choice for every athlete who attacks.

## 6.2 Big Server

**Typical positions:** OP, OH, S.

**Investment identity:** Accessible vertical or secondary specialization.

Big Server accumulates:

- Serve Velocity.
- Spin.
- Some ACC investment.

The path is more accessible than Terminal Hitter.

Its capstones are intended to peak slightly lower than the most demanding vertical offensive paths.

### Intended gameplay identity

Big Server develops an exceptional serve as a significant source of offensive pressure.

Its value does not depend on the athlete becoming an exceptional spiker.

### Investment relationship

Big Server has important overlap with the ACC-primary serving outcome.

A Setter who already invests heavily into ACC may naturally pursue Big Server as a secondary specialization.

This is not merely a minor supplement to an existing Setter build.

It can become a substantial secondary identity because the Setter has already paid part of the attribute requirement through their primary positional investment.

The interaction between POW-primary and ACC-primary serving specializations should be designed deliberately.

They should offer related but meaningfully different paths into high-level serving.

---

# 7. POW / ACC Archetypes

## 7.1 Broad Range

**Typical positions:** OH, MB.

**Investment identity:** Hybrid offensive specialization; more accessible than the most expensive vertical paths.

Broad Range enhances:

- The distance over which Directional Influence can reach or accommodate sets.
- The effectiveness of contact near the edges of the spiking hurtboxes.
- The Broad Range auxiliary property.

### Intended gameplay identity

Broad Range expands the athlete's practical attacking envelope.

It allows attacks from less favorable contact locations and improves the athlete's ability to exploit sets that do not align perfectly with their preferred contact point.

Its primary advantage is spatial flexibility rather than maximum spike velocity or maximum shot precision.

### Position-specific considerations

An offensively minded MB may choose Broad Range after satisfying necessary END investment.

It can provide a more cost-effective offensive direction than Terminal Hitter.

A defensive MB may find deep Broad Range investment prohibitively expensive because their blocking demands already consume substantial attribute resources.

Exceptional AP advantages could make otherwise impractical builds possible.

## 7.2 Spotter

**Typical positions:** OH, MB.

**Investment identity:** Accessible hybrid specialization with relatively low costs and caps.

Spotter uses ACC investment to improve:

- Directional Influence's ability to modify spike trajectory.
- The resource efficiency of that trajectory modification.
- The Court Vision auxiliary property.

### Intended gameplay identity

Spotter is a precision-oriented attacker.

Rather than expanding which sets can be contacted effectively, Spotter improves how effectively an available contact can be directed.

It is a comparatively accessible offensive specialization.

### Investment relationship

Spotter is particularly valuable to all-rounders or defensive athletes who want some meaningful offensive specialization without committing to an expensive carry-oriented build.

Its lower requirements and lower ceiling are deliberate.

## 7.3 Tooler

**Typical position:** OH.

**Investment identity:** Expensive dual-vertical specialization.

Tooler requires substantial and approximately equivalent investment in POW and ACC.

It combines:

- Spike Velocity.
- Court Vision.
- Broad Range.

### Intended gameplay identity

Tooler is an elite technical scorer.

It combines powerful attacks, expanded attacking reach, and exceptional trajectory manipulation.

Its scoring potential should be extremely efficient when the athlete can exploit its full capabilities.

### Investment tradeoff

Tooler is one of the most economically demanding POW outcomes.

The athlete must invest deeply in two attributes rather than concentrating on a single vertical path.

The reward is a higher ceiling for technical offensive scoring.

The cost is severe opportunity loss in other attributes and responsibilities.

Tooler should not simply be an inexpensive combination of Broad Range and Spotter.

Its exceptional ceiling must be justified by its demanding requirements.

---

# 8. POW / SPD Archetypes

## 8.1 Transition Attacker

**Typical positions:** OH, MB, OP.

**Investment identity:** Supplemental path that also supports deeper specialization.

### Intended gameplay identity

Transition Attacker gives an athlete tools to carry defensive pressure while still producing equivalent, or potentially greater, offensive pressure as a consequence.

The defining concept is that defensive responsibility does not merely coexist with offensive capability.

**Defensive involvement can contribute positively to the athlete's subsequent offensive threat.**

This is more specific than simply improving recovery speed or movement between actions.

A conventional attacker may sacrifice positioning, preparation time, or resources when contributing defensively.

Transition Attacker should be capable of turning those defensive responsibilities into opportunities for sustained or enhanced offense.

### Investment relationship

The path is intended to supplement builds whose primary investment may be elsewhere.

It is especially relevant to athletes who already perform substantial defensive work.

However, it should also support deeper vertical investment.

A dedicated Transition Attacker should be exceptionally effective at its particular defensive-to-offensive playstyle, even if it cannot match Terminal Hitter in raw attack power.

### Unresolved mechanics

The exact means by which defensive participation improves offensive pressure have not been established.

Potential implementations should be evaluated against the intended playstyle rather than chosen prematurely.

## 8.2 Burst Attacker

**Typical positions:** MB, OH, OP.

**Investment identity:** Supplemental path with meaningful deeper specialization potential.

Burst Attacker is an expensive path relative to its exceptional benefits, but is intended to be usable as a supplement to athletes whose major investments lie elsewhere.

Its defining privilege is access to exceptional improvements involving the **Explosiveness subattribute**.

### Intended gameplay identity

Burst Attacker specializes in explosive offensive execution.

Its distinction from Terminal Hitter should be preserved:

- Terminal Hitter maximizes raw attacking performance and the quality of its ideal contact.
- Burst Attacker develops exceptional explosive capabilities that change how the athlete creates or exploits attacking opportunities.

Burst Attacker should not simply become a weaker version of Terminal Hitter.

### The Middle Blocker example

An MB may choose Burst Attacker for two reasons:

1. The path's offensive mechanics complement their desired attacking style.
2. Its attribute requirements can be compatible with the investment the MB already needs for positional responsibilities.

Because blocking is END-primary and POW-secondary, an MB already has reasons to invest in POW.

A supplemental Burst Attacker path can capitalize on that investment without demanding that the athlete abandon blocking specialization.

A more defensive MB can instead forgo Burst Attacker and pursue another path.

### Deep Burst Attacker specialization

An MB who strongly prefers Burst Attacker can invest vertically into it.

This should be supported.

However, equivalent deep investment in a deliberately vertical offensive path such as Terminal Hitter should generally produce greater performance in that path's specialized conventional offensive metric.

The deeply invested Burst Attacker instead receives exceptional access to unconventional capabilities for their position.

The tradeoff is:

- Lower ceiling in raw terminal offense.
- Greater access to distinctive explosive techniques and alternative offensive possibilities.

This is an intended difference in specialization, not a general inferiority.

---

# 9. POW / END Archetype

## 9.1 Jackknife

**Typical positions:** OH, OP.

**Investment identity:** Economical diversification and role-player specialization.

Jackknife deliberately chooses not to pursue exceptional offensive specialization.

Instead, it relies on ordinary attribute growth to preserve sufficient attacking potency.

Its major benefit is **privileged access to selected exceptional auxiliary improvements normally reserved for investment elsewhere**.

### Intended gameplay identity

Jackknife is a versatile role player who remains capable of attacking when necessary.

It is not intended to become an elite offensive carry.

Its unusual capabilities arise from access to auxiliaries that would ordinarily be unavailable or prohibitively expensive for its attribute distribution.

### Defining limitations

Jackknife does not automatically receive the deeper attribute specialization that normally complements those auxiliaries.

For example, obtaining an exceptional receiving auxiliary does not make the athlete equivalent to a dedicated receiving specialist.

The athlete has access to an unusual capability but lacks the supporting specialization needed to maximize its effectiveness.

Likewise, Jackknife does not gain overwhelming offensive prowess as compensation.

### Investment philosophy

Jackknife purchases breadth rather than maximum performance.

It should create an economically efficient athlete who can contribute in several ways without dominating any one specialist's intended domain.

An important design safeguard is to distinguish **access to an auxiliary** from **full mastery of the auxiliary's associated playstyle**.

Jackknife should not become an inexpensive route to the strongest benefits of several different attribute trees simultaneously.

---

# 10. Investment Identities

The eight POW outcomes demonstrate that specialization paths should not be evaluated solely by their absolute AP costs.

A path's real cost depends on the athlete's existing attribute distribution and intended positional responsibilities.

## 10.1 Expensive vertical specialization

**Examples:** Terminal Hitter; Tooler as an expensive dual-vertical case.

These paths demand major investment commitments.

They reward that commitment with exceptional performance ceilings.

Their primary cost is reduced flexibility.

## 10.2 Accessible secondary specialization

**Example:** Big Server.

These paths become particularly attractive when an athlete has already invested heavily in a compatible attribute for another purpose.

A Setter's ACC investment makes Big Server a natural secondary outcome.

The path can be substantial without requiring the athlete to abandon their primary positional role.

## 10.3 Accessible hybrid specialization

**Examples:** Spotter, Broad Range.

These paths offer meaningful improvements without requiring maximum offensive investment.

They are especially useful to athletes whose other responsibilities constrain their ability to specialize deeply in POW.

Spotter is intended to have particularly low requirements and a correspondingly lower ceiling.

Broad Range may demand more commitment, depending on how deeply the athlete pursues it.

## 10.4 Supplemental specialization

**Examples:** Transition Attacker, Burst Attacker.

These paths are designed to offer meaningful benefits to athletes whose primary investment priorities may be elsewhere.

Their initial and intermediate benefits should justify entering the path without requiring the athlete to become a dedicated offensive specialist.

However, they should not terminate prematurely.

Both must support meaningful deeper specialization.

An athlete who invests deeply into a supplemental path should become exceptional at that path's distinctive playstyle.

They should not necessarily surpass a dedicated vertical specialist in the latter's primary performance metric.

## 10.5 Economical diversification

**Example:** Jackknife.

This model sacrifices specialization for access to otherwise inaccessible auxiliary capabilities.

Its reward is flexibility and role-player utility rather than a dominant conventional offensive metric.

---

# 11. Marginal Investment Cost

A central design principle is that **a Trait path's practical affordability depends on how much additional attribute investment it requires beyond what an athlete already wants for their position and playstyle**.

Consider Big Server.

A Setter already invests heavily into ACC.

If Big Server requires POW and ACC, the Setter has already satisfied a substantial portion of its attribute requirements through ordinary positional development.

An MB may face a much larger burden because their blocking specialization demands END, while their offensive ambitions demand POW and potentially ACC.

The same path therefore creates different opportunity costs for different athletes.

This is desirable.

It encourages position-specific build patterns without requiring explicit position locks.

## 11.1 Illustrative relationships

| Path | Natural investment relationship |
|---|---|
| Terminal Hitter | Strong commitment to POW; significant opportunity cost |
| Big Server | Naturally accessible to ACC-heavy Setters as a secondary specialization |
| Broad Range | Offensive POW/ACC hybrid, potentially costly for defensive MBs |
| Spotter | Lower-cost POW/ACC specialization for all-rounders |
| Tooler | Deep investment into both POW and ACC |
| Transition Attacker | Supplemental to athletes with substantial defensive responsibilities |
| Burst Attacker | Can supplement an MB's existing POW investment while retaining END priorities |
| Jackknife | Economical access to exceptional auxiliaries without equivalent specialization |

Exact thresholds have not yet been determined in the supplied material.

The tree should be evaluated using actual attribute costs once those thresholds are available.

---

# 12. Vertical Paths Versus Supplemental Paths

One of the most important design conclusions is that **supplemental paths must not simply be weaker versions of vertical paths**.

A vertical path is intentionally designed to maximize performance in a particular domain.

A supplemental path is designed to interact efficiently with other investments and provide a distinct capability.

Both can support deep investment, but their ceilings should be different in kind.

### Example: Terminal Hitter versus Burst Attacker

An athlete who invests deeply in Terminal Hitter should achieve exceptional conventional attacking power.

An athlete who invests equally deeply in Burst Attacker should not necessarily match that attacking power.

Instead, Burst Attacker should offer exceptional explosive capabilities that Terminal Hitter cannot access as easily.

The Burst Attacker sacrifices some conventional offensive ceiling for unconventional possibilities.

This distinction preserves the economic reward of vertical specialization without making supplemental paths undesirable.

### Example: Terminal Hitter versus Transition Attacker

Terminal Hitter should excel at maximizing offensive output from favorable attacking opportunities.

Transition Attacker should excel at sustaining offensive pressure despite defensive participation, potentially improving that pressure as a result.

These athletes may have comparable overall strategic value in different systems, even if their maximum spike velocities differ substantially.

### Example: Tooler versus Spotter

Tooler pays for elite technical scoring through deep dual-attribute investment.

Spotter provides a more accessible way to gain precision-oriented offense.

Spotter should not approach Tooler's full ceiling without comparable investment, but its lower cost makes it practical for athletes with competing responsibilities.

---

# 13. Positional Flexibility Is Intentional

Trait paths should create recognizable positional tendencies without hard-locking athletes into conventional roles.

An MB may choose:

- A defensive build emphasizing END and blocking.
- A supplemental Burst Attacker build.
- A more offensively committed Burst Attacker build.
- Broad Range for greater attacking flexibility.
- Spotter for economical precision.
- An unusually expensive Terminal Hitter or Tooler specialization.

These choices should differ in both capability and opportunity cost.

The design should allow an athlete to pursue an unconventional identity when they are willing to pay for it.

However, unconventional specialization should not automatically erase the advantages of athletes whose builds are designed around more natural positional demands.

A deeply specialized offensive MB can become exceptional, but may have to surrender some blocking capability or flexibility.

An OH pursuing Tooler may gain exceptional offensive scoring efficiency while sacrificing defensive development.

A Setter pursuing Big Server can gain a meaningful secondary offensive identity without requiring the same sacrifices as an athlete who must first invest heavily into ACC.

This is the desired relationship between attributes, positions, and Traits.

---

# 14. Tree Construction Principles

The following principles should govern subsequent Trait design.

**1. Design athlete outcomes before individual nodes.**

Begin by defining the athlete's intended playstyle and strategic role.

Only then determine the Traits needed to create that outcome.

**2. Preserve the separation between subattributes and Traits.**

Subattributes are ordinary competing specializations within attributes.

Traits are distinct unlockable capabilities, including exceptional enhancements that ordinary attribute progression does not provide.

**3. Allow numerical auxiliary improvements.**

Not every Trait must introduce a new technique.

Improvements such as Platform Quality +X can be legitimate Traits when they provide meaningful auxiliary specialization.

**4. Use cross-attribute requirements to express hybridization.**

A Trait belongs to one primary attribute page, with additional requirements shown explicitly.

**5. Evaluate costs relative to positional demands.**

The same requirement can be inexpensive for one position and prohibitive for another.

This is a source of build diversity, not a defect.

**6. Distinguish accessibility from maximum potential.**

A path can be accessible as a supplement while still supporting expensive deeper specialization.

**7. Reward expensive specialization appropriately.**

Terminal Hitter and Tooler must justify their substantial opportunity costs through exceptional performance.

**8. Preserve different kinds of specialization ceilings.**

Deep supplemental investment should create an exceptional version of its own playstyle, not merely an inferior version of a vertical specialist.

**9. Keep auxiliary access distinct from full specialization.**

This is particularly important for Jackknife.

**10. Avoid prematurely assigning numerical requirements.**

Attribute thresholds, auxiliary increments, and capstone values should be derived after intended outcomes and investment relationships are sufficiently clear.

---

# 15. Current State and Remaining Work

## Established

- Four primary attribute pages.
- Introductory Trait for each attribute.
- Cross-attribute requirements without duplicated listings.
- Strict separation of subattributes from Traits.
- Auxiliary improvements as legitimate Trait effects.
- Action–attribute matrix.
- Athlete-archetype-first design methodology.
- Eight POW archetype outcomes.
- Basic gameplay identities of all eight POW outcomes.
- Investment identities and positional incentives.
- Distinction between vertical, hybrid, supplemental, and diversification paths.
- Importance of marginal attribute investment cost.
- Deep specialization support for supplemental paths.

## Not yet established

- Complete individual Trait lists for the eight POW paths.
- Exact path topology and branching relationships.
- Attribute thresholds for individual nodes.
- Auxiliary improvement increments and caps for each path.
- Exact Explosiveness enhancements for Burst Attacker.
- Exact defensive-to-offensive mechanics for Transition Attacker.
- Which exceptional auxiliaries Jackknife may access.
- Exact serving interaction between POW-primary and ACC-primary paths.
- Complete ACC, SPD, and END archetype outcomes.
- Numerical balance of path accessibility and capstones.
- Complete verified contents of `docs/trait-master-list.md`.

## Recommended next design phase

Continue the archetype-first process across the remaining attributes before finalizing the actual Trait trees.

For each attribute:

1. Identify its limited number of vertical outcomes.
2. Identify flexible cross-attribute outcomes.
3. Define each outcome's gameplay identity.
4. Define its intended investment identity.
5. Examine how its attribute requirements interact with each position's action demands.
6. Determine whether it is primarily a vertical specialization, secondary specialization, supplemental path, or diversification path.
7. Establish what makes deep investment worthwhile.
8. Only then develop the specific Traits, auxiliary improvements, requirements, and capstones.

Once the four attributes have been examined, the complete set of archetypes can be audited for overlap, missing playstyles, excessive investment burdens, and undesirable dominant builds.

**Central design objective:** The Trait system should make different athletes emerge naturally from different investment decisions, rather than require predefined classes or position-exclusive progression. A successful tree creates recognizable specialists, hybrids, and role players whose strengths and weaknesses reflect the opportunities they chose to pursue and the alternatives they sacrificed.

---

**Handoff caveat:** This document consolidates the design information established in the current Volleyball MOBA discussion and the supplied Claude audit summary. It does not claim to reproduce the inaccessible repository file or its numerical data. Specific implementation details not supplied here remain subject to verification.