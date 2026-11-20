# Map concept: a reclaimed section of the Hudson waterfront

> Design direction, not implemented rules. Layout rules live in `docs/map-spec.md`; look and mood in `docs/aesthetic-identity.md`.

## Provenance

- **Yours (authoritative).** Messages of 2026-11-16: the map is "a reclaimed section of the looping highway structure of the ny/nj
  Hudson river highway area leading up to and around the GWB, around NJ's Elizabeth and Union county's highway layout, and Central Park's
  and Boston's brutalist urbanized and transformed public use structures"; later "trying to evoke Edgewater NJ, Hudson River, Elizabeth
  and the Filipino parts of NJ/NY, Central Park, urbanization and brutalism". Your answers to my four questions are in section 2.
- **Mine (proposals until you adopt them).** Marked *(proposal)*. The real-place details are from memory and have not been checked.

## 1. References and what each contributes

| Reference | What it contributes |
|---|---|
| Hudson River highway, GWB approaches | Looping ramps and stacked decks; bridge towers and anchorages as massive landmarks *(proposal)* |
| Elizabeth and Union County | Turnpike interchanges, ramps, port and rail yards, marsh behind them; the industrial, elevated side *(proposal)* |
| Edgewater NJ and the Hudson | Waterfront promenade at the river, Palisades cliffs behind it, high-rises and old industrial lots along the shore *(proposal)* |
| Central Park | Wooded hollows (the Ramble), rock outcrops, sunken roads, a tiered terrace *(proposal)* |
| Boston | Stepped brick-and-concrete plazas; a highway replaced by a park *(proposal)* |
| Filipino communities in NJ and NY | Street-level vocabulary: hand-painted shop signs, parol lanterns, banderitas (fiesta flags), jeepney colour, basketball and volleyball courts as block centres. To be specific and respectful, not a collage of clichés. *(proposal; to be corrected by you)* |
| Urbanization and brutalism | Massive exposed concrete, stacked decks, retaining walls |

## 2. Decisions so far (yours)

- **Lane levels: mixed by lane.** Each lane has its own street character: the top lane an elevated highway deck, the middle lane an at-grade
  avenue, the bottom lane the waterfront promenade.
- **The Hudson is a visible map edge:** the river and the Palisades cliffs bound the map.
- **Evoke, do not reproduce.** An original map in this visual vocabulary. No specific real place is copied, so the layout can serve gameplay.

## 3. Structure *(proposal)*

| Part | Concept | Spec link |
|---|---|---|
| Top lane | Elevated highway deck with ramps up and down; cliffs and highway above it at the map's top edge | Top: vertical traversal, Box Jump Parkour, hitting Drills |
| Middle lane | At-grade urban avenue: shop frontages, fiesta flags, a block court | Middle: short rotations, contested access, blocking and hitting Drills |
| Bottom lane | Waterfront promenade along the river | Bottom: cooperative Drills, Transition Set |
| Upper jungle | Rocky wooded hollow, Ramble-like, with the upper pit | Pit above, Serve Receive sectors |
| Lower jungle | Marsh hollow, with the lower pit | Pit below, Serve Receive sectors |
| Central Net | Hardwood court with stepped terrace seating around it, like a plaza amphitheatre | Nets on one central line |
| Top and bottom Nets | Hardwood courts set into a deck and into the promenade | Three Nets on one line |
| Bases | A toll-plaza-like depot at each end | Blue and Red sides |
| Walls and dividers | Jersey barriers, sound walls, retaining walls | Jumpable, divable or routable by build |
| Landmarks | Tower and anchorage masses at both ends for orientation | Symmetry of opportunity |

The Net court floors are clean wood laid over a roadbed, so the faded road paint can still show at their edges. Highway signs repainted with
lane names, exits and objectives would double as wayfinding.

## 4. Constraints to design around

- A third-person camera behind the player means decks and overpasses above a Net would block the view and shade the court. Keep each Net open
  to the sky and put the stacking away from the Nets.
- The spec wants symmetry of opportunity, so the structure can mirror along the central line while obstacles and dressing differ.
- Ramps must be walkable at the lab's slope limits and fit its jumps and dives. Check early.
- Net spacing and travel time between Nets are open in `docs/map-spec.md`. Too close and one player contests every serve; too far and it is
  three isolated matches.
- Greenery and dense structure are expensive. A full map needs merged geometry and cheap foliage.

## 5. Pockets: small restrictive places *(yours, with my proposals)*

