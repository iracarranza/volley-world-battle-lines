# Map spec, recovered from the handoff

Source: `RallyLanesHandoff1.md`, the recovered conversation plus its consolidated summary. Line numbers below point into that file.
The handoff's own rule applies: later explicit user decisions beat earlier proposals, and assistant suggestions stay provisional
unless the user adopted them.

**Present, but only as text.** The handoff has no standalone map spec. The map is described across several exchanges and in one
paragraph of the consolidated summary (line 13618). The schematic the assistant drew (lines 3804-3851 and 3871-3901) was a visual
widget, and the archive kept only its labels ("Schematic, not to scale", "5v5", filters for Drills / Nets / Terrain, legend for Drill /
Energy Drink / Wall / Routes). No coordinates, lane angles or drawn geometry survived. What follows is every statement about the map
that survived, sorted by who said it.

## 1. Stated by you (authoritative)

**Topology**
- Three hitting lanes, with a **Net** in each: "a key location within each lane" (line 1661). Serving happens at a Net.
- The map is like a **Pokémon Unite map: diagonal lanes that progress into a central net area** (line 3867).
- **All three Nets lie along one central line** (line 3915, "yes one central line"). Blue and Red occupy opposite halves of it.
- Both the **top and bottom jungles contain a central objective to contest, like League's two pits** (line 3867).
- The map "is also geometrically divided by walls, dividers, and other elements that can be navigated or circumvented by mobility
  tools like higher jumps or dives" (line 3105).
- There are **few areas that hide players from vision (e.g. bushes)**. Walls, corners and areas of varied elevation serve as ways to evade
  vision (line 3304).

**Position assignments** (line 1669)
| Position | Where |
|---|---|
| MB | middle lane |
| OP | top lane |
| OH | bottom, the carry |
| S | bottom, support |
| L | the jungler |
Positions "generally occupy different sections of the map and stay near other positions". The summary adds that these are natural
responsibilities, not exclusive permissions (line 13589).

**Recurring map elements**
- **Drills** recur at preset locations (line 1822). Examples:
  - **Spike Trainer**: best done by a hitting position, costing the least Stamina.
  - **Transition Set**: needs one player to receive and another to set the receive accurately into a goal.
  - **Serve Receive**: a demanding Drill found in the jungle, and "centrally in all the jungle sectors" (line 3108). It requires great
    defensive Endurance and receiving distant serves, rewarding those who receive all of them in a row.
  - **Box Jump Parkour**: near the top lane. Players continuously execute demanding high jumps up a winding course, and those who reach
    the top are rewarded (line 3107).
- **Energy Drinks** are on the map to gain HP and Stamina (line 3105).
- Level 1 Liberos must invest into something (SPD or END) to clear the first Serve Receive Drill safely (line 5943).

**Nets, courts and rallies (spatial rules)**
- Nets can always contain up to **6 players per side**. The playing area is highlighted from the highest number of players on one side, so
  a numbers advantage enlarges the area for both teams (line 3663).
- The **serving area stays the same distance from the Net** whatever the player count (line 3663).
- Players can enter a Rally by walking into its bounds and can leave, but leaving does not shrink the court until the Rally ends (line 3663).
- Players join a Rally only while in their team's area and after the other side has contacted the ball at least once, a Block included.
  Rallies start only when a Serve crosses the Net successfully (lines 3755-3756).

**Vision and invasion**
- When a Pepper is being prepared, nearby susceptible players get a **directional icon**. Its size and visibility depend on the source's
  own distance and visibility (line 3304).

## 2. Proposed by the assistant (provisional unless you said otherwise)

- A **diamond-shaped** map as the starting point, closer to Pokémon Unite, still with three distinct Nets (line 3874). It said lane
  angles, Net spacing, Drill locations and pit mechanics are "not yet established" (line 3888).
- **Lane character** (line 3834):
  | Region | Identity | Likely players |
  |---|---|---|
  | Top | vertical traversal, Box Jump Parkour, hitting Drills | OP |
  | Middle | short rotations, contested access, blocking and hitting Drills | MB |
  | Bottom | cooperative Drills, especially Transition Set | OH + S |
  | Jungle | Serve Receive Drills, demanding defensive exercises, cross-lane routes | L |
