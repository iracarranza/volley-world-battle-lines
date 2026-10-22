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
