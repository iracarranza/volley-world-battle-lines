> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Provisional Flow and receive knockback

`scripts/contact_flow.gd` owns contact-driven Flow, inactivity decay, prepared aura resources, and underpowered receive impulses. It covers the player (including player_serve alias), eight training bots, and three Pepper partners. Machine drill feeds do not accumulate Flow. Flow contact effects and reactive traits are now implemented; see `attribute-runtime.md` for the subsequent stat/trait layer.

## Flow

Each athlete has an independent 0–100 meter. Player storage is `athlete.flow`; bot storage is `contact_flow.values[actor_id]`. Read any actor using `contact_flow.amount(actor_id)`. `last_changes[actor_id]` retains applied delta and contact evidence. Duplicate event IDs are ignored.

- Sweet matched contact: +25.
- Ordinary successful contact: +1 to +24, scaled from resolved quality; charge mismatch and rescue reduce the gain.
- Provisional poor threshold: quality below 0.40 or effective charge mismatch severity >= 0.5. These contacts lose 5–25 Flow according to error severity.
- Tiny charge mismatches retain small, gradual penalties rather than automatically becoming severe Flow losses.
- Every physical contact restarts that athlete's inactivity timer, including poor contacts.
- For 14 seconds following contact there is no passive decay. Afterward Flow decays exponentially, provisionally halving every 8 seconds. Integration handles ticks crossing the 14-second boundary exactly and is frame-rate independent. Values below 0.01 are cleared.
- Entering Winded or Exhausted immediately clears player Flow. `athlete.fatigue_epoch` ensures a contact that causes fatigue cannot immediately refill it. Subsequent contacts while Winded may build Flow again; Exhausted contacts cannot. Existing bots do not simulate individual stamina/fatigue, so no new bot stamina simulation is invented here.
- Reset clears all meters, idle timers, auras, and impulses. Pausing stops inactivity decay. MoC does not slow the Flow clock.

A thin teal Flow bar sits above Stamina. A translucent procedural flame aura surrounds each athlete, with alpha proportional to Flow fraction. All actor meshes/materials are allocated at setup, share one shader, and are warmed before contact. Rendering uses transforms/uniforms only; it does not allocate contact-time visual resources.

## Underpowered receive impulses

Only a physical receive with undercharged status and nonzero severity creates knockback. Matched receives and overcharged receives do not. The horizontal incoming velocity provides the main direction. The contact's offset perpendicular to that incoming path adds a glancing lateral component; centered hits follow the incoming direction exactly. Impulse strength scales continuously with incoming speed and effective charge mismatch severity, including the existing DI mitigation. Max initial horizontal speed is 7 m/s, reached only for high-speed, severe mismatches.

An impulse decays linearly over 0.18–0.60 seconds. Its displacement is integrated analytically. Player displacement uses CharacterBody collision movement rather than teleporting; the receiving bot moves physically too. Other athletes, the ball's independent shank trajectory, and the camera are unaffected. Existing underpowered floor recoveries retain Claude's animations/input locks but skip their canned slide distance, preventing a second, facing-based push from adding to the incoming-path impulse. Other floor recoveries preserve their previous travel. Benching clears pending player recoil.

## Validation

`tests/contact_flow_test.gd`: contact gains, poor/shank losses, cap, event deduplication, independent bot meters, player serve ownership, Winded/Exhausted reset and contact ordering, grace period, exponential decay, frame-rate independence, direct/glancing/mirrored recoil, mild mismatch continuity, collision-driven player displacement, bot recoil, aura resource allocation/opacity, bar and reset.

Regression suites: receive outcomes, fatigue status, bot rally motion, MoC continuous motion, floor recovery lab. `tests/render_flow.gd` captures 25% and 100% Flow. Graphical `tests/contact_hitch_profile.gd` with MoC off completed 12 contacts with a maximum measured contact-render interval of 23.53 ms and no >100 ms stalls.
