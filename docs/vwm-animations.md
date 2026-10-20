> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# VWM voli animations: what the lab has

Inventory of the animation families in `vendor/vwm/construction` against what the Contact Lab draws. The lab drives the VWM rig
directly (pose library, spine rig, blender, smoother) and does not call the VWM actor's own `set_pose`.

| Family (VWM source) | In the lab | Notes |
|---|---|---|
| Ready stance, gait, shuffle | yes | `ready_stance` pose, gait, shuffle when a receive is ready |
| Receive postures: planted, reaching, off-axis, moving | yes | `receive_pose.gd`; planted is authored data |
| Dive (commit, flight, floor arrival) | yes, redesigned | `dive_stage.gd`, `dive_recovery.gd`, authored poses |
| **Recoveries: knee, fall (roll / slide), blown_away** | **yes, new** | `floor_recovery.gd`, `data/poses/floor_recoveries.json`. Played from `receive_resolved` for the player |
| Set | yes | `set_stage.gd`, poses `set_*` |
| Spike (approach, windup, swing) | yes | `spike_stage.gd` |
| Wing poses (Avi) | yes | `wing_pose.gd` |
| Block jump (phased, `block_biomechanics.gd`) | **no** | the lab holds a static block pose |
| Serve action (`serve_action_biomechanics.gd`, `serve_biomechanics.gd`) | **no** | |
| Landing absorption (`landing_biomechanics.gd`) | **no** | |
| Idle motion (`idle_biomechanics.gd`) | **no** | |
| Contact arrival (`contact_arrival_biomechanics.gd`) | **no** | blends gait into a contact pose: how much of the upper body, lower body and stride the contact owns as the ball nears. The lab snaps instead |
| Face expressions (`face_expressions.gd`) | **no** | |

## Receive recoveries

VWM reaches `knee` and `fall` when a defender is off balance after a contact, and `blown_away` when a hard ball drives them off it.
Durations are VWM's own priced recovery times (knee 0.55 s, fall 0.95 s, blown away 1.35 s), so the drawn recovery and its cost agree.

| Recovery | Drawn as | Authored poses |
|---|---|---|
| `knee` | one knee down, fold over it, push, rise | `recover_knee_drop/catch/push` |
| `knocked_away` (event `fall_roll`) | the impact carries through the arms and swings them off the off-axis line, the spine twists that way, and one foot steps back to catch the centre of mass. Authored for a contact on the right, mirrored for the left | `recover_ka_hit/swing/step/settle` |
| `collapse` (event `fall_slide`) | falls to hands and knees in the direction of the contact (forward, leaning to the side it landed on), pushes, gathers, rises | `recover_collapse_stumble/hands_knees/push` |
| `shrug` (new, not VWM) | midline receive mishandled while planted or moving: arms shrug in and up, platform drops along the chest, body straightens and heightens, staggers back 0.6 m, never falls (0.7 s) | `recover_shrug_hit/platform/stagger` |
| `blown_away` | thrown back onto the back, lie, sit up, gather, rise | `recover_blown_hit/down/sit/gather` |

All four end exactly in `ready_stance`, so they hand back to standing with no seam. Every pose is a pose file and shows in the pose editor.

### How the lab plays them

The lab listens to `receive_resolved` (see `docs/receive-outcome-handoff.md`); the event's `recovery` is authoritative and `choose()` is no
longer called. For the player only (bots and Pepper partners are not animated yet):

- The resolver's event names `fall_roll` and `fall_slide` are kept; `FloorRecovery.resolve()` maps them to `knocked_away` and `collapse`.
- Contact side is the sign of `receive_outcome.platform_coord.x` (handedness when centred); it mirrors the poses and sets which way the body travels.
- The DI `penalty_factor` (0.65 to 1.35) stretches or shortens the whole animation.
- Input is locked until the rise (shrug: until `recovery_penalty_seconds`, since its gameplay budget of 0.25 s is shorter than its 0.7 s animation).
  Moving during the unlocked tail speeds the animation up, as with the dive.
- The body travels the plan's `travel` metres with constant deceleration: knocked away steps back and a little away from the contact side, collapse goes forward leaning to the contact side, blown away and shrug go backward.
- Skipped while jumping, diving, rolling or already recovering. Smoothing treats each recovery as its own animation source (`floor:<name>`).

Not done: bots and Pepper partners, and the Stamina and HP cost of a recovery.

Strips: `godot --path . --script res://tests/render_recovery_strip.gd -- --name=knee|fall_roll|fall_slide|blown_away [--side=left] [--close]`
writes `artifacts/recovery-<name>.png`. Tests: `tests/floor_recovery_test.gd`, `tests/floor_recovery_lab_test.gd`.


## Procedural by contact side

Receive animations are built from where the ball is, not from fixed left and right poses:

- **Postures:** moving, reaching and off-axis all turn the platform and shoulders toward the ball (35%, 60% and 100% of the angle), and a reaching receive lunges with the leg on the ball's side.
- **Recoveries:** knee, knocked away, shrug and blown away are authored for a contact on the right and mirrored for the left. Shrug and blown away also blend toward a symmetric version as the contact nears the middle (`lateral`, full at 0.45 of the platform width), so a ball down the middle favours no side. A shrug lifts the near shoulder higher and steps the far leg back; blown away flings the near arm higher and twists the body away.
- **Running:** a prepared receive no longer runs with the platform out. The arms come down as the athlete speeds up (from 55% to 85% of top speed) and come back as they slow or as the ball gets within about 3 m.

## Spike and set lead-in

- **Angled spikes:** the cross-body and outward swings were reversed (a shot to the left swung the right-hander's arm outward). A sign in `SpikeStage._aim` is fixed: a shot to the left now carries the hand left for either hand, a shot to the right carries it right (`tests/swing_lead_in_test.gd`, `tests/render_spike_directions.gd`).
- **Spike lead-in:** a ball struck before the strike had finished (a click as the ball is already in reach) used to snap the arm from the loaded pose to contact in one frame. The arm now carries on through the rest of the strike over 0.09 s, and the follow-through starts from contact.
- **Set lead-in:** the hands now gather as the ball comes in (from the ready stance a second out to the forehead as it arrives) instead of already being gathered, and the push after contact blends over 0.20 s instead of 0.12 s. With no ball coming the gather holds, as before.
