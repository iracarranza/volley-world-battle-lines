# Locomotion: head on the cursor, hips on the movement

Visual only. The body's own yaw stays the aim direction, so hurtboxes, contacts and the camera are unchanged.

**Module:** `scripts/lab/athlete_locomotion.gd`, stepped once per rendered frame from `athlete_animation.gd`. **Rig:** a new spine channel `hip_yaw` (degrees, + left) turns the legs, their sockets, the tail and everything above the hips; the lumbar, chest and neck twists counter-rotate so the head stays on the cursor. It is a pose-library channel, so it is smoothed, blended and shown in the pose editor like the others.

- **Hips follow travel.** They turn at 620 deg/s toward the direction of travel, and settle back to the cursor at 240 deg/s when standing. A fast cursor swing drags them only as far as 95 degrees from the cursor; they trail behind it.
- **Head stays on the cursor.** The counter-twist is shared lumbar 17%, chest 44% (limits 15, 40) with the neck taking the remainder (limit 70), so no joint passes its range and the head world yaw equals the cursor.
- **Backpedal.** Travel more than 112 degrees from the cursor (back to 96 on the way out) is a backpedal: the hips face the cursor and the legs run backwards.
- **Steps.** From standing, one leg leads toward the input and the other pushes off behind it (0.26 s launch). Input against the velocity at speed (dot below -0.35, over 1.4 m/s) starts a brake: the grounded (trailing) leg plants ahead and bent, the body leans back 12 degrees, the other leg reaches toward the new direction and the hips hold the old line. When the speed is under 1 m/s (or after 0.45 s) the hips turn and the launch step goes the new way.
- **Off in** the air, dives, floor recoveries, receive-ready (the shuffle keeps its square hips), sets and the jump approach.

Not done: the sprint has no lean of its own, and a hip-turned pose with `hip_shift` foot planting is unsupported (the IK solve ignores the turn). Strips: `tests/render_locomotion_strip.gd -- --case=strafe|reverse|start|backpedal [--side]`. Tests: `tests/athlete_locomotion_test.gd`.
