# Airborne block field

Jumping with Block prepared opens a passive field until landing. Landing consumes the preparation. One confirmation per jump adds an immediate press; its cubic boost decays over 0.5 actor-local seconds, leaving passive coverage intact. Slowdown therefore also slows this decay.

`block_state.gd` owns this lifecycle for players and bots. `block_field.gd` owns the forward-facing inverted-triangle geometry, debug mesh and regional grading. `contact/block_response.gd` owns charge capacity and outgoing flight. Both players and bots use the shared contact resolver.

Best passive capacity is 75% of the athlete's effective Auto-block reference. Confirmation doubles capacity at the palms; distance from the palms reduces the boost. Core, torso boundary, arm boundary and fingertip grades progressively reduce capacity. Charge Tolerance softens overload severity separately. Timing improves downward control; Ball Control reduces scatter; Flow improves absorption and downward pressure. Incoming charge remains uncapped.

Lower boundary contacts shed force outward. Upper contacts can escape behind the blocker; incoming vertical velocity affects the reflection. Contact moves the ball beyond the departure face. A separation latch and incoming-direction guard prevent repeated hits during one overlap. Serve blocking remains a fault; ordinary blocks do not consume a team contact. Bot jumps still require opposing approach cues, with tracking accuracy affecting confirmation timing.

Validation: `block_field_test` covers passive capacity, immediate/decaying confirmation, regional ordering, vertical-velocity response, outward/backward escapes, separation, once-per-jump confirmation and persistent player contacts. Existing block, bot, contact and roster suites cover integration. Ground-confirmed blocking remains supported; only airborne preparation creates passive coverage.