**Your direction (2026-11-16).** The map's traversal types should vary, with fire-escape-like stairwells and narrow alleyways drawn from real
places that make you imagine "if this strange, unaccommodating area with restrictive but engaging geometry was part of a game map". Edgewater,
the Central Park and NYC area, and Elizabeth are full of these small pockets of urban imaginativeness. This is a broad facet of the map's
design, not only traversal. Two photos of 727 County Road 505, Edgewater (a road above a building, a Jersey barrier, a stair beside it, a
hedge against the facade, a grey slab with one orange band, rooftop antennas, overhead wires) are the reference.

**Decisions (yours):**
- **New movement verbs:** vaulting low obstacles; climbing ladders and fire escapes; **diving as a traversal tool** that gives faster access
  through congested or narrow areas into points of interest.
- **Stairs are geometry only:** hidden ramp colliders under visual steps, with no new mechanic.
- **Pocket roles:** lane shortcuts and flanks, and jungle sector identity.
- **Squeezing or crouching** is not a separate verb; narrow gaps are handled by diving.

**Principle *(proposal)*:** each pocket creates its own play problem with restrictive geometry, and offers a decision or a risk and reward,
not just difficulty. It touches vision and Pepper warnings, cover, rally space, drills, rotations, camera and wayfinding.

**Catalogue *(proposal)*:**

| Pocket | From | Play problem |
|---|---|---|
| Grade-split stair | the photos | A one-person stair between a barrier and a wall; easy to defend; hidden from the road side |
| Fire-escape switchbacks | NYC | Zigzag stairs with landings you can drop from; climb a ladder or drop |
| Narrow alley | Elizabeth, NYC | A 2 to 3 m corridor with dead ends and hidden sightlines; faster by diving |
| Under-viaduct forest | highways | Pier clusters with low headroom that limits jumps |
| Barrier chicane | the photos | A low continuous wall you vault; forces a jump decision |
| Arch tunnel and stepped terrace | Central Park | Choke points and tiered seating |
| Parking-deck loops and roof | Edgewater | A spiral ramp up to a roof court |
| Rooftop hollows | NYC | Elevated pits with antenna farms and water towers |
| Container maze | Elizabeth port | Stacked boxes forming routes and dead ends |

**Engineering notes.** The lab's athlete is a standard character body with jumps, dives and one-way platforms. It has no stairs, vault,
ladder or ledge-drop mechanics. Stairs need ramp colliders; vault, ladder climbing and a dive-through-gap behaviour are new. A narrow alley needs
a camera that copes with tight spaces. `mockups/pocket_study.tscn` tests the scene at human scale.

## 6. Building stock, decay and the pits

**Your direction (2026-11-16).** Refine the map at a macro scale. The buildings should be both the modern and the brutalist buildings from all the
reference regions, at varying degrees of decay, so that it evokes "what if we had to play volleyball here". The pits should use verticality to
emphasise their separation from the normal environment, and be housed in more well-kept stadium-like buildings.

**Building stock *(proposal)*.** Archetypes: Edgewater-style glass towers; brutalist terraced civic blocks; ribbed bus-terminal halls; parking decks;
mixed-use rows with shopfronts and fiesta flags; warehouses and container yards; decayed slab towers; anchorage and tower masses.

**Decay scale *(proposal)*:** 0 kept, up to 1 reclaimed. By zone: the waterfront glass towers are kept to worn (0.1 to 0.4); the avenue rows and
plaza civic blocks are worn (0.3 to 0.5); the highway-side terminals, parking decks, slabs and under-deck sheds are decayed (0.7 to 0.9); the jungle
ruins are reclaimed (0.94 to 0.97); the bases and container yards sit in the middle. Decay shows as moss, grime, missing panels, leaning crowns,
missing deck sections and rubble.

**Pits *(proposal)*.** Each pit is a tall, clean stadium drum (about 12 m above ground) with its floor sunk 8 m, four portals, terraces stepping
down to the objective, a partial roof and lighting masts. Kept on purpose, against the decay around it. They hold the only surfaces on the map with
no growth. They are 16 m across, which leaves little room, so the pit size and the spacing from the middle Net are open.

`mockups/map_massing.tscn` shows this; press D for the decay map.

