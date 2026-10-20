# Cleanup methodology

This is a behavior-preserving structural cleanup of the Godot contact prototype,
requested October 19, 2026. The reviewed cleanup scope is complete. See cleanup-checkpoint.md for the final
validation ledger and architecture.md for intentional boundaries. The project
remains a prototype; completing this cleanup does not implement planned game modes.

## Rules for making changes

1. Establish a recoverable baseline before editing. The initial local Git commit
   is `dd4b32c`. Generated artifacts and Godot caches are excluded; source assets,
   Godot UIDs, authored poses, vendor provenance and specifications are retained.
2. Characterize the existing build in an isolated copy. Record existing failures
   before changing expectations. The baseline passed 65 of 73 suites. The eight
   failing suites are recorded in `checks/pre-cleanup.json`.
3. Change ownership before tuning behavior. Extract controller state and methods
   together, migrate their callers, and verify the same movement/contact cases.
   Keep the session responsible for scheduling, composing peers and rally state.
4. Resolve contacts through one ordered pipeline. Target selection is an input;
   geometry, timing, charge, DI, execution and shanks are shared rules. Keep
   cooperative Pepper target tuning explicit rather than silently duplicating
   the mechanics. Preview assumptions must be explicit and must not consume Flow,
   mutate ball state, or advance a random generator.
5. Treat persisted names as labels, not gameplay identity. Trait IDs are stable.
   Named statistics are authoritative; offsets are the editor's projection.
   Call `AthleteStore.sync_statistics` after editing offsets/parent ratings;
   migration normalizes old saves and retains their archived allocations.
6. Remove retired behavior and callers together. MoC is local 60% slowdown or
   off. Abandoned hold, input-buffer and engine-time restoration code was removed.
7. Optimize measured work. Record frame/contact profiling, retain scene quality,
   and reduce resource churn/duplicate updates before changing visual fidelity.
   Benchmark with the same renderer, resolution, scene and scenario; report
   distributions or repeated observations rather than claiming a speedup from
   one frame. Never call headless timing a GPU benchmark.
8. Validate at each boundary, then run the complete suite and graphical checks.
   Fix stale assertions from current design evidence; do not weaken an assertion
   merely to obtain a pass. Add regression coverage for new contracts and caches.
9. Document the current architecture and behavior, then archive superseded prose.
   Every remaining intentional exception belongs in the architecture guide.

## Validation command

`python3 tools/test.py` discovers behavioral suites. Optional suite stems select a
subset. `--render` enables graphical execution for render/profile scripts.
`--logs PATH` chooses the log directory; `--timeout` defaults to 90 seconds.
The runner copies the project to a temporary workspace, isolates `user://`, imports
Godot classes, captures logs, detects script errors even with a zero process exit,
and writes `results.json`. Authored poses and the live roster remain untouched.
Long traversal/box-route tests need the normal timeout, not the 25-second smoke
budget. Shared assertions live in `tests/support/test_case.gd`.

## Current ownership

- `scripts/contact_lab.gd` / `LabSession`: scene composition, input routing,
  contact confirmation, ball/rally state and scheduling. The architecture guide records this deliberate orchestration boundary.
- `scripts/lab/athlete_motor.gd`: movement, approaches, takeoff and their state.
- `scripts/lab/athlete_animation.gd`: player pose layers and recovery clocks.
- `scripts/lab/camera_controller.gd`: view/facing controls and camera state.
- `scripts/lab/lab_hud.gd`: lab controls, debug menus and HUD updates.
- `scripts/lab/lab_world_builder.gd`: lab geometry construction and draw helpers.
- `scripts/contact/`: action enum, typed request/result and shared contact resolver.
- Bots and drills supply intentions and apply consequences; they no longer own
  separate implementations of the contact rules pipeline.

The extracted controllers hold a typed session reference and access named peers.
This makes ownership explicit without pretending the controllers are independent
engines. Cross-controller operations remain typed and named; do not replace them
with an untyped service-locator dictionary. Procedural world/HUD construction and
fixed indexed scene handles are retained intentionally, as documented in the guide.

## Rendering changes and evidence

- Reuse the trajectory ribbon's ImmediateMesh rather than allocating each update.
- Reuse line meshes when geometry remains present.
- Generate the contact preview once per rendered frame, not again each physics tick.
- Redraw the portrait/XP arc only when its value or layout changes.
- Batch the 39 static net strings into one MultiMesh, preserving their transforms.

- Cache bounded, geometry-specific hurtbox subtrees and phase materials; rebuild
  after physique changes. This removes repeated mesh/material construction on
  repeated confirmations.
- Skip hidden HUD updates and invisible aura transforms/material updates.
- Snapshot portraits into an ImageTexture after three render draws, then stop the
  viewport. This fixes incomplete initial HUD portraits without continuous rendering.
- Redraw Action Wheel text once after its glyphs enter the atlas, then return to
  event-driven updates. Graphical artifacts stay under the test run's `renders/`.

On the same Apple M2 Compatibility renderer, the retained 12-contact comparison
measured confirmation median **7.60 → 1.69 ms** (max 17.92 → 14.87 ms), contact
resolution median **0.345 → 0.440 ms**, and post-contact render wait median
**9.43 → 7.76 ms** (max 21.26 → 22.66 ms). Neither run had a >100 ms stall.
The typed/deep snapshot boundary adds a small contact-resolution cost; repeated
geometry construction is substantially cheaper. The worst render sample did not
improve. These are small sampled observations, not a guaranteed FPS improvement
or a GPU-time measurement. Raw cases and protocol are in
`checks/render-comparison.json`; later HUD repair passed its own graphical check.

## Final verification

The baseline passed 65/73 suites. The final behavioral ledger is **74/74**, including
one new contract suite. The full run had one stale stat-offset fixture; its corrected
save-migration test and the final UI-dependent suites passed targeted reruns. The
ledger retains that provenance instead of claiming an untouched full run was green.
The eight baseline failures were reconciled against current mechanics: recovery
endlag, fixed controlled receive flight, zero ordinary HP costs, toss/strike feeds,
landing-based drill scoring, local MoC and three modes, sweet Pepper timing, and
stable-ID paged traits. No gameplay rule was weakened to satisfy the old assertions.

Six graphical utilities passed (contact profile, HUD, hurtboxes, map, preview and
bot set poses). The final portrait regression and contact profile also passed.
Screenshots were inspected; the portrait sampling issue discovered there was fixed.
Vendor assets and authored poses are unchanged. `git diff --check`, Python syntax
checks and Godot import complete the source checks.

`--revision <commit>` runs a committed snapshot in the same isolated runner for
comparison and discovers suites from that snapshot, including tests removed from
the current checkout. Missing requested suites or an empty suite set are errors.
Runner regression checks require no Godot:
`python3 -m unittest discover -s tools -p '*_test.py'`.
Script errors terminate a suite early with a live log rather than
waiting for its timeout. Long traversal suites retain their normal 90-second budget.
Each run clears the previous `results.json` before preparing its snapshot. Import
errors/timeouts retain `import.log` and publish one failed `__import__` entry in
the same results-list format. Successful runs publish their complete suite list
atomically; an absent report means the run has not completed (or setup failed),
not that zero suites passed. Use the runner's exit code alongside the report.
