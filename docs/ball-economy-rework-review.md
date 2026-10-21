# Ball carts, drills and Pepper rework: record and review (2026-10-21)

Source: the designer's brief of 2026-10-21 (carts, ball-gated Serving, Workouts and Setups, Pit Nets, new Net point targets). Nothing here is implemented. This file records the accepted rules in short, then a review: what conflicts with the current docs and code, what is unspecified, proposed examples for the "need more examples" lists, and risks.

## Accepted rules, condensed

- **Carts:** 12 net carts (two per team per lane, stopping either side of that team's Net antenna) plus carts at preset Jungle spots. 5 balls each. A player takes one ball per interaction. Carts refill on a fixed timer shown as a filling hover circle; the timer ignores emptying; refill may happen with balls left (capped at 5); players cannot put balls in.
- **Net threat window:** a Net is a Serving drill zone for both teams until a team's carts at that Net are empty; then it can be Served on for points. Players may empty the opposing team's carts.
- **Ball handling:** Toss (E) needs a held ball; holding E charges height; E again serves, or any other contact may be used on the tossed ball. Only a Serve starts a Pepper or Rally. A ball that lands outside a Rally, Drill, Serve or Pepper is pickable by anyone and despawns after 5 s. Benched players drop their ball.
- **Drills:** Workouts (no ball, Solo only, XP, HP, marginal sub-attribute access on repeats, short reactivation) and Setups (need a ball, often Multi, XP, HP, privileged non-Node auxiliary access, longer reactivation, more Stamina and time). Nets are Setups (Serve Velocity) that never deactivate; the served ball is consumed. Rewards go to whoever completes the final rep (stealable), shared only if the drill needs several teammates. A ball used in Setup reps is consumed on completion; reward balls only go to the completer. Being in a Pepper blocks drilling; opposing players can Pepper a Workout to interrupt and take it. Allies may "leash" a Solo drill (guard the doer).
- **Pepper:** it no longer steals HP; it remains the way to Exhaust.
- **Pit Net:** at long intervals one of the Pit Nets becomes active (first random, then alternating); vulnerable to both sides at 5v5 size; first to 7; the winner adds 7 points to the two lanes it joins; no overflow to the next Set or Net; the Coach is unaffected.
- **Net targets:** Primary: best of 3 sets, first to 11. Secondary: one set to 15. Tertiary unchanged.
- **Legibility goal:** a ball-count mismatch signals which Nets are vulnerable; routing through drills is part of player identity beside the Trait tree.

## Conflicts with the current docs and code

- `docs/laning-and-objectives.md` section 4 says a lost Pepper steals HP, with the shortfall becoming Exhaustion, and section 6 has primary sets of 15 and secondary of 21. Both change. Exhaustion from a lost Pepper then needs a new source (what is lost, if no HP is stolen?).
- Section 3 (Serve cost) must be re-read against "a Serve needs a ball from a cart"; it may now be partly redundant.
- Existing drills (`map_drills.gd` box parkour, `serve_receive_station.gd`, `transition_set_drill.gd`, `drill_basket.gd`) are Setups or Workouts in the new language. They currently reward via the lab; they will need ownership of reps, deactivation timers and completion credit.
- The tree has no way to grant an auxiliary from a drill. Several tree nodes require auxiliaries from traits (Tooler needs Spin 8 from current Traits). If Setups grant "privileged non-Node auxiliary access", we must decide whether that access counts toward `needs_stats` (see Open questions).
- Net AP rewards (2/3/4, local doubles) and the 19 AP per match figure assumed 15 and 21 point sets. At 11 and 15 points, falls will come faster; the Net AP budget and the Benching timers need a re-check.

## Unspecified (needs an answer before building)

1. **Which Net gets the carts.** "The furthest Net in their lane" reads as the front (primary) Net. Do secondary and tertiary Nets get carts once exposed, or are they always served at without balls? Is "a team's carts at that net" the team's two carts, and does it become vulnerable only when both are empty?
2. **Whose point threat.** When Team A's carts at a Net are empty, can only Team B serve on it (as an attacker) or does A also lose its own drill zone? Presumably B can score and A cannot drill.
3. **Refill interval and timing.** Same for every cart? Does a stolen-from cart refill on its own clock (the brief says yes)? Interval length is the main balance knob.
4. **Pickup rules.** One ball per use or hold several? Can a player carry more than one ball (needed for passing and Pepper)? A ball cap per player is implied but not stated.
5. **Pit Net winner points.** Do the 7 points go to both connected lanes in full (7 each)? "Add 7 points to the two lanes it connects" reads that way.
6. **Setup grants.** Which auxiliaries, in what units, and whether they stack or cap; whether they decay when a build changes.
7. **Pepper without HP stakes.** What does a Pepper win now give (XP only, or Exhaustion pressure on the loser)?

## Proposed examples (to start the lists)

Workouts (Solo, no ball) by sub-attribute; the first four are the designer's.

| Workout | Sub-attribute | Notes |
|---|---|---|
| Inclined Obstacles | Explosiveness | given |
| Salmon Ladder | Work Rate | given |
| Box Parkour | Jump Power | given (exists in the lab) |
| Weighted Balancing | Stability | given |
| Heavy Bag Swings | Swing Power | rep timing on a rotating bag |
| Sled Starts | Acceleration | short sprints against a resisted sled |
| Reflex Wall | Reaction Speed | lights or dropping panels to hit or dodge |
| Get-Up Circuit | Transition Speed | floor, kneel, stand, sprint transitions |
| Wall Bumps | Ball Control | keep a rebound alive with receives |
| Metronome Court | Timing | hit marks on a beat |
| Crash Pads | Cushioning | absorb a series of dropping weights |
| Stair Run | Capacity | long route with a Stamina gate (second floor) |

Setups (need a ball; reward auxiliaries):

| Setup | Mode | Reward |
|---|---|---|
| Spike Trainer | Solo | Spike Velocity (given) |
| Serve Machine | Solo | Platform Quality (given) |
| Balance Ball Setting | Solo | to decide (Stability or Placement) |
| Transition Set Basket | Multi | Placement and Court Vision, both players (given) |
| Topspin Wall | Solo | Spin |
| Wingspan Rack | Solo | Broad Range and Vertical Reach |
| Film Room | Multi | Court Vision for a setter and a hitter |
| Flow Metronome | Solo | Flow State |
| Impact Pad Dig | Solo | Charge Tolerance |
| Mat Dig Lane | Solo | Receive Control and Absorption |
| Block Wall | Multi | Block timing and Vertical Reach (two blockers) |
| Pepper Cage | Multi | Charge matching practice; also a safe Pepper (no Exhaustion stakes) |

Jungle and second-floor ideas: a rooftop Salmon Ladder, drink machines (Stamina), a neutral Multi Setup that needs a full lane trio and gives a large auxiliary grant, and ambush corners where a Pepper can interrupt Workouts.

## Risks

- **Ball economy tuning.** The mismatch signal only works if carts empty visibly and refill predictably. If the interval is long relative to how fast a team can drain 10 balls, windows will be rare; if short, never. Start with a simulation or a lab toggle for interval and capacity.
- **Griefing.** Emptying the enemy carts costs nothing but time; a lone ganker can hold a Net open. The Pepper-interruption and Setup-vulture rules push the same direction. Ensure counterplay (leashing exists), and that benches drop balls.
- **Reward stealing versus onboarding.** New players lose Setups to veterans; Multi Setups (stealable only by full teams) and reactivation timers help; watch for Setups that become farmed by one player.
- **Complexity.** Three layers (ball ownership, drill ownership, Net threat) interact; each needs an obvious on-screen state: cart fill, timer, "active" icon, hover indicator.
- **Auxiliary access versus the Trait tree.** Granting auxiliaries from drills can make tree nodes with auxiliary requirements (Tooler) optional or trivial; decide whether drill access satisfies requirements.

## Suggested build order

1. Ball ownership and Toss with charge, held ball, ground balls, despawn (no carts yet).
2. Carts with refill timers and the hover indicator; Net threat from cart state.
3. Drill framework: Workout and Setup types, reps, completion credit, reactivation timers; port the existing drills.
4. Pepper changes (no HP steal) with the Exhaustion source decided.
5. Pit Net and the new set targets.
6. Tree link: drill-granted auxiliaries and how they count toward requirements.

## Designer answers, 2026-10-21

**Conflicts**
1. Stamina drains much faster, especially at low levels; higher-level players force Stamina loss faster. Pepper becomes a steadier way to Bench players outside Rallies, notably just before a Drill completes.
2. The new set lengths are intended.
3. Serving needs its own mini rework.
4. Pepper exhausts but no longer steals HP: confirmed.
5. Traits remain the main source of auxiliaries; Drills are a costlier, more available, less generous alternative per instance, mainly a way to make Balls and XP without Peppering or Rallying. Drill auxiliary grants do not cap (tuning only).

**Resolved questions**
1. Carts: two per team per side of the Net (so the Middle lane need not lean toward one side, and Setups near either side keep a ball source); yes to the front-Net reading.
2. If only one side's carts are empty, only that side can be scored on. A defending side can exhaust the attackers' balls, or a Libero can gank or steal their cart. A ball from a team cart that an opposing player causes to despawn (outside a Rally, Pepper or Setup) **returns to that cart**, so stolen balls cannot simply be discarded.
3. A player holds **one ball**.
4. Refill every 3:00 (maybe 2:30): long enough to spend most balls on farming Setups, then Workouts, roaming, Pepper skirmishes or scoring threats, with few moments of zero usable balls. **Setup ball rewards depend on attempts**: reps above the minimum reduce the reward, so leashing (fewer errors) is worth balls. Workouts reactivate after 30 s, Setups after 45 s.
5. Pit Net: 7 points to each connected lane; first activation at 5:00 game time, then every 1:30, alternating (first random). The short interval is deliberate because there is one Pit at a time and many balls elsewhere.
6. Setup auxiliary grants do not cap.

## Follow-up questions
- Where does a ball go after a Pepper or Rally ends (consumed, dropped, returned)? "Returns to the cart" covers only stolen-and-lost balls.
- Does a rep error mean a missed contact only, or also leaving the zone, Stamina out, or an interruption?
- With one ball and a Pepper started by a Serve, can a Peppering pair pass the ball between teammates mid-Pepper (a held-ball rule) or only toss it?
- Stamina drain: all Drill Stamina costs (and the 15/s Sprint and 15 per contact proposals) must be re-set together; a Workout that fits at level 1 may be unreachable once drain rises.
- Uncapped Setup auxiliaries: with a 45 s reactivation and no cap, one Setup farmed all game is unbounded. Fine if per-instance value is small, but a diminishing curve or per-player lockout may be safer than a hard cap.

## Designer answers, second round (2026-10-21)

- **Stamina:** the new cost system needs no change for this rework; it is just another interaction.
- **Balls after a Pepper or Rally:** consumed. A ball unclaimed when a player is Benched belongs to the player who Benched them; if that player is in a Rally, holds a ball, or cannot pick it up, it disappears.
- **Winded rework (replaces `laning-and-objectives.md` section 5 and `LabAthlete`'s winded/exhausted flow):**
  - A Winded player gets a provisional **Winded bar**, visible to everyone and acting as a de facto health bar. Spending Stamina drains the Winded bar instead; the real Stamina bar keeps its regeneration rules (including the standing-still bonus) but no expenditure, so jumping costs only the Winded bar.
  - Winded ends when real Stamina reaches 50%. The Winded bar regenerates 1% per 0.1 s.
  - If the Winded bar empties the player is Exhausted with all Exhausted penalties.
  - An Exhausted player struck by a Serve or Attack, or who must Receive (such as in a Rally), is Benched; their Receive always counts as 1% quality instead of not occurring; the player who Benched them gains some XP.
  - UI idea: the word WINDED in the title font above the player, filled by remaining bar.
- **Setups:** a player places a ball in a **ball distributor**, which activates the Setup and returns one ball. A Setup has some number of balls and a minimum number of reps; maximum output is the award reduced by reps above the minimum.
- **Pepper:** a Pepper cannot be started with a teammate; a teammate can join one you are in; the ball is consumed when the Pepper completes.
- **Drill auxiliaries:** small per instance; the number of Workouts needed for sub-attribute growth rises at higher bands.
- **Reachability:** drills are reachable with the new Stamina system.

### Questions from these answers
1. **Winded bar size and spending.** What is the bar's size (a fixed 100, or tied to Capacity)? Do Stamina costs hit it 1:1? At 1% per 0.1 s it regenerates 10% per second, about 10 s to full, close to today's 10.5 s Winded duration; with Sprint at 15 per second a Winded player drains about 5 per second net while sprinting. Is that intended?
2. **Entering Winded.** Winded begins when real Stamina hits 0, as today? What happens to the real bar after (it must climb to 50% to end Winded)?
3. **Second Wind and Exertion Efficiency.** Second Wind restores a share of Stamina on entering Winded; Exertion Efficiency cuts cost. Do both act on the real bar, the Winded bar, or both?
4. **Setup output rule.** Is output = award − (reps performed − minimum reps)? Does the distributor's returned ball count as the first rep's ball, and is the last-rep ball still consumed?
5. **Benched receive.** "Always a 1%" means receive quality or charge 1%? The ball would then be nearly dead; is that the point?

## Designer answers, third round (2026-10-21)

1. The Winded bar is tied to Capacity; all Stamina costs are doubled (the current calibrated costs). Intended.
2. Winded starts under the same condition (real Stamina reaches 0). Exhaustion expires after 7 s of not being struck or forced to receive.
3. **Second Wind** is an auxiliary: it restores one Stamina per point of Second Wind when the player becomes Winded, shortening the time spent Winded. The base node grants +10 Second Wind (applied to `new_trait_2`; the runtime already restores points, with its 30 s cooldown, which I kept).
4. **Arbitrary Setup:** 5 reps, a distributor holding 10 balls; the player relinquishes their held ball to begin, does the 5 reps, and earns 6 balls (the 5 remaining plus the relinquished ball). Output falls with reps above the minimum.
5. A 1% receive charge means any contact is a hugely mismatched receive; that is the intent.

Verification note (2026-10-21): after the Second Wind change (`new_trait_2`: +10 Second Wind) the full isolated suite passes 124/124 once `six_step_completion_test` is updated from 23 to 10.

## Drill Lab (workouts and setups in one row)

`drill_lab.tscn` (title menu: DRILL LAB) is the Contact Lab with the map ball economy on and eight drills in a row, west to east:
Inclined Obstacles (Explosiveness), Salmon Ladder (Work Rate), Box Parkour, Weighted Balancing (Stability) | Spike Trainer, Serve Machine,
Balance Ball Setting, Transition Set. Bins beside the Setups hold five balls and refill every 20 s.

- **Workouts** extend `workout_drill.gd`: no ball, Solo, a timed run that is abandoned (not failed) on leaving the area, XP and HP on completion,
  and a 30 s reactivation. Each completion counts toward its sub-attribute through `workout_progress.gd`: the neutral band needs 3 completions
  per +1 point, and higher bands need more (2, 2, 3, 4, 6, 9, 13, 18 for tiers -2..5). Counts live in `build.workout_counts`.
- **Provisional**: the Balance Ball Setting reward was left as "?" in the design notes; it pays +1 Stability progress on a completed Setup. The
  Setups other than Balance Ball Setting do not grant sub-attribute progress yet (Spike Velocity, Platform Quality, Placement / Court Vision).