**The slope *(yours, then my interpretation)*.** Your vision: the map is a recessed portion of the region between the Palisades-side highway (Fort Lee
and the GWB approach) and the Hudson River, with a **sawtoothed slope** from the top lane's mountains, highways and upper-floor buildings, down
to the middle lane's streets, alleyways and markets, to the bottom lane's promenade and riverside. The wider version is
`mockups/map_terrain.tscn`: about 240 m across and 120 m deep, in six bands from the mountain to the river. A flat highway shelf at +18 m, a gentle
terrace stepping down by a retaining wall, a wild slope with the upper pit, the avenue at about +2 m, a lower wild slope with the lower pit, and the
promenade at the river. Each band is a gentle slope ending in a wall, which is the sawtooth. The lanes cross the walls on long ramps. The heights
and the 40 to 45 m Net spacing are placeholders. Volis are placed at real size only, with beacons and rulers in Voli heights; scaled-up marker figures were dropped because they read as building-sized. Key 6 shows a profile along the slope.

**Top lane *(yours, then my interpretation)*.** Your direction: the way up to the top lane should be a winding, tiered highway that leads to decrepit buildings, roofs and
parking lots. It is now four long sweeps across the slope with a landing at every turn (about 9 degrees at the steepest, 0.4 m minimum clearance over the terrain),
parapets with failed gaps, piers, parking-lot landings with painted stalls and abandoned cars, and decayed buildings whose roofs meet the tiers, with water
tanks, AC units and fallen slabs. The avenue is dressed
with hand-painted shop signs, parol lanterns and banderitas strung across the street, market stalls, jeepney-style parked vehicles, street lamps and
planters. The signs and shop names are placeholders in the spirit of the Filipino streets in the references and should be corrected by you.

## 7. Open questions

- Which specific places and details from the Filipino communities you want in, and what you would rather leave out.
- Net spacing and map size for five-on-five.
- Whether the bases are toll plazas, bus-terminal-like depots, or something else.
- How much of the cliff, river and skyline backdrop the player sees versus how much is hard boundary.

## Highway: one deck, exits and the interchange loop (assistant's proposal, refined with the user's direction)

The top lane is one elevated deck at a single level (y 15.4) along each west/east edge, climbing to the shelf at its north end and shedding exits at different elevations: a flush roof exit, a parking-lot exit, and a long ramp down to the avenue. At its south end the deck crosses a Bayway-Circle-style elevated oval ring with a through road, planted medians and Goethals-style stay-cable pylons (stylised, not 1:1). The user's vision: reclaim the car-centric infrastructure (Elizabeth / GWB looping highways) into humanistic athletic space. The base form is built first and kept bare: the baseline map has no courts or athletic equipment (the earlier drill-court, drill-pad and serving-lane overlays were removed at the user's direction, to see what occurs naturally in the work). The only athletic marks are the three designated main-net locations (top shelf, middle plaza, bottom promenade), each a bare 18 x 9 m pad with corner brackets and a label. The prominent courts are still to be housed in the pits.

**Widening pass (user's direction).** Every band (the three lanes, the Ramble and the Marsh) is 30% wider across the slope (z), with sizes of everything inside unchanged, so each lane has room for its primary and secondary courts and the three tertiary courts before its base. Highway angles change as a result. Bands are widened, not lengthened: the lanes' length (x) is as before.

**The recess and what lies outside it (user's direction).** The map is a recessed strip between the Palisades-side highway (Fort Lee + GWB) and the Hudson. On its west and east ends it is sunk into a higher, un-recessed region at the highway-shelf level; that region is industrial, desaturated and car-centric, and is not part of the game map. The shelf highway runs straight out onto it under a gantry sign ("To Fort Lee / GWB"), past container yards, a tank farm, warehouses and transmission towers. The recess's inner faces act as its retaining walls. *(Assistant's first pass; the outside is deliberately dull so the recess reads as the reclaimed, hopeful part.)*

## Bases as locker rooms and bus bays, lanes branching out (assistant proposal, mockup only)

The map is longer: the recess now runs to x = ±188 m (was ±118) so the bases sit well beyond the old lane ends. Each base is where the athletes and coach are: a locker-room block built against the recess wall, a team bus bay and forecourt in front of it, and a dark tunnel mouth onto the middle lane. From the forecourt the middle lane continues straight on at avenue level, while the outer lanes branch diagonally. The top lane leaves from the locker block's roof (the athletes' bus deck, y 8.4) and climbs as a viaduct onto the shelf highway; the bottom lane runs at ground level down to the promenade. The old highway deck and interchange ring stay where they were and now read as the car-centric approach between the bases and the park.

Open points: the top viaduct climbs up to about 15 degrees where it clears the retaining walls (untested against lab movement limits), the extra length is mostly empty ground apart from the bases, and each base is only a placeholder block.
