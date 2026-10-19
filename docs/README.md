# Documentation index

## Current runtime and development

- [Contact mechanics](contact-mechanics.md): shared stages, Receive Conditioning, ball charge and new traits.

- [Project README](../README.md): play, controls, current locations and limitations.
- [Architecture](architecture.md): ownership, contracts, clocks, persistence and where to edit.
- [Attribute runtime](attribute-runtime.md): stat tiers and mechanics.
- [Current MoC](moc-comparison.md): local slowdown modes and timing.
- [Cleanup methodology](cleanup-methodology.md): workflow, tests and optimization evidence.
- [Cleanup checkpoint](cleanup-checkpoint.md): continuation status and validation ledger.

## Design and implementation history

Other top-level notes document individual feature iterations and handoffs. Their
headers identify them as historical references because later design decisions may
supersede their tuning. In particular, `map-spec.md`, `map-build-plan.md` and
`laning-and-objectives.md` describe the wider design, not a completed multiplayer
MOBA. Pose, bot and contact notes preserve reasoning and authorship.

`history/` retains the pre-cleanup README and MoC comparison verbatim beneath a
status notice. `checks/` contains compact machine-readable validation snapshots.
Verbose logs and generated render captures belong in ignored `artifacts/`.
