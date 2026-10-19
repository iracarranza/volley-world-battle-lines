> Design/implementation note retained for history. It may include superseded tuning or APIs. For current runtime and navigation, use [the README](../README.md) and [architecture guide](architecture.md).

# Serving inputs and feed telegraph

Hold E for one second to complete a basic standing serve. The first 180 ms distinguishes a tap from a hold. Once channeling, grounded movement locks; releasing early cancels. Completion automatically serves through a safe arc to a target inside the opposing court. From the serve line, the solver checks net clearance including ball radius and a 20 cm margin; lateral facing chooses a clamped in-court target. Aim away from the court cannot turn the basic serve into a deliberate fault. The guarantee describes the untouched flight; an opponent may receive it.

Tap E to toss, release the key promptly, then tap E again to swing. This retains the existing swept physical hand contact, mouse-controlled facing/loft, and rising/high versus falling/low toss trajectory differences. A swing can miss. A central hand contact is sweet-eligible. Both modes publish serve charge metadata and spend the existing 4 stamina on a strike. Held serves use ordinary contact quality and the existing nominal serve charge.

Serve Receive now begins each feed with a visible 600 ms upward toss from 1.80 m, followed by an animated overhead machine paddle at the 3.60 m strike point. Feed charge metadata and driven velocity begin on the strike. The full 6 × 13 m area, far-half landing targets, opposite-half scoring, 2-point right quadrant, and 8-point goal remain in place.

Validation: `serve_modes_moc_test.gd` covers actual key press/release dispatch, held cancellation/completion, multiple facing angles and serve-line positions, ballistic landing/net clearance, manual hand contact, physical drill toss/strike, sweet duration addition, duplicate suppression and additive chain caps. `render_serve_telegraph.gd` renders the toss and overhead strike.
