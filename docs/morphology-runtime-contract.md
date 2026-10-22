# Morphology/runtime collaboration contract

Agreed October 20: Claude owns creation sliders, save migration and visual proportions. Codex owns stamina costs, receiving geometry and runtime validation. Shared build inputs:

- `height`: absolute meters, retained.
- `span`: absolute wingspan meters, retained.
- `stride_ratio`: 0.8–1.2, 1.0 neutral.
- `wingspan_ratio`: 0.8–1.2, 1.0 neutral.

Creation enforces the 0.8–1.2 bounds and AP neutrality. The two ratios are independent, with no shared budget: maxing both is limited by its costs (arm and leg Stamina, a harder-to-control platform at speed, and strenuous jumps that use the athlete's own proportions), not by a cap; runtime reads independently for controlled comparisons. Legacy missing stride ratio means 1.0. Missing wingspan ratio derives from span/height, retaining existing absolute proportions. New records should supply explicit ratios. If only wingspan_ratio exists, its absolute span is height times ratio.

Codex's `morphology_runtime.gd` reads these fields. Neutral leg reference remains the existing 0.43 x height; the runtime uses its difference under stride_ratio to move the receiving stance reference. Extra per-arm reach is half the difference between wingspan and height. Both feed receive geometry and discrete cost adjustments. Claude can use these same resolved measurements for visuals, without altering stamina methods.

Codex edits athlete cost/regeneration methods, receive-platform geometry, shared cost/actor integration and corresponding tests. Keep creation/save/visual changes separate. No new continuous proportion/Work Rate cost coefficient, speed formula, momentum coefficient, receive aim curve, sourspot/mismatch base surcharge or DI HP rate is introduced by this slice.
