# Map play and bot assignments

Choose **Enter Map** on the title screen. **Contact Lab** remains a separate
sandbox. The selected athlete, camera controls, action and jump controls, stamina,
Flow, held/tapped serving, drills and MoC controls are shared with the lab.

The playable primary nets are **1 Top**, **2 Middle**, and **3 Bottom**, at their
authored positions, heights and court dimensions. Approaching a court while no
ball is active selects it; starting a serve also selects the nearest primary net.
A live rally retains its selected court. Held serves choose a legal target on
that court and clear its particular net height, from either side. Tap serves keep
their geometric hand contact and mouse aim. Tape/webbing physics and midline net
fault checks apply at all three primary nets. Pit nets remain traversal geometry:
no falling, objectives or Pit rally rules were added.

There is one shared live ball/rally, as in the lab. Bots assigned to other nets
remain visible there, but only the active court's bots plan contacts for that
ball. All twelve marked drill locations are functional and use **I**: four Serve Receive stations, four Spike Trainers, two Box Jump towers and two Transition Set stations.
**O** cycles MoC modes; **MoC Settings** exposes its sliders and toggles. **N**
opens/closes the map overview; **M** returns to the title.

## Bot controls

**G** summons one generic bot at the athlete's current location. It starts
unassigned, with Receive on 1, Set on 2 and Attack on 3. **I**, within 2.2 metres,
opens that bot's inspector. **F9** opens the roster in both Map and Contact Lab.
Choose Home/Away and a primary net, then Apply: assigning a different net or side
teleports the bot to that destination's Receive Bot Target. Editing responsibilities
on the same net/side preserves its current position and saved placement.
**Move To Me** explicitly saves a new placement; **Dismiss** frees its roster slot.

Each athlete has independent responsibilities for contacts **1, 2 and 3**, each
set to None, Receive, Set or Attack. **Block** is a separate toggle; all five bots
on a side may block. Movement can be Follow Ball, Static or Move, with separate
movement speed, tracking accuracy, aiming accuracy and charge accuracy controls.
Pepper partner accuracy controls remain in the same menu.

A net permits **five bots per side (ten total)**; a team permits **fourteen
bots across the map**, including unassigned bots. Invalid changes leave the
previous assignment intact. The bounded pool has 28 hidden/reusable rigs to allow
both teams' unassigned rosters; up to 28 bots can occupy the three primary nets, subject to each team’s 14-bot cap.
Unassigned bots remain where summoned and do not chase rally balls.

**Shift+F6** captures the current net/side's Receive Bot Target. Its default is
the middle of that side's playable half. **F6** captures its Set Bot Target,
defaulting to half a metre diagonally inward from the team-relative left pin.
Targets are stored separately for each net and side.

The eligible first-contact bot nearest the ball's predicted floor intersection
owns the first contact. Receive/Set recipients prefer an allied next-contact bot,
then an available player, then self if assigned the next contact; without a
recipient the ball is returned across the net. First passes prefer a second-contact
setter nearest the Receive Bot Target. Second passes aim at the Set Bot Target
when a third-contact participant exists. Attacks always attempt an attack.
Self-chains use normal movement and contact geometry, so they can fail.

Blockers jump only after observing an opposing athlete's attack approach, with
one attempt per approach. Sets (including self-sets), serves, and passive high
balls do not trigger jumps. They coordinate adjacent coverage lanes using ball
flight and opponent facing, without reading hidden charge or DI. Tracking accuracy
adds jump timing error, up to ±0.22 seconds at 0%; 100% adds none. Blocking a serve
is a fault for both player and bot and ends the rally. Blocks do not consume an
ordinary team contact. A missed block leaves the normal first-contact defense
available; a committed airborne blocker must finish its jump before taking that
ordinary contact.

Each court bot and Pepper partner has independent stamina, with the same contact
and jump costs as the athlete and a drain for actual ground travel. Winded
slows regeneration for 10.5 seconds. Depleting stamina again while Winded causes
seven seconds of Exhaustion, then returns to Winded. Exhausted bots retain their
responsibilities, with lower movement speed and jump height; they are never
Benched. New rally preparation restores stamina, HP and fatigue, as does entering
a new Pepper. The bot inspector displays live stamina and fatigue status.

