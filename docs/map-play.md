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
ball. The three existing drills remain at their map locations and use **I**.
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
and jump costs as the athlete and an active movement/preparation drain. Winded
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
`primary_net_world.gd`. The original map layout, sectors, obstacles and drill
anchors remain authored by the map scripts. `map_bot_roster.gd` extends the common
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
menu for visual verification. The latest broad run passed **96/97 suites**
(`artifacts/block-fatigue-full`); the remaining prototype fixture was corrected
to label its legal attack-block ball as an attack, and passes in
`artifacts/block-fatigue-followup`. The added physical self-set/block regression
passes in `artifacts/bot-self-set-block` and `artifacts/bot-vitals-motion`.
All **98 current suites** have passing results across the broad run and targeted
follow-ups. The selected-bot inspector and live Exhausted status are checked in
`artifacts/bot-vitals-inspector`; its render was visually verified.
