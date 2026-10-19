# Current Moment of Contact behavior

`O` and the toolbar cycle Current Slowdown → Tuned Slowdown → Off. Reset preserves
the selection; a new lab starts in Current. Current runs at 60% speed; Tuned runs at 10% speed.
Only ball integration and the acting athlete use the local scale. Other athletes,
drill timers, camera, UI and VFX remain at normal speed. `Engine.time_scale` is
never changed. Input is not buffered. No contact holds the ball or freezes poses.

Sets emit contact events and visual impacts but have zero MoC and clear any prior
slowdown. Off also retains events/VFX without slowdown.

Current duration uses incoming pace, outgoing pace and their vector difference.
Its velocity contribution is 18–140 ms, plus 40 ms for a sweet contact and 100 ms
for a nonzero effect. A contact chain is capped at 280 ms, followed by 80 ms of
normal-speed recovery. Exchanges below the impact threshold receive no effect.

Tuned applies only to spikes (Attack contacts). Preparation remains at normal speed;
actual physical contact starts a fixed 200 ms real-time window at 10% speed for
both the outgoing ball and the acting athlete, including follow-through. There is
no pause or global time change. A subsequent non-spike contact ends the effect
immediately. A distinct spike restarts the window; duplicate events cannot extend
it. Current's chain cap and recovery cooldown do not apply to Tuned.

`scripts/moment_of_contact.gd` owns the clock, event deduplication, duration and
actor scale. A monotonic clock can be injected for tests. Event evidence reports
velocity, sweet, extension and fixed-contact contributions separately. Scene exit, pause and
mode changes clear the effect.

Coverage: `moc_test`, `moc_modes_test`, `moc_slowdown_test`,
`moc_duration_extension_test`, `serve_modes_moc_test`. The graphical
`contact_hitch_profile` checks post-contact render waits separately from gameplay
slowdown. Earlier freeze/compression experiments are retained only in
[history](history/moc-comparison-before-cleanup.md).
