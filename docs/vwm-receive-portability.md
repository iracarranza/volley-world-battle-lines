# VWM receive portability review

Reviewed the current local `/Users/iracarranza/volley-world-manager` checkout at `7da049b`. This is a source review; no VWM receive resolver was imported or enabled in Rally Lanes in this change.

## Finding

The physical forearm-contact kernel is a good candidate for adaptation. The complete manager-side receive subsystem is not a drop-in replacement for player input and live collisions.

`PlatformContactModel.evaluate()` in `scripts/simulation/platform_contact_model.gd:155` accepts a plain Dictionary of actual incoming velocity, contact point/height, body velocity, contact difficulty, stability, technique, intended destination/arrival height, timing floor and seed. It computes a physically bounded outgoing launch independently of the manager's career/UI state.

Its old header says shadow-only, but current production authority is clearer at the call site: `scripts/simulation/rally_feature_flags.gd:25` has `ENABLE_PHYSICAL_RECEPTION = true`; `rally_simulator.gd:11361` replaces the successful reception's outgoing flight with `_physical_platform_dig_result(..., "reception")`. That shared function calls `PlatformContactModel.evaluate()` at about line 11003 and launches an unconstrained projectile from its resulting velocity. Read the runtime path over the stale header.

## Reusable parts

- Incoming pace carries into the available outgoing speed ceiling (30% retention), alongside active generation, stability and actual body motion.
- Redirection is bounded by a cone around the incoming ball's natural rebound direction. Difficult stretched contacts narrow that cone and reduce active generation.
- Intent and realized launch are separate. Desired destination/arrival height do not teleport the ball into the next athlete's hands.
- Technique gives bounded angular execution variation, projected back into the feasible envelope.
- VWM contact-envelope and defensive-pose helpers can inform geometry/animation, but Rally Lanes must retain one authoritative live contact test.

These coefficients are authored game abstractions in VWM, not measured biomechanics or automatically correct MOBA balance.

## Adaptation required

| Boundary | Rally Lanes treatment |
|---|---|
| Normalized 9×18 court coordinates | Adapt x/z world metres to the helper's coordinate basis; do not confuse its conversion units with Rally Lanes' dynamically sized court boundaries. |
| Source trajectory/replay records | Supply live Vector3 ball velocity directly; do not reconstruct it through BallTrajectory serialization. |
| AI-selected target and actor | Supply player's committed charge/aim intent and actual contacted actor. |
| Body state / arrival grading | Measure actual moving hurtbox contact, dive posture, body velocity and timing. Do not substitute a projected AI arrival. |
| VWM player ratings | Map Rally Lanes gameplay capabilities explicitly. Menu stat names and final Timing/Stability semantics still need reconciliation. |
| Seeded angular variation | Keep physical geometry/timing errors distinct from any bounded residual execution variation. Do not import synthetic timing errors for a human-controlled athlete. |
| Flight selection search | The source performs 241 coarse samples plus refinement. Cache intent/envelope work and profile it before running multiple candidate previews every rendered frame. |
| Existing bump calibration | Preserve the agreed full-charge height ceiling and per-charge landing distance as intended outcomes; model clipping due to incoming/contact constraints must be explicit and tested. A raw swap would change those curves. |

Avoid importing `ShadowReceptionSystem` wholesale (AI perception, receiver choice, rollout), `LiveReceptionIntegrator.apply()` (advances manager RallyState and applies projected actor state), or the monolithic RallySimulator. Their jobs are already performed by human input, live CharacterBody motion and Rally Lanes contact logic.

## Suggested next slice

Extract a namespaced pure platform-contact adapter. First run it in diagnostic comparison against existing live receives, using the same incoming velocity/contact evidence/committed intent without changing output. Verify controlled incoming-speed, facing, platform offset, dive and left/right cases; reconcile the current charge-height/distance expectations. Only then promote its outgoing velocity as the receive authority. Keep the MoC event hook unchanged: it will automatically read the new incoming/outgoing exchange.
