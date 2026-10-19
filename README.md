# Rally Lanes — Contact Lab

An independent Godot 4.7 prototype of the first Rally Lanes milestone: a directly controlled athlete, one Net, a walkable Serve Receive station, repeatable incoming balls, two-stage contacts, stepped approaches, confirmation hurtboxes, trajectory previews, and HP/STA costs. VWM remains untouched.

## Run

Double-click `Launch Rally Lanes.command`, or open `project.godot` in Godot and press F6/F5. From this folder:

```sh
godot --path .
```

The bottom-right Action Wheel keeps the selected action at the bottom-right corner, with the other three actions arranged on a quarter-circle around it. Numbers stay assigned to their action as the wheel changes. The first ball arrives automatically in **Athlete View**. Move the mouse to look and aim, and press **V** for **Ball View**. Press **H** for the in-game guide. **Esc** releases the cursor for the HUD buttons; click back on the court to resume mouse look.

Athlete View uses a 7.5 m orbit with an elevated resting angle to show height and depth, staying behind your athlete with a stabilized, ground-referenced camera: only 15% of jump height reaches the rig, with vertical damping and no inherited stride or pose bob. Looking up or down orbits around a torso-height athlete pivot that stays at screen center, rather than tilting away from the athlete. Mouse movement applies exact facing deltas immediately; the camera updates every rendered frame without delayed orbit sway. Ball View uses a higher, farther-back rig anchored to your athlete, centers strongly on the live ball (90% ball weighting) with fast tracking rotation, and allows a bounded mouse orbit. WASD follows the camera heading in both modes. In Ball View the athlete continually faces the live ball, including visually while airborne; mouse orbit does not overwrite this facing. Committed airborne shot aim remains locked independently. Switching to Athlete View restores the athlete's current facing. Airborne aim stays committed while the view can move independently within a limited angle. Ball View falls back to looking ahead when no ball is live. Athlete View smooths translation while keeping mouse heading aligned with facing; Ball View also smooths tracking rotation. Both avoid solid geometry.

| Control | Action |
| --- | --- |
| WASD | Move relative to the current camera heading |
| Shift | Sprint; consumes STA and a small amount of HP |
| Mouse | Look around; in Athlete View this also controls grounded facing and aim |
| 1 / 2 / 3 / 4 | Select Receive / Set / Attack / Block while grounded |
| Left mouse, hold then release | Charge and arm an action; a quick tap uses stat-based default power |
| Left mouse again | Confirm contact; briefly buffers the input while the ball enters your reachable envelope |
| Right mouse | Cancel grounded action or interrupt jump preparation |
| Space, hold then release | Begin a four-part approach; release for Dive, Jump Set, Spike Jump or Block Jump |
| I | Start / retry / stop Serve Receive while in its blue station east of the court |
| V | Switch Athlete View / Ball View |
| Esc | Release or capture cursor; click the court to return from HUD buttons |
| Tab / athlete button | Switch OH, MB, S and L comparison builds; resets the exercise |
| B | Feed another ball immediately |
| F1 / F2 / F3 | Home Receive / Set / Attack bots |
| Shift + F1 / F2 / F3 / F4 | Away Receive / Set / Attack / Block bots |
| F5 / F6 / F7 | Mark feed landing / mark set destination / restore tracking feed |
| G | Toggle all four bots |
| T | Reset position, resources and counters |
| P | Pause |
| H | Controls |
| C / Create button | Open the Rally Lanes athlete editor (pauses the lab) |

Start by selecting **3**, aiming toward the far half, tapping left mouse, then clicking again as the descending ball reaches overhead height. Default attack power can clear the Net from the starting position. For a receive, select **1** and wait until the ball is lower. Aim toward your own court when receiving or setting if you want to follow with another contact. You can make three personal contacts; the fourth faults. To spike, prepare Attack first and jump as the ball approaches. Receive plus Jump produces a low directional dive.

