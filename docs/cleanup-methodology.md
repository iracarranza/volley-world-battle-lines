# Cleanup methodology

This is a behavior-preserving structural cleanup of the Godot contact prototype,
requested October 19, 2026. It is **in progress**; see cleanup-checkpoint.md for
completed stages, validation and the remaining work. Do not treat a passing
subset or an extracted file as completion of the entire cleanup.

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
  contact confirmation, ball/rally state and scheduling. Further separation remains.
- `scripts/lab/athlete_motor.gd`: movement, approaches, takeoff and their state.
- `scripts/lab/athlete_animation.gd`: player pose layers and recovery clocks.
- `scripts/lab/camera_controller.gd`: view/facing controls and camera state.
- `scripts/lab/lab_hud.gd`: lab controls, debug menus and HUD updates.
- `scripts/lab/lab_world_builder.gd`: lab geometry construction and draw helpers.
- `scripts/contact/`: action enum, typed request/result and shared contact resolver.
- Bots and drills supply intentions and apply consequences; they no longer own
  separate implementations of the contact rules pipeline.

The extracted controllers hold a typed session reference and access named peers.
This makes ownership explicit but is not complete dependency isolation. Remaining
cross-controller mutation should be reduced with deliberate operations/events;
do not replace it with an untyped service-locator dictionary.

## Rendering work begun

- Reuse the trajectory ribbon's ImmediateMesh rather than allocating each update.
- Reuse line meshes when geometry remains present.
- Generate the contact preview once per rendered frame, not again each physics tick.
- Redraw the portrait/XP arc only when its value or layout changes.
- Batch the 39 static net strings into one MultiMesh, preserving their transforms.

The initial graphical contact profile had a maximum observed post-contact render
wait of 27.90 ms and no >100 ms stall. It is a baseline observation, not a claimed
optimization result. After-change graphical comparison is still required.
