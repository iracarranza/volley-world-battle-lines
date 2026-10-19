# Ball View: tracking camera, independent athlete input

This experiment supersedes the athlete-centered orbit/framing experiment in `freeplay-serve-pepper.md`.

Athlete View retains mouse-controlled camera/facing. Ball View follows athlete translation and elevation immediately, then automatically positions behind the athlete relative to the ball. Its lower viewpoint puts the athlete at bottom center and the ball above. The horizontal stand-off starts at 4.2 m and smoothly shortens toward 0.8 m for close overhead balls. The framing reference rises from the torso to the head, deliberately allowing the lower body to crop at steep angles. Heading holds for a directly overhead ball to avoid flips from tiny horizontal changes. Physical obstacle clearance recomputes the framing after clipping camera distance.

Automatic camera positioning does not rotate athlete facing. The athlete can turn independently while the camera observes the athlete/ball pair. With no live ball, framing uses a forward reference.
Mouse left/right turns the athlete with normal yaw sensitivity, independent of tracking rotation. Mouse up/down changes intentional contact loft without rotating/repositioning the tracking camera. Incoming ball motion cannot change facing or shot loft. Serving in Ball View likewise uses deliberate athlete heading/pitch rather than tracking-camera orientation.

WASD uses the live horizontal athlete-to-ball direction in Ball View. Forward moves toward the ball; backward moves away; left/right strafe perpendicular to that direction. This basis updates as either moves, independently of mouse facing and camera smoothing. A directly overhead ball retains the last valid horizontal direction to avoid an unstable basis; no active ball also retains that direction. Returning to Athlete View transfers the chosen facing to its free-camera yaw.

A gold world arrow and a small FACING compass next to the resource bars show the contact heading. The compass remains readable when steep framing crops the lower body. It projects the chosen heading relative to the camera's horizontal orientation. Debug-volume toggles do not hide these gameplay aim indicators.

Ball View permits turning an airborne action before confirmation, supporting jump-set orientation. Once confirmed, its airborne direction remains committed. Existing immutable contact intent and post-impact ball flight remain unchanged. Claude's dive/wing stages are preserved.

`ball_framing_test.gd` verifies bottom-center athlete framing, ball visibility, low camera placement, overhead cropping, anchored jumping/movement, and obstacle correction. `ball_view_controls_test.gd` covers independent facing/loft, ball-relative movement, pre-confirm jump-set turning, commitment, view transitions, indicators, and actual Ball View serving. `render_ball_view_controls.gd` captures the high-receive/setter scenario.

Near the main net (within 3.5 m, strongest within 1 m), Ball View gradually allows the ball toward vertical screen center. The athlete reference can move lower, capped at 94% screen height. The overhead camera stand-off increases toward 2 m near the net to reduce close-up crowding. This exception is confined to the net span; facing and loft remain independent.
