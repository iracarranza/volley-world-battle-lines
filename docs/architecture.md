# Architecture and change guide

## Entry points and ownership

`project.godot` opens `title.tscn`. `main.tscn` hosts the Contact Lab.
`map_graybox.tscn` uses `scripts/map_lab.gd` to subclass the lab, change world
placement and add the overview. `map_traversal.tscn` is the minimal movement scene. Root scenes intentionally
remain small: their runtime geometry is procedural, and the VWM construction
adapter must preserve the source character pipeline.

| Responsibility | Edit here |
| --- | --- |
| Composition, input routing, contact commit, rally scheduling | `scripts/contact_lab.gd` (`LabSession`) |
| Movement, approach clocks, launch, dive movement | `scripts/lab/athlete_motor.gd` |
| Player pose layering, action clocks and recovery | `scripts/lab/athlete_animation.gd` |
| Camera state, framing and facing | `scripts/lab/camera_controller.gd` |
| Editable camera defaults | `resources/lab_camera.tres`, `scripts/lab/camera_tuning.gd` |
| Lab controls, help and bot panel | `scripts/lab/lab_hud.gd` |
| Portrait, resource bars / action wheel | `scripts/athlete_hud.gd`, `scripts/action_wheel.gd` |
| Lab geometry and primitive builders | `scripts/lab/lab_world_builder.gd` |
| Cached contact-volume presentation | `scripts/lab/hurtbox_view.gd` |
| Athlete ratings, stamina and trait access | `scripts/athlete.gd`, `scripts/stat_tuning.gd` |
| Roster schema, migration, editor projection | `scripts/athlete_store.gd` |
| Shared contact pipeline and contracts | `scripts/contact/` |
| Bot intentions and contact planning | `scripts/training_bots.gd`, `scripts/pepper_partners.gd` |
| Per-helper configuration | `scripts/bot_settings.gd` (Resource) |
| Shared bot movement/preparation/poses | `scripts/bot_motion.gd`, `bot_preparation.gd`, `bot_animation.gd` |
| Serving / drills | `interactive_serve.gd`, `serve_receive_station.gd`, `map_drills.gd` |
| Flow, fatigue consequence, visual impact | `contact_flow.gd`, `bench_status.gd`, `impact_visual.gd` |
| Block volume, lifecycle and response | `block_field.gd`, `block_state.gd`, `contact/block_response.gd` |
| Map activities and rally legality | `map_activities.gd`, `rally_rules.gd` |
| Morphology projection and stamina costs | `morphology_runtime.gd`, `stamina_costs.gd` |
| Local slowdown and trajectory steering | `moment_of_contact.gd`, `moc_steering.gd` |
| Shared Receive/Block contact presentation | `scripts/contact_response_pose.gd` |
| Hand-authored poses | `data/poses/`, `scripts/pose_library.gd` and action stage scripts |

Controller members own their clocks and state; callers use `lab.motion`,
`lab.animation`, `lab.camera_rig`, `lab.hud`, and `lab.world_builder`. Controllers
hold a typed LabSession reference. This is an explicit composition boundary,
not a general service locator. Session still schedules its peers; introducing an
independent engine for every small mechanic would make this prototype harder to
navigate. Map placement hooks remain overridden by `map_lab.gd`.

## Contact data flow

The Receive Conditioning slice and mechanic registry are documented in
[contact mechanics](contact-mechanics.md). Outgoing receive charge is now a
resolved ball state rather than a copy of its action input.

1. Controls or bot planning select an action and intended target. Confirmation
   captures an immutable intent; live DI remains a separate execution input.
2. `ContactRequest` supplies shape, local intersection, age, incoming shot,
   charge, facing, DI, athlete, Flow and caller-selected base trajectory.
3. `ContactResolver.assess` evaluates geometry, timing, set Stability, receive
   charge and receive outcome. `resolve` applies platform/spike direction,
   scatter, DI, execution effects and receive shanks, returning `ContactResult`.
4. The caller applies velocity, costs, animation, contact count and next plan.
5. Typed `ContactEvent` construction publishes one schema for all actors. Its
   dictionary snapshot is copied and recursively read-only. Signals retain this
   dictionary boundary for animation/VFX listeners and debug inspection. Consumers
   do not infer missing fields differently for a player versus a bot.

The preview uses this resolver with explicit ideal timing/charge and no random
scatter. It must not consume Flow, resolve a contact, or advance an RNG.
The resolver does not move scene nodes or apply consequences. Bot aiming may
advance the explicitly supplied RNG; pure previews never supply one.

