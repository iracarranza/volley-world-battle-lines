# Bot responsibility checkpoint — 2026-10-19

Status: implementation, regression checks and visual verification complete.
Gameplay changes were included in Claude's repository snapshot (`eb530d5`).
The final follow-up records inspector coverage and verification documentation.

## Implemented behavior

- Generic per-contact 1/2/3 responsibilities plus independent Block.
- G summons at the athlete; I inspects a nearby bot; F9 opens the roster.
- Net/side changes teleport to that destination Receive Bot Target. Same-court
  responsibility edits preserve current and saved placement; Move To Me saves home.
- Per-net/per-side receive and set targets, Shift+F6 and F6 respectively.
- Nearest eligible floor-intersection first contact, recipient priority and self-chains.
- Five bots per net and fourteen per team, including unassigned team members.
- All bots return after rally end; interception/knockback never rewrite saved homes.
- Serve/feed wait for net clearance; automatic receivers never overwrite another bot.
- Blockers react only to observed opposing attack approaches, once per approach.
  Self-sets, serves and passive high balls cannot trigger jumps. Tracking accuracy
  adds up to ±0.22s timing error. Both player and bot contacts fault on serve blocks.
- Court bots and Pepper partners have independent stamina profiles, shared contact
  and jump costs, and active preparation/movement drain. Winded slows regeneration
  for 10.5s; a second depletion causes 7s Exhaustion, then returns to Winded.
- Exhausted bots move/jump less effectively but remain active and never get Benched.
  New rally preparation and Pepper entry restore stamina, HP and fatigue.
  The inspector shows live stamina/status.

## Validation evidence

The broad run passed **96/97 suites** in `artifacts/block-fatigue-full`.
The remaining prototype fixture retained serve metadata while testing a legal
attack block. Its metadata was corrected; `prototype_test` passes in
`artifacts/block-fatigue-followup`. The additional physical self-set regression
passes in `artifacts/bot-self-set-block` and `artifacts/bot-vitals-motion`.
All **98 current suites** therefore have passing results across these runs.

Additional targeted checks:

- `artifacts/block-approach-validation`: approach gating, single-attempt behavior,
  accuracy-based timing, serve-block faults, contact and net checks.
- `artifacts/bot-vitals-motion`: individual stamina, fatigue transitions, movement,
  generic receive/set/attack, self-set/block and Pepper behavior.
- `artifacts/bot-vitals-inspector`: live Exhausted status assertion and rendered
  selected-bot inspector; visual QA passed.
- `artifacts/bot-fatigue-trait-check`: Capacity regression.
- `git diff --check`: clean.

Updated native prototype is open at the title screen. Owned process marker:
`artifacts/map-play-live.pid`; clean startup log: `artifacts/map-play-live.log`.
No unfinished gameplay implementation remains. Preserve concurrent changes and
continue from this state rather than rebuilding earlier work.
