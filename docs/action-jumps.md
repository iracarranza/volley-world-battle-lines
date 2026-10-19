# Action-specific player jumps

Attack retains the four-step approach, its timing and distance, and conversion of
lateral momentum into height. Exploration retains its existing travel jump.

With Receive prepared, Space begins a compact split-step bound (6.5 cm height,
55% of movement speed before directional/physique effects). After landing, normal
movement resumes while Space remains held, with 15% faster acceleration. This
composes with the Acceleration subattribute and the registered `stride_speed`
percentage effect. Stride Speed has no trait-tree node yet. Holding indefinitely
does not auto-launch a dive. Release at any point dives using the existing timing,
speed, direction and automatic confirmation behavior. Clicking to confirm a
Receive cancels pending dive preparation and jump charge; the small split step
lands naturally. An already launched dive keeps its flight and confirmation.

Set and Block use direct jump loading with no approach or split step. Preparation
charges in 0.8 seconds at neutral Explosiveness, scaled by its pace. Ground movement
can reach 85% of ordinary movement speed while loading. Jump height scales from
60–88% of the athlete’s full action leap with charge, independently of run-up
distance. With directional input held at release, 85% of lateral velocity carries
into flight, plus 25% of the exploration jump's charge-based directional impulse.
Without input, only 15% carries. Neither receives attack's momentum-to-lift bonus.
Action charge remains separate from jump charge. Attack approach footprints appear
only for Attack; direct jumps use the exploration loading pose, and post-split
Receive preparation uses the mobile receive pose.

Validation: `action_jump_modes_test`, `station_approach_test`,
`stat_movement_test`, `confirmation_movement_test`, dive and spike animation suites,
and `box_jump_routes_test` cover the live controller and the retained routes.
