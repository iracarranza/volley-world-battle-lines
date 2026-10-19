Latest scope: O / toolbar cycles CURRENT → TUNED → OFF. OFF emits impact visuals but never applies slowdown. Enabled MoC slows only ball integration and the acting athlete (player, training bot, or Pepper partner) to 60%. World clock, other athletes, camera, drills, and impact effects remain real-time. Impact shell geometry is prebuilt and shared rather than recreated each frame.

Continuous-motion implementation: MoC scales lab simulation deltas to 0.60 while keeping Engine.time_scale unchanged. Ball integration, actor motion, and pose timing continue; camera and effects remain real-time. Removed lab physics/input/pose hold gates. Frame-by-frame regression tests verify ball displacement on every contact update, including sets at full speed.

Latest tuning: both modes run at 60% speed. Set contact explicitly clears any remaining MoC from the previous contact, so its outgoing flight starts at normal speed.

Current behavior: both modes use 25% simulation speed, never a physics pause. The toolbar labels are CURRENT and TUNED. TUNED retains the experimental contact-duration budgets, including the extra 100 ms; its former freeze, pose hold, and input buffering are disabled. Sets have no MoC in either mode. Historical Impact Hold descriptions below describe the earlier experiment.

# MoC A/B comparison

The persistent Contact Lab toolbar button **MoC: CURRENT [O]** switches between **Current Slowdown** and **Impact Hold**. O provides the same toggle without releasing the mouse. The default remains Current Slowdown. Reset preserves the selected mode for repeated trials; returning to a fresh scene restores the default.

Current Slowdown retains the existing tuning: global 25% simulation speed, 18–140 ms velocity emphasis plus a 40 ms sweet contribution and a 100 ms extension, additive distinct contacts capped at 280 ms per chain, and 80 ms recovery after the cap.

Impact Hold is the proposed REMATCH-inspired timing adaptation, not an attempted reproduction of its complete charge system. Once a physical contact resolves, the simulation stays at that contact point, briefly compresses the ball and holds the contact pose. The already-resolved outgoing velocity is retained and runs at normal speed when the hold ends. No second collision or trajectory resolution occurs, and the engine time scale is never changed by this mode.

Provisional budgets use 60 FPS reference frames, represented as real-time seconds:

- Ordinary / rescue / shank: zero for soft contacts; otherwise 100 ms plus one frame (116.7 ms).
- Sweet Receive: 100 ms plus two or three frames (133.3–150 ms). Sets always have zero MoC.
- Sweet Attack / Block / Serve: 100 ms plus three to five frames (150–183.3 ms).
- Sweetness contributes one frame; impact strength supplies the remaining frames. Distinct overlapping impacts add within a 100 ms plus five-frame maximum, followed by 80 ms normal-speed recovery. Even a zero-hold contact still emits its impact visual.

Ball, athlete, bots, drill clocks and other lab simulation timers wait during the hold. Camera movement, V camera switching, UI and impact visuals remain live. Gameplay button/key input is queued in order and replayed once on release; mouse aiming remains responsive and cannot alter the captured outgoing shot. The queue is bounded at 64 events. Contact poses are sampled once after contact callbacks and then held. The previous ball scale is restored on release.

Switching modes during an effect, disabling MoC, pausing, resetting or leaving the scene clears the effect safely. A mode change cancels pending gameplay input rather than replaying it unexpectedly. The original slowdown clock is restored when leaving that mode. Neither mode changes the existing charge, 200 ms sweetspot delay, contact geometry, stamina or bot logic.

Validation: `moc_modes_test.gd` checks the toggle/default, unchanged baseline, timing budgets/additive contributions, zero-hold VFX, simulation hold, responsive camera/effects, buffered input, full-speed release, compression cleanup, pause/reset/switch behavior and actual contacts for all four action types. Existing MoC, impact visual, bench and serve suites cover regressions. `render_moc_modes.gd` captures both toolbar states.

## Updated duration tuning

Sets now have no slowdown or hold, including sweet ground, jump and bot sets; physical impact visuals remain. Every existing nonzero MoC for Receive, Attack, Block and Serve has an additional 100 ms. Previously zero-duration soft contacts remain zero. The extension is exposed separately in event evidence and remains additive with velocity and sweet contributions.

The Current Slowdown chain cap is now 280 ms. Impact Hold budgets are now 116.7 ms for previously active ordinary/rescue contacts, 133.3–150 ms for sweet Receive, and 150–183.3 ms for sweet Attack/Block/Serve. Its chain cap is 183.3 ms. The original 80 ms recovery is unchanged.

`moc_duration_extension_test.gd` checks exact increases in both modes, event contribution sums, raised caps, real-time expiry, non-extension by Sets, retained visuals, and actual sweet ground/jump/bot Sets.
