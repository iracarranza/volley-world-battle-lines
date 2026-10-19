# Bot and camera tuning

F9 opens the independently configurable home/away bots. Each uses the real VWM Feli construction, default 73-inch height / 1.90m span, and POW/SPD/ACC/END 65. Contact geometry comes from the same `contact_geometry.gd` definitions as the athlete, including actual rig shoulder measurements. Receive uses the forward-only fan, Set the overhead ellipsoid, Attack the dominant-arm sector, and Block the wall. Tracking positions the athlete around its preferred contact point; high Attack/Block contacts raise the entire bot instead of detaching its hurtbox. Static contacts and swept tracking contacts test this actual geometry.

Tracking accuracy is separate from the athlete's ACC attribute: 100% places the preferred point on the flight; lower percentages add a uniformly distributed horizontal positioning error in a disk, reaching 2.5m at 0%. A genuine geometric overlap is still required. The error is sampled per plan, and a missed plan does not retry indefinitely on the same flight. Static mode ignores this slider. Existing contact assignments and home-block restriction remain.

Athlete View orbits at 7.5m until reaching 0.4m floor clearance. Further upward input retains that position/distance while tilting the optical axis upward. The athlete consequently leaves exact screen center after the floor stop. Collision avoidance for other solid obstacles remains active. Pitch now extends to 1.15 radians.

Parallel-to-floor aim (view_pitch 0.27, accounting for the rig's -0.27 offset) preserves the calibrated outgoing arc. Receive and Set scale vertical rise from 35% at the downward limit to 250% at the upward limit. Horizontal speed is re-solved to preserve the charge-based landing range. Attack and Block adjust their launch angle with aim pitch, capped between -65 and +70 degrees. Bot scripted destinations remain independent of the player's look direction and build.

Validation: `bot_camera_arc_test.gd` checks default bots, real rig construction, geometry rejection, tracking misses, arc caps/range preservation, and fixed-distance floor tilting. The legacy calibrated trajectory fixtures explicitly use level aim.

## Approach and block motion

Attack bots now perform a timed right-lead bound, short step and inward plant, followed by a vertical spike jump, dominant-arm swing and landing. Block bots load, jump with both arms extended, contact and land. Their hurtboxes travel with the athlete, and the default build caps jump reach; the boxes are never independently elevated. Static attackers/blockers retain their fixed ground position while jumping. Landing continues after the ball is down.

The away blocker now responds only to an identified opponent Attack, not a Serve or Receive/Set, and only inside its reachable height band. Previously it intercepted every incoming serve and return (including unreachable high balls), preventing the away receiver, setter and attacker from participating. Serve/feed clear the flight action; player and bot contacts mark it before replanning. Home still has no blocker. With all helpers enabled, a serve now produces real away Receive → Set → Attack contacts.

`tests/bot_rally_motion_test.gd` covers the away sequence, approach/jump, raised-arm block, landings, serve exclusion, and static jumping contact.

A missed block now replans the rest of the same flight for ordinary contacts as soon as the ball clears the block wall (or its contact window expires). It skips another block attempt and leaves the receiving side's contact count unchanged. The blocker continues its landing independently while the away receiver can take first touch. Regression coverage includes 6m/s and 24m/s incoming attacks at both 60 and 120Hz.