Each confirmed action now reveals a labeled **HURTBOX** at the actual ball-contact volume. Receive is a low forward ellipsoid; Set is an overhead ellipsoid; Block is a broad thin wall. Attack/Spike is a forward-extruded upper semicircular sector pivoted at the dominant shoulder, with radius derived from actual arm reach. The colored volume and its outline use the same position, facing, dimensions and geometric shape as contact acceptance, with the ball's radius included in overlap. The box follows the athlete during confirmation and briefly lingers at its last position afterward, including on a miss. The earlier broad always-on cylinders have been replaced. The faint movement capsule remains a separate locomotion collider. Confirmation buffers and 100 ms grace remain forgiving; bot boxes retain their larger size and 120 ms late-contact tolerance.

The pale ground ring forecasts the ball's floor intersection; the dark ring is its current shadow. The teal arc previews intended outgoing flight from your expected contact height. Actual contact location, physical reach and execution quality can change the result. Gold footprints and connecting ground projection mark the remaining approach steps, excluding airborne travel.

Spike sectors show **green sweet**, **gold fair**, **orange weak**, and **red sour** areas. The sweetspot is above and beside the dominant arm; the fair region is farther to that side. Contact above the head and toward the weak arm is weaker. The outer rim, area close to the shoulder pivot, and low edges are genuine sourspots. These affect actual outgoing strength and fidelity, rather than just the debug color. Accuracy reduces execution variance without promoting a sourspot to a sweetspot. Dominant-arm choice in the creator mirrors the sector; approach footedness remains fixed as previously requested.

After successful player contacts in the court rally, the Action Wheel automatically selects **Receive → Set → Attack → Block → Receive**. The completed action and its airborne aim/hurtbox remain committed. Misses and bot contacts do not advance the wheel. The Serve Receive station keeps Receive selected. Pepper combat is still unimplemented.

## Stepped approaches

Hold Space while moving to begin **long right bound → short left step → short inward right plant → upward launch**. The first step now has a real ~15 cm ballistic lift, a carried horizontal impulse and a landing; it is not a visual bob. A Receive release during the bound converts directly into a dive, while Set/Block/Attack releases buffer their takeoff until the landing. The first stride takes about 0.54 s, the second about 0.24 s and the third about 0.21 s; each has a different loading/drive pulse and travel distance. The third foot closes toward the centerline and turns inward to square the body. The fourth phase is the vertical takeoff, not another forward stride. Footprints match the actual right/left/right placement and an upward arrow marks launch. Right-foot lead is deliberately fixed for now; later handedness-based inversion is deferred. Movement and mouse orientation can steer the available ground approach. Standing preparation remains possible.

- **Receive / Dive:** move + Space, then release around the first-step windup/drive transition (about 0.15 seconds) for the fastest and farthest dive. It automatically arms default Receive power if necessary and opens the Receive confirmation window, so an emergency dive does not need a mouse click. If Receive was already prepared, its power is retained. Earlier or later releases travel less quickly and less far.
- **Set / Jump Set:** releasing Space takes off for the overhead set; waiting for the full approach adds no jump-height bonus. Confirm the prepared set with left mouse at contact.
- **Block / Block Jump:** early release gives the same jump capability as a complete run; use left mouse to confirm the block.
- **Attack / Spike Jump:** completing the three ground steps and launch gives a substantially larger takeoff benefit. The full-run bonus also requires actual ground travel; standing in place does not earn it. Attack takeoff arrests 98% of lateral velocity and converts approach/closing-step momentum into extra upward lift, producing an almost vertical jump. Dive, Jump Set and Block Jump keep their previous momentum behavior. Prepare and confirm the spike using the existing mouse inputs.

## Serve Receive station

Walk **east/right from the starting court**, following the blue ground path into the blue court. It is part of the same world, with no teleport. The HUD gives distance to the station. Inside the area, press **I** to start a six-serve sequence. A serve machine alternates target positions and gradually shortens flight time. Receive every serve in a row using the same live contacts and directional dives as the lab.

