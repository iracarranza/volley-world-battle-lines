# MoC and trajectory gameplay plan

Status: reviewed plan. The first player-impact MoC slice is implemented; see `moc-slice.md`. Remaining phases below are proposed work.

## Design authority

Use the user's corrected impact example in `RallyLanesHandoff1.md:10391`, explained at lines 10400–10595, over the earlier description of MoC as a pre-contact option-selection interval. Consolidated references are lines 13695–13723. Numerical settings below are proposals, not recovered final rules.

- MoC is a shared impact event. Selecting or confirming an option without physical contact does not start it. Movement and ball physics share one slowed simulation clock; camera orientation and interface remain responsive. The committed action cannot be reselected for free during its impact frames.
- Intended trajectory, resolved ball flight, and athlete contact opportunity are separate data. Allies receive intent, not an automatically corrected truthful flight prediction. Opponents read the moving ball and animation.
- Set options may be visible to allies during preparation. Receive/Attack share only the chosen option. Block shares its collision-produced result with its allies; it does not offer an arbitrary outgoing-shot menu.
- Spike Points describe maximum-height opportunities under ideal starting/preparation conditions. They do not chase the player's position or approach. Lower tactical contacts are not automatically worse contacts.
- Existing jump/dive commitments, forgiving action geometry, bump distance/height tuning, set tuning, action-wheel progression and drill behavior remain regression requirements.

## Current implementation review

| Area | Existing implementation | Required change |
|---|---|---|
| Action preparation | Stored action/charge, confirm buffer, airborne aim | Formal intent snapshot separate from next selected action |
| Preview | `_update_preview()` generates one arc from estimated reach height using `_shot_velocity()` | Explicit candidate options, shared ballistic sampler, physical feasibility and intent visibility |
| Contact | Per-frame overlaps plus 100ms `contact_memory`; a missed current overlap can still produce a stretched contact | Timestamped swept contact evidence; preserve forgiveness without inventing a new impact outside geometry |
| Contact output | Zone strength plus simulation-phase sine-based yaw deviation | Deterministic geometry/timing correction first; bounded stat-dependent residual variation only if warranted |
| Block | A fixed-speed, fixed-angle `_shot_velocity()` branch; bot blocks also choose a target | Deflect incoming velocity against the actual oriented blocking surface |
| MoC | None; `paused` is a separate full pause | Shared impact clock and one event path for player, bots, serves and blocks |
| Spike Points | None | Athlete-specific geometric references from a trajectory and one authoritative capability calculation |
| Attributes | Core gameplay uses four ratings; the new title/creator carries additional draft stats | Read-only gameplay profile adapter; explicitly provisional mapping for Timing/Stability rather than silently redefining creator stats |

`contact_lab.gd` contains the integration points; `contact_geometry.gd` owns hurtbox definitions/zones; `training_bots.gd` currently resolves contacts independently. The vendored VWM flight solver remains useful, but VWM synthetic AI timing errors and overlapping approach penalties must not be imported.

## Implementation order

### 1. Contact and trajectory contracts

Introduce isolated gameplay modules before changing rendering or menus:

- `TrajectoryIntent`: actor/team/action, stored charge, facing, option ID, intended contact-frame origin/direction, preview velocity, cost estimate and commitment timestamp. Attack candidates are framed by the athlete's hitting envelope, not anchored to the freely moving incoming ball.
- `ContactEvidence`: ball and actor transforms/velocities at impact, action geometry, contact point/normal/zone and event time.
- `ContactResult`: incoming/outgoing velocity, contact quality, costs, legality and side-contact updates. It references the original intent without overwriting it.
- One ballistic sample/intersection API for previews and runtime tests, using the existing gravity and ball radius. Ground, platform and Net termination are explicit; overlays must not claim a clear flight through an obstruction.
- An impact event containing actor, team, action, charge/intensity, timestamp, intent and contact result. Player and bot contact paths emit the same event exactly once.

Keep initial resolver outputs compatible with existing bump/set range curves and attack zone strengths. Snapshot committed choices so action-wheel auto-advance cannot change the preceding contact's intent.

### 2. Authoritative contact timing

Sweep relative ball/player motion across each physics step through the committed geometry. Resolve at the earliest valid impact, then advance any remaining simulation time with the outgoing velocity. Bounded substeps or conservative tests are needed for moving/rotating sectors; a simple endpoint-only test is insufficient for driven serves.

Keep early input buffering distinct from physical contact. Replace bare overlap memory with timestamped contact evidence; any late-input allowance must reuse that evidence consistently rather than strike the ball at an unrelated current position. Choose the exact permitted grace rule before enabling retroactive late hits. Preserve current geometry sizes and visible confirmation envelopes.

Use per-contact/actor duplicate guards, not a global cooldown that could suppress a legitimate spike followed immediately by an opponent's block. Resolve legality and costs once. No MoC on a miss, canceled preparation or failed legal action.

### 3. MoC vertical slice

First implement player Receive/Set/Attack impacts, then route bot contacts and E's serve through the same event path. Debug feeds and suspended-ball placement are not contact events.

Proposed starting tuning: Receive 35–55ms, Set 55–80ms, Attack 70–110ms, Block 45–75ms of real time at roughly 0.2–0.3 simulation speed; Serve scales from negligible to about 80ms with drive. Expose these values centrally for playtesting. They are deliberately short and may change substantially after testing.

