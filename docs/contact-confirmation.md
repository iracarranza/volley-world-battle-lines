# Confirmation timing and contact geometry

Confirmation starts a 200 ms windup, then a 160 ms Receive sweet-eligible window (200–360 ms) or 90 ms for Set/Attack/Block (200–290 ms), with contact forgiveness through 550 ms total. Initial power charging does not activate sweetspots. A remembered overlap (100 ms grace) is rescue-only, including a late confirmation after the ball leaves the volume. Actual geometry is still required for a sweet contact. After 550 ms the input expires. Dive confirmation also uses this same maximum.

The shared contact_execution.gd resolver combines geometric assessment with confirmation age. Players, court helpers and Pepper partners use it. Helpers accumulate charge and confirm 200 ms before their predicted intercept time; delayed arrivals become rescues. Contact events record sweet/rescue state and confirmation age. Debug volumes use gray windup shading before the precision window and lose their green grading after it and show RESCUE; orange denotes the remaining contact allowance.

Spike: visual sector follows actual constructed arm length, limited by the athlete reach envelope. Contact adds a 12 cm radial margin at reference height, plus ball radius. The outer margin cannot be sweet, but moderate stretch still produces a reduced-power spike. Sweet eligibility requires physical reach in 3D. A very late or extremely stretched attack is a weak forward push (3.2 m/s horizontal, 2 m/s up), with a short push pose. Receive rescue is 3.8 m/s forward, 6 m/s up. Both use committed contact facing and bypass target/directional influence. These velocities are provisional tuning.

Set: the spherical sector extends down to shoulder/chin height. The lower shelf has reduced quality and cannot be sweet. The overhead central column retains Ball Control-based width.

Block: two separate cylindrical contact columns replace the single prism. The gap is open. Central hand/forearm regions are sweet-eligible; fingertips and column sides are sour. Contact explicitly returns the normal velocity component while absorbing tangential force and redirecting downward. This prevents opposite velocities cancelling into a stationary ball; better geometry and sweet Timing absorb more tangential force.

Timing increases sweet spike power, reduces sweet set direction error, stabilizes sweet receive toward intended flight, and increases block absorption/downward redirection. It does not extend the precision window in this slice. Timing now has its own canonical `statistics.timing` value and tier-band accessor, independently of Ball Control and Stability. Legacy ACC offsets are migrated safely rather than misread as Timing. A 65 Timing spike preserves the previous sweet power baseline.

Tests: contact_execution_test.gd checks the temporal/spatial boundary, all four Timing benefits, rescue direction, arm margin, low sets, block sourspots/gap, and actual lab contacts. render_contact_windows.gd captures spike/block sweet and rescue states.

Ball contact radius is 0.13125 m (25% above the 0.105 m visual radius), shared by player, bot and serving contact checks.

Driven-flight tuning: ordinary attacks use a 1.40 speed factor on the existing curve, retaining the separate 1.50 airborne multiplier. Neutral attack launch is 6 degrees grounded and about -2 degrees airborne. Gravity remains active. Neutral player sets use 1.40 times the previous range and a 0.80 rise coefficient in place of 1.12 (about 29% less rise). Mouse loft and directional influence still apply. Helper attacks use shorter flight times; helper sets retain their designated destination with a lower arc. Rescue pushes are unchanged.

Block regression fixes: player blocks use swept ball-path checks, matching fast-flight bot sampling. Blocks do not increment ordinary three-touch counters. Rally termination clears pending confirmations, preserving the actual fault message. Away blockers plan at 0.25 m beyond the net with contact eligibility down to net height, allowing flatter driven attacks. block_contact_regression_test.gd covers 30/60/120 Hz driven bot blocks, fast player blocks, touch accounting, and confirmation/fault cleanup.

Resource update: ordinary contacts, serves, sprinting, approach bounds, jumps, and box landings spend STA only. Explicit Quick Step and Rolling Receive ability HP costs remain. Drill rewards can still restore HP. Spike contact depth is 2.10 m instead of 1.10 m, adding 0.50 m ahead and behind the arm plane; the physical sweet region remains reach-limited, and debug colors show the outer depth as non-sweet forgiveness.

Graduated spike forgiveness supersedes the earlier immediate rescue rule: after the 90 ms sweet window, an attack remains a driven spike with gradually reduced power until 420 ms. Moderate reach extensions retain approximately 68–90% spatial strength before the timing modifier. Weak facing-only pushes are reserved for 420–550 ms contacts, remembered overlaps, or extreme placement (reach ratio >= 1.80 or >= 95% of extended half-depth). Receive timing is unchanged. The debug label reads FORGIVING SPIKE during the intermediate timing window.


Grounded confirmation locks horizontal locomotion immediately through contact or window expiry/cancellation. Existing ground momentum and Quick Step travel stop; jump preparation cannot start during the lock. Raw directional keys still feed the DI buffer, so this restriction does not remove aiming input. Initial action-power preparation stays mobile; airborne motion remains committed as before. confirmation_movement_test.gd covers immediate stopping, DI preservation and contact/expiry release.

Serve/attack → Receive also uses the independent charge matching layer described in [receive-charge.md](receive-charge.md).