A miss or a non-Receive contact fails the sequence and resets its streak; I retries. Successful receives generate HP (8 normally, 4 while exhausted) after normal exertion costs. Completing all six awards **25 lab XP, 20 HP and 15 STA**. These are prototype reward values; lab XP is tracked locally and is not a full progression/trait system. Bots and ordinary auto-feed are suspended during the drill. Leaving its area fails a running attempt; I also stops the drill. Walking back to the original court restores normal lab feeds. Reset returns to the original court.

## Athlete creator / VWM bodies

Press **C** or the Create button. The preview and on-court athlete share the same VWM-derived rig adapter. Choose **Feli, Avi, Cani, Ursi, Simi or Vegi**, with matching VWM palettes and markings; Vegi also has five shape variants. Authored ears, beaks, wing fans, tails, garment pieces and body contours come from VWM's unchanged `body_type_models.gd`. The face and live action poses are simplified by this prototype.

The reworked build portion chooses an athlete name, one of all five positions, dominant arm, height, wingspan and POW/SPD/ACC/END. A shared **12 AP lab budget** buys increases from a 65 baseline, one AP per point. Apply uses those values for actual movement, jump/contact capabilities and positional contact discounts. Cancel preserves the existing athlete. Body appearance does not silently import VWM's species attribute bonuses. Presets remain accessible with Tab.

This is a partial lab creator, not final match creation: the 12 AP budget and unrestricted lab height range are provisional, with no Giant/Tiny pricing, creation Innates, Trait claims, manual twelve-stat allocation, progression or persistent save yet. Applying a character resets the exercise and resources. It preserves the VWM appearance-selection pipeline while leaving career-manager/philosophy/origin screens outside this game.

## Camera-test bots

Press **G** to enable all bots, then **V** for Ball View. Bots use shared contact counts for each side: Receive only takes first touch, Set second, and Attack third. A disabled or unreachable role is left for the player; other bots never skip ahead. Legal Net crossings reset the receiving side’s count. Block is an optional incoming interception near the Net before ordinary touches; this prototype treats a bot block as non-counting and prevents consecutive bot-block loops. **F1–F3** toggle home roles; **Shift+F1–F4** toggle away roles independently; the left-side Camera Test Bots panel also has switches accessible with Esc. Bots are off by default, and reset preserves your toggle choices.

These are simple training helpers. Each instantly moves its visible contact box to a predicted descending-ball intercept and redirects the ball when it reaches that box. There is no tactical AI or travel-speed constraint. Ball flight remains physical between contacts. Disabled or unreachable contact roles remain open for you; an unplayable ball ends normally and auto-feed restarts. You can still make manual contacts, which advance the same side counter and cause the helpers to replan against the new flight. Bot contacts do not spend athlete resources or count as your successful returns.

## Implemented

- Fixed-step live athlete movement with floor/Net collision, acceleration, sprinting and charge-based jump preparation.
- Airborne action/facing commitment and four action-specific ballistic launches.
- Physically gated contact heights and horizontal reach. ACC influences contact forgiveness and execution deviation.
- Real ball integration, swept Net crossings, in/out scoring and a repeatable feed loop.
- HP/STA expenditure, positional contact discounts, escalating successive-contact HP costs, regeneration, and exhaustion that persists until 50% STA.
- Four comparison builds with different physique and attributes; VWM standing-reach and stride formulas plus its ball-flight solver.
- Athlete-following mouse-look and dynamic Ball View, resource display, charge state, trajectory/landing previews, score feedback and help.

## Deliberate prototype boundaries

This is the local contact lab, not the full MOBA. There is no tactical opponent or multiplayer, Moment of Contact slowdown, optional secondary charge correction, trait tree, protected HP Minimum, additional Drills, Pepper combat, full progression or multi-lane match. The player now uses VWM’s authored procedural body meshes through a live-input adapter. The adapter reuses silhouettes, palettes, markings, mesh builders and attached features, but not VWM’s full replay animation, facial-attention or regional kit controllers. Block is a selectable overhead redirection exercise, not a complete two-player block contest. Dive has a low committed directional flight and a simple forward-leaning placeholder pose. No balance claims are made for these coefficients.

