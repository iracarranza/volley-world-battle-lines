class_name BallFlightModel
extends RefCounted

## Projectile motion launched from a contact height, with a signed launch angle.
##
## This exists alongside `RallyKinematics.solve_launch_arc()` rather than
## replacing it, because the two answer opposite questions and the old one is
## still wired into every live call site.
##
## `solve_launch_arc` is the *level-ground* solution: it assumes the ball is
## launched and lands at the same height, it clamps the launch angle positive,
## and it takes the landing point as given and back-solves the force needed to
## reach it. That is the right shape for "the setter is putting the ball on the
## pin" and the wrong shape for a spike. A spike contacts near 3.2 m and is
## struck *downward*; a negative angle puts a negative under that square root,
## so the engine currently models every attack as a ball lobbed upward from the
## floor to the floor and only gets away with it because nothing ever asks
## whether the flight is physical.
##
## Here the causal direction is inverted. Speed and angle are chosen, and the
## landing is whatever the physics produces -- including landing out. That is
## what allows in/out, block contact and the drawn arc to be one computation
## instead of three that have to be kept in agreement by hand.
##
## Purely the vertical plane along the shot's bearing: distances are horizontal
## ground distance, not court coordinates. Callers compose this with a
## horizontal bearing to get a 3D path, which keeps the physics free of court
## geometry and keeps the bearing free of gravity.
##
## No drag and no spin. That is a real simplification, but a smaller one than it
## sounds: a struck volleyball's range is dominated by its downward launch angle
## rather than by aerodynamics, and allowing negative angles does most of the
## work a drag term would otherwise have to. Float and topspin serves remain
## outside what this can express.

## Gravity, for every ball in the engine.
##
## The single declaration. It stood at 9.8 here and in `RallyKinematics` and at
## 9.81 in `BlockJumpModel` -- one physical constant with two values, which is a
## small error and exactly the kind that survives because nobody looks at it.
## Unified downward to 9.8, which is what two of the three declarations used and
## what the hand-derived expectations in `_test_ball_flight_from_contact_height`
## were computed from. The other 0.1% buys no physical fidelity and would have
## invalidated every one of those literals.
const DEFAULT_GRAVITY_MPS2: float = 9.8
const MIN_SPEED_MPS: float = 0.1
const MIN_FLIGHT_DURATION: float = 0.01
## Signed, unlike the level-ground model's 2..75. Negative is a struck ball
## driven downward and is the *ordinary* case for an attack, not an edge case.
## The bounds exist only to keep cos(theta) away from zero, where horizontal
## range collapses and the inverse solve stops being meaningful.
const MIN_LAUNCH_ANGLE_DEGREES: float = -85.0
## Deliberately *not* the same bound as `RallyKinematics.MAX_LAUNCH_ANGLE_DEGREES`,
## which sits at 75 degrees. That one bounds the apex of a drawn ground-to-ground
## arc, where an unclamped steep solution implies a physically silly apex over a
## real court distance. This one bounds a launch from three metres up whose
## outcome is read off where it lands, and a serve or a heavily lifted ball
## genuinely leaves the hand steeper than 75.
##
## The divergence is the point and is stated in both files. What was wrong was
## that neither knew the other existed, so a reader of either would have assumed
## it was the bound.
const MAX_LAUNCH_ANGLE_DEGREES: float = 85.0


