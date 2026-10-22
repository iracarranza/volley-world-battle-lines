# MoC animation audit and refinement

Approved after the organization cleanup. Audit anticipation, contact, force
absorption/extension, follow-through and recovery at normal speed and every
applicable MoC mode. Prioritize spike windup/follow-through, block press/recoil,
and receive cushioning/trapping/blowback. Add key poses, timing curves or
coordinated joint/body motion only where inspection demonstrates a gap.

## Existing implementation and likely audit targets

- `spike_stage.gd` already has staggered trunk/shoulder/elbow motion, contact
  catch-up and follow-through; inspect before adding duplicate pose systems.
- `lab/athlete_animation.gd` composes player layers; `bot_animation.gd` composes
  court/Pepper layers using shared action stages. Their phase clocks differ;
  compare visuals and timing rather than assuming parity.
- Bot block presentation currently sets overhead arm/elbow angles while airborne.
  Player prepared/airborne pose likewise supplies raised arms. Investigate whether
  press/recoil is visibly missing; a shared block presentation stage may be
  appropriate, but do not change block collision or confirmation state.
- `receive_pose.gd` supplies postures and `floor_recovery.gd` supplies outcome
  recoveries. Inspect controlled cushioning and transition into blowback, without
  duplicating the existing recovery system.
- Current `moment_of_contact.gd` has Current, Tuned, Off and Trajectory Steering.
  Older docs listing only three modes are incomplete. Inspect current code and
  relevant tests when constructing the playback matrix.

## Workflow and acceptance

1. Capture reproducible before sequences, showing phases around actual contact.
   Prefer animation/video or timed image strips with known phase/clock labels.
2. List specific observed defects, then refine one action family at a time using
   existing pose channels and rig limits. Check both handednesses and representative
   body proportions, plus player and bot actors. Include successful and poor contacts.
3. Compare before/after at normal speed and applicable MoC speeds; check no snaps,
   layer fighting, foot sliding introduced by the edit, or unintended pose freezes.
4. Keep gameplay authoritative: no ball attachment/trapping rule, hurtbox/reach,
   contact timing, actor translation or movement penalty changes disguised as
   animation polish. Visual cushioning depicts already-resolved outcomes.
5. Preserve authored pose files unless a specific approved refinement requires an
   edit; retain baseline copies. Leave vendor source assets untouched.
6. Run affected contact, pose, bot and MoC regression suites plus final full checks.
   Provide inspected visual evidence and explicitly record remaining limitations.

Useful existing captures: render_spike_strip, render_spike_directions,
render_receive_responses, render_bot_animation, render_block_field. Read them
before use; they may not cover the required full temporal sequence. All validation
must use isolated project/user data through tools/test.py.

## October 20–21 audit results

The organization stage passed 123/123 suites before animation behavior changed.
Evidence lives under `artifacts/cleanup-organization/` (generated, not committed).

| Area | Observation and decision |
| --- | --- |
| Spike | Existing strip and cross-body/outward captures show loading, strike and follow-through. Left/right short/tall variants also retain these phases. Kept existing authored stages. |
| Standing Receive | Before strips held a fixed platform after contact. Added shoulder/elbow absorption, small chest response and release, settling by 0.42 actor-local seconds. Stronger mismatches absorb more. |
| Block | Before strips held overhead arms after contact. Added a confirmation-driven press and outcome-driven elbow/shoulder/chest recoil, with contact-side lean for severe touches. Recoil settles by 0.38 seconds; press by 0.50. |
| Receive floor outcomes | Inspected shrug, knocked-away, collapse and blown-away phase strips. Existing authored recoveries retain ownership; the new response is suppressed during floor/dive recovery and rolling. No replacement floor system. |

No wrist/finger channels exist in this rig. “Trapping” here means visual force
absorption only: no ball attachment, catch, hold, changed contact window or changed
bounce. Existing authored pose files and vendor assets remain unchanged.

Final numeric comparison (`motion-comparison.json`): all 32 cases settle within
0.001 degrees of the baseline at the last sample. At one real second, sampled
actor time is .904 s in Current, 1.0 s in default Tuned/Off, and .720 s in
Trajectory Steering. These reflect the active defaults, not an assertion that
Tuned mode can never slow actors.

### Evidence and coverage

- `animation-before`: four established graphical capture utilities passed.
- `motion-before` and `visual-final`: same 32 temporal cases, player/bot ×
  Receive/Block × controlled/overpowered × four MoC modes. Columns are real
  seconds `[0, .05, .12, .22, .38, .60, 1]`; joint JSON records actor-local time.
- `visual-final`: 12 handedness/proportion strips (Left/Right, 1.55/2.05 m,
  wingspan/stride ratios .8/1.2 and 1.2/.8, three action families), plus five
  press/recovery strips. Variant columns are `[-.2, 0, .07, .15, .25, .38, .6]`;
  negative contact age is anticipation. Spike uses those values as stage phase,
  not seconds. Press columns: `[0, .03, .06, .12, .25, .4, .6]`; recovery columns:
  `[0, .12, .25, .45, .65, .85, 1]` times each recovery duration.
- `motion-after/spike-directions.png`: existing cross-body/outward stage audit.
- `contact_response_pose_test`: phase continuity, severity/side differentiation,
  actor-local clock ownership, reset, repeated pose evaluation, unchanged shape,
  actor/ball state, recovery precedence and a mid-response action-switch seam.
- `physical-response`: real swept player/bot block events at 30/60/120 Hz verify
  resolved evidence reaches presentation. Existing contact/receive/MoC suites
  remain the authority for gameplay behavior.

Temporal strips deliberately inject finalized event evidence to isolate pose
motion; they are not recordings of a live rally. The proportion/handedness sample
is representative, not every possible build/species combination. No performance
improvement is claimed. Normal-speed human playtesting remains useful for judging
how strong the subtle cushioning/press should feel in play; timing and geometry
were deliberately not retuned to exaggerate it.
