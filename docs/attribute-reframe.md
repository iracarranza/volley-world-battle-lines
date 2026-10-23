# Attribute reframe: working spec (draft 1)

Status: design draft for the designer's approval. Nothing here is a tuning commitment except where marked **done**. It records the
shared understanding reached between the designer, Claude (design/implementation) and Codex (implementation review).

## Principle

A primary attribute (ATT) gives the athlete a *universal identity*; its three subattributes say *where* that identity shows. Raising an ATT
already raises its subattributes' baseline (`athlete_store.gd`), so an ATT's own effect is an additional benefit and must be budgeted
together with that. Each attribute needs a one-sentence identity and one on-screen tell.

| ATT | Identity | On-screen tell | Subattributes |
|---|---|---|---|
| POW | Charge converts to more output at the top end, with a soft ceiling | Faster, flatter attacks; defenders staggered | Explosiveness, Jump Power, Swing Power |
| ACC | Awareness: how fast the athlete resolves what changed on the court | Late-changing entities sharpen sooner; clearer beam | Ball Control, Timing, Stability |
| SPD | Multiplier on grounded Sprint speed | Sprint speed | Acceleration, Reaction Speed, Transition Speed |
| END | Performance does not fade when tired or Winded | Fade marker on the Stamina bar; posture outcomes | Resistance, Work Rate, Core Strength |

## Agreed decisions

1. **One owner per penalty.** Fatigue/expenditure/pool/recovery stay separate: END mitigates deterioration, Work Rate reduces expenditure,
   Capacity (auxiliary) sets the pool, Stamina Recovery changes replenishment, Core Strength changes postural consequences.
2. **POW is a charge-to-output conversion** (below). Swing Power keeps its charge multiplier; Spike Velocity adds *effective charge before*
   conversion and never adds velocity after it. POW's earlier direct effect on the distance from the sweetspot where contamination begins is
   **replaced** by the conversion, so POW does not scale twice. A separate ball-carried "pressure" property is **not** added until equally
   fast balls are shown to need different handling; if it is added, it is snapshotted when the shot is produced, applies to hostile
   contacts only, and is replaced at every following contact.
3. **ACC is information, not a physical bonus.** No finer steering, aim-snap or collision-radius change. The visual system is the mechanic.
   Prototype each component separately: focus width (action charge), peripheral obscuration (current Stamina, mitigated by END), clarity
   acquisition (ACC), MoC trajectory display (Ball Control; length and opacity, not tube width), momentum distortion (Stability).
4. **Degrade detail, not the screen.** Low-ACC athletes see changed or peripheral entities as ghosted silhouettes that sharpen over time.
   Bots need an equivalent: awareness latency, the time from a state change to the bot acting on it, as a function of ACC.
5. **Core Strength** is a posture mechanic: contact strain → Core Strength mitigation → posture outcome → recovery duration (Transition
   Speed). It never changes the outgoing ball. Classification lives in gameplay code; animation only consumes the result.
6. **Capacity** becomes an auxiliary and END does not regain a pool-size effect. **Cushioning** becomes Resistance and loses its additive
   receive-charge behaviour (it is removed, relocated or deliberately folded into the incoming-pressure model, not renamed).
7. **No hidden-sequence variation in a trajectory** (see the audit; first pass is **done**).

## POW: provisional output table (for approval)

The relationships are approved first; the formula is then fitted. Current runtime (neutral POW) is linear:

`speed(e) = (6.0 + 7.0·e + 1.3) · 1.40 · 1.50 · hp ≈ 15.3 + 14.7·e m/s` before flight solving, where `e` is effective charge
(`input charge × Swing Power multiplier + Spike Velocity/100`). Provisional POW response, with `h(e) = e²` for `e ≤ 1` and
`h(e) = 1 + (1 − exp(−2(e − 1)))` above it (slope-continuous, so charge beyond 100% keeps paying with a soft ceiling at `h = 2`):

`speed = speed_linear(e) · (1 + G(tier) · h(e))`, with `G` the full-charge gain by POW band tier:

| Tier | −2 | −1 | 0 (neutral) | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|---|---|
| G (full-charge gain) | −10% | −5% | 0% | +4% | +8% | +11% | +13.5% | +15% |
| Step from previous | | +5 | +5 | +4 | +4 | +3 | +2.5 | +1.5 |

Resulting speed (m/s, pre-flight, full HP) by effective charge:

| Tier | e = 0.25 | 0.50 | 0.75 | 1.00 | 1.25 | 1.50 |
|---|---|---|---|---|---|---|
| −2 | 18.9 | 22.1 | 24.9 | 27.0 | 29.0 | 31.3 |
| 0 | 19.0 | 22.7 | 26.4 | 30.0 | 33.7 | 37.4 |
| 1 | 19.1 | 22.9 | 26.9 | 31.2 | 35.6 | 39.8 |
| 2 | 19.1 | 23.1 | 27.5 | 32.4 | 37.5 | 42.3 |
| 3 | 19.1 | 23.3 | 28.0 | 33.3 | 38.9 | 44.1 |
| 4 | 19.2 | 23.4 | 28.4 | 34.1 | 40.0 | 45.6 |
| 5 | 19.2 | 23.5 | 28.6 | 34.5 | 40.8 | 46.5 |