The charge-to-flight curves, STA/HP costs and build presets are tunable lab values. The higher jump-capability baseline is preserved, with action-specific takeoff factors: Set/Block do not scale up with run duration, while Spike gains a completed-run bonus. Full-charge bump height is now capped at the previous stat-based tapped bump peak. Lower charges produce proportionally lower peaks; tapped bumps therefore sit below that ceiling. Bump horizontal landing distance at each charge is preserved by solving horizontal velocity after choosing the new vertical rise. Sets are recalibrated around the same reference peak band, including bot receive/set launches; their old horizontal range curves are preserved. Launch angles are now solved outcomes, not a fixed 76°. Receive dive speed and distance depend on first-step release timing, with a lower arc than overhead jumps. Low HP reduces attack output; this prototype does not yet implement the handoff's final technique eligibility and HP-Minimum accounting. No spin or air drag. The preview is intentionally an estimate from the athlete's expected contact height; it is not a guarantee or a target-seeking ball.

## Validation

```sh
godot --headless --path . --script tests/prototype_test.gd
godot --headless --path . --script tests/station_approach_test.gd
godot --headless --path . --script tests/creator_bound_test.gd
godot --headless --path . --script tests/contact_zones_test.gd
godot --path . --script tests/render_preview.gd
```

The first command tests scene startup, reach/build differences, exhaustion hysteresis, feed flight, geometric contact rejection, direct two-stage input, cancellation, costs, jumps, camera tracking/orbit, view-relative movement, airborne commitment, Net faults, contact-limit faults, in/out scoring, individual bot toggles, and automated bot contact sequences. The contact-zone suite verifies the corrected bump ceiling across builds/contact heights, set heights, actual spike strength across all zones, sourspots at high ACC, dominant-arm mirroring, reach-based radius, automatic wheel transitions and the drill exception. The creator/bound suite checks all six VWM body types, recognizable attached features, AP limits, apply/cancel behavior, gameplay role/physique effects, a real first-step bound, buffered jumping on landing and mid-bound diving. The station/approach suite also checks walking to the station, real receive contacts across six serves, miss/retry behavior, rewards, step impulses, timed directional dives without clicks, action-specific approach benefits and visible hurtbox/contact agreement. The render command captures `artifacts/contact-lab-athlete.png` using the running engine renderer. Add `-- --ball` to capture `artifacts/contact-lab-ball.png`, `-- --station` for the Serve Receive station, or `-- --approach` for the approach projection.

See `vendor/vwm/PROVENANCE.md` for reused source and formulas. `RallyLanesHandoff1.md` remains the design reference; later explicit decisions in it supersede earlier proposals.

Latest tuning: jump height reduced 10%, retaining the vertical Attack plant. Set vertical rise increased 12%, with existing player set range preserved. The first Set-bot activation captures your position; F6 explicitly retargets subsequent sets. The opposite side mirrors that location across the Net.

Debug court controls: **F5** locks the ordinary serve-feed landing destination at your position; **F7** returns to a feed that follows you. **F6** locks the set destination at your position (mirrored for the away court). Set target no longer changes when toggling a setter. **F1–F3** toggle home Receive/Set/Attack, **Shift+F1–F4** toggle away Receive/Set/Attack/Block independently. Home has no blocker. **G** toggles all seven available bots. These choices and marked destinations survive court resets; the Serve Receive station retains its own feeds.

Exploration/rally prototype: the traversable floor now extends to ±78m with three lane paths, base pads and open jungle space. This is a provisional navigable blockout; extra lane Nets/objectives and jungle drills are not implemented. Auto feed defaults off. **E** from the home side of the original Net launches a serve and ensures one away Receive bot is present; it does not add other roles. Ball down returns to exploration, and B remains a debug rally feed. Space outside live play charges a generic travel jump: 0.6m up to the build's exploration maximum (80% of its standing leap, at most 1.6m, always below what a clean attack approach reaches) high and 1.5–5.5m horizontal distance, selected from charge and movement input at release, independent of existing momentum. No movement input means vertical takeoff. Exploration sprint drains 3 STA/s with no HP drain versus 10 STA/s + 0.8 HP/s during rallies/drills (normal recovery still applies). Live rallies and drills retain action-specific sporting approaches.

