# VWBL cleanup — October 20, 2026

## Scope and continuation

The user requested another careful repository cleanup, paced across the full
five-hour usage window, then useful VWBL maintenance if time remains.
Window ends **2026-10-20 08:03:45 America/New_York** (12:03:45 UTC).
**Window closed.** Heartbeat `vwbl-cleanup-through-reset` was confirmed paused
at the 08:05 Eastern closeout. No further scheduled work remains.
No reset credit is authorized or needed by this request.

Preserve the substantial pre-existing uncommitted trait-tree work. At start,
HEAD was `71c7a25`; 19 tracked files were already modified, including trait data,
athlete/store/book/editor/view and their tests. Several trait docs/tests and Godot
UIDs were untracked. Recoverable source snapshot and tracked patch:

- `artifacts/cleanup-oct20/baseline.tar.gz`
- `artifacts/cleanup-oct20/baseline.patch`

Do not revert those changes or misattribute them as cleanup work. Authored poses,
vendor assets and live user saves must remain untouched. Use `tools/test.py`
for Godot validation; it copies the project and isolates saves.

## Current work

1. Baseline complete behavioral run with original source in isolated copy:
   **101/101 pass**. Logs: `artifacts/cleanup-oct20/baseline`.
2. Fixed runner test discovery to use the actual selected revision snapshot.
   Missing/empty suites are errors; timeout must be positive and finite.
   Added eight Python runner regression checks covering discovery, error exits,
   zero-exit engine errors, script-error termination and timeouts.
   `python3 -m unittest discover -s tools -p '*_test.py'`: **8/8 pass**.
3. Profiling trait frontier traversal before optimization. Current algorithm
   repeats parent traversal for every pair of picks. Representative baseline
   (five batches of 100 calls) in `frontier-before-valid/renders/trait-frontier-profile.json`
   under the same artifact directory. Rough medians: 87 µs for three merged picks,
   112 µs for a five-node chain, 36.8 ms for all 73 nodes. All-node selection is
   a stress case, not a valid gameplay build. CPU microbenchmark, not FPS/GPU.
   `tests/trait_frontier_profile.gd` is the reproducible profiling utility.
4. Added `tests/trait_frontier_test.gd` to characterize consumption, merges,
   alternative parents, requirements, ordering, unknown IDs and duplicates.
   Initial fixture incorrectly put one merge source in `parent`; actual schema
   lists both in `merges`. Corrected fixture passed original algorithm.
5. Replaced pairwise frontier traversal with one consumption pass, preserving
   order, duplicate handling and self-parent behavior. No persistent cache was
   added, so editor mutations require no new invalidation protocol.
   Corrected contradictory comments describing the already-existing consumption
   semantics; did not change trait schema or gameplay rules.
   Seven targeted behavioral suites and the profile passed (8/8 invocations).
   Output frontiers match baseline exactly. Median CPU microseconds per call:

   | Pick count | Before | After |
   | --- | ---: | ---: |
   | 0 | 0.26 | 0.44 |
   | 3 (merge) | 87.06 | 40.94 |
   | 5 (chain) | 112.15 | 45.46 |
   | 73 (stress) | 36,759.02 | 858.55 |

   Evidence: `artifacts/cleanup-oct20/frontier-after` and
   `artifacts/cleanup-oct20/frontier-comparison.json`. Empty selections incur
   a small additional allocation cost. These are CPU samples on this machine
   with other validation running, not frame-rate guarantees.
6. Runner committed-revision smoke passed: `--revision HEAD pose_library_test`,
   logs in `artifacts/cleanup-oct20/revision-smoke`.
7. Full post-change run **102/102 pass**, logs
   `artifacts/cleanup-oct20/after-batch1`. Collected at 03:35 Eastern.
8. Read-only documentation-link audit found no broken relative Markdown links
   in README/current docs (history excluded).
   Inspected idle thread **Assess Rally Lanes side project**; its latest requested
   Auto/Reaction Speed adjustment was completed and pushed as current HEAD.
   No need to restart it or message that thread.
