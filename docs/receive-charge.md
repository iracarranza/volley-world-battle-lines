> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Receive charge matching

Serve and attack shots carry immutable charge-fraction metadata (1.0 = 100%; effective values may exceed 1.0). Receives resolve geometry, confirmation timing, charge match, then facing/platform intersection/directional influence. A charge match permits clean reception; it never upgrades bad geometry or mistiming.

The provisional clean band is incoming charge through incoming charge + 15 percentage points, inclusive, without a 100% ceiling. Cushioning adds to available receiving charge; Charge Tolerance softens mismatch severity without changing matched status. There is no tolerance below the incoming charge. This applies only to serve/attack → receive. Sets and other incoming shot types do not impose this charge requirement yet.

Receive charge no longer controls pass distance or height. Controlled receives use the previous 65% baseline, with camera loft, platform geometry, facing and directional influence shaping flight. Undercharge retains much of the incoming velocity and can travel through the platform. Overcharge produces a faster, flatter, sideways overhit. Charge error scales smoothly with distance outside the clean band, reaching full shank severity at a 35-percentage-point disparity. Near misses have small flight and quality penalties; the strict matching band and sweet eligibility remain unchanged. The mismatch resolver runs last, so aiming assistance cannot repair a shank. The serve receive drill keeps shanks live and scores their actual landing.

Player contacts, actual hand-struck serves, test bots, Pepper partners, debug serves and serve receive feeds publish shot metadata. Serve metadata includes additive Serve Velocity effects; toss/hand timing still shapes manual serve trajectory. Held safe serving and tapped toss/strike inputs are described in `serve-modes.md`.

## Bot preparation

Bots accumulate charge at the player's 0.85-second full-charge rate. While waiting they prepare toward a 65% baseline. An assigned contact targets the middle of the receive matching band after accounting for Cushioning and available low-Stamina output, or 65% for other actions. They confirm 200 ms before the predicted impact and lock the amount actually accumulated. Insufficient preparation time can cause a shank even at 100% charge accuracy. Reducing charge cancels and restarts preparation rather than silently subtracting stored charge.

Each of the eight test bots and three Pepper partners has an independent F9 **Charge accuracy** slider. At 100%, no target error is added. At 0%, the target can deviate up to ±35 percentage points. Tracking, aiming and charge accuracy have separate random streams and settings. Slider changes affect the next planned preparation. Settings persist across lab resets. Bot animations receive actual accumulated charge. Confirmed non-receive shot strength scales with actual charge; 65% preserves the prior baseline.

`last_receive_match`, bot `last_preparation`, player contact events and Pepper `last_delivery` expose matching/preparation evidence for tuning. Feed messages show incoming charge and its acceptable band.

## Timing

All sweetspots begin 200 ms after confirmation. Receive lasts 160 ms (200–360 ms); Set, Attack and Block last 90 ms (200–290 ms). Confirmation contact remains possible for 550 ms. Before/after the precision window the previous ordinary/rescue rules apply. Spikes retain their graduated forgiveness until 420 ms, then become rescue pushes. Debug geometry is gray during windup, uses its normal sweet geometry during the precision window, and turns orange afterward.

Validation: `tests/receive_charge_test.gd` covers strict boundaries, timing, independent bot preparation, actual bot shanks and metadata, charge-independent player receive flight, slider persistence and live drill shanks. Existing contact, drill, bot, Pepper and spike suites cover integration.
