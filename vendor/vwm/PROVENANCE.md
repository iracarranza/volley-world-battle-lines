# VWM reuse provenance

Source checkout: `/Users/iracarranza/volley-world-manager`

Source revision: `7da049bc87d62d43a426da4f8d956606ba1c3f05` (2026-09-06).

- `ball_flight_model.gd` is copied unchanged from `scripts/simulation/ball_flight_model.gd` at that revision. Its shared gravity, signed launch-angle solver and output velocities drive the live prototype's outgoing ball.
- `scripts/athlete.gd` adapts the standing reach formula from `scripts/models/volleyball_player.gd`: `1.215 × height + 0.32 × (wingspan − height)`, expressed in metres.
- Default stride retains VWM's `clamp(0.43 × height_m, 0.55, 1.15)` convention.

All other gameplay coefficients and the live-input rig adapter are new prototype work. The career system, AI resolver, replay timeline, fatigue model and full player actor are not imported. Existing source-checkout changes were not copied or modified. The separate `volley-world-manager-m8` checkout was not used as the source baseline.

- `body_type_models.gd` is copied unchanged from VWM's `scripts/data/body_type_models.gd` at the same source revision. `scripts/voli_visual.gd` adapts its `silhouette()` / `build_mesh()` output and parented extras to the live approach rig. The adapter shares appearance choices with `scripts/athlete_creator.gd`, following the selection pattern of VWM's `new_career_screen.gd` (body, palette, marking and Vegi variant). VWM's manager/career creation screens, AI stat bonuses and replay controller are not imported. Rally Lanes owns position, physique and the provisional lab AP build.

## Actual VWM character construction

`construction/` vendors the current local VWM `player_actor_3d.tscn` and its construction dependencies from the same revision. `construction/SOURCE_MANIFEST.json` records original paths and SHA-256 hashes. Source logic is retained; resource paths are relocated under this vendor directory, and scene UID attributes are removed to resolve the isolated project resources. Shared body definitions and ball-flight helpers point to the existing unchanged copies above. VWM's source checkout is untouched.

The live adapter now instantiates the real scene, calls `configure()` with Rally Lanes' physique/appearance, then transfers the completed BodyPivot into the input-controlled rig. VWM owns anatomy, garments, hands, facial geometry, material palette, ink hulls and painted surface markings. VWM replay controllers, floor marks and temporary actor wrapper are discarded after construction. Rally Lanes retains its own movement, action poses, hurtboxes and gameplay attributes.

- `scripts/dive_stage.gd` ports the staged dive model from VWM branch `claude/voli-dive-animation-f36de5` (commit eedda78), adapted to radians and the lab rig. The vendored `defense_action_biomechanics.gd` is unchanged.

- Rig-as-data and Avi wing joints: `body_type_models.gd` is now VWM branch `claude/voli-rig-data-wing-on-von64k` (commits 44529aa, 51abc84; base 7da049b) and the vendored `player_actor_3d.gd` carries the same actor patch (`_build_rig`, wing joints, arm-length scaling). The wing is driven from Lanes by `scripts/wing_pose.gd`. Backup of the folder before this change: /private/tmp/claude-501/lanes_backup.

- `fonts/` copies VWM's Cherry Bomb One (headings, buttons) and Short Stack (body) with their OFL licences. `scripts/vwm_style.gd` mirrors VWM's title-screen conventions: Cherry Bomb One headings in cream ink with a dark drop shadow, yellow Cherry Bomb kicker labels, Short Stack body with a Cherry Bomb fallback, numbered left-aligned nav buttons with a gold left edge.
