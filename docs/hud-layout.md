# Contact Lab HUD

The Action Wheel has a translucent quarter-disk background behind the four action buttons. Action power fills it vertically from bottom to top: green at the base, yellow through the middle, red at the top. Height represents the normalized current action charge, with a numeric percentage while charged. Charging uses live power; an armed action retains its chosen power until contact/cancellation. The fill clears afterward. Jump charge does not overwrite action power.

Stamina and HP are always-visible, vertically stacked bars centered at the bottom: yellow Stamina above light-blue HP. Their numeric values remain legible over filled or empty portions. Detailed stats and preparation text remain under MENUS. Feedback sits above the resource bars; the large former bottom debug panel and duplicate charge bar are removed. F8 still hides/restores the entire HUD, and F9 opens bot settings.

Bottom-left portrait uses the athlete's actual VWM body type and appearance in an isolated 256px viewport. A circular shader clips the head/shoulder portrait; it renders once per athlete/appearance rebuild. Name and position are above it, the saved athlete level appears in a lower-right badge, and a gold arc follows the circular border for earned lab XP. Current drill XP is the sum of Serve Receive and map-drill rewards. The ring uses a provisional 100 XP capacity and caps at full; this UI change does not implement progression or award levels/AP.

`scripts/athlete_hud.gd` owns the portrait and resource display; the wheel owns charge drawing. `tests/render_hud.gd` captures the rendered HUD. `-- --avi --half --low` exercises a different portrait, 40% charge, low Stamina and empty HP. Startup/gameplay smoke verification remains in `prototype_test.gd`.
