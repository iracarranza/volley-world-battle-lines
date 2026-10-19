> Historical checkpoint, superseded by ../cleanup-checkpoint.md. Do not execute its remaining-work list or reset instructions.

# Cleanup checkpoint — October 19, 2026

## User authorization and continuation

Complete the full structural cleanup from the preceding audit, document the
methodology, and optimize rendering wherever beneficial. Claude is NOT currently
editing this project. Preserve the existing gameplay feel and authored animation.

User authorizes ONE full usage reset only when **weekly remaining <3%** (weekly
used >97%). No reset has been consumed. If the five-hour window runs out first,
resume at its reported replenishment. The current replenishment epoch is
1792407873: October 19, 2026, 07:04:33 America/New_York. A local one-shot launcher
queues this existing thread using `tools/resume_cleanup.py`; execution requires
an awake machine. See the launch-agent log for actual delivery, never assume it.

## Completed implementation

- Local Git baseline established (`dd4b32c`).
- Isolated test runner and shared assertion harness.
- Removed source-spelling architecture assertion.
- Stable gameplay trait IDs, canonical named-stat precedence; explicit editor sync.
- Removed obsolete MoC hold/buffer/global-time compatibility machinery. Two local
  slowdown tunings and Off remain; an injectable monotonic clock is available.
- Typed ContactRequest/ContactResult, action enum, one shared assessment/flight
  resolver used by player, court bots, Pepper and trajectory preview.
- Extracted camera, motor, animation, lab HUD and world construction with owned
  state. Main script reduced from 2,572 to about 1,170 lines. Tests/callers migrated.
- First rendering allocation/batching improvements listed in cleanup-methodology.md.

## Validation evidence

Baseline: 65/73 suites. Existing failures: confirmation_movement_test,
contact_zones_test, creator_bound_test, map_drills_test, moc_modes_test, moc_test,
pepper_move_set_test, title_menu_test. These predate this cleanup and mostly encode
superseded mechanics. Read their logs and current design before repairing them.

Shared resolver: prototype, receive outcomes, Flow, Pepper sequence and preview
all passed. Extraction broad run passed 61/73 with a 25-second timeout: two long
suites timed out (box_jump_routes, map_traversal), one fixture still called the old
pose API (fixed), and set_hurtbox's authoring fixture needed explicit stat sync
(fixed). The remaining eight match baseline failures.

Final smoke after initial rendering changes: pose_wiring, trajectory_preview and
prototype all PASS. Additional normal-timeout tests are at
`/tmp/cleanup-checkpoint-long.log` and `/tmp/cleanup-checkpoint-long/`.
Full logs: `/tmp/cleanup-baseline-tests`, `/tmp/cleanup-extracted`,
`/tmp/cleanup-checkpoint`. Machine-readable snapshots are in docs/checks.

## Remaining work — do not claim full cleanup complete

1. Finish baseline failure reconciliation. Confirmation test assumes no endlag;
   bump test assumes charge still controls distance/height; drill test samples the
   toss as the struck serve; Libero test assumes HP contact costs; MoC tests still
   assume global time / two-mode cycling; title test assumes old trait-tree IDs;
   Pepper test needs review against current charge/timing and outcome rules.
2. Complete typed contact event/schema (events still dictionaries), migrate
   parallel bot settings arrays into per-bot records, remove unused root imports
   and consolidate repeated enums/constants. Improve long dense expressions.
3. Further narrow session responsibilities and explicit controller interactions.
   Introduce editable Resources/scenes for camera/tuning/HUD composition where
   useful; do not change vendor rig construction or blindly rewrite authored poses.
4. Profile rendering after the initial optimizations. Inspect repeated player pose
   work, hurtbox rebuilding and shader/material churn, hidden menus and bot poses.
   Preserve animation/physics synchronization, visibility and immediate controls.
5. Rewrite README around current behavior; make an architecture/navigation guide;
   mark or archive superseded docs instead of appending contradictory updates.
6. Add meaningful tests for canonical stat precedence, rename-safe traits, shared
   resolver parity, immutable contact contracts and cached rendering resources.
7. Run all behavioral suites with normal timeout; graphical profile and screenshots;
   inspect artifacts, make final commit, and relaunch only the verified build.

## Usage monitoring discovered

Installed CLI exposes `codex app-server --stdio`, JSON-line initialize followed by
`initialized`, then `account/rateLimits/read`. Protocol types were generated to
`/tmp/codex-quota-protocol`. `/tmp/read_codex_usage.py` is a read-only sampler.
Usage samples: five-hour used 51 ->67 ->77 ->88%; weekly used77 ->79 ->81 ->82%.
The measured five-hour burn was roughly6–7 percentage points/minute during the
large-context refactor, so finishing this window was not a credible forecast.

`account/rateLimitResetCredit/consume` takes an idempotencyKey and optional creditId.
Use only under the user's condition, at most once, and persist evidence to prevent
accidental double consumption. Three reset credits were available at checkpoint.
No reset operation has been called.
