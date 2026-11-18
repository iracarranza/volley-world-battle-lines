# Performance notes

Press **F3** in any lab or map scene for the on-screen readout: frame rate, frame time (average and worst of the last second), engine process and
physics time, draw calls, objects, nodes and memory.

## Measuring

- `godot --headless --path . --script res://tests/profile_rally.gd` runs a map rally (three bots a side on the middle net) and prints the cost of the
  frame's pieces (script time per frame; headless, so no rendering).
- `godot --path . --script res://tests/profile_render.gd` opens a window and prints real frame times (average, median, p95, p99, worst) with the
  engine's draw/object counts. Close other game windows first.

## Findings (first pass)

- A map rally is bound by GDScript, not physics or drawing: hiding the map, props, Pepper partners or carts barely changed frame time, and the
  physics engine itself has one active body. The biggest cost was posing bot skeletons every physics frame.
- Pose lookups rebuilt node paths and key strings for every joint of every posed athlete each frame, and the staged swings re-read their base pose
  file from disk each frame. Both are cached now (`PoseLibrary.rig_node`, `flat_pose`, the joint tables).
- A bot that is standing still with nothing to do is re-posed every 0.1 s, and one off screen every 0.25 s (the time it missed carries into the
  next update). A bot that is moving, planned or following a contact still updates every frame.
- Debug contact boxes are refreshed only while visible (the map roster has 28 slots).
- Physics-frame time for the profiled rally went from about 5.8 ms to 3.7 ms; the bot tick from 3.5 ms to 1.5 ms.

## Not done yet

- Frame spikes (p99 about 31 ms, worst about 300 ms in the rendered run). Suspects: shader compiles the first time an effect appears, and garbage
  from per-frame dictionaries and arrays in the bot tick.
- Each bot rig is about 78 meshes; the three Pepper partners (240 meshes) are always visible. Merging rig meshes, or hiding partners when unused,
  would cut draw work if the GPU becomes the limit.
- The pose smoother and the pose-apply step are now the largest remaining bot costs.

## Action/UI cleanup pass (2026-10-23)

- Pose smoothing computes the quintic transition weights once per update, and skips offset
  calculations after the blend ends. A 72-channel, 10,000-update headless comparison against
  the previous implementation measured 80.56 → 51.87 µs/update for steady poses and
  91.16 → 67.40 µs/update while switching sources. A 1,000-frame equivalence check had
  zero numerical difference for the sampled poses. These are component measurements, not FPS gains.
- Receive planting reuses a per-action working pose instead of deep-copying the authored pose
  and allocating side-channel dictionaries every frame. Each new action reloads the cached
  authored baseline, so pose-editor changes are picked up on the next confirmation.
- Timeline regions rebuild only when the action or spike windup changes. Parked/held timelines
  redraw only when their displayed state changes; fading uses canvas modulation.
- Trajectory previews now use the same tilt/lean-relative contact coordinates as live contacts.
- The same 900-frame rally profile produced eight bot contacts before and after. Physics script
  cost was essentially unchanged (3.012 → 3.014 ms/frame); render-side script work was
  0.387 → 0.378 ms/frame. This pass reduces local work without claiming a large overall FPS gain.

Validation: pose smoother/blender, movement animation, receive planting, action timeline,
trajectory preview, bot rally, and spike sweep suites passed. Profiles were run headlessly.

## Rig draw-call prototypes (2026-10-25)

`VoliVisual.rig_mode` selects how an athlete's ~77 meshes are drawn:

| Mode | Meshes | Draw calls | Frame time | Look |
|---|---|---|---|---|
| SEPARATE | 77 | baseline | baseline | baseline |
| MERGED (default) | 53 | about 24% fewer | about 13% faster | matches separate |
| SKELETON | 17 (19 bones) | about 60% fewer | about 8% slower | matches separate |

- MERGED combines each limb joint's rigid parts into one solid and one outline mesh (`rig_merge.gd`); part colours are baked to vertex colours.
- SKELETON (`rig_skeleton.gd`) skins the rigid parts to one Skeleton3D. Syncing bones costs about 0.1 ms/frame, and skipping it did not change the result, so the
  extra cost is the engine's skinned-mesh path in the Compatibility renderer. Not the default here.
- Torso, Singlet and Neck are still CPU-skinned by the spine rig, and face parts stay separate. Later ideas: GPU spine skinning, faces and hands.
- `tests/render_rig_modes.gd` renders five poses in each mode (pixel differences at most about 0.0009); `tests/rig_modes_test.gd` checks counts, paths and bone poses.
