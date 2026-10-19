# Map build plan

Status: **phase 1 (graybox) is built as a separate scene** (`map_graybox.tscn`, see section 9). Phases 2 onward are not started. Reads `docs/map-spec.md` (topology) and `docs/laning-and-objectives.md` (rules). Numbers marked
*placeholder* are my proposals, not decisions.

## 1. Verdict

**Ready to graybox the geometry. Not ready to build gameplay on it.**

- The topology is decided: three Nets on one central line, diagonal top and bottom lanes converging on it, a straight middle lane, an upper
  and a lower jungle with a pit each (pits are Pit Nets), walls and elevation dividing the jungle, bases at the two ends.
- The rules for Points, sets, Nets falling, AP, Bench and Winded/Exhausted are decided enough to implement as pure rules code.
- Missing before gameplay: lane Net numbers, Net spacing, base and pit layout numbers, pit rewards, Energy Drink placement and mechanic,
  wall and elevation placement, and the whole Coach. None of them blocks a graybox if I use placeholders.
- The bigger issue is the code: **the lab is built around one Net at the origin** (section 3).

## 2. What the map looks like (placeholder coordinates, metres)

Axes: the central line runs along x at z = 0. Blue is z > 0, Red is z < 0. West is the top lane, east is the bottom lane (the Box Jump
tower is already on the west).

```
 z = -56   RED BASE (0,-56)
             |  \                    middle straight x = 0
   diag      |   \                          diag
   top lane  |    \                         bottom lane
        (-36,-8)  (0,-8)               (36,-8)
 z = 0 ---- NET T ---- PIT NET ---- NET M ---- PIT NET ---- NET B ----   central line, spacing 18 m
         (-36,0)   (-18,0)        (0,0)       (18,0)       (36,0)
        (-36, 8)  (0, 8)               (36, 8)
 z = +56   BLUE BASE (0, 56)           (mirrored)
```

- **Nets (T, M, B)** at x = -36, 0, 36 (the existing lane x positions). **Pit Nets** at x = -18 and 18 on the same line, in the middle of the
  upper and lower jungle.
- **Lanes:** middle is straight from each base to its Net. Top and bottom start at the base and run diagonally out to x = ±36, then straight in
  to the Net over the last ~8 m. Each lane is ~5 m wide, as now.
- **Distances:** Net to Net 36 m (about 6 s on foot), Net to Pit Net 18 m (3 s), base to Net about 56 to 62 m (9 to 10.5 s). The worry from the
  handoff, that rotating is too fast or too slow, gets playtested here.
- **Jungle sectors:** four (upper and lower, each split by the central line). A Serve Receive Drill in the middle of each, at about (±18, ±24).
- **Other Drills:** Box Jump near the top lane on each half (outside the court area, not at z = 4 as now), Spike Trainers beside the lanes,
  Transition Set in the bottom lane. Energy Drinks at the pits and at lane edges (placeholder, mechanic open).
- **Walls and elevation:** low dividers between lane and jungle with gaps, one raised ledge per jungle sector reachable by a jump or dive.

## 3. Net numbers (placeholder)

Standard Net and Pit Net: 2.43 m high, court 9 m wide by 18 m deep (the current court). Lane Nets start from the standard and move
toward it as players join, reaching it at 5 per side.

| Net | Height | Court width | Depth |
|---|---|---|---|
| Top | 2.60 | 0.8 x standard (7.2) | 0.8 x (14.4) |
| Middle | about 2.42 | 1.0 x | 1.0 x |
| Bottom | 2.24 | 1.2 x (10.8) | 1.2 x (21.6) |
| Pit Nets | 2.43 | standard | standard |

Heights and widths blend toward standard by the number of players on the busiest side, only at the moment a player joins (a ball-crossing).
The lab's current court table (half width 2.5 to 4.5, half depth 5 to 9 for 1 to 4 players) is the interpolation to extend to five.

## 4. What the current code assumes (the real risk)

`contact_lab.gd` (2,389 lines) treats the world as one court:
- one Net collider and one drawn Net at the origin, one `court_outline`, global `court_half_width` and `court_half_depth`;
- `side_index(z)` decides team side from the sign of z, and ball-in-court checks compare against the origin court;
- the serve station, Pepper partners, training bots, camera net-look and hurtbox orientation all use that origin;
- 50-odd tests build on it.

So the work is a **Net abstraction** (position, facing, height, width, depth, serve area, team sides), with the existing court becoming the
first instance, before any second Net exists.

## 5. Phases

