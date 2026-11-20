# Golden scenario traces (MS-05)

One JSON file per scenario of the catalogue (`tests/support/scenarios.gd`, blueprint section 3.1): `{"trace": [...], "facts": {...}}`.
`trace` is the consequence ledger (ordered snapshots of ball position and velocity, shot metadata, Stamina, HP, Flow, fatigue epoch, rally
counters, last touch, locks, MoC scale); `facts` is the named observations the BDR pins assert on. Floats are snapped to 1e-10 and compared
at 1e-9. They were recorded from the unmodified code (the pre-MS-05 behaviour of MS-04's head) with MoC clock injected and every random source
seeded (`SEED` 1234, rally seed 7).

`writer_ratchet.json` is not a trace: it is the writer-ratchet baseline (category -> file -> number of write lines).

## What compares against them

* `characterization_catalogue_{a,b,c}_test`: run each scenario twice in fresh sessions (the two must agree) and compare the first to its file here.
* `characterization_coverage_test`: files here and the catalogue must agree one-to-one.
* `writer_ratchet_test`: the writer set may shrink, never grow.
* `tools/dual_run.py BASE [CHANGED|WORKTREE]`: runs the catalogue on two builds and diffs the traces (baseline versus changed build).

## Regeneration procedure (rare)

A refactor stage never regenerates a golden: a difference is the finding, and the stage stops. Regenerate only when a behaviour change was
decided and recorded: a decision record, a divergence-register status change (`behavioural-divergence-register.md`), and the designer's ratification
for a gate. Then:

1. `python3 tools/regen_golden.py` (all traces and the ratchet) or `python3 tools/regen_golden.py --ratchet-only` (only to tighten the ratchet
   after a routing stage removed writers). The tool works on a temp copy with an isolated user dir and copies the files back.
2. `git diff tests/golden`: every changed number must be explained by the decision record. Unexplained differences mean the code changed by accident.
3. Commit the files with a message that names the decision record (and, for the ratchet, the stage that removed the writers).

Never regenerate to make a red test green without step 2. Never grow `writer_ratchet.json`.

## Determinism notes

Scenarios use the injected MoC clock, `reseed(1234)` on bots and Pepper, scripted calls (`_contact`, `tick`, `_tick_ball`, `_physics_process` with fixed
dt) and no wall-clock reads. Two scenarios step real physics frames (S-07 settles the player on the floor). Console lines `RNG ... seed` are the
MS-02 seed log and are not part of any trace.