Target planning intentionally differs: player flight follows input, court bots
choose legal court destinations, and Pepper chooses cooperative deliveries. These
are inputs to shared execution, not separate definitions of contact quality.
Pepper's attack strength normalization is explicit in the request.

## Save and trait rules

Named `statistics` are canonical. `offsets` are the creator's editable projection;
call `AthleteStore.sync_statistics` after an editor changes parent ratings or
offsets. `migrate` owns old labels/allocations and retains a legacy archive.
Runtime stat lookup reads named ratings, or a parent rating for bare comparison
builds. It does not guess the meaning of unlabeled old offsets.

Trait ownership uses stable node IDs. Names are presentation labels. A name change
must never deactivate a trait. Editing/saving the trait book invalidates the store
cache; runtime effect caches compare book identity, owned IDs and `trait_via`
against saved copies, including in-place pick/parent-choice edits. Legacy roster
migration is the boundary for automatic old threshold picks.

All claimed IDs remain available for prerequisites, but only the *frontier*
(traits not consumed by another claimed trait) contributes effects and capacity.
A successor supplies its authored totals; ancestors do not automatically stack.
`parent` advances a line; `alt_parents` offers alternative sources, with `via`
selecting the consumed source (or the first owned source by default). `merges`
lists sources that must all be owned and are all consumed. `requires` only gates
ownership: those traits retain their own effects and capacity. `carried` adds the
successor's authored contributions from its consumed source history.

Current rules allow free starting choices within capacity, exclusive forks,
6 capacity points (8 with Deep Bag), and one current Flow trait (two with Open
Mind). Node weights determine capacity use. These are editable rules in
`data/trait_tree.json`; the older [trait master list](trait-master-list.md) retains
superseded inheritance rules and counts as design history. Authored descriptions
and numeric fields can include planned mechanics: runtime effects are limited to
the keys registered in `scripts/contact/mechanic_registry.gd`.

Court helper `settings[slot]` contains all configurable behavior. Slots 0–3 are
home Receive/Set/Attack/Block and 4–7 away; home Block stays disabled. Scene handles
(actors, rigs, captions and shapes) remain fixed-size indexed presentation arrays
created together in setup. They are not additional copies of configuration.
Pepper has its own three settings records and always uses Move behavior.

## Rendering and clocks

Physics advances movement, contact windows, ball flight and drill state. Render
updates camera/VFX and the preview. Pose evaluation remains available in both
paths because confirmation geometry/recovery and immediate facing depend on it;
removing it solely to lower a call count risks changing visible contact timing.
Pose smoothing advances at most once per rendered frame.

The motor schedules `animation.tick_action_clocks(dt)` once per physics step,
with actor-local time. Animation owns receive, roll, dive, spike and set clocks.
Its `update()` lists composition order: base locomotion, preparation, takeoff/roll,
receive, dive, spike, recovery, set, locomotion spine, contact response, smoothing, final overrides.
Private layer methods retain that ordering; later layers deliberately win.
Court and Pepper controllers group dependencies, fixed configuration and state
before lifecycle/action methods. Keep related declarations together when extending them.

`contact_response_pose.gd` supplies bounded additive Receive/Block joint curves.
Player animation receives finalized contact events; bot animation receives the
resolved assessment. Both retain only response evidence and use actor-local
clocks. Rebuild the base before applying the response, then smooth the combined
pose to preserve action-switch continuity. Dive/floor recoveries retain priority.
The layer must never write ball, collision, actor translation or contact timing.

MoC exposes separate ball and actor scales. World time remains unscaled. Do not
multiply the whole lab delta by MoC or alter `Engine.time_scale`.

Trajectory ribbons and continuous lines reuse ImmediateMesh resources. Contact
volumes cache complete geometry-specific subtrees (bounded to 16) and phase
materials, invalidated when the athlete is rebuilt. The net's 39 static strings
share one MultiMesh. Portrait rendering is on demand; XP arcs redraw on value or
layout changes. Hidden HUD and invisible Flow auras skip unnecessary updates.
Bot pose work already skips disabled idle helpers; active/recovering actors keep
updating even if visibility changes.

## Changing a mechanic

Change the rule module first, then supply any new inputs through ContactRequest.
Add a focused outcome test and run affected integration suites. Keep design tuning
separate from extraction so regressions can be attributed. For visual changes,
run graphical capture/profile utilities and inspect the artifacts: headless tests
cannot validate appearance or GPU performance.

Preserve external assets and authored pose files unless the task calls for edits.
Do not validate against the user's live roster. See `tools/test.py` and
[cleanup methodology](cleanup-methodology.md). Historical notes preserve design
context but the current README, this guide and validated rules describe runtime.