Reading it: at low charge every athlete is nearly identical (differences under 1%), so a POW build is not a weaker feeling at the start of
a swing. The advantage grows toward full charge (+15% at T5) and keeps growing, softly, above it (+24.5% at e = 1.5), where Swing Power and
Spike Velocity also carry an athlete. Each tier step is at least 60% of the one before, so the top still feels like a higher ceiling and
there is no hard cap. **Questions for the designer:** are the full-charge gains the right size; is `e²` the right "growth toward high
charge" (alternatives: `e³`, which concentrates the advantage nearer the top); and does the T5 step (+1.5) feel too small?

## Determinism audit (first pass done)

Principle: an identical physical contact gives an identical result. Findings and treatment:

| Source | Was | Now |
|---|---|---|
| Receive scatter (`contact/receive_response.gd`) | `sin(contact serial)` noise, sign and size by what happened earlier | mean magnitude (0.64), always continuing the contact's own lean; **done** |
| Block scatter (`contact/block_response.gd`) | `sin(seed·1.73 + incoming.y·0.21)` | sign from the contact side (then incoming side), mean magnitude; **done** |
| Set/block spread (`contact/contact_resolver.gd`) | `sin(elapsed·7)` (lab) / `sin(total_contacts·1.7+0.8)` (bots) | leans to the hurtbox side the ball met, mean magnitude; `spread_phase` removed; **done** |
| `charge_aim_variance` trait | seeded `randf_range` | leans with the directional input, then the contact side; **done** |
| Auto charge error (`auto_charge.gd`) | `sin(seed·1.73 + incoming…)` | systematic underestimate that grows with incoming pace; **done** |
| Bot aiming scatter (`training_bots.gd`, `pepper_partners.gd`: `aim_random`, `aiming_accuracy`) | random aim error after a correct contact | **open**: bot error should appear as imperfect preparation, positioning or chosen aim, not post-contact deviation |
| Preview vs contact | preview applies no spread and assumes ideal timing and matching charge | **open**: preview and contact should share one inputs path (needed before the MoC-only preview) |
| `athlete_motor.gd` clock reads | input timing only | not a trajectory source; no change |

The constants replacing the old noise (0.64, the mean of |sin|) keep average behaviour but are placeholders until the designer chooses how
strongly each lean should read; the `response_seed` is still published in evidence but no longer drives any trajectory.

## Open questions

- POW table above (sizes, shape, whether T5 is too flat).
- Does Core Strength's passive-block benefit change ball deflection (overlaps Resistance) or only posture? Recommended: posture only until a
  gameplay consequence for "better posture" exists.
- ACC: clocks. Real time or the slowed actor clock? When does focus end after a miss or cancel? What does a passive block (no
  confirmation) get? Does fatigue obscuration follow release-time Stamina or expenditure? Recommended: define on prototype.
- Should the preparation preview remain for new players when the Trajectory Preview becomes MoC-only? Recommended: playtest decision.
- Auto vision width: recommended to use the outgoing (visible) charge, not the handling effort.
- Migration: versioned save for Cushioning → Resistance and Capacity → auxiliary, with an archived value and a respec policy.

## Slice order

1. Freeze ownership and migration rules (this document).
2. Remove hidden-sequence variation and unify preview/contact inputs (partly done; bots and preview open).
3. POW conversion, Resistance, consolidate the three overlapping mitigators (Cushioning, Charge Tolerance, receive-charge bonus).
4. Core Strength strain pipeline.
5. END owns fatigue protection; SPD owns the Sprint enhancement.
6. ACC awareness prototype and Ball Control preview.

## ACC vision focus: prototype (Esc menu, off by default)

`scripts/vision_focus.gd` with `resources/vision_focus.gdshader`; switches and numbers are in the Esc settings menu (VISION FOCUS), and a master switch
leaves the rest of the game untouched.

- **Focus beam:** on release, a directed triangular beam fans out from the athlete's head toward the ball like light through a prism, a post-process over
  the 3D picture. Its far-end half-width follows the action's charge (a strong action narrows it); outside it the picture is blurred and darkened, and
  its edges refract (red and blue are bent opposite ways).
- **Clearing (ACC):** the sharp centre line widens to the whole beam over a time set by Accuracy (`Stats.pace`, so higher Accuracy is faster).
- **Fatigue:** current Stamina sets the blur and darkness outside the beam; Endurance covers part of it.
- **Trajectory preview:** Ball Control sets its length and opacity (a readable floor for everyone), and it can be limited to the Moment of Contact.
- **Not prototyped yet:** momentum distortion of the preview (Stability) needs the same inputs as the real contact, so the preview does not drift from the
  outcome; ghosted silhouettes for low-ACC awareness and the bots' awareness latency; the open clock questions above.
