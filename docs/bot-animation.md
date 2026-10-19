# Shared bot action animation

Court helpers and Pepper partners use bot_animation.gd, a presentation driver over the same authored pose files and stage modules as the player. Each rig has independent contact time, source state and PoseSmoother.

- Ready stance, walk/shuffle and planted receive read the current pose library.
- Moving, reaching and off-axis receives use ReceivePose and actual local contact geometry. Post-contact receive poses linger briefly.
- Sets use SetStage.apply_data, including ready/gather, authored contact, extension and recovery; follow-through continues while waiting for the other player.
- Attacks use SpikeStage windup, actual-impact phase zero and follow-through, with the geometry/DI swing yaw applied to the striking arm and torso. Actor facing stays committed.
- Blocks keep raised arms and use the shared Avi wing layer. Avi bots also use the tucked/balance wing states.
- DiveStage and authored DiveRecovery are available through explicit dive-state hooks. Existing bot behaviors do not automatically choose a dive merely because they are reaching.

Animation changes the rig, never actor location, contact geometry, velocity, resource costs or turn order. BotMotion remains responsible for approach/jump movement. Pepper Move remains responsible for travel and jump height. Hidden inactive helpers skip pose updates.

bot_animation_test.gd verifies authored receive/set data reaches bot rigs, impact phase and follow-through, receive variants, Avi wings, independent actor position, and dive/recovery hooks. render_bot_animation.gd captures authored setter gather/contact/extension.