Keep fixed physics stepping authoritative; use one controlled global simulation-time policy rather than scaling the ball alone or multiplying arbitrary CharacterBody deltas. The current `move_and_slide()`/physics-tick relationship needs explicit verification. MoC expiration uses real elapsed time so slowing the simulation does not lengthen its own recovery. Camera/input orientation and UI use real time; world movement, collision, cooldowns, stamina accounting, bots and drill timers use simulation time. Preserve regular pause semantics and restore time scale on reset, scene change and exit.

A new genuine contact can refresh the impact emphasis within a short capped chain budget. It never adds an unbounded queue of freezes. Camera orientation during MoC cannot rewrite the already resolved outgoing shot; it may orient for the next action. Pre-impact action adjustment remains its own state/cost policy.

Do not add extra camera bob/zoom as part of the first slice.

### 4. Reachable trajectory options and execution

Generate a small useful candidate set from stored charge, action, facing, dominant arm, available capability/traits and contact envelope. Keep the current neutral shot as the fallback. Candidate count should be bounded, with more options shown only when preparation time permits; do not tie that count to MoC duration.

Proposed initial controls: directional input sampled with M1 confirmation selects a reachable variant relative to committed athlete facing. Existing movement continues normally. Display bindings/costs through a gameplay-facing overlay contract; coordinate visual layout with the UI owner. M2 currently cancels, so do not silently repurpose it for Back Set. Alternate trait bindings and Setter View need a separate agreed control specification.

Set/Receive preserve existing charge-to-distance and height baselines unless an explicitly selected variant changes them. Invalid directions cannot promise impossible down-the-line placement or hidden-defender awareness. Attack options originate from the athlete's nominal sweet-spot/contact frame. At real impact, contact geometry and timing can move a late cross-court shot toward the center; the intent remains cross-court. ACC reduces the discrepancy within physical capability, never supplies missing reach or teleports the ball.

Represent costs and eligibility from a gameplay profile adapter. Use existing ratings provisionally until the detailed-stat schema and HP-Minimum rules are reconciled; do not manufacture final trait unlocks or spend the same correction cost twice.

### 5. Block collision and information policy

Replace scripted block launch angles with incoming velocity reflected/redirected by a blocking surface whose normal is influenced by prepared hand orientation, dominant geometry and contact location. Bound energy and stability effects; no energy creation from a stationary blocker. Player and bot blocks use the same model and emit a distinct impact event, even directly after an Attack.

Implement visibility as data policy first: local actor options, allied Set options, allied committed Receive/Attack intent, allied Block result and separately tagged debug truth. Existing truth landing rings/trails can remain in an explicit Contact Lab debug mode; they must not become normal team information. There is no networked team simulation yet, so verify filtering with synthetic observers rather than claim multiplayer synchronization is complete.

### 6. Spike Points and contact opportunity visualization

Calculate each athlete's ideal maximum attacking contact height from the same jump/reach capability function that gameplay uses. Current Attack jump lift includes approach-momentum conversion: define its ideal allowed approach speed from existing limits once, rather than reading current momentum or applying the bonus twice. Use the nominal sweet-spot height for ideal attacking contact; distinguish this from the outer forgiving sector edge.

Solve future ascending/descending height intersections analytically for a ballistic arc; if its apex is below the capability ceiling, return the valid apex reference. Omit already elapsed roots; do not project onto the ground or clamp to court bounds. Elevated floors and obstacles require separate feasibility/legality annotations. A deliberately lower pin contact can still be clean.

Cache against trajectory identity and capability changes, not current player movement. Show current reachability/actual intended interception separately. Start with the local athlete; expose the same query API for future teammates.

## Acceptance checks

- Confirmed misses/cancels create no impact event or slowdown. Player/bot/serve contacts create one event; adjacent spike/block contacts create two in order.
- All world actors/ball/drill timers slow together. Camera orientation stays responsive. Pause/reset/title transitions reliably clear MoC. Slowdown preserves trajectories and jump height/distance relative to simulation time.
- Driven serves cannot tunnel through an active receive envelope. Moving/rotating geometry uses the same definition as the displayed hurtbox. Contact costs/counts are charged once.
- Preview sampling matches the shared ideal ballistic model. Changing actual contact geometry can change resolved flight without rewriting stored intent.
- Full-charge bump ceiling, charge-dependent receive distances, raised sets, vertical Attack plant and generic travel jumps retain their current tests.
- Prepared Receive still dives; actions retain stored power through jump preparation; action-wheel auto-advance cannot change a committed shot.
- Block direction follows hand normal/incoming velocity; it is not an arbitrary target. Spike/Block event chains cannot freeze the world indefinitely.
- Synthetic local/ally/opponent/debug observers receive exactly their permitted trajectory information.
- Spike Points handle two roots, tangent/apex, below-ceiling apex, elapsed roots and out-of-court points. Player repositioning alone cannot move them; physique/capability changes can.
- Replayable deterministic contact scenarios cover sweet/fair/weak/sour impact, late cross-court contact and left-handed mirroring. No wall-clock phase influences the result.

## Work boundary and first deliverable

Own new gameplay modules, gameplay tests and narrow integration hooks in `contact_lab.gd`, `training_bots.gd` and `contact_geometry.gd`. Avoid title scenes, athlete menu/store layout, art construction, persistence and UI styling while another agent owns those areas. Those shared integration files still require coordination before simultaneous edits; separate modules alone do not eliminate conflicts.

First playable deliverable: actual-contact MoC plus committed neutral trajectory data for Receive/Set/Attack, using preserved current controls and curves. Add options, block deflections and Spike Points after that slice passes contact/clock regression checks. Final durations, Timing mapping, correction cost curves, M2 trait input and networking remain explicitly open rather than silently treated as finished design.
