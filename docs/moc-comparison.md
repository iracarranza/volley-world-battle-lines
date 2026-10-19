# Current Moment of Contact behavior

`O` and the toolbar cycle Current Slowdown → Tuned Slowdown → Off. Reset preserves
the selection; a new lab starts in Current. Every enabled effect runs at 60% speed.
Only ball integration and the acting athlete use the local scale. Other athletes,
drill timers, camera, UI and VFX remain at normal speed. `Engine.time_scale` is
never changed. Input is not buffered. No contact holds the ball or freezes poses.

Sets emit contact events and visual impacts but have zero MoC and clear any prior
slowdown. Off also retains events/VFX without slowdown.

Current duration uses incoming pace, outgoing pace and their vector difference.
Its velocity contribution is 18–140 ms, plus 40 ms for a sweet contact and 100 ms
for a nonzero effect. A contact chain is capped at 280 ms, followed by 80 ms of
normal-speed recovery. Exchanges below the impact threshold receive no effect.

Tuned duration uses 60 Hz frame units. Sweet Receive contributes two or three
velocity/sweet frames; sweet Attack/Block/Serve uses up to five. Ordinary or rescue
contacts receive at most one frame when impact is strong enough. Nonzero effects
add 100 ms; the chain limit is 183.33 ms. This is the retained REMATCH-inspired
comparison tuning, now implemented as continuous slowdown.

`scripts/moment_of_contact.gd` owns the clock, event deduplication, duration and
actor scale. A monotonic clock can be injected for tests. Event evidence reports
velocity, sweet and extension contributions separately. Scene exit, pause and
mode changes clear the effect.

Coverage: `moc_test`, `moc_modes_test`, `moc_slowdown_test`,
`moc_duration_extension_test`, `serve_modes_moc_test`. The graphical
`contact_hitch_profile` checks post-contact render waits separately from gameplay
slowdown. Earlier freeze/compression experiments are retained only in
[history](history/moc-comparison-before-cleanup.md).
