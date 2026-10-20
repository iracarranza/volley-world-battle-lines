# Bot intended charge

Court bots now expose Charge target: Auto (action-based) or Fixed, alongside a 0–100% Intended charge slider and the independent Charge accuracy slider. The same choices are available for the three Pepper partners. The saved Net 2 default remains Auto for every bot.

Auto preserves the existing bot planner: a receive against an attack/serve targets the incoming matching band, accounting for Cushioning and available output; other cases target 65%. This is automatic target selection, not the player's Reaction Speed-based tapped-Auto preparation path. Fixed overrides that desired input target for all the bot's assigned actions.

Both modes use charge accuracy to perturb the desired target by up to ±35 percentage points at 0% accuracy, tapering to no perturbation at 100%. The target is bounded to legal input charge. Actual charge still accumulates before confirmation, so short preparation can release below the target. Attribute multipliers and outgoing ball pressure remain separate and may exceed 100%.

`BotSettings` stores mode/value independently of accuracy. `BotPreparation.begin` accepts an optional fixed target and publishes mode, intended charge, perturbed target and actual released charge in its evidence. Test bots, approach-triggered blockers and Pepper share this preparation implementation. Confirmed blocks now use actual prepared effort; passive coverage keeps its existing Auto-based capacity.

Validation covers exact fixed targets, adaptive receives, accuracy errors, insufficient preparation time, inspector round-trip, block effort response, soft backward/outward touches, passive persistence, player/bot block regression, default roster, Pepper and preview parity. The rendered inspector verifies both selectors/sliders are usable within its scroll area.
