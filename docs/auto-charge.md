# Auto preparation, Reaction Speed and Set Isolation

Reaction Speed replaces Lateral Speed under SPD. Tapping the charge input arms
**Auto**; holding beyond the existing tap threshold retains explicit numeric
charge. Auto uses the same paths when jump charging interrupts a tap and when
an unprepared receive becomes a dive. The wheel displays AUTO without a numeric
charge fill. The neutral facing-relative strafe fraction stays at .75.

Confirmation captures facing/aim and opens the usual hurtbox window, but records
charge as `auto`. Preparation continues reacting until the actual contact. The
contact samples the latest ball and preparation state; it never freezes a value
at confirmation, teleports preparation to a new target, auto-confirms, expands
reach or grants sweet timing. Timing, Ball Control, geometry, DI and stamina
retain their independent roles. Previews do not mutate preparation or RNG state.

| Rating | Auto ceiling | Adaptation charge/s | Maximum matching error |
|---|---:|---:|---:|
| 50–55 | 35% | .50 | ±16 pp |
| 56–60 | 48% | .80 | ±11 pp |
| 61–65 | 61% | 1.20 | ±7.5 pp |
| 66–69 | 65% | 1.45 | ±6 pp |
| 70–79 | 70% | 1.70 | ±4.5 pp |
| 80–89 | 75% | 2.00 | ±3 pp |
| 90–98 | 80% | 2.40 | ±1.8 pp |
| 99 | 85% | 3.00 | ±1 pp |

These are provisional tuning values. Error is deterministic from contact seed
and observed incoming motion, never a new random roll per preview/tap. Receive
and Set accumulate preparation; Attack and Block use their ceiling immediately.
Manual preparation can still reach 100% input, before the existing multipliers
and additives. Effective charge remains uncapped.

## Receive

Auto targets the middle of the incoming ball's matching band, compensating for
Cushioning and low-stamina availability. It attempts matching for any charged
incoming ball, not just Serve/Attack. Its ceiling and adaptation rate can prevent
a match; existing gentle near-miss/shank curves still resolve the result.
Resultant ball charge remains derived from the interaction, not copied from input.
The bot's deliberate charged preparation shares the receive-target calculation;
bots do not gain an unrequested automatic-input setting.

## Set

A tapped set always intends **61% outgoing action power**, independently of how
much handling effort it needs. Reaction Speed limits handling effort, not that
61% output target. Set Isolation has an ordinary-pressure comfort range plus a
handling allowance. Provisional pressure is the larger of incoming charge and a
pace-based estimate. Required effort grows above .20 pressure; each point of
effective handling contributes 1.25 pressure capacity, reduced on weaker geometry.
Auto preparation includes a small handling margin so ordinary pressure changes
within capacity preserve the standard set.

Above capacity, residual incoming pace leaks into the output and quality/sweet
eligibility degrades. Stability and stamina participate through the shared resolver.
Manual sets use their numeric charge for intended output and handling effort.
This is a bounded gameplay response, not a raw collision simulation.

Set metadata records output action charge, handling charge, conditioned delivery
quality and resultant ball charge. The latter uses delivered pace and retained
incoming pressure, with the same slow-ball safeguards as Receive. It does not
multiply velocity a second time. Attack transfer penalties and setter-granted
attack efficiency remain future work.

## Saves and validation

Schema v3 archives the retired Lateral Speed allocation and resets that SPD group
for respec. It preserves other ratings, traits, identity and older archives;
migration is idempotent. It does not reinterpret Lateral Speed as Reaction Speed.

`auto_charge_test` covers real tap/hold/confirm/contact input, post-confirmation
adaptation, all tier ceilings, matching accuracy, standard set output, independent
handling, overload, outgoing metadata and old-save migration. Existing stat,
contact, jump, preview, receive, bot/Pepper and serving suites cover integration.

Validation: `artifacts/reaction-auto-full` passed 99/99 suites. Final contact and
stat/serve follow-ups passed in `artifacts/reaction-auto-contact-final` and
`artifacts/reaction-auto-final-targeted`. Both graphical captures in
`artifacts/reaction-auto-visual/renders` were visually verified.
