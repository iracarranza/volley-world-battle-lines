# Vocabulary rules

Migration stage MS-01. Controlled terms for code comments, docs, commit messages and ADRs. Source: the study's constitution article III. These are naming rules; they rename nothing in code.

| Term | Meaning | Not |
|---|---|---|
| overlap | a physical meeting of ball and action volume that the resolver judges (resolver input) | a team touch |
| team touch | a contact counted against the allowance (`contacts`, `side_contacts[side]`); a Block yields none | an overlap |
| attempt | a confirmed action from confirmation to contact, miss or cancel | a click |
| contact commit | the transaction that applies a resolved overlap (ball, shot, ledger, publish, spend, follow-up) | the Flow rule commit |
| rule commit | application of a conditional rule's activation in the Flow system (`commit_context`) | the contact commit |
| input charge | player-chosen or Auto effort (`charge`, `locked_charge`, `request.charge`) | shot pressure |
| effective charge | input charge adjusted for available output and cushioning | input charge |
| shot pressure | the quantity the ball carries (`ball_shot.charge`) | input charge |
| handling effort | the Set's `handling_charge` | shot pressure |
| receive capacity | what a Set or Block can absorb | stamina capacity |
| jump progress | `motion.jump_charge` | a charge |
| quality | four senses: geometry quality, contact quality (`assessment.quality`), delivery quality, final published quality | each other |
| sweet | the full predicate (timing-sweet and zone in SWEET SPOT or CLEAN, not remembered, not rescue-only, Receive matched; Block uses `BlockResponse`) | timing-only |
| DI | contact-time resolved input, post-contact steering axes and Receive lean are three distinct things | one thing |
| lock | a gameplay state controlling input eligibility or recovery motion, currently hosted in animation | a pose clock |
| commit (unqualified) | forbidden: write "contact commit" or "rule commit" | |
| shot metadata | the role of `scripts/contact/ball_state.gd`: a builder of the frozen dictionary carried as `ball_shot` | the live ball |
| LiveBall | the target name of the live-ball record (not yet in code); `BallState` is not that | `BallState` |

`BallState` keeps its name. Renaming the file is a refactor with parity tests, not part of the documents stage.

Also: "session" means class `LabSession` in `contact_lab.gd`; "charge" has six senses and `event.charge` two (see `event-field-registry.md`).
