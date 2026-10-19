# Directional influence: Receive / Set / Attack

WASD continues moving the athlete and now also influences the outgoing contact. Mouse facing and pitch remain the main aim. The game averages intended world-space movement over the last 80ms of real time, then projects that input into the confirmed contact's horizontal forward/right frame. Athlete velocity, sprint speed and jump momentum are not DI inputs. Diagonals share a normalized budget. A fresh one-frame press ramps in rather than applying maximum influence immediately; released input fades out across the same window. Reset/pause clear the history.

At full contact quality:

| Action | Left/right | Forward | Back |
| --- | --- | --- | --- |
| Receive | Up to 12 degrees | Up to 10% more range | Up to 10% less range |
| Set | Up to 20 degrees | Up to 15% more range | Up to 15% less range |
| Attack | Up to 15 degrees | Up to 10 degrees flatter | Up to 8 degrees higher |

These are provisional playtest values. Contact quality scales the authority linearly. Receive platform deflection, Set column accuracy and Attack zone strength resolve before DI. Receive/Set DI changes horizontal velocity while preserving vertical velocity, so charge/pitch still determine height. Attack DI rotates the resolved velocity without adding speed, respecting the existing -65 to +70 degree angle caps. Neutral input returns the original velocity exactly. Block, Serve, and scripted bots gain no new DI behavior in this slice.

Before confirmation, the intended preview includes current DI at ideal quality. Confirmation freezes that preview and its input evidence. Input may continue changing until physical contact; the resulting flight may therefore differ from that intent. Actual contact events contain immutable `directional_influence` evidence: sampled world input, local axes, quality authority, yaw, range multiplier, pitch adjustment and outgoing velocity. Nothing applies DI to the ball after impact.

Implementation: `scripts/directional_influence.gd` owns sampling and the pure resolver. `contact_lab.gd` samples alongside movement and applies the resolver after geometric contact/accuracy effects and before recording the impact and replanning bots. MoC's time scale is removed from input sample durations so it does not stretch the response window. `contact_intent.gd` retains the confirmed influence separately from actual impact evidence.

Validation: `tests/directional_influence_test.gd` checks neutral equivalence, directions/caps, both court orientations, diagonal limits, quality scaling, preserved loft height and attack speed, input-window aging/rates, actual late-input contacts, momentum independence, immutable intent/evidence, reset, and no post-contact steering. Gameplay, receive platform, Set sector, MoC, approach and bot rally/fallback suites remain passing.


## Spike intersection direction

Spike direction now combines committed body facing, lateral ball intersection relative to the dominant-arm sweetspot, and buffered DI. Neutral player shots use body facing as the reference rather than aiming back across the body toward a point projected from the feet. The geometric offset rotates the shot toward the contact side (up to 20 degrees). The sweet reference mirrors with handedness; world-left/right bias remains literal relative to body facing. Random execution yaw is no longer added to spikes.

Complementary lateral DI accentuates the geometry angle and recovers some lost ball velocity (up to an 18% factor, capped by nominal spatial speed). Contrary DI corrects toward facing and loses velocity (up to a 22% factor). Correction does not cross facing into an opposite-side swing. A perfect-strength contact has no lost spatial speed to recover. Geometry and timing quality still apply, and very late/far rescue pushes retain facing-only behavior. The Power attribute is never modified.

Player torso/striking-arm yaw reflects the resolved direction without rotating committed body facing. Court bots and Pepper partners share the intersection bias with neutral input; their deliberate shot intent remains constrained to the existing 15-degree limit before geometric bias is added. Immutable impact DI evidence records geometry offset, geometric yaw, speed factor and final relative swing yaw. Intended preview cannot predict future physical intersection.

spike_geometry_direction_test.gd checks both hands and rotated facing, complementary/contrary angle and speed effects, actual lab contacts and unchanged body facing/Power.
