# Volley World: Battle Lines

Godot 4.7 volleyball prototype, formerly Rally Lanes. The title screen leads to a
persistent athlete roster, Contact Lab and trait editor. The project also includes
a playable map graybox and pose editor. VWM's character construction and supplied assets remain under `vendor/vwm`.

## Run and validate

Open `project.godot` in Godot and press F5, or double-click
`Launch Rally Lanes.command` (the launcher retains its old filename). With Godot on
PATH: `godot --path .`. The project uses the Compatibility renderer at 1440×900.

```sh
python3 tools/test.py                       # all behavioral suites, isolated saves
python3 tools/test.py receive_charge_test   # one suite
python3 tools/test.py contact_hitch_profile --render
```

Set `GODOT` or pass `--godot` if Godot is elsewhere. Tests copy the project and use
a temporary user directory; they do not edit the live roster or authored poses.
Open `map_graybox.tscn` and press F6 for the map-hosted lab;
`map_traversal.tscn` is the minimal geometry/movement scene.
Logs and machine-readable results go to `artifacts/checks`. See
[cleanup methodology](docs/cleanup-methodology.md) for verification and profiling.

## Play

| Input | Effect |
| --- | --- |
| WASD / Shift | Move / sprint; sprint costs less outside rallies |
| Mouse | Athlete View: look and face; Ball View: face and adjust contact loft |
| V | Switch camera; while Benched, spectate teammates |
| 1–4 | Select Receive, Set, Attack, Block |
| Hold left mouse, release, click | Charge, arm, confirm contact |
| Right mouse | Cancel grounded preparation |
| Hold/release Space | Travel jump, or an approach for the prepared action |
| Hold E | Complete a standing serve channel |
| Tap E, tap E again | Toss, then manually strike using facing and contact geometry |
| I | Start/stop/retry the nearby drill |
| K / O | Toggle contact volumes / cycle Current MoC, Tuned MoC, Off |
| F8 / F9 | Toggle HUD / bot settings |
| F1–F3 | Toggle home Receive / Set / Attack helpers |
| Shift+F1–F4 | Independently toggle away helpers, including Block |
| F5 / F6 / F7 | Mark feed destination / set destination / restore tracking feed |
| G / B | Toggle court helpers / feed a test ball |
| C / Tab | Open lab creator / cycle comparison builds |
| T / P / H / M | Reset / pause / help / return to title |
| Esc | Release or capture cursor; click court to resume mouse look |
| N (map graybox) | Toggle map overview |

Athlete View follows the athlete at a default 4.2 m distance, including jumps and
elevated landings. Ball View automatically frames the athlete and ball; mouse yaw
controls the athlete independently. Forward/back move toward/away from the ball,
with strafing perpendicular to that direction. Camera settings live in
[`resources/lab_camera.tres`](resources/lab_camera.tres).

A charged Receive plus movement and Space performs a dive. Set and Block use their
own jumps. Attack benefits from completing the bound, short second step, inward
plant and launch; it converts almost all lateral approach motion into height.
Grounded confirmation and subsequent recovery temporarily lock locomotion while
movement input remains available for directional influence.

## Contacts, resources and helpers

All actors share contact geometry, timing, charge matching, directional influence
and execution rules. Geometry differs by action: a forward receiving platform,
an overhead set sector and central column, a dominant-arm spike sector, and two
block columns. Sweet timing starts 0.2 s after confirmation and lasts 0.16 s for
Receive, 0.09 s for the other contacts. Later contacts can remain ordinary or rescue
contacts according to their timing and placement.

Receive charge cushions incoming serve/attack charge; it does not directly set
pass distance. Cushioning adds to effective charge, and Charge Tolerance reduces
mismatch severity. Mild mismatches have mild consequences. Offensive charge and
incoming metadata may exceed 100%. Camera pitch affects loft; geometry and DI
shape outgoing direction. The nearby-ball preview assumes ideal contact timing
and charge matching, so it is an aid rather than a guaranteed flight.

Ordinary actions and drills cost Stamina. HP is reserved for abilities. Reaching
zero Stamina causes Winded for 10.5 s; reaching zero again while Winded causes
Exhaustion (7 s without regeneration, then Winded). Exhausted athletes cannot serve;
entering a rally/Pepper while Exhausted benches them for 5 s. Flow rewards contact
quality, clears on fatigue, holds for 14 s after contact, then decays exponentially.
See [attribute runtime](docs/attribute-runtime.md) for implemented stat/trait effects.

MoC is local **60% speed**, never a pause: only the ball and contacting athlete
slow down. Sets cancel existing MoC and launch at full speed. Off retains impact
visuals. [Current MoC tuning](docs/moc-comparison.md) describes duration and scope.

Court helpers have independent enabled state, contact assignment, Follow ball /
Static / Move mode, movement speed, tracking accuracy, aiming accuracy and charge
accuracy. There is no home blocker. Helpers use the default 65 profile and the
same hurtboxes and animation library as the athlete. Pepper partners always move:
serve into a partner's circle to begin Receive → Set → Attack exchanges, with
contact quality deciding whether the next ball is suitable for Set or Attack.

## Locations and current limits

- **Contact Lab:** one live Net, Serve Receive station, Box Jump Parkour, Spike
  Trainer with approach runway, and three Pepper partners.
- **Serve Receive:** telegraphed overhead feeds target the farther half of the
  original-size area. Receive into the other half for one point; its right half
  awards two. Eight points completes the drill. A shank can still score; leaving
  the area does not end the drill, but an unreceived feed does.
- **Map graybox:** the same lab mechanics on the larger navigable map. Middle Net
  is playable; the other Nets, objectives and progression remain design/graybox
  work. This cleanup does not implement the full MOBA or Pepper rewards.

The project name and save directory retain the legacy Rally Lanes identity so
existing rosters remain accessible. The title art uses Volley World: Battle Lines.

## Work on the project

Start with [architecture and change guide](docs/architecture.md). Current docs are
indexed in [docs/README.md](docs/README.md). Older handoffs are design history and
may describe superseded mechanics; they are not runtime specifications.
