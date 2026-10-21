# Map symmetry audit and proposed 180-degree rotation (2026-10-21)

Source: the designer's direction of 2026-10-21 (the map favours Blue in the jungle; side lanes should move well outward to give the drills independent space; the map should in some respects be a 180-degree rotation, not only a reflection across the team sides). Nothing here is built yet. The designer will send more direction as work proceeds.

## What the code does today

`map_layout.gd` defines the Blue half and `mirrored()` flips z to get Red, so Red is a **reflection**, not a rotation. Lanes and bases happen to be symmetric in x, so for them reflection and rotation coincide. The drills do not coincide, for two separate reasons.

**1. Positions.** Each drill's start point is built from the marker plus the drill's own local offsets, which are not mirrored. Distance from each team's use point to its own base (base at z = +/-75.4):

| Drill (use point) | Blue | Red | Red is farther by |
|---|---:|---:|---:|
| Box Jump start | 70.7 m | 81.8 m | 11.1 m |
| Spike Trainer start | 65.8 m | 69.3 m | 3.5 m |
| Serve Receive start (west) | 51.0 m | 56.0 m | 5.0 m |
| Serve Receive start (east) | 48.6 m | 53.9 m | 5.3 m |
| Transition Set | 75.9 m | 75.9 m | 0 |

So Blue's drills sit closer to Blue's base, which matches the designer's reading.

**2. Orientation.** Every drill is authored with a fixed facing along -z, and Red's copy reuses it. Blue's Spike Trainer runs toward and hits toward the centre; Red's copy runs and hits toward **Red's own base**. Blue's Serve Receive machine feeds from the centre toward Blue's base; Red's feeds from Red's base toward the centre. A true rotation turns Red's drills 180 degrees, so they face the centre like Blue's.

Both boxes (Box Jump) are at x = -59.8 and both Transition Sets at x = +59.8, again a reflection; under rotation Red's Box Jump would be at +x and Red's Transition Set at -x.

## Proposed rule

Red = Blue rotated 180 degrees about the map centre: (x, z) -> (-x, -z), and every Red drill is turned 180 degrees (flipped) around its anchor so it faces the centre. Where the designer wants deliberate asymmetry (a shorter wall, the Spike Trainer by the top-lane wall), it is authored once and marked as an exception rather than left as an accident.

## What would change (for review before building)

1. **Layout as one source of truth.** Define the Blue half and derive Red by rotation; add `flip` to each drill marker.
2. **Drill orientation support.** Each drill gets a `flip` (+1, -1). Everything it builds under its own root is rotated 180 degrees; logic that compares the player or ball with local coordinates (zone checks, goal checks, the hung ball, the partner pass, the serve machine) converts through the flip. About 67 anchor/origin references across `map_drills.gd`, `serve_receive_station.gd` and `transition_set_drill.gd`.
3. **Side lanes moved outward.** The two side Nets currently sit at x = +/-46.8 (top and bottom). Moving them to roughly x = +/-78 widens the jungle quadrants, so each drill gets its own space instead of crowding the lane and the Pit.
4. **Drill placement per quadrant** recomputed after the lanes move, using the new free span between the Pit ring (radius 10.5 around x = +/-23.4) and the side lane.
5. **Walls.** Keep the shorter wall; open the top lane's short wall toward Red; flip the Spike Trainer and move it clear of that wall.

## Questions for the designer

- Which structures are the "pit walls": the eight-segment ring around each Pit Net, the slanted strips beside the Spike Trainer markers (the jungle-sector divider walls), or the low walls beside the lanes?
- How far out should the side lanes go (about x = +/-78 is my starting guess), and do the side Nets keep their different sizes (top 0.8, bottom 1.2)? Under a rotation the small Net is Blue's top and Red's bottom.
- Should Red's "top" lane be the +x lane (true rotation), so the same physical Net is Blue's top and Red's bottom?
- Which drills must be flipped, and which positions kept fixed? (Box Jump and Transition Set swap sides under rotation.)
