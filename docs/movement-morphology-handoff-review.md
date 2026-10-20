# Movement, morphology and momentum handoff review

Reviewed October 20, 2026 against `9e1dc35`. This records implementation gaps; it does not enable the proposed mechanics. The accompanying trajectory-preview edit is presentation only.

## What still matches

The twelve subattributes match the handoff, including POW Explosiveness, ACC Stability and END Cushioning/Work Rate/Capacity. The current tree still has 72 nodes: POW 35, ACC 28, SPD 1, END 8. The only SPD node is Quick Step; Impulse, Quick Takeoff and Twitch Dive are absent. Capacity remains 6 plus Deep Bag's 2. Exclusive forks, consuming progression, authored cumulative successor effects, alternative parents, merges and non-consuming prerequisites already exist.

Explosiveness already changes approach pace, dive speed and ascent time. Acceleration controls velocity convergence. Transition Speed controls recovery/endlag. Attack takeoff already arrests lateral motion and can convert run-up energy to jump height. Receive split steps, dive outcomes, DI, charge matching, set isolation, actor-local MoC and shared contact resolution are established systems to extend, rather than replace.

## Gap table

| Handoff mechanic | Current runtime | Required work |
|---|---|---|
| Momentum inherited by every contact | Request has scalar movement speed for posture, but no body-velocity vector or shared momentum response | New shared contact stage, action profiles, evidence and preview support |
| Stability mitigates momentum interference | Stability reduces weak-set geometry penalties through `stabilize_set` | New role; decide whether existing set benefit is retained separately or reassigned |
| Height/Stride ordinary speed; SPD sprint boost | `speed()` multiplies height-derived stride by a direct SPD contribution; Sprint is fixed 1.32x | Rework base-speed and sprint accessors; retune preparation/approach consumers |
| Independent relative Wingspan/Stride Length | Absolute span exists; stride is derived as 0.43 x height and clamped | Creation schema, normalization, migration, UI, visual morphology and runtime accessors |
| Limb-proportion exertion | Jump cost scales with height; ordinary contact cost is fixed; no span/stride cost layer | Action/category-aware arm and leg costs |
| Strong low-Height defensive benefits | Receive geometry scales uniformly with height; low platform triggers Knee/lift loss | Morphology-aware low-contact difficulty and angle/cost adjustments; asymmetric bonuses need design values |
| Sprint-modified approach, receive, set/block jumps | Sprint is disabled while jump charge is active; no sprint-at-initiation state; set/block carry follows movement-input presence | New action-context inputs and action-specific takeoff/confirmation rules |
| Additive Work Rate after mitigation | Work Rate reduces low-Stamina output penalty, not cost; Exertion Efficiency multiplies expenditure | New final cost layer; settle old Work Rate role, units and zero-cost policy |
| Receive aim eventually goes backward | Camera pitch changes positive loft while horizontal direction remains forward | Receive-only aim mapping plus integration with DI, failure reflection and body separation |
| Impulse and exclusive successors | Cross-stat effect keys and fork architecture exist; these nodes do not | Impulse's numeric effects can use existing hooks; aerial redirection and dive specialization require runtime extensions |

## Conflicts that must be addressed deliberately

### Physical velocity and confirmation

`athlete_motor.gd` zeros grounded horizontal velocity while contact-locked. Sampling current velocity after that loses the momentum the new design wants to preserve. Receive confirmation also cancels a pending split step/dive and zeros lateral velocity. Record pre-lock velocity explicitly, then distinguish input suppression, braking and actual body motion. Do not manufacture momentum from held WASD.

Use a velocity vector in the shared request, not just the scalar posture speed. For bots, `request.movement_speed` currently uses configured Move speed, not measured instantaneous travel. Bot jumps, return movement, animation/root translation and knockback need an explicit inclusion policy. Velocity measured from displacement must use actor-local simulation time so MoC does not accidentally change momentum potency. The preview should use the same snapshot without consuming resources or changing live state.

Recommended, not finalized: sample a committed pre-lock velocity for locked ground actions and actual velocity at physical contact for airborne actions. Resolve predominantly deterministic trajectory effects according to momentum's alignment with intended flight. Keep any additional quality penalty separately named and tunable; do not lower geometry, Timing or charge match merely because momentum exists.

### Speed changes have a wider blast radius

