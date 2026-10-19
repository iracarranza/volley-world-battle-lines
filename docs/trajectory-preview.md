> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Nearby-ball contact trajectory hint

A prepared or charging action shows a fading cyan trajectory ribbon when a live ball is within 3.5 m of the athlete's upper-body reference. The path starts at the ball's current position, rather than the old synthetic hand-height origin. A bright core, translucent halo and small directional chevrons indicate the first 35% of the ideal outgoing flight, capped at 0.7 seconds and 5.5 m of path length. It is a partial hint, not a landing prediction. Existing approach footprints and incoming landing marker remain separate.

The hint uses the actual shot, platform geometry, spike intersection, buffered directional influence, Timing and block reflection resolvers. It updates with camera loft/facing, charge, ball position, incoming velocity and grounded/airborne state. It assumes ideal timing and a matching receive charge; real early/late contacts, shanks and execution scatter may differ. Geometry quality is retained, so off-axis receives and side-of-arm spikes show their appropriate direction. Current committed target data is read without being changed.

A nearby ball outside the current hurtbox receives a fainter hypothetical hint, using the nearest projected platform/arm/column region for contact grading. The path still begins at the actual ball. Full brightness means it currently fits the action geometry, not a guarantee of sweet timing. Receiving behind the athlete, absent/distant balls, no preparation, serving toss/channel and Benched state hide the hint.

The renderer updates after the camera each visible frame and remains available with debug hurtboxes hidden. Its mesh is unlit and alpha blended, with the thin hint drawn over geometry so the athlete does not obscure it in close Ball View. Prediction never spends resources, changes the ball, emits contact/MoC events or modifies committed intent.

Validation: `trajectory_preview_test.gd` checks actual ideal contacts for all four actions, camera loft/facing, charge, spike and receive intersection effects, directional influence, ball-relative origin, partial flight, state/proximity gates, and lack of gameplay mutation. `moc_test.gd` retains immutable-intent coverage. `render_trajectory_preview.gd` captures Receive, Set and Attack in both camera modes.
