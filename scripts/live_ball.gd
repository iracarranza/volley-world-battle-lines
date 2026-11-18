extends RefCounted
## LiveBall operations (MS-07): the named ways the live ball (lab.ball position, lab.ball_velocity, lab.ball_shot) changes.
## The record stays on the lab, where readers find it; this is not contact/ball_state.gd (BallState builds shot metadata).
## Commit applies a resolved contact, integrate advances the flight by one ball-clock step, steer is MoC's trajectory steering and the
## declared real-time exception (it is called from the render-rate path, not the physics step). Pre-resolver velocity shaping in the bot
## and Pepper providers (low_stamina_factor, Preparation.output_factor) stays with them: intent must not depend on the outcome.

## A resolved contact: its velocity replaces the ball's, its separation moves the ball off the athlete.
static func commit_contact(lab, result) -> void:
	lab.ball_velocity = result.velocity
	lab.ball.position += result.separation_offset

static func commit_shot(lab, shot: Dictionary) -> void:
	lab.ball_shot = shot

## One flight step of dt ball-clock seconds: ballistic motion, gravity on the velocity, the visual spin.
static func integrate(lab, dt: float) -> void:
	lab.ball.position += lab.ball_velocity * dt + Vector3.DOWN * (lab.GRAVITY * dt * dt * 0.5)
	lab.ball_velocity.y -= lab.GRAVITY * dt
	lab.ball.rotate_x(dt * 4)

## What a collision step did to the ball (the net response, a basket): position and velocity after resolving it.
static func commit_step(lab, step_result: Dictionary) -> void:
	lab.ball.position = step_result.position
	lab.ball_velocity = step_result.velocity

## An activity's feed: the ball appears at `position` moving at `velocity` with `shot` as its metadata, and is live.
static func launch(lab, position: Vector3, velocity: Vector3, shot: Dictionary) -> void:
	lab.ball.position = position
	lab.ball_velocity = velocity
	lab.ball_shot = shot
	lab.ball_active = true

## The ball is out of play (a drill ended or stopped, a feed ran out, the ball was parked or caught).
static func release(lab) -> void:
	lab.ball_active = false

## Trajectory steering: the change the player's input made since the last update, on top of whatever physics added meanwhile.
static func steer(lab, delta: Vector3) -> void:
	lab.ball_velocity += delta
