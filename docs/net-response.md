# Middle Net physics and faults

Ball-net contact no longer ends a rally. The existing Middle Net has two swept
ball responses, using the ball’s enlarged gameplay collision radius:

- Tape: a relatively rigid collision. Its contact normal reflects part of the
  incoming speed and damps tangent motion. A direct strike can be arrested or
  rebound; a top-edge contact can bounce up and dribble across.
- Webbing: a local damped spring pocket. Incoming normal speed and ball charge
  select damping. Softer impacts lose speed and drop under ordinary gravity;
  harder impacts can push the ball beyond the resting net plane before the spring
  returns it toward the incoming side. A short bounded pocket lifetime prevents
  trapping. Tangential movement remains possible. This is a gameplay response,
  not a mesh or cloth simulation; the visible net remains static for this pass.

Only a free ball clearing to the opposite side resets that side’s contact count.
Temporary penetration into stretched webbing does not reset contacts. A player or
bot can still contact the ball; a fresh contact releases the pocket. Ball-down
rules eventually end play as usual. A free ball passing completely beneath the
webbing is an under-net fault rather than a legal crossing. Generic obstacle rays exclude the Middle Net
so they cannot bypass this resolver with the former instant-failure behavior.

An athlete’s body capsule touching the actual webbing/tape during a live rally is
a net fault and ends the rally. Swept player checks include collision tolerance;
active court bots receive the same body check. Action hurtboxes do not count as
body contact. The physical collider matches the visible webbing and tape bands,
leaving the area below the webbing open. Drill and Pepper rule areas retain their
own behavior; the other map nets still have no active rally rules.

Provisional tuning lives in `scripts/net_response.gd`: tape tangent retention
82%, normal restitution 22%; web spring stiffness 100, damping 32 down to 7,
maximum pocket time 450 ms. Both physics and pocket time use the ball’s local
simulation clock, so MoC remains consistent with ball motion.

`net_response_test` covers tape arrest/dribble, low/high web impacts in both
directions, contact-count protection, body bounds and live rally/fault integration.
Bot rally, blocker fallback and block-contact regression suites also pass.