## Where a ball struck at `speed_mps` and `launch_angle_degrees` from
## `contact_height_meters` comes back to the floor.
##
## Always solves for a contact above the floor -- the ball always comes down --
## so a shot with too little speed lands short rather than failing to resolve.
## There is no "cannot reach" case to special-case anywhere downstream.
static func solve_flight(
	speed_mps: float,
	launch_angle_degrees: float,
	contact_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var speed := maxf(speed_mps, MIN_SPEED_MPS)
	var gravity := maxf(gravity_mps2, 0.1)
	var height := maxf(contact_height_meters, 0.0)
	var angle := clampf(
		launch_angle_degrees, MIN_LAUNCH_ANGLE_DEGREES, MAX_LAUNCH_ANGLE_DEGREES
	)
	var radians := deg_to_rad(angle)
	var vertical := speed * sin(radians)
	var horizontal := speed * cos(radians)
	## t = (v*sin(theta) + sqrt(v^2*sin^2(theta) + 2*g*h)) / g
	var duration := (
		vertical + sqrt(vertical * vertical + 2.0 * gravity * height)
	) / gravity
	duration = maxf(duration, MIN_FLIGHT_DURATION)
	## A ball already descending at contact never rises, so its apex is the
	## contact itself. Only a ball struck upward has an apex above the hand.
	var apex := height
	if vertical > 0.0:
		apex = height + vertical * vertical / (2.0 * gravity)
	return {
		"range_meters": maxf(horizontal * duration, 0.0),
		"duration_seconds": duration,
		"apex_height_meters": apex,
		"landing_speed_mps": sqrt(speed * speed + 2.0 * gravity * height),
		"launch_angle_degrees": angle,
		"speed_mps": speed,
		"contact_height_meters": height,
		"horizontal_speed_mps": horizontal,
		"vertical_speed_mps": vertical,
	}


## How high the ball is once it has travelled `horizontal_distance_meters` along
## the ground.
##
## This is what a block intersection test reads: put the blocker's distance in,
## compare the height out against their reach. Returns a negative height past
## the landing point, so callers can tell "the ball was already down" from "the
## ball passed over low".
static func height_at_distance(
	flight: Dictionary,
	horizontal_distance_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var horizontal := float(flight.get("horizontal_speed_mps", 0.0))
	if horizontal <= MIN_SPEED_MPS:
		return float(flight.get("contact_height_meters", 0.0))
	var gravity := maxf(gravity_mps2, 0.1)
	var elapsed := maxf(horizontal_distance_meters, 0.0) / horizontal
	return float(flight.get("contact_height_meters", 0.0)) \
		+ float(flight.get("vertical_speed_mps", 0.0)) * elapsed \
		- 0.5 * gravity * elapsed * elapsed


## Speed, time and apex for a ball struck at a chosen angle between two contacts
## at known heights.
##
## The general form of `minimum_speed_for_range`, and the one the rally actually
## needs. That function solves a launch from height `h` down to the floor, which
## is right for a serve going long and wrong for every flight that *ends in
## somebody's hands* -- a set finishing at a hitter's contact three metres up was
## being solved as though it had to reach the floor, and came out with a third
## more hang time than the ball really had.
##
## Rearranging the trajectory equation at y = h1 rather than y = 0 leaves the
## drop `h0 - h1` exactly where the launch height used to sit, so the whole
## difference is one substitution:
##
##   v^2 = g*R^2 / (2*cos^2(theta) * (R*tan(theta) + h0 - h1))
##
## and the drop is signed -- negative for a ball played *upward* into a hitter's
## reach, which is the case that motivated this.
##
## `feasible` is false when that denominator is not positive: at this angle the
## ball is still climbing when it reaches the range, so no speed lands it there
## and the caller is asking for a shot that does not exist. Reported rather than
## clamped, for the reason `solve_angle_for_range` gives at length -- a solver
## that answers a different question than the one posed is the failure this
## module exists to remove.
static func solve_between(
	range_meters: float,
	launch_angle_degrees: float,
	start_height_meters: float,
	end_height_meters: float = 0.0,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var distance := maxf(range_meters, 0.0)
	var gravity := maxf(gravity_mps2, 0.1)
	var angle := clampf(
		launch_angle_degrees, MIN_LAUNCH_ANGLE_DEGREES, MAX_LAUNCH_ANGLE_DEGREES
	)
	var radians := deg_to_rad(angle)
	var cosine := cos(radians)
	var drop := start_height_meters - end_height_meters
	var denominator := 2.0 * cosine * cosine * (distance * tan(radians) + drop)
	if distance <= 0.0001 or cosine <= 0.0001 or denominator <= 0.0000001:
		return {
			"feasible": false,
			"duration_seconds": MIN_FLIGHT_DURATION,
			"apex_height_meters": maxf(start_height_meters, 0.0),
			"apex_rise_meters": 0.0,
			"required_speed_mps": MIN_SPEED_MPS,
			"launch_angle_degrees": angle,
		}
	var speed := maxf(
		sqrt(gravity * distance * distance / denominator), MIN_SPEED_MPS
	)
	## Horizontal motion is uniform without drag, so the time to cover the ground
	## distance *is* the flight time. Taken this way rather than from
	## `solve_flight`, whose duration runs on to the floor and would overshoot
	## every flight that ends in a contact above it.
	var duration := maxf(distance / maxf(speed * cosine, MIN_SPEED_MPS),
		MIN_FLIGHT_DURATION)
	var vertical := speed * sin(radians)
	var apex := start_height_meters
	if vertical > 0.0:
		apex = start_height_meters + vertical * vertical / (2.0 * gravity)
	return {
		"feasible": true,
		"duration_seconds": duration,
		"apex_height_meters": apex,
		"apex_rise_meters": maxf(apex - start_height_meters, 0.0),
		"required_speed_mps": speed,
		"launch_angle_degrees": angle,
	}


## How high a ball is partway between two contacts it is known to have made.
##
## The drawing problem, not the solving problem, and it is the one place the two
## meet. Everything above chooses a launch and reads the landing off it. A
## *drawn* flight is the opposite: both ends are already facts -- the hitter
## contacted at 3.1 m, the digger contacted at 0.9 m, and the resolver has
## already decided how long the ball took to get between them. Three knowns,
## and a parabola has exactly three degrees of freedom, so the flight is
## determined. Nothing is left to choose.
##
##   h(t) = h0 + v0*t - g*t^2/2,   with v0 fixed by h(T) = h1
##
## What this replaces is worth stating, because it was wrong in a way that looked
## right. The drawn height used to be a *symmetric hump* fitted to an authored
## apex: `lerp(h0, h1, t) + 4*(apex - midpoint)*t*(1-t)`, with the apex supplied
## by a presentation table of per-action lift multipliers. That curve is
## symmetric about the midpoint whatever the ball is doing, so a spike struck
## downward from 3.1 m to the floor in 0.45 s was drawn holding 3.1 m to the
## halfway mark and then dropping: **65% of its descent happened in the last
## quarter of the flight**, against 31% for the real parabola. That is precisely
## the reported symptom -- a flat ball that arrives over the target and falls out
## of the sky -- and it was not a bug in the arithmetic. It was a curve shape
## that cannot express a ball hit downward at all, because the presentation table
## floored the apex *above* the contact height and a hump with an apex above both
## ends has to rise first.
##
## `progress` is the fraction of the flight elapsed, so a caller sampling a
## Bezier horizontally at the same `t` gets a height that belongs to that moment.
static func height_between(
	start_height_meters: float,
	end_height_meters: float,
	duration_seconds: float,
	progress: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var duration := maxf(duration_seconds, MIN_FLIGHT_DURATION)
	var gravity := maxf(gravity_mps2, 0.1)
	var elapsed := clampf(progress, 0.0, 1.0) * duration
	var rise := rise_speed_between(
		start_height_meters, end_height_meters, duration, gravity
	)
	return start_height_meters + rise * elapsed - 0.5 * gravity * elapsed * elapsed


## The vertical speed the ball left the first contact with, for a flight that is
## known to reach `end_height_meters` after `duration_seconds`.
##
## Signed, and the sign is the whole point: negative is a ball struck downward,
## which is the ordinary case for a spike and the case the old drawn curve could
## not represent.
static func rise_speed_between(
	start_height_meters: float,
	end_height_meters: float,
	duration_seconds: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var duration := maxf(duration_seconds, MIN_FLIGHT_DURATION)
	return (end_height_meters - start_height_meters) / duration \
		+ 0.5 * maxf(gravity_mps2, 0.1) * duration


## The highest the ball gets between two known contacts.
##
## Derived rather than supplied. A caller that wants to know whether a flight
## clears the net asks this; it does not get to decide the answer.
static func apex_between(
	start_height_meters: float,
	end_height_meters: float,
	duration_seconds: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var gravity := maxf(gravity_mps2, 0.1)
	var rise := rise_speed_between(
		start_height_meters, end_height_meters, duration_seconds, gravity
	)
	if rise <= 0.0:
		## Already descending at the first contact, so the contact is the apex.
		return start_height_meters
	return start_height_meters + rise * rise / (2.0 * gravity)


## The flight time that puts the ball's apex at `apex_height_meters`.
##
## The inverse of `apex_between`, and the join that lets a *decision* about how
## high to play a ball become a hang time rather than a drawn decoration. A
## passer choosing to put the ball 4 m up is choosing how long the setter has,
## and this is the conversion between those two statements of the same choice.
##
## Solves the rising leg to the apex and the falling leg back down to the second
## contact separately, because they are only equal when the two contacts are at
## the same height and they almost never are.
static func duration_for_apex(
	start_height_meters: float,
	end_height_meters: float,
	apex_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var gravity := maxf(gravity_mps2, 0.1)
	var apex := maxf(
		apex_height_meters, maxf(start_height_meters, end_height_meters)
	)
	var up := sqrt(2.0 * maxf(apex - start_height_meters, 0.0) / gravity)
	var down := sqrt(2.0 * maxf(apex - end_height_meters, 0.0) / gravity)
	return maxf(up + down, MIN_FLIGHT_DURATION)


## The launch angle that lands a ball of this speed at this range.
##
## The inverse of `solve_flight`, for a decision layer that knows where it wants
## the ball and how hard it intends to hit it. Substituting the trajectory
## equation at y = 0 and writing u = tan(theta) gives a quadratic:
##
##   k*u^2 - R*u + (k - h) = 0,  where k = g*R^2 / (2*v^2)
##
## Its two roots are the two ways to hit the same spot at the same speed: the
## flatter, driven one and the lofted one. They are returned separately rather
## than picked here, because which is wanted is a decision -- a spike takes the
## driven root, a roll shot takes the lofted one -- and that decision does not
## belong to the physics.
##
## `found` is false when the discriminant is negative: no angle at this speed
## reaches this far, which is the honest answer for a ball hit too softly.
##
## Each root is flagged separately, and **a root outside the representable angle
## band is reported unusable rather than clamped into it**. Clamping looks
## harmless and is not: the lofted root for a fast ball at short range is a
## near-vertical lob -- 22 m/s over 4 m solves to 87.7 degrees -- and pinning
## that to 85 returns an angle that carries 8.8 m instead of the 4 m asked for.
## A solver that answers a different question than the one posed is the exact
## failure this whole model exists to remove, so it declines instead.
static func solve_angle_for_range(
	speed_mps: float,
	range_meters: float,
	contact_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var speed := maxf(speed_mps, MIN_SPEED_MPS)
	var target_range := maxf(range_meters, 0.0)
	var height := maxf(contact_height_meters, 0.0)
	var gravity := maxf(gravity_mps2, 0.1)
	var unreachable := {
		"found": false,
		"driven_found": false, "driven_angle_degrees": 0.0,
		"lofted_found": false, "lofted_angle_degrees": 0.0,
	}
	if target_range <= 0.0001:
		return unreachable
	var k := gravity * target_range * target_range / (2.0 * speed * speed)
	if k <= 0.0000001:
		return unreachable
	var discriminant := target_range * target_range - 4.0 * k * (k - height)
	if discriminant < 0.0:
		return unreachable
	var root := sqrt(discriminant)
	var driven := rad_to_deg(atan((target_range - root) / (2.0 * k)))
	var lofted := rad_to_deg(atan((target_range + root) / (2.0 * k)))
	var driven_usable := driven >= MIN_LAUNCH_ANGLE_DEGREES \
		and driven <= MAX_LAUNCH_ANGLE_DEGREES
	var lofted_usable := lofted >= MIN_LAUNCH_ANGLE_DEGREES \
		and lofted <= MAX_LAUNCH_ANGLE_DEGREES
	return {
		"found": driven_usable or lofted_usable,
		"driven_found": driven_usable,
		"driven_angle_degrees": driven,
		"lofted_found": lofted_usable,
		"lofted_angle_degrees": lofted,
	}


## The slowest a ball can be struck to carry this far *at all*, and the angle
## that does it.
##
## Distinct from `minimum_speed_for_range`, which asks the same question with the
## angle pinned, and which has a degenerate answer this one does not: at a fixed
## shallow angle there are ranges no speed reaches, and that function returns the
## speed floor rather than an error. A caller taking that literally draws a ball
## at 0.1 m/s -- measured, a sixteen-metre attack came out with a hundred and
## twenty-four second flight and a tape height in the hundreds of metres, which is
## how this function came to exist.
##
## Maximum range from a launch height is R = (v/g)*sqrt(v^2 + 2gh); inverting for
## v gives a quadratic in v^2 whose positive root is below, and the angle that
## achieves it follows from the same optimisation.
static func minimum_speed_to_reach(
	range_meters: float,
	contact_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var distance := maxf(range_meters, 0.0)
	var height := maxf(contact_height_meters, 0.0)
	var gravity := maxf(gravity_mps2, 0.1)
	var speed_squared := gravity * (
		sqrt(height * height + distance * distance) - height
	)
	var speed := maxf(sqrt(maxf(speed_squared, 0.0)), MIN_SPEED_MPS)
	return {
		"speed_mps": speed,
		"launch_angle_degrees": rad_to_deg(atan(
			speed / maxf(sqrt(speed * speed + 2.0 * gravity * height), 0.0001)
		)),
	}


## The slowest a ball can be struck at this angle and still carry this far.
## Useful to a decision layer deciding whether a course is available at all
## before it commits to a power.
static func minimum_speed_for_range(
	range_meters: float,
	launch_angle_degrees: float,
	contact_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var target_range := maxf(range_meters, 0.0)
	var height := maxf(contact_height_meters, 0.0)
	var gravity := maxf(gravity_mps2, 0.1)
	var radians := deg_to_rad(clampf(
		launch_angle_degrees, MIN_LAUNCH_ANGLE_DEGREES, MAX_LAUNCH_ANGLE_DEGREES
	))
	var cosine := cos(radians)
	if target_range <= 0.0001 or cosine <= 0.0001:
		return MIN_SPEED_MPS
	## From y = 0 at x = R:  v^2 = g*R^2 / (2*cos^2(theta)*(R*tan(theta) + h))
	var denominator := 2.0 * cosine * cosine \
		* (target_range * tan(radians) + height)
	if denominator <= 0.0000001:
		## The angle alone already carries the ball past the range no matter how
		## softly it is struck.
		return MIN_SPEED_MPS
	return maxf(
		sqrt(gravity * target_range * target_range / denominator), MIN_SPEED_MPS
	)