`athlete.speed()` also feeds approach steps, the first bound, dive travel and the attack momentum-conversion cap. Changing its SPD dependence changes all of these, plus gait/stride calculations and traversal assumptions. Preserve the 65 reference approach deliberately, then compare extremes. Bots use explicit movement-speed sliders, so decide whether those represent an absolute design override or a modifier of the new morphology-derived speed; do not silently reinterpret the saved Net 2 preset.

### Sprint action semantics

Current jump-set/block takeoff keeps 85% of velocity with movement input and 15% without, adding directional carry. The handoff instead makes Sprint state select controlled versus moving takeoff. Store Sprint state separately at approach/jump initiation and receive release; keep actual velocity distinct from the input flag. Define how release timing works before tuning it. Existing grounded confirmation locking does not implement Sprint Receive because it also destroys velocity.

### Morphology and geometry ownership

Height and span already influence visual construction/reach, but receiving fans scale only with height. A span benefit for all actions requires revisiting the anatomical baseline, not globally multiplying every hurtbox. Preserve Platform Quality's control of receiving quality/proportions as a separate layer. Short athletes currently have lower height-scaled jump costs and different absolute platform heights, but there is no explicit disproportionate short-body advantage or stride-dependent low-contact cost. Tiny/Giant descriptive text is not sufficient evidence of those mechanics.

Store relative morphology with a versioned save migration; retain old absolute span rather than discarding it. The exchange rate between span and stride, their legal ranges and extreme-height benefits remain unchosen.

### Work Rate and timestep independence

Apply the proposed additive reduction after existing mitigations, including Exertion Efficiency. Continuous costs need a Stamina-per-second adjustment followed by multiplication by dt; subtracting a fixed amount on every frame would make efficiency depend on framerate and could eliminate movement costs. One-shot actions need event costs. A category-aware cost API should serve players and bots. Do not silently install an unapproved positive minimum cost or remove the current low-Stamina Work Rate benefit.

Ordinary player walking currently has no direct movement drain: Sprint spends 10 Stamina/s in a rally and 3 outside; jump charging spends 3/s, with separate bound/split-step/jump costs. Bots spend 3/s while moving or busy during a live rally. Therefore the handoff's premise that movement already costs Stamina is only partially true. Define walking/drain and regeneration together before judging Sprint sustainability.

### Receiving and momentum are separate from incoming-ball pressure

The existing receive response models incoming charge, velocity, timing, platform intersection and shank reflection. That remains useful. Body momentum is a distinct input; it must not replace incoming-ball pressure, charge matching, Cushioning or Set Isolation. Establish intended receive aim first, then preserve geometry/timing/charge failures and shared separation guarantees. Backward-intended clean passes must clear the athlete; the rule forbidding contact with a ball already behind the platform should remain intact.

The low-contact Knee penalty already reduces lift, but it is not the new Height/Stride penalty. Keep those separate from movement Stability so high Stability cannot erase anatomical disadvantages.

### Quick Takeoff is not ordinary impact MoC

Current MoC starts at physical impact and can steer an outgoing ball. Quick Takeoff proposes a pre-contact jump-redirection window. It needs a distinct phase, actor clock and movement target. Decide which actors slow, whether the ball slows, whether redirection has an HP cost, and what momentum remains afterwards. Reusing ball-contact MoC wholesale would make those decisions accidentally. Twitch Dive can extend existing dive takeoff, slide and recovery, with separate definitions for faster travel versus longer travel.

## Suggested implementation order

1. Freeze the neutral reference behavior and define relative morphology/save migration.
2. Separate base movement speed, sprint modifier and typed Stamina costs. Settle Work Rate's retained/replaced functions.
3. Add Sprint action-context state and controlled set/block takeoffs while preserving attack approach rhythm.
4. Add shared body-momentum requests/response, Stability mitigation and matching preview/bot behavior.
5. Implement receive aim transformation and morphology-aware low-contact effects together.
6. Author Impulse and Twitch Dive; add Quick Takeoff after its pre-contact MoC contract is settled.

Test player/bot parity, preview/live agreement, actor-local slowdown invariance, 30/60/120 Hz expenditure, short/tall and short/long-stride extremes, aligned/perpendicular/opposed travel, Sprint release transitions, charge-mismatch shanks and fatigue progression. Existing Net 2 bots provide a useful playtest fixture, but their 100% accuracy sliders should not erase morphology or momentum consequences.

No numerical coefficients, new cost floor, creation exchange rate or Quick Takeoff slowdown policy are adopted by this review.
