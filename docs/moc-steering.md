# Trajectory steering experiment

Choose **MoC Settings → Trajectory steering — all contacts**, or cycle with O.
Current, Tuned and Off retain their previous behavior. The experiment applies to
Receive, Set, Attack and Block after physical contact; preparation stays normal.

Defaults:

- Ball and acting athlete ease from normal speed to **0.5% speed over 60 ms**.
- The observation/steering window lasts **1 second of real time**.
- Hold movement directions to accumulate DI at **125% per second**, capped at the
  normal full-DI authority. Releasing retains the selected alteration. Opposite
  input moves back toward neutral. Spike geometry and complementary/contrary
  power adjustments remain relevant.
- Full accumulated DI costs **10 HP**. Cost follows actual steering travel, so
  reversing direction is not a refund or free correction. Insufficient HP limits
  alteration. DI Cost Reduction applies; the cost is provisional.

Speed, duration (up to 3 seconds for testing), steering rate, HP cost and the two
local slowdown toggles are editable in the menu. There is no subattribute scaling
of the window yet. Engine time scale, camera, world and other athletes stay normal.

During the window, the preview remains visible even though preparation has ended.
It projects the current ball velocity at normal flight speed and updates as DI
changes. Its lane and the HP bar glow blue at neutral and progressively red with
alteration. The HP bar also blends toward red and drains smoothly for ordinary HP
expenditure outside this mode. Its number always reports actual remaining HP;
the fill briefly trails the resource change for visibility.

Implementation: `moment_of_contact.gd` owns local clocks and the window;
`moc_steering.gd` integrates DI and HP cost; `trajectory_preview.gd` shares one
ballistic path builder for preparation and post-contact previews. Contact Flow,
charge matching and contact quality are not rerun while steering. Gravity already
accumulated by the physical ball is preserved when its direction is adjusted.

Checks: `moc_steering_test`, existing MoC/trajectory tests, and
`render_moc_steering --render` through `tools/test.py`.