Every rally end cancels contact plans and returns all bots to saved summoned or
explicitly moved positions, including Static and Follow bots. Interceptions and
knockback never change those saved placements. A new serve waits only until bot
bodies clear the net. Reset preserves assignments and saved placements; scene
re-entry starts with an empty roster. Animation test pads remain Contact Lab only.

## Implementation and verification

`map_lab.gd` selects the court context and builds the primary nets through
`primary_net_world.gd`. `map_layout.gd` is the single source for activity anchors and horizontal spacing. Map centers and extent are expanded to 130% of the previous layout (208 m floor); court dimensions, lane widths, obstacles and drill-course dimensions remain unchanged. Paths reconnect the spread-out centers. Stair and ramp assemblies preserve their internal spacing. The Home bench follows the base, and the first Pepper partner stands on the actual third tower deck. `map_activities.gd` owns the location instances and selects the nearby idle activity without moving the world or interrupting an active drill. `map_bot_roster.gd` extends the common
helper controller; bot identity is independent of action and team. `bot_contact_policy.gd` owns recipient selection, `bot_block_coordinator.gd` owns observable block planning, and `bot_return.gd` owns rally-end returns. The shared
controller plans and resolves against the selected slot, so duplicate roles use
their own hurtboxes, settings and facing. `map_bot_menu.gd` exposes the roster;
capacity validation belongs to the model, independently of the UI.

`net_response.gd` accepts origin, width and height context while retaining the
lab's defaults. The world builder has narrow hooks for map net geometry. Other
lab systems operate in world coordinates; the map/world/player are never shifted
temporarily to make origin-based calculations work.

Behavioral coverage includes `title_map_route_test`, `map_lab_test`,
`map_bot_roster_test`, `map_court_play_test`, `map_bot_rally_test`, and existing serve, bot, net, MoC,
movement and drill suites. `render_map_play` captures the title, Net 1 and roster
menu for visual verification. The expanded-map regression run passed **121/121 suites** (`artifacts/map-activities-final-full`). The later athlete-change/tower/Pepper synchronization checks pass in `artifacts/map-course-build-sync`, with map and Pepper follow-ups in `artifacts/map-build-change`. Screenshots of every drill type, the overview, and available/consumed drinks were rendered and inspected in `artifacts/map-activities-final-render`.

## Map activities — October 20 update

Each Serve Receive marker has its own tossed/struck feeds and eight-point scoring course. Each Spike Trainer has its own runway, hanging ball, gold goal and moving bonus circle. Both Box Jump markers have the same four physically climbable one-way decks. Selecting another athlete rebuilds both towers for that build and keeps the tower Pepper partner on the third deck. Active drills retain ownership of the shared ball until completed, failed or stopped; walking near another marker does not steal it. The Contact Lab keeps its original local drill positions.

Transition Set is a provisional practice implementation: a visible receiving partner passes into the pad, the athlete uses the normal Set contact to land in a two-metre-radius gold target, and three successful sets complete the drill. A missed pass, wrong action, missed goal or timeout fails it; I retries. It currently uses an automated receiving partner rather than requiring a second human. Completion uses the existing drill reward scale (+30 XP, +20 HP, +10 Stamina). These new course parameters are provisional.

Energy Drinks use **I** within 1.8 m. They restore Stamina only, provisionally 40, capped at capacity. They disappear for 30 seconds and show a replenishment countdown. Full Stamina or the Exhausted regeneration lock does not consume a drink. Drinking never clears Winded or Exhausted timers. Amount and respawn duration live in `map_activities.gd`.

Outside rallies/Pepper, walking costs a base 1.5 Stamina/s and Sprint costs a base 10/s total; drills use these rates. Live rallies retain 3/s and 15/s. Existing Height-band and efficiency modifiers still apply. Entering Winded restores half maximum Stamina; Second Wind adds a flat 23, subject to its cooldown.

`map_activities_test` exercises every marker, actual serve arrival positions, normal player Set resolution, Transition Set completion, I-driven drink consumption, cooldown and movement rates. `winded_restoration_test` checks flat Second Wind across capacities and the Exhaustion return. Map traversal and rally tests cover the expanded layout independently.

The expanded six-route physical traversal test takes about 97 seconds. The test runner default is now 120 seconds per suite; explicit `--timeout` overrides remain available.
