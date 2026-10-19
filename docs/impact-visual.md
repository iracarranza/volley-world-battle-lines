> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Contact impact visual

Adapted from the current VWM workspace's experimental `tools/ball_treatment_gallery.gd` (`_draw_shell`, `_shell_point`, shell/stop/boom profiles). This is the gallery's contact-air treatment, not a claim that it is already wired into VWM's production replay. The existing vendored `construction/assets/vfx/aura_soft.svg` supplies the short soft contact flash used by VWM's signature presentation.

The effect is an expanding equatorial shell flattened along outgoing minus incoming velocity. It stays at the contact point as the ball leaves. This preserves the gallery's three-dimensional side-view silhouette instead of a flat billboard shockwave. Attacks, sets and serves use the struck-ball shell; blocks use the tight stop profile; a receive absorbing a much faster ball uses the wider soft boom profile. Impulse magnitude controls size and intensity. Gameplay alpha is increased from the gallery's subtle study setting.

Ordinary hits are pale blue/white. Sweet hits add gold color, 20% larger final radius, more opacity and 60 ms of extra visual lifetime. Rescue contacts are warm; charge mismatches are muted salmon. The soft core lasts 45 ms normally or 75 ms for sweet contact. Base shell profiles last 100–200 ms. These are presentation timings and do not add another MoC contribution.

The visual listens to the existing deduplicated physical contact event, covering player, training bots, Pepper, blocks, both serving forms and drill feeder strikes. External events now include a frozen contact point and charge/rescue evidence. Misses and illegal contacts do not emit the physical event. Visuals work when MoC slowdown is disabled. No camera shake, audio, collision, resources, charge or trajectory changes are introduced.

Lifetimes use the camera's real-time delta, so MoC does not stretch a flash into a persistent object. Pause freezes the effects, reset clears them, and a maximum of 16 simultaneous effects bounds node count. Presentation remains available with debug volumes hidden.

Validation: `impact_visual_test.gd` checks physical-only spawning, anchoring, impulse alignment, expansion, sweet differentiation, block/receive styles, shank color, deduplication, lifecycle, pause/reset, bounded effects, no gameplay mutation and actual player contact dispatch. `render_impact_visual.gd` captures normal and sweet effects in the lab.

Contact-stall fix: a graphical Compatibility-renderer profile with MoC OFF reproduced 209–213 ms contact render stalls. Disconnecting the impact listener removed them. Impact presentation now uses a fixed pool of 16 visual nodes, persistent shader materials, startup shader warm-up, and shared shell meshes; play/tick only update transforms and uniforms. The same 12-contact profile (helpers off, tracking, static; receive/set/attack/block) now measured a maximum contact render of 13.17 ms, with no frames exceeding the 100 ms regression threshold. `tests/contact_hitch_profile.gd` must run with graphics enabled to catch this renderer-only failure; `-- --no-fx` is the diagnostic comparison. Headless impact and MoC suites pass 19 and 100 checks respectively.