Gold boundaries are authoritative provisional court lines, based on the larger roster (home athlete plus home bots versus away bots): 1 player = 5×10m, 2 = 6×12m, 3 = 7.5×15m, 4+ = 9×18m. Both halves match; bot toggles update boundaries and landing adjudication. The physical Net remains the existing full-size training Net. Run `godot --headless --path . --script tests/exploration_rally_test.gd` for traversal, fixed jump trajectories, sprint costs, serving, enemy receiving, team-size changes and mode transitions.

Character rendering now uses the actual vendored VWM PlayerActor3D scene/configure construction pipeline in both creator and live court: real anatomy, physical-profile fitting, hands, faces, garments, ink and surface markings. The former simplified limb/face builder is removed. Rally Lanes still drives the transferred articulated body with its own live poses and movement.

New map drills: follow the gold westward markers. **Box Jump Parkour** is on the west/top lane around (-36,13): I starts a tower of four one-way platforms about (-36,4), under 2 x 5m across. You pass up through a platform from below and land on top; falling to the ground loses progress. Land on 1–4 in order. Every layer is an attack jump, no exploration jumps: run the length of the deck below, charge Attack, hold Space and release to jump straight up through the next layer. A longer hold gives a higher jump (a release at no charge is 0.6 of the standing leap, a full hold 1.2), and each layer sits higher above the one below than the previous layer's charge reaches, so each needs a longer hold than the last. The labels show how much of a full hold each layer asks for. Heights are set from the athlete's own leap, so it works on every build, and the tower turns off the extra energy an attack jump normally takes from its release speed so only the hold counts. Start clears action preparation. Completing grants +35 lab XP, +18 HP, +10 STA. **Spike Trainer** is west of the Net around (-16,10): I starts three suspended-ball jump spikes. Charge Attack, approach/jump, then confirm inside the spike sector and land the ball in the gold circle. Grounded/wrong actions, missed target, timeout and leaving fail the run. Completion grants +30 lab XP, +20 HP, +10 STA, with +5 HP per accurate hit. These are provisional local rewards, not persistent character progression. I also stops/retries either drill. Receive feeds now reach their existing destinations in 0.95–0.825s, for substantially faster and flatter deliveries.

Prepared or actively charging actions always select their sporting jump, even outside a live rally. Space commits an in-progress action charge without replacing its type/power; prepared Receive produces its directional dive. With no action preparation outside live play, Space retains generic travel jumps. `tests/map_drills_test.gd` verifies prepared jumps/dive, faster feeds, the complete four-layer tower through real collision/physics, and real spike flights plus failure/retry paths. Render options `-- --box` and `-- --trainer` capture the new locations.

Athlete View follows the full world-space elevation of the athlete through jumps, falls and elevated platform landings, with fast smooth vertical tracking. It continues to ignore animated torso/head/stride offsets so the restored elevation tracking does not introduce animation bob.

Normal idle/walk now uses VWM gait joints from a narrow, nearly straight standing base. Prepared Receive loads the defensive wide/knees-bent stance; other preparations and cancellation release it. Hip, knee and ankle transforms are rewritten per frame rather than retaining the initial VWM ready pose. Shoe geometry grounds the supporting feet and raises the neutral body relative to the crouch. Creator previews use the same upright base. `tests/stance_test.gd` checks standing, receive readiness, body rise and grounded walking across all six body types. Startup uses Claude's `title.tscn`, including athlete selection and entry into the Contact Lab.

## Pose editor

Author poses by dragging joints: title screen -> POSE EDITOR. See `docs/pose-editor.md`.

## Map graybox

`Launch Map Graybox.command` (or `godot --path . map_graybox.tscn`) hosts the Contact Lab on the planned map: the athlete, actions, bots and Drills are the lab's own, the Middle Net is the lab's court, and the other Nets are walls with their own heights and court sizes. `map_traversal.tscn` is the same map with a bare walking body. See `docs/map-build-plan.md` section 9 and `tests/map_lab_test.gd`.
