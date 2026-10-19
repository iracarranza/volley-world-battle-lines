# Free serve, Pepper partners and camera experiment

## Controls

- **E** tosses a real ball anywhere outside an active ball drill/Pepper exchange. **E again** initiates a short serving-arm swing. A missed swing does not launch the ball; a fallen toss ends the attempt.
- **K**, or **BOXES** in the toolbar, toggles player contact volumes, movement capsule/reach ring, training-bot hurtboxes, the serving-hand volume and Pepper contact volumes. Detection remains active. The setting survives resets. Purple Pepper activation rings remain visible as destination markers.
- **V** switches Athlete/Ball View. **T** resets the current free-play exchange.

## Serving

`interactive_serve.gd` owns toss/swing/flight state. The toss is placed relative to the actual dominant shoulder and physique. The serving arm moves on the real VWM rig. A relative swept test between the moving ball and `Elbow/Wrist/ContactAnchor` accepts contact inside a 0.28m hand envelope plus the ball radius. Moving away, turning the arm away, or mistiming the swing can miss.

Launch direction follows the camera heading/pitch at impact. Vertical launch also incorporates incoming toss velocity and contact height, so a rising high contact leaves a higher arc than a falling one along the same aim. Default serve speed is 9 + 0.035×POW m/s, with Power Serve applied. Strike evidence retains hand position, physical contact point, incoming/outgoing velocity and timing. Only a successful strike near the original home court enables the single away court receiver. Free serves do not invoke court helpers elsewhere. Ball paths collide with solid map geometry, including raised boxes.

## Pepper

Three away partners use actual VWM models at box level 3 (-29, 3.5, 3), east between the Net and Serve Receive (8, 0, 5), and the home-base approach (0, 0, 27). A purple radius of about 3.99m has the same plan area as a 5×10m one-player court. A swept serve entering the partner's 3D proximity starts Pepper. Elevated partner movement stays on the box footprint.

Contacts alternate athletes. Serve → partner Receive to the player's current location → player Set → partner Attack to player → player Receive → partner Set → player Attack → partner Receive, repeating. Partners never take a three-contact self-pass sequence. They aim at the player at their actual contact time, with delivery height suited to the required action.

Quality >= 0.72 on Receive requires Set next; that quality on Set requires Attack. Attack requires Receive next. Poor Receive/Set require a recovery Receive. A delivery that falls below overhead reach near its receiver becomes a recovery Receive; the partner likewise recovers a pass that cannot reach the required overhead height. Wrong action types and consecutive player contacts do not create impacts. The HUD/action wheel shows the required player action. Pepper uses its own turns instead of global Net-side counters. It grants no XP or completion rewards.

## Camera

The revised athlete follow radius is **4.2m**, slightly farther than the initial 3.4m experiment. It follows world elevation without pose bob and retains the floor-stop/in-place-look behavior.

The current Ball View experiment is documented in `ball-view-controls.md`: automatic low camera placement frames the athlete at bottom center with the ball above, while mouse input independently aims the athlete.

Claude's staged directional dive and Avi wing pose modules remain wired into the live athlete pose update; serve poses override arms only during their own action.

## Verification

- `serve_pepper_test.gd`: physical toss/strike timing, hand misses, raised serving, box toggles, camera distance, all three partner activations and actually aimed serves.
- `pepper_sequence_test.gd`: alternating contacts, player-targeted ballistic delivery, quality/action requirements, wrong/consecutive contact rejection, physical Set→partner Attack, recovery Receive and athlete-centered framing.
- `render_freeplay.gd -- --pepper --ball --hidden` and `-- --box --ball` capture rendered layouts.
- Existing court rally, map drills, serve receive/approach, contact intent/MoC, directional influence and Claude's dive/wing checks remain regression coverage. Trajectory fixtures explicitly use level aim where they verify calibrated arcs.


## Moving Pepper and longer ground sets

Pepper partners always use Move at 6 m/s. Planning records a destination without teleporting. Receive/set footwork follows actual ground travel; attacks orient before takeoff and commit facing in flight. Movement remains within the partner's existing safe ground area (the box partner stays on its platform). Poor positioning can still miss; contacts continue to use the shared player geometry.

After a sufficiently accurate player receive, the partner attempts Set. The planner first checks the usual 2.25 m contact plane, then the shoulder-height set extension before falling back to Receive for an actually unreachable overhead contact. pepper_move_set_test.gd verifies a real player receive → moving partner set → player attack transition.

Ground sets gain a 1.65 range factor and a 0.80 rise factor relative to the previous set calibration. This applies before deliberate camera loft; jump sets retain their previous curve. Helper sets keep their designated target and use a flatter arc. Full ground sets are checked at low camera aim for reaching hand height across two Pepper radii (~8 m).

Current serving supports a one-second held-E basic channel as well as tap E → toss → tap E → physical swing. See [serve-modes.md](serve-modes.md).