9. 03:35 heartbeat: reproduced stale success reporting after import failure and
   lost output on import timeout with a controlled fake engine. Regression
   evidence in `artifacts/cleanup-oct20/runner-report-before.log`.
   Runner now clears old results before setup, uses its existing subprocess
   monitoring for imports, retains timeout/error logs, handles missing executables,
   and writes a failed `__import__` entry in the existing list schema. Completed
   suite reports are published atomically; interrupted runs have no final report.
   No partially successful suite list is published as a complete result.
   **14/14 Python checks pass** (`runner-report-after.log`), including invalid
   selection removing stale results. Real Godot smoke: **2/2** (frontier and Auto
   charge), `artifacts/cleanup-oct20/runner-report-smoke`.
   `git diff --check` clean. No gameplay changes in this batch.
10. Compact accumulated evidence is in `docs/checks/cleanup-oct20.json`.
11. 04:05 heartbeat: measured warm-cache `LabAthlete.trait_effect` reads, then
    replaced per-read string serialization with book-ID and value comparisons.
    Cached picks/via are copies, so callers' in-place mutations still invalidate.
    Existing book replacement invalidation is preserved; no editor schema changes.
    New `trait_effect_cache_test` passed before and after (11 contract assertions
    covering empty/changed/cleared picks, alternatives, book replacement and
    unsupported effects). Nine affected behavioral suites plus CPU profile passed
    **10/10** in `artifacts/cleanup-oct20/effect-after`.
    Five batches of 10,000 warm reads per case:

    | Pick count | Before median µs | After median µs |
    | --- | ---: | ---: |
    | 0 | 0.9924 | 0.4964 |
    | 1 | 1.3413 | 0.5137 |
    | 5, with parent selection | 3.6467 | 0.5408 |

    Effects and checksums match; `effect-comparison.json` contains the summary.
    CPU-only microbenchmark with small absolute costs, not an FPS claim.
    Full run **103/103 pass** in `artifacts/cleanup-oct20/after-batch3`, collected
    at 04:35 Eastern.
12. 04:35 heartbeat: existing graphical editor, trait picker and roster captures
    **3/3 pass** in `artifacts/cleanup-oct20/graphics-review`. Inspected
    `pow-tree-full.png`, `trait-picks.png`, `stat-roster-six.png`. Visible picker
    and roster controls are readable; no demonstrated new layout regression.
    Editor screenshot is only a viewport of the wider tree despite its filename;
    do not describe it as whole-tree coverage. No visual code changed.
13. Completed a bounded documentation maintenance task: `trait-master-list.md`
    claimed obsolete Model C stacking and exclusive starts as current. Added a
    specific historical notice, preserving its earlier audit and proposals.
    Architecture now documents current frontier consumption, alternatives/via,
    merges, requires, carried effects, capacity/Flow limits and registered versus
    planned effects. Also documented value-based effect cache invalidation.
    Local Markdown link audit and `git diff --check` pass. Accumulated evidence
    updated in `docs/checks/cleanup-oct20.json`.

## Closeout

Final recorded validation: **103/103 behavioral suites, 14/14 runner checks,
3/3 graphical utilities**, with the three captures inspected as described above.
Closeout re-read those results and confirmed `git diff --check` is clean.
At window close, changes remained uncommitted alongside the preserved pre-existing work.
No reset credit was consumed.

Work was performed in periodic batches through 04:35 Eastern. The later queued
heartbeat messages contain no additional recorded execution; this was not five
continuous hours of active work. The requested window has now expired, so no
new cleanup tasks will be started under this schedule.

## Commit handoff

The user subsequently requested a summary, commit and push. The runtime
optimizations depend on the pre-existing trait-consumption implementation, so
the saved pre-cleanup baseline is committed separately as `f5c0599` (35 files).
The following cleanup commit contains only this session's changes and evidence.
This preserves the boundary between feature work and cleanup while publishing
a complete implementation.

## Optional future work (not scheduled)

- Review remaining measured runtime/tooling issues in small batches. Do not
  invent new game mechanics to fill the time window.
- Import failure/timeout reporting is fixed and validated; do not repeat that work.
- Runtime effect serialization and full validation are complete; do not repeat.
- Initial graphical and trait-documentation review is complete. No UI changes
  justified from the three inspected viewports.
- Further performance candidates need measurements before edits: repeated trait
  UI lookups. Keep the mutable editor model safe; avoid broad cache rewrites.
- Run graphical checks for any visual changes; inspect captures before claiming
  visual correctness. Update this checkpoint with each batch and final evidence.
