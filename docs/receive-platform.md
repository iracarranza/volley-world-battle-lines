> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Forward receive fan and contact poses

Receive uses a vertically extruded forward half-ellipse (a rough semicircular fan), not an ellipsoid. At reference height 1.86m, reach is 1.85m forward and 1.15m sideways. Its flat rear boundary is the athlete's body plane: no receiving volume or rendered vertex extends behind it. Ball-center positions behind that plane are rejected, including the old overlap-memory grace path.

All dimensions and reference positions scale uniformly by `height / 1.86`. Height does not change proportions. Standing/dive retain different vertical bands. Future Platform Quality traits can customize proportions separately; none are enabled in this change. These remain deliberately forgiving prototype dimensions, not measured biomechanics.

## Contact region → live receive pose

| Condition | Pose |
|---|---|
| Central contact, standing still | Planted |
| Central contact while moving faster than 0.45m/s | Moving |
| Far-forward contact (at least 68% of forward reach) | Reaching |
| Side contact (at least 40% of side reach and outside the central 35° sector) | Off-axis |

A side reach takes priority over a forward reach; a forward reach takes priority over movement. These describe the actual contact, independent of quality: a moving receive can still be clean. The same classification drives pre-contact adjustment when the ball enters the envelope, impact metadata, the visible hurtbox label and 0.42s of follow-through. The end of follow-through blends back toward neutral locomotion.

The live variants use the actual VWM constructed skeleton, posed through `receive_pose.gd`. Positive shoulder pitch extends the rig's downward arm toward -Z, its forward direction. This fixes the reversed Avi ready arms and is tested on all six body types. Planted joins the forearms; moving retains gait; reaching extends both arms and lunges; off-axis turns the platform, trunk/head and far leg toward the side contact. Rolling Receive retains its separate existing roll behavior.

## Grading and trajectories

The fan is graduated into clean/green, fair/gold, weak/orange and sour/red zones using normalized planar reach, lateral angle and vertical offset. Grading and animation are separate axes. Current wide horizontal edges retain the `edge` flag used by Rolling Receive. Its existing roll/lob and HP cost remain intact.

Left/right contact offsets produce mirrored facing-relative outgoing azimuth, with incoming lateral glance contributing more as quality falls. Output stays within the existing 38° forward cone. Forward contact position changes loft: center contact keeps the calibrated charge curve, farther contacts are flatter, and no variation raises the bump above its ceiling. Horizontal pace is re-solved to preserve distance for stored charge and contact height. Receive output is deterministic; no phase-based yaw noise is added.

This remains Rally Lanes' provisional contact resolver, not a port of VWM's pace-retention solver. It supplies explicit contact coordinates and posture for that future adapter. Existing intended previews stay separate from resolved contact variations. MoC uses the resulting velocity exchange normally.

## Debugging and validation

Confirmation displays the actual graded fan. Its geometry, colors and contact tests come from the same module. `last_contact_result` carries quality zone, posture and normalized platform coordinates.

`tests/receive_platform_test.gd` checks height scaling, forward-only extrusion, wider forward than lateral reach, body-plane rejection even with overlap memory, animation classification, forward wrists on every body type, live pose correspondence, mirrored and rotated outputs, preserved charge distance/height, existing edge behavior and matching debug mesh. Existing action/trait/stance/drill tests cover regressions.

`tests/render_receive_platform.gd` accepts `-- --avi`, `-- --avi --reaching`, `-- --avi --off-axis`, and `-- --avi --moving` for engine-rendered snapshots. Avi planted, reaching and off-axis poses were visually inspected.
