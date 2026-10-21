# Bot attack lane commitment

Attacking bots choose an opposing-court destination when planning their approach. `bot_attack_target.gd` samples nine lateral lanes and three depths inside the active court. It prioritizes clearance from visible opposing blockers at the net crossing, then open floor away from opposing defenders. It reads current positions and block responsibilities, not future movement targets, charge or DI. A visible opposing player is included as a defender and as a blocker when block preparation/coverage is active.

The chosen destination is stored per bot and supplies approach facing and the eventual launch. Airborne replanning retains the committed destination. The contact still uses existing facing limits, geometry, charge and aiming accuracy; choosing an open lane does not guarantee hitting it. Blockers continue reading the visible approach/facing and may move to close that lane.

Block geometry is narrower: at 1.86 m, width is 0.72 m (previously 1.20), depth 0.22 m (previously 0.46), and extra reach above the anatomical reach is 4% of height (previously 10%). Sweetspot falloff ends at 0.28 m rather than 0.48 m from the palm. Edge falloff begins outside the actual palm centres so tightening coverage does not penalize a correctly centred hand contact. The torso triangle, passive field, confirmation pulse and regional charge tolerances remain in use. Player/bot/debug meshes share this definition, with normal ball-radius collision expansion retained.

Tests cover lane choice against one/two blockers, court bounds, committed facing, old oversized block misses, retained palm coverage, and existing block/bot/aim regressions.
