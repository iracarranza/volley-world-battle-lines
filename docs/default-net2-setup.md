# Default Net 2 setup

`data/net_2_bot_setup.json` records the eight bots inspected in the live build. Interactive Map and Contact Lab entry from the title screen load this preset once. Direct scene launches remain empty for isolated development and tests. Startup loading refuses to replace an existing roster; resetting play preserves settings and saved starting positions.

All eight use Move and 100% tracking, aiming and charge accuracy. Bots retain the inspected order:

| Bot | Side | Contact responsibility | Block | Speed (m/s) |
|---|---|---|---|---|
| 1 | Home | 1: Receive | Yes | 1.75 |
| 2 | Home | 1: Receive | No | 7.25 |
| 3 | Home | 2: Set | No | 7.25 |
| 4 | Away | 1: Receive | No | 7.25 |
| 5 | Away | 1: Receive | Yes | 3.50 |
| 6 | Away | 2: Set | Yes | 3.50 |
| 7 | Away | 3: Attack | Yes | 3.50 |
| 8 | Home | None | Yes | 6.00 |

The accidental ninth bot is excluded. Home's third-contact role remains available for the player. Positions are provisional, spread-out offsets from Net 2's center, rather than a capture of the inaccessible live coordinates. Custom receive/set targets are not part of this preset.

Validation: `default_net2_setup_test` exercises actual Contact Lab navigation, all eight settings, formation, reset persistence and refusal to overwrite a live roster. `title_map_route_test` verifies Map entry loads the same four-per-side lineup.
