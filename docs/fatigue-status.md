> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Winded and Exhaustion

The first positive-to-zero stamina depletion applies Winded for 10.5 simulation seconds. Winded halves resting regeneration from 9 to 4.5 stamina/s and moving regeneration from 2 to 1 stamina/s. It does not change movement, jumps or HP costs. The regeneration multiplier is provisional tuning.

A second positive-to-zero depletion while Winded replaces it with Exhaustion for 7 seconds. Stamina remains at zero and does not regenerate during that period. Existing Exhaustion effects remain: 55% movement speed, 65% jump height (including exploration jumps), and 1.5× explicit ability HP costs.

After seven seconds, Exhaustion ends and a fresh 10.5-second Winded period begins. Regeneration resumes at Winded rates. Winded expires by its timer, regardless of stamina level; the previous 50-stamina recovery threshold is removed. Frame time crossing a status boundary is divided between the relevant rates, so a large delta cannot skip or extend the lockout.

Costs applied while already at zero neither escalate nor refresh a status. Regain some stamina and deplete it again while Winded to become Exhausted. Timers share the existing simulation clock, pause and MoC scaling. Lab reset clears both effects and timers. The stamina HUD displays the active status and remaining time.

Validation: `fatigue_status_test.gd` checks transitions, exact durations, regeneration, preserved Exhaustion penalties, repeated costs at zero, timer overshoot, HUD and reset.

Exhaustion also blocks serving and initiating Pepper. Entering a live court rally or being Exhausted in an active Pepper invokes the provisional five-second [Benched state](benched.md); Winded alone does not.
