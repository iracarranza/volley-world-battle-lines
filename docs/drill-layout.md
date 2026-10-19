> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Narrow drill lanes and jump-serve feed

Spike Trainer occupies a 6 m-wide lane (x -19 to -13). Its suspended ball is standing reach + 1.40 m, 30 cm above the earlier setting. A 1.5 m-wide floor runway runs from z 10.5 toward the plant stripe at z 7.5, centered at x -16. Start/plant labels and right-left-inward foot marks suggest the approach rhythm. These are provisional guidance, not a movement lock; physique and approach execution still matter.

Serve Receive occupies a 6 × 13 m lane (x 13–19, z 0–13), retaining its original dimensions. Feeds land only in the far half (z 6.5–13). The participant receives toward the entire opposite half (z 0–6.5): its left quadrant scores 1 point and its right quadrant (x 16–19) scores 2. Floor colors and the center line mark the regions. Eight points completes the drill and grants the existing completion reward.

Points are awarded only when the received ball lands. Shanks stay in play; wrong-half/outside landings score zero and another serve follows. An untouched serve still fails the attempt. Leaving/reentering the station does not stop a running attempt. A 12-second return safety timeout advances with zero points. Serve patterns and charge demands cycle independently of score, allowing more than six serves. Each feed telegraphs a 600 ms upward toss and an animated overhead paddle strike. Feeds retain a 3.60 m strike height, z -10 origin and 22–25 m/s horizontal pace, but are now solved to actual floor targets inside the far half of the full area. This off-court lane has no net.

bot_facing_drill_layout_test.gd checks approach orientation, airborne commitment, shot limits, lane widths and all six serve trajectories. Map-drill and station-approach tests complete both actual contact sequences. render_drill_layout.gd captures the floor markings and launch location.

Once Serve Receive starts, its painted bounds only designate the entry area. Leaving does not stop the sequence or erase progress, and reentry does not cancel a live feed. The scheduled serves continue; an unreceived ball ends the streak normally. Active drill status remains available outside the lane.
