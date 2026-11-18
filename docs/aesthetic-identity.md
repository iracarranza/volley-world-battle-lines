# Aesthetic identity: urban punk whimsical hopecore

> Design direction, not implemented rules. The map is still graybox; mockups live in `mockups/`.

## Provenance

- **Yours (authoritative).** Written on 2026-10-23 in Claude session `1f59a0a2`, in the draft titled "Trinkets, the Scouting Phase,
  Aesthetic and Identity". The words in quotation marks and the first section below are that text, unchanged.
- **From a ChatGPT conversation you pasted on 2026-11-16.** It expands your wording. Items marked *(ChatGPT)* come from it and are
  suggestions until you adopt them.
- The Voli character and animation tone ("cool, clean, polished volleyball performed by cozy, toy-like Volis") is a separate
  direction from the Volley World Manager docs (`docs/design/VOLI_ANIMATION_AESTHETIC_DIRECTION.md` in that repo). It is not part
  of this document.

## 1. The direction, in your words

The game (Volley World: Battle Lines) should be "urban punk whimsical hopecore." Brutalist AND greenified, with worldbuilding within
the structures and colors of each match, combining the grit, realism, and struggle of real-life sports with refreshing vibrancy and
uplifting energy. Hard concrete is marred by erosion, scattered with graffiti, and topped with green roofs, with the hardwood court
floors of the Nets becoming a clean oasis within the chaos.

## 2. Visual identity *(ChatGPT)*

The central idea is the contrast between a harsh environment and an optimistic sport. The world is not a pristine sports complex: it is
a place where people have carved out spaces for play and competition amid aging, repurposed infrastructure.

| Element | Visual identity |
|---|---|
| Architecture | Brutalism, exposed concrete, massive structural forms |
| Environmental history | Erosion, repairs, weathering, graffiti, repurposed infrastructure |
| Nature | Rooftop gardens, climbing vegetation, spontaneous growth |
| Sports surfaces | Clean hardwood, painted boundaries, carefully maintained Nets |
| Colour | Vibrant accents against desaturated concrete and natural greens |
| Atmosphere | Energetic, communal, rebellious, optimistic |

## 3. Rules that follow

1. **The world is chaotic, the sport is sacred.** The clean court is the visual anchor. *(ChatGPT)*
2. **Readability beats irregularity.** Surroundings can be dense and eccentric. The playable court, the ball, trajectories and
   athletes must stay immediately legible. No dressing may cross the court, hide the ball, or compete with the hurtbox and trajectory
   overlays. *(ChatGPT)*
3. **No two arenas share one palette.** Some arenas are mostly concrete and graffiti, others nearly reclaimed by vegetation. The shared
   identity is the juxtaposition, not an identical palette. *(ChatGPT)*
4. **Worldbuilding lives in each match's structures and colours** (yours), so each arena should have its own history that its graffiti,
   repairs and plantings suggest.

## 4. Mapping to the map spec

See `docs/map-spec.md` for the layout. The aesthetic applies to it as follows:

- **Nets:** each lane's Net court is the clean hardwood oasis: painted lines, maintained Net, nothing growing on the playable floor.
- **Lanes and bases:** concrete, repaired and weathered, with the most graffiti, and the arena's team colours as vibrant accents.
- **Jungles and pits:** where reclaimed vegetation is strongest, since they are the least maintained spaces.
- **Walls and dividers** (the navigable and jumpable ones in the map spec): brutalist masses. Their tops can carry green roofs, which
  can also mark which ones can be climbed.

## 5. Open questions

- How much saturation can accents carry before they compete with the ball and the team colours?
- Do team colours (blue and red sides) become the vibrant accent, or sit apart from it?
- Is graffiti decoration only, or also wayfinding (lane names, objective markers)?
- Which two or three arena palettes to build first (concrete-dominant, reclaimed, and one between)?
