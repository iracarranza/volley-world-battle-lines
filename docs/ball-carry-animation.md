# Ball possession and pickup presentation

`ball_carry_animation.gd` composes a cosmetic held-ball mesh and arm pose after gait and serve presentation. It does not move the live ball, alter inventory, or delay acquisition. Moving interrupts pickup/idle presentation immediately; serving hides it.

Stationary athletes settle into a dominant-arm tuck, transition to a two-hand hip hold, dribble twice, then return to the tuck. Ball and hand targets share quintic transitions. Movement resets the sequence and uses a two-hand mid-torso carry. The render-frame guard prevents duplicate pose builds from advancing the clock twice.

Cart and ground acquisition publish a serial, source kind, and exact removed-ball world position. Pickup reaches toward that source before lifting the cosmetic ball. Ground pickup derives crouch depth and body turn from source position. Arm IK uses actual rig lengths; resting positions adapt to shorter arms. Acquisition is immediate, so moving or serving can interrupt the gesture without changing ownership.

Adaptive swing branch review: ported the presentation changes from `8c05958` and `64263db` on `origin/fix/spike-contact-presentation`: impact-point latching and stronger cross-body chest rotation. The latch reads the current contact event's `point` key, correcting the branch's obsolete `ball_position` lookup. No older gameplay snapshot was merged. Bots already latch their contact point and share the chest tuning.

Validation: `ball_carry_animation_test`, `ball_carry_morphology_test` (Avi/Feli, both hands, height/span extremes), existing inventory and swing suites. `render_ball_carry.gd` produces idle, ground-pickup and cart-pickup strips. Tune timeline and reach in the carry module; keep pickup metadata independent of inventory decisions.