1. **Graybox layout** (new `map_layout.gd`, data-driven, small hook in `_build_world`): floor, bases, lanes, jungle, dividers, ledges, drill pads,
   Net markers and labels. Visual and collision only, no rules. Replaces the straight-lane blockout. Safe and mostly new files.
2. **Net abstraction, no behaviour change:** a `NetSite` object and the existing court as the middle Net. Tests stay green.
3. **Three real Nets plus two Pit Nets:** per-lane dimensions and the join-time blending. Serve, Rally and Pepper per Net; bots and the serve
   station follow a Net.
4. **Rules layer** (pure, headless-testable): points, win by two, sets, Net falling and succession (primary, secondary, tertiary, one-way
   attacker rules), AP and XP payouts, Bench timing. Winded/Exhausted is Codex's.
5. **Relocate the Drills** (Box Jump tower, Spike Trainer, Serve Receive) to their lanes, mirrored for each team, and add Energy Drinks.
6. **Pits and walls:** Pit Net rules and rewards (open), dividers and ledges as route choices.
7. **Coach** once it is designed.

## 6. How I would check it

- Geometry tests: the three Nets and two Pit Nets are collinear, symmetric across the central line, and at the stated spacing.
- Reachability: a character can walk from each base to each Net, and the ledges are not reachable by walking.
- Net dimensions: values at 1 to 5 players per side, and unchanged between joins.
- Rules as pure functions: the AP tables (global and local rounding), win by two, the one-way successor rule, tertiary 3-2-1, and the Bench
  curve (5 s plus 4/3 s per level).
- Renders of the whole map from above and at lane level.

## 7. Decisions I need (or placeholders to accept)

1. The Net numbers in section 3, and the Net spacing.
2. Where the bases and spawn positions go.
3. Whether top is west and bottom is east, as the lab already has it.
4. Pit rewards and mechanics (open in the handoff).
5. Energy Drink mechanic: consumable, fixed pickup or station.
6. Whether both teams get their own copy of each Drill, mirrored.

## 8. Coordination

Codex is changing receive, serve and Pepper code in the same files. Phases 2 and 3 touch those, so I would do phase 1 first (new files), and
start phase 2 only once those changes have landed or been fenced off.

## 9. Phase 1 as built

Two scenes, both on the same map builder (`scripts/map_world.gd`, from `scripts/map_layout.gd`). The Contact Lab scene (`main.tscn`) is untouched.

**`map_graybox.tscn` (the graybox): the Contact Lab hosted on the map.** `scripts/map_lab.gd` extends the lab, so everything the lab has is live:
the athlete model and creator, movement, jumps and approaches, actions, the Moment of Contact, bots, Peppers, Serves, Bench, HUD, and the three
Drills. Only the world under it changes.
- The lab's blockout lanes and bases are replaced by the map. The lab's own court and Net at the origin are the **Middle Net**, with the lab's
  court sizing, so Rallies, Serves and the bots work there.
- The top, bottom and two Pit Nets are real walls at their placeholder heights with their own court sizes. **Nothing happens at them yet**,
  because the lab's rules are written around one Net at the origin (phase 2).
- The Drills are the lab's real ones, moved onto the map: the Box Jump tower beside the top lane at (-46, 22), the Spike Trainer in the open floor
  outside the bottom lane at about (47, 12 to 26), and the Serve Receive station in the east Blue jungle sector. The other Drill positions are
  floor markers labelled "(marker)".
- The athlete starts on the Blue base. Extra key: **N** shows the whole map from above. Everything else is the lab's controls.
- Run it with `Launch Map Graybox.command` or `godot --path . map_graybox.tscn`.

**`map_traversal.tscn`: the plain traversal scene.** The same geometry with a bare walking body and nothing from the lab (WASD, Shift, charged jump,
V overview, G stand-in mobility jump). Kept for quick geometry checks and tests.

How the lab was made hostable, without changing what it does by default: `_build_lanes_and_bases()` was split out of `_build_world()`, and
`start_position`, `station_origin`, `box_origin` and `spike_origin` were added (all at their old values by default). The station and the Drills
(`serve_receive_station.gd`, `map_drills.gd`) now work from an origin, so they can sit anywhere. The Box Jump zone was also tightened to the tower
so it no longer reaches a nearby Net.

Tests: `tests/map_lab_test.gd` (35 checks: the lab is still plain `main.tscn`; the lab's systems are live in the graybox; its movement walks; the
Middle Net is the lab's and the others are walls of the right heights; the tower, Spike Trainer and station work where they now stand) and
`tests/map_traversal_test.gd` (48 checks of real-physics traversal). `tests/render_map_graybox.gd` takes screenshots.
