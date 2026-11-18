# MS-12 decision record: locks and recovery as tunable gameplay data (G-09, provisional)

Supersedes `docs/architecture.md` lines 117-120 (animation owns locks). G-09 (designer, 2026-11-01), G-10, G-20, G-06 provisional and revocable.

As built (values unchanged):
- `scripts/lock_data.gd`: `ROLL_TIME` 0.9, `RELEASE_SPEEDUP` 1.6, dive and floor lock seconds (floor: shrug uses `recovery_penalty_seconds`, G-20), and the pure predicates `dive_locked`, `floor_locked`.
- Animation reads them; `PlayerLocks.input_locked` evaluates them directly.
- Not moved: countdown clocks (`roll_lock`, `dive_recovery_time`, `floor_recovery_time`, `floor_recovery_lock`) stay on the animation controller: the traces and the BDR-10 pin read them there. Moving them is a trace change and needs its own step.
- Not done: `action_endlag` as a tunable enforced field (G-10). Its literals appear in the source-text trace of scenario S-11, so routing them through data differs by text. It gates nothing today; enforcement at defaults would add no gating.
- Bots gain nothing. Plant (G-06): hurtbox offset and aim lock stay 0.85 s; no change made.
