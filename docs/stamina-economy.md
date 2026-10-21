# Stamina economy calibration — October 20, 2026

This slice implements the accepted costs and morphology-dependent receive platform. It does not choose unresolved speed, momentum, receive-aim, surcharge or ability coefficients. Claude owns the opposed creation sliders, save migration and visuals; see `morphology-runtime-contract.md`.

## Cost resolution

`stamina_costs.gd` returns an immutable breakdown: base, Height, Stride, Wingspan, mismatch, sourspot, subtotal, Exertion Efficiency, Work Rate, floor and total, with explicit units. `LabAthlete.last_stamina_cost` exposes the latest quote. The bot inspector displays it. Pure quote calculations never spend resources.

Discrete calculation: add the relevant modifiers, apply existing Exertion Efficiency (at least 10% of subtotal), subtract Work Rate, then enforce the 5-Stamina minimum. `spend_resolved()` deducts that total without applying efficiency a second time. Existing raw `spend()` remains available for external/legacy callers.

- Ordinary jump: base 20 + Model B Height adjustment + Stride adjustment.
- Successful Receive/Set/Attack/Block: base 15 + Wingspan adjustment, independent of input charge.
- Serve: existing base 4 + Wingspan adjustment, now subject to the 5-point minimum. Advanced serve costs remain unspecified.
- Travel jump: separate base 5, leg proportion adjustment and the discrete minimum; never also pays ordinary jump's 20. Travel physics remain unchanged.
- Quick Step: retains the existing half-jump base relationship, taking half the ordinary jump base/Height/Stride components before its own efficiency, Work Rate and minimum; existing 3 HP remains separate.
- Rolling Receive: ordinary contact stamina plus the existing 5 HP.
- Bound/split step: no additional cost and no minimum.
- Timing miss and drill box step: retain base 2 and 3, existing efficiency, and exemption from Work Rate/action minimum.
- Jump charging: retains its existing 3/s drain, with no new continuous morphology or Work Rate adjustment.

Work Rate subtracts 2 per positive band, up to 10. No new below-neutral cost penalty is introduced. Its former mitigation of low-stamina output loss is removed. The independent neutral output curve remains: below 30% capacity, output falls smoothly to at most 20% loss; existing explicit Exhausted penalties remain separate.

## Height and proportions

Heights use the same rounded inch representation as creation. Neutral is 72–74 inches. Selected-band Model B applies the band's rate to every inch beyond the appropriate neutral boundary, rather than progressively integrating bands:

| Band | Inches | Jump adjustment | Movement/s | Sprint/s |
|---|---|---|---|---|
| Tiny | 60–65 | −1.00 per inch below 72 | 2.25 | 14.25 |
| Lower +2 | 66–68 | −0.75 per inch below 72 | 2.50 | 14.50 |
| Lower +1 | 69–71 | −0.625 per inch below 72 | 2.75 | 14.75 |
| Neutral | 72–74 | 0 | 3.00 | 15.00 |
| Upper +1 | 75–77 | +0.50 per inch above 74 | 3.50 | 15.50 |
| Upper +2 | 78–80 | +0.625 per inch above 74 | 4.00 | 16.00 |
| Giant | 81–86 | +0.75 per inch above 74 | 4.50 | 16.50 |

The base Sprint premium is 12/s at every Height band. Sprint replaces ordinary movement drain. Existing efficiency traits can modify these base rates; Work Rate and limb proportions do not receive an uncalibrated per-second subtraction.

Ratios 0.8–1.2 are read through `morphology_runtime.gd`. Each +0.04 adds 1 to an eligible discrete action; each −0.04 subtracts 1.5, interpolated for the sliders' intermediate values. Stride applies to leg actions; Wingspan to arm actions. Resolved Stride also feeds the existing gait/base-speed accessor, retaining the neutral ratio baseline. Jump reference values are covered at every supplied boundary/example.

## Regeneration and clocks

Moving or newly stationary: 2/s. After three consecutive grounded stationary seconds: 6/s. Leaving that state resets the stationary timer. Upper-body contact preparation alone does not reset it. Airborne/jump-charging actors do not qualify as resting. Recovery traits multiply the rates. Winded halves them for 10.5 s. Exhaustion prevents regeneration for 7 s, then returns to Winded.

Regeneration splits timesteps at rest-delay, fatigue and cooldown boundaries. Actor-local time drives player, court-bot and Pepper spending/recovery under MoC. Movement drain follows actual ground travel, rather than held inputs or a bot merely having a plan. New rallies refresh bots; debug reset also refreshes Pepper profiles.

## Receiving morphology

The original receiving fan supplies the neutral calibration. Height scales that reference. The stance-height difference from Stride is the difference from the existing 0.43 × Height leg reference. The extra per-arm reach is half the wingspan difference from Height. These shift the comfortable platform down for longer arms and up for longer legs, extending forward/lateral reach for longer arms. Dive posture does not inherit an upright leg-height shift.

The debug mesh clips its lower surface at the athlete's local floor. Grading keeps the original anatomical extent, so clipping does not stretch the remaining low band upward. Long arms can move more of that band below the floor, making the same world-space low ball a more comfortable contact. The rear-contact restriction remains. Platform Quality still modifies grading independently; it does not replace anatomical reach.

Player, court bots, Pepper and previews use this same definition. Shape and geometry-assessment evidence expose resolved ratios, arm/leg shifts, anatomical bottom, floor-clipped bottom and exposed lower-band height.

## Unresolved values and double charging

New universal mismatch and sourspot surcharges are not enabled: their coefficients have not been supplied. Existing authored serve-carried mismatch drain is preserved as a separate component inside the contact quote, before the common reductions/floor. The later serve-consequence callback only applies its other consequences, avoiding a second stamina payment. Timing labels do not manufacture a geometric sourspot.

DI spends HP only. Existing HP rates/trait modifiers remain; no new rate is selected. The old DI-stamina effect key is retained for data compatibility but does not charge stamina.

New SPD-to-Sprint speed coefficients, contact momentum/Stability response, receive aim reversal, Sprint approach range and continuous Stride/Work Rate modifiers remain outside this calibrated slice.

## Verification

`stamina_calibration_test` covers reference jumps, every Height rate, proportions, Work Rate, efficiency/floors, exempt actions, 30/60/120 Hz drains/regeneration and fatigue/cooldown boundaries. `receive_morphology_test` checks identical low-ball positions, limb reach, Knee classification and floor clipping. `stamina_morphology_integration_test` checks player/bot/Pepper geometry agreement, live preview parity, actual contact expenditure and physical walking/Sprint expenditure. Existing fatigue, serving, traits, Pepper, bot, map, MoC and preview regressions are included in the full run.
