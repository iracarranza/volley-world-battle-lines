# Benched prototype

An Exhausted athlete participating in a live court rally or an active Pepper is immediately Benched. Court participation currently means an active free-play ball and the athlete within the provisional court bounds plus a 1.5 m perimeter. A distant rally does not bench an Exhausted bystander at Home Base. An active Pepper always counts as participation. Drill stations are excluded.

The five-second provisional status includes a one-second airborne arc back to the existing Home Base (z 48), followed by sitting on the new bench for the remaining time. Preparation, contact buffers, jump/approach, dive and Quick Step are cancelled, and player collision is temporarily disabled. Gameplay input and player contacts stay blocked until release. Reset restores the saved collision mask/layer and clears the state. On release the athlete stands just in front of the bench.

Current team ball/bot simulation continues while the player is Benched; an individual Pepper ends because its athlete has left. Fatigue continues to recover on the simulation clock, preserving the seven-second Exhaustion lock and transition to Winded. Being released from a five-second bench does not itself clear any remaining Exhaustion. Pause stops both timers. No HP reset, score penalty, rewards or scaling respawn timer is added in this provisional design.

V toggles optional spectating, and Q/R cycle enabled Home bots only. The bench HUD also offers buttons for these actions. Disabling a watched bot chooses another active Home bot or returns to the bench view if none remain. Spectator camera follows the bot while the actual athlete remains on the bench. Release returns the camera to the athlete.

Exhausted and Benched athletes cannot initiate either held or tapped serves. A toss/channel also cancels if Exhaustion begins before the strike. Exhausted/Benched athletes cannot start Pepper. Winded athletes may still serve and participate normally.

Validation: `bench_status_test.gd` covers serve/Pepper restrictions, rally entry, airborne return, seating, timer/pause, input/contact lock, live simulation, Home-only spectating and target removal, collision restoration, fatigue continuation, no distant-rally retrigger, drill exclusion, reset, and exhaustion caused by an actual contact. `render_bench_status.gd` captures return, seating and spectating.