- Top and bottom lanes **bend inward toward their Nets**, while the middle lane is the most direct path between bases (line 3890).
- The jungle should not be one open corridor: **several sectors separated by walls and elevation changes**, so a Libero can invade,
  defend and rotate (line 3841).
- The upper and lower pits are neutral objectives whose **strategic role** (contest, pull players off lane economy) is set, but whose
  **rewards and mechanics are open**. They should not automatically work like Baron and Dragon (line 3899).
- The map should be **symmetrical in opportunity**, with obstacles not necessarily mirrored (line 3843).
- Keep the three Nets far enough apart that contesting one does not put you in reinforcement range of another (line 3901).
- **Geometric versus practical accessibility**: a route can be open to everyone yet efficient only for some builds. A tall, Power-invested
  player might clear a divider in one jump, a Speed-invested player might go around, and a mobility Trait might open a third route
  (lines 3123-3127).
- The map should **reward physical specialization through efficiency and opportunity**, while keeping routes to success for skilled players
  on less specialized builds (line 3226).
- Map control follows from economic opportunity: controlling a region gives reliable Drill access, denies opponents, and threatens nearby
  Nets (line 3274).
- Pepper interruption should not erase all Drill progress by default. The Drill's physical nature decides what interruption means (line 3282).
- Pepper warnings should be proximity-based and modified by visibility, not a prediction of the trajectory (line 3359).

## 3. Open questions the handoff left unresolved

- Net spacing and the travel time between Nets: too fast and one player contests every serve, too slow and it becomes three isolated matches
  (line 3847).
- Exact lane angles and paths, base positions, and how lanes, jungle corridors, walls and pits connect.
- Pit rewards and mechanics.
- Whether Energy Drinks are consumable items, fixed pickups or stations (line 3165). Whether Drills are exclusive or shareable, and whether
  hard Drills pay partial rewards (line 3201). The summary says some are exclusive and some shareable.
- Where Drills sit in each jungle sector, so the Libero has real choices about which sector to clear or invade (line 3849).
- How much obstruction mobility builds can exploit versus how much basic players can still rotate and see threats (line 3851).
- What "susceptible" means for the Pepper warning, and what a missed Pepper initiation costs.
- The sixth participant on a side, when teams have five players.
- Win condition, score target and match length.

## 4. Where the Contact Lab stands against this

From the README and the code, as of this recovery:
- **Built:** one Net and court at the centre; a traversable floor to ±78 m with three lane paths, base pads and open jungle space ("a
  provisional navigable blockout"); a Serve Receive station east of the court; the Spike Trainer at (-16, 10); Box Jump Parkour at (-36, 13)
  on the west/top side, now a four-layer one-way tower where every layer is an attack jump needing a longer Space hold than the one below.
- **Not built, per the README:** extra lane Nets and objectives, and jungle drills beyond the Serve Receive station.
- **Not in the lab, from what I can see:** diagonal lanes converging on a central Net line, the two jungle pits, walls, dividers and
  elevation as route choices, Energy Drinks, and the vision-warning rules.
- The Box Jump Parkour spec ("demanding high jumps up a winding jump course") described a winding course. The lab's tower is a compact
  vertical version you asked for later, so it deliberately departs from "winding".

## 5. A first schematic, rebuilt from the text

This is **not** the recovered artifact. It is the stated topology only: one central line of three Nets, diagonal lanes converging on it, a
jungle with a pit above and below. Distances and angles are placeholders.

```
                         UPPER JUNGLE
                (Serve Receive sectors, Drills, PIT)
        BLUE base                                  RED base
              \                                      /
        TOP    \_____________ NET (top) _____________/    TOP
         lane  /                                      \   lane
              /                                        \
   BLUE ----- MIDDLE lane ----- NET (middle) ----- MIDDLE lane ----- RED
              \                                        /
         BOTTOM\_____________ NET (bottom) ___________/BOTTOM
         lane  /                                      \   lane
                         LOWER JUNGLE
                (Serve Receive sectors, Drills, PIT)

   all three Nets sit on one straight central line; Blue is on one side of it, Red on the other
   Box Jump Parkour: top lane   Cooperative Drills: bottom lane   Walls and elevation divide the jungle sectors
```
