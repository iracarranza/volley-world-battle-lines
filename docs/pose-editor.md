> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Pose editor (VWBL)

Author movement poses by dragging joints on the real voli rig instead of editing code.
Open it from the title screen (**POSE EDITOR**) or run `godot --path . pose_editor.tscn`.

## Using it
- **Left-drag a handle** to change its joint. The hint line says what each direction does.
- **Right-drag** orbits, **wheel** zooms, **Front / Side / Back / 3/4** snap the view.
- Sliders on the right edit the same values numerically.
- **Mirror left / right** (on by default) makes one value drive both sides. Turn it off to
  edit one side; turning it back on keeps the left side's values.
- **Shift + drag** a handle changes its twist or rotation instead (spine twist, hip rotation,
  shoulder rotation, forearm rotation, neck turn).
- **Hold B** to see the saved pose against your edit. **Ctrl+Z** undo, **Ctrl+Shift+Z** redo.
- **Save pose** (Ctrl+S) writes `data/poses/planted_receive.json`; the game reads it on next launch.
  **Revert** returns to the last saved file, **Built-in** to the values the code shipped with.
- The body type picker previews the pose on any of the six body plans. The pose is shared.

## Transitions
Every pose is a set of joint numbers, so moving from one pose to another is each joint running
from where it is to where it should be, all over the same time.
- In the editor, **Transition preview** (scroll to the bottom of the panel) picks a From and a To
  pose, a time in milliseconds and a curve, then plays it. Drag the slider to scrub.
- **Save time** stores that pair in `data/poses/transitions.json`; pairs that are not listed use
  the default (160 ms).
- The default curve is a minimum-jerk quintic that starts with the speed each joint already has,
  so changing target halfway through carries on smoothly instead of snapping.
- **In the contact lab**, `scripts/pose_smoother.gd` removes the seam whenever the animation source
  changes (walking, receive stance, approach, jump, dive, roll). Each frame the lab reads the pose
  the code built back into channels (`PoseLibrary.read_rig`), and when the source changes the gap
  to the previous frame becomes an offset that is run to zero over the transition time, starting at
  the speed the joints already had. The new animation keeps full control; the offset only hides the
  seam. Transition times come from `transitions.json` (default 160 ms; pairs are keyed by source name,
  such as `locomotion>receive:planted`). Set `lab.pose_smoothing = false` to turn it off.
- Game code uses `scripts/pose_blender.gd`: `snap(pose)`, `go(pose, seconds)`, `update(delta)`,
  `apply(body)`.
- The set from VWM (`set_gather`, `set_contact`, `set_extend`, `set_jump_contact`, `set_underhand_contact`) is in the library too,
  baked by `tests/bake_reference_poses.gd` through `scripts/set_stage.gd`. The lab's set action does not use them yet.
- Reference poses: `ready_stance`, `planted_receive`, `dive_load_right`, `dive_contact_right`
  (baked from code by `tests/bake_reference_poses.gd`). The editor can open and edit any of them.

## Joints
Each joint has the movements a person has, inside their normal range, so the editor will not
pose the body into something it cannot do.
- **Hips:** forward/back in centimetres (drag the hips handle sideways in the side view). The
  feet stay planted and the legs fold to meet them, so hips back is a sit-back, not a slide.
- **Spine:** a chain of hips (hinge), lumbar, chest and neck. Each has bend forward/back, side
  bend and twist. The torso, singlet and neck meshes are skinned to the chain, so the body
  curves smoothly instead of folding at a seam.
- **Hips and shoulders:** flexion, abduction and rotation about the limb's own long axis, so a
  hip rotation swings the knee hinge outward and the knee tracks over the foot.
- **Knee:** a hinge, 0 to 150 degrees, no hyperextension. **Elbow:** hinge plus forearm rotation.

## How it works
- `scripts/pose_library.gd` defines the joint channels and their limits, loads and saves pose
  files, and writes a pose onto a rig.
- `scripts/spine_rig.gd` poses the spine chain and skins the meshes to it.
- `scripts/receive_pose.gd` applies the `planted` posture from that data. The other receive
  postures (moving, reaching, off-axis) are still code.
- The editor poses the rig through the same path as the game (`Pose.base`, then
  `ReceivePose.apply`, then `ground_feet`), so what you see is what plays.

## Not yet
- Only the player is smoothed; bots still switch poses instantly. Per-pair times for the lab's sources are not tuned yet (everything uses 160 ms).
- Moving, reaching and off-axis receive postures still lean only the torso mesh in code; once smoothing runs they go through the spine like the rest.
- Keyframes within one animation (carry-forward edits across frames).
- An ankle (the rig has none) and a knee that rotates when bent.
- Other postures and the dive still pose the old way, so they do not use the spine.
- Planted receive no longer carries gait leg motion at very slow speeds (under 0.45 m/s), because
  the authored legs replace the stance.
- Old pose files that carry `trunk_pitch` load as `hip_hinge`.

## The dive, start to finish
The crouching step, the dive, the landing and the getting up are one animation (source `dive`).
- Holding Space on a charged receive plays the crouching step (the dive's own preparation), not the jump approach footwork.
- The floor recovery starts from the pose the dive actually ended in, and runs through its stages on one continuous curve
  (`scripts/dive_recovery.gd`, `data/poses/dive_recovery.json`), about 0.7 s in all.
- A backward dive turns the body to face where it is going during the crouching step, then dives forward in that direction,
  and gives the facing back as the body rises. Forward and sideways dives do not turn.

## What reaches the lab (read this before editing)
| Animation | Where it comes from | Edit it in the editor? |
|---|---|---|
| Standing still, and the walk's resting stance | `ready_stance` | Yes. The walk's stance comes from it. |
| Receive stance, shuffle, planted receive | `planted_receive` | Yes. The shuffle walks out of it, and the pose itself is drawn from it. |
| Set (ground, jump, follow-through) | `set_gather`, `set_contact`, `set_extend`, `set_jump_contact` (blended by phase) | Yes. `set_underhand_contact` is in the library but not used by the lab yet. |
| Dive landing, slide, push-up, rise | `dive_recovery.json` and the `dive_recover_*` poses | Yes. |
| Transition times between sources | `transitions.json` | Yes. |
| Walk, run, backpedal, shuffle cycle | VWM gait code, resting stance from the data above | The stance only. The stride is code. |
| Dive crouch step and flight | `scripts/dive_stage.gd`, built on `planted_receive` plus offsets | Only through `planted_receive`. `dive_load_right` and `dive_contact_right` are reference copies and do nothing. |
| Spike swing | VWM spike model through `scripts/spike_stage.gd` | No. It is a curve of phase, not poses. Takeoff loads the arm and points the lead arm, then holds until the click; the click starts the strike, aimed by the ball's position and the shot direction. |
| Jump approach, block | Code in `contact_lab.gd` | No. |
The game reads pose files when it launches, so relaunch the lab after saving.
