# Organization cleanup and MoC animation continuation

Authorized order: behavior-preserving organization cleanup following
`cleanup-methodology.md`, then `moc-animation-audit-plan.md`. User explicitly
approved both after temporarily holding cleanup for the animation discussion.
No commit/push was requested for this round.

One-time heartbeat `vwbl-cleanup-through-reset` dispatched at October 20, 2026,
23:33 America/New_York and was **paused successfully**. No reset credit consumed.
Do not recreate or resume the old morning reset-window automation.

## Baseline and protected work

Starting HEAD: `8f967b7`. Existing morphology/title work in project.godot,
map_graybox.tscn, athlete_creator/menu/store, contact_lab, title_screen,
voli_visual and untracked title/morphology scripts/tests/docs is preserved.
Snapshot: `artifacts/cleanup-organization/baseline.tar.gz` and `baseline.patch`.
The first baseline was interrupted during the temporary user hold; the fresh
`baseline-resumed` run passed **123/123** suites.

`preservation.json` compares 132 source/asset files with the snapshot: no changes
to protected files, authored poses or vendor assets. AppleDouble archive metadata
is excluded. contact_lab matches the baseline after removing this round's two
new animation hooks. All runs use isolated copies/user data via tools/test.py.

## Structural stage — complete

- Split `LabAthleteAnimation.update()` into named layers in existing composition
  order, preserving predicates/calculations/overrides. Moved set-phase comment to
  its actual method.
- Grouped dependencies, constants and state before lifecycle/action methods in
  court/Pepper controllers; moved misplaced initialization method/declarations.
- Moved receive/roll/dive/spike/set clocks into animation ownership. Motor now
  schedules `tick_action_clocks(dt)` with actor-local time. Removed unused preload.
- Updated architecture ownership and composition guidance. No mass file moves or
  broad reformatting. No measured performance improvement is claimed.

Checks: `animation-layers` 6/6, `controller-layout` 5/5, `clock-ownership` 6/6,
`structural-final` **123/123**. Structural-only diff saved as `structural.patch`
before animation implementation. Source changes after that full run were removal
of an unused preload and the separately validated animation stage below.

## Animation stage — implemented, final full check pending

- Before temporal strips showed static standing-receive and block post-contact
  poses. Added shared `contact_response_pose.gd` with bounded shoulder/elbow/chest
  curves: receive absorption/release, block confirmation press and severity/side
  recoil. Uses resolved event/assessment evidence and existing local clocks.
- Existing spike stages already show coordinated load/strike/follow-through;
  inspected directions, handedness and proportions, retained them.
- Player and bot composition apply response before existing source smoothing.
  New seam test proves a mid-response action switch retains the displayed pose.
- Dive/roll/floor recoveries retain precedence. Existing authored floor strips
  inspected; no ball trapping, geometry, root movement or gameplay timing changes.
- Physical block integration test now checks evidence reaches player and bot
  animation at 30/60/120 Hz. New contact response suite covers shape/ball/root
  preservation, clock/reset, nonaccumulation, continuity, evidence ownership and
  recovery/switch priority.

Checks already passed: `response-integration` 4/4, `response-contracts` 1/1,
`physical-response` 1/1, `response-seams` 4/4, `response-switch` 1/1.
Python runner regressions: **14/14**. `git diff --check` clean.

Graphical evidence: `animation-before` 4/4, `motion-before` 1/1,
`motion-after` 2/2, `variants` 1/1, `visual-final` **3/3**. Final utilities produce
32 MoC temporal strips, 12 handedness/proportion strips, five press/floor strips
and sampled joint JSON. Representative final strips inspected. Detailed matrix,
timing labels, conclusions and limitations are in `moc-animation-audit-plan.md`.

## Finish from here

1. Collect `artifacts/cleanup-organization/final-verified/results.json`, exec
   session **37893**, which includes current runtime and strengthened tests.
   Earlier `final` run (session 67929) predates the response-smoothing adjustment;
   do not use it as final proof. Both snapshots are isolated.
2. Compare final temporal JSON against `motion-before` and save
   `motion-comparison.json`; verify settled poses and actual MoC clock samples.
3. Update this checkpoint with final results and any failures; run diff whitespace
   check. Report the completed scope and honest visual limitations. No commit/push.

No known blockers. Human playtesting can guide future aesthetic amplitude tuning;
this pass deliberately keeps cushioning/press subtle and protects game rules.

## Final verification (2026-10-21, run from Claude's session)

- `tools/test.py` isolated full run over the current working tree (which includes the morphology sliders, title backdrop and the Second Wind +10 data change made after Codex's run): **123/124 on first run**; the one failure, `six_step_completion_test`, was a stale expectation (Second Wind restoring 23, now the base node's 10). After updating that check it passes **48/48**. Logs: `artifacts/cleanup-organization/final-claude/`.
- Codex's earlier `final-verified` run: 124/124. `motion-comparison.json`: 32 cases settle within 0.001 degrees.
- `git diff --check` clean. No commit/push of this animation/cleanup work was requested; `project.godot` and `map_graybox.tscn` carry Godot editor re-save churn (UIDs, header comment, one default filter line removed) and should be reviewed or reverted before any commit.
