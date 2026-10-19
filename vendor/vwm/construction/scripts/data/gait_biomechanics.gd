class_name GaitBiomechanics
extends RefCounted

## Walking and running as one model, separated by where the body is highest.
##
## The rig's locomotion was a single sine driving the hips, with the arms
## counter-swinging at 46% of it, the knees zeroed every frame, and the vertical
## bob a fixed 3.5 cm. That is a walk, at one speed, forever -- so a libero
## sprinting for a dig and a setter strolling back to their seat moved their legs
## through identical arcs at identical amplitude, and neither ever bent a knee.
##
## ## What actually separates a walk from a run
##
## Not cadence, and not stride length -- those are matters of degree and both
## gaits span a wide range of them. The structural difference is **where the
## centre of mass sits through the step**:
##
##   *Walk* -- an inverted pendulum. The body vaults *over* a near-straight
##   stance leg, so the hips are **highest at midstance** and lowest during the
##   double-support phase when both feet are down. There is always a foot on the
##   floor.
##
##   *Run* -- a spring. The stance leg compresses under the load and rebounds, so
##   the hips are **lowest at midstance** and highest during the flight phase
##   when neither foot is down.
##
## That is a half-cycle inversion of the same oscillation, which is why this is
## one continuous model with a `run_blend` rather than two code paths with a
## transition to hand-tune between them. The phase shift falls out as `PI *
## run_blend` on the vertical term, and every other difference -- stance share,
## knee fold, arm carriage, trunk lean -- is an interpolation between two ends.
##
## ## Phase convention
##
## `cycle` is a **full two-step gait cycle**, and its fractional part is the
## position within one. The right foot strikes at 0.0, the left at 0.5, and the
## right strikes again at 1.0. Callers advance it by distance travelled over two
## stored step lengths: `VolleyballPlayer.stride_length_m` is metres per step,
## despite its historical name. The gait is therefore driven by ground covered
## rather than by wall-clock -- a player who stops mid-step stops mid-step
## instead of continuing to pedal.
##
## Pure and deterministic, like `SpikeBiomechanics`, for the same reason: pose
## work that cannot be checked without eyes on a screen does not get checked.

## Visual vocabulary semantics
##
## - ready/standing: settled, watchful non-contact base; preparation can grow
##   out of it without first resetting the body.
## - walk: controlled positional relocation with continuous grounded steps.
## - run: urgent relocation with carried momentum and a flight-weighted stride.
## - backpedal: retreating adjustment while the chest and attention stay in play.
## - shuffle: lateral defensive or net movement with a low base and uncrossed feet.
##
## Contact families inherit the live stride phase from this vocabulary; a bump,
## set, or attack preparation is something the moving body begins doing, not a
## replacement pose that restarts its feet.

## Where the blend between the two gaits runs, in metres per second.
##
## The lower bound is a stroll and the upper an honest sprint. Real humans
## transition abruptly near 2 m/s rather than blending; this blends because a
## discontinuity in a *drawn* gait reads as a glitch, and because the simulator's
## speeds move continuously through the boundary many times a rally.
const WALK_SPEED_MPS: float = 1.5
const RUN_SPEED_MPS: float = 4.4

## Below this the actor is standing, and the cycle should not advance at all.
const IDLE_SPEED_MPS: float = 0.25

## By this speed the feet have left the job-specific ready stance and the leg
## cycle is being drawn from an upright standing leg. Below it, the first part
## of a move is a weight shift: the hips travel while the wide ready base yields,
## before either foot begins to read as a walking step.
##
## This is intentionally below `WALK_SPEED_MPS`. A slow defender can initiate
## out of their crouch, but once they are visibly walking their foot placement
## must not inherit that crouch's knee and hip angles -- the ground clock is the
## geometry of a standing/walking/running leg, not of whichever tactical stance
## happened to precede it.
const READY_RELEASE_SPEED_MPS: float = 0.75

## What fraction of the stride each foot spends on the ground.
##
## Over half in a walk -- the overlap is the double-support phase, and it is what
## makes a walk a walk. Under half in a run: the shortfall is the flight phase,
## when nobody is touching the floor.
const WALK_STANCE_SHARE: float = 0.62
const RUN_STANCE_SHARE: float = 0.36

## How far the thigh swings either side of vertical.
const WALK_HIP_DEGREES: float = 20.0
const RUN_HIP_DEGREES: float = 39.0

## The yield: how far the knee folds under load at midstance. Nearly straight in
## a walk, which is exactly what lets the body vault over it; deeply compressed
## in a run, which is the spring.
##
## Negative, because every knee on this rig folds backward.
const WALK_STANCE_KNEE_DEGREES: float = -8.0
const RUN_STANCE_KNEE_DEGREES: float = -34.0

## The fold: how far the heel comes up under the body during the swing. This is
## the single most legible difference at a glance -- a runner's heel comes near
## their backside and a walker's barely leaves the floor.
const WALK_SWING_KNEE_DEGREES: float = -54.0
const RUN_SWING_KNEE_DEGREES: float = -114.0

## Where in the swing the knee is most folded. Early rather than halfway: the leg
## folds fast to shorten the pendulum, then unfolds slowly to reach for the
## ground. Below 1.0 skews the peak earlier.
##
## Applied to a *smoothstepped* progress rather than to progress itself, and that
## detail is load-bearing. A raw `pow(p, 0.72)` has an infinite derivative at
## p = 0, which sits exactly on toe-off -- so the knee left the ground with
## unbounded angular speed. Measured at a 5.2 m/s sprint it peaked at 18,700
## degrees per second, against 2,800 for the fastest joint in a spike, and would
## have read as the shin flicking out from under the runner once per step.
## Smoothstep is flat at both ends, so composing through it makes the rate finite
## at toe-off while leaving the peak where it belongs, a little before halfway.
const SWING_PEAK_SKEW: float = 0.72

## Arm swing amplitude, and how bent the elbow is carried.
##
## The elbow is the tell. A walker's arms hang nearly straight and swing from the
## shoulder; a runner's are locked near a right angle and drive front-to-back.
## Getting this wrong is why a fast walk and a slow run look identical.
const WALK_ARM_DEGREES: float = 10.0
const RUN_ARM_DEGREES: float = 33.0
const WALK_ELBOW_DEGREES: float = 20.0
const RUN_ELBOW_DEGREES: float = 82.0

## Forward trunk lean. Negative is forward on this rig, matching
## `SpikeBiomechanics.TORSO_PLANT_RADIANS`.
const WALK_TORSO_RADIANS: float = -0.025
const RUN_TORSO_RADIANS: float = -0.16

## How much of the leg's angle the ankle gives back during swing.
##
## In stance the sole is held flat -- the ankle cancels hip and knee exactly,
## because a planted foot does not rotate with the leg above it. In swing there
## is nothing to hold it against, so it relaxes toward the shin and the toe
## drops. Full relaxation would point the toe straight down like a dancer;
## a little over half is a walker.
const SWING_ANKLE_RELAX: float = 0.55

## How far the hips travel vertically over the stride, in metres.
const WALK_BOB_METERS: float = 0.028
const RUN_BOB_METERS: float = 0.082

## ## The ready stance
##
## **What a stationary voli should be doing, which is not standing.** `gait_blend`
## scales every joint toward zero as speed falls, and zero on this rig is a
## person standing straight up with their arms at their sides. That is the pose
## six of the twelve players on court hold for most of a rally, and it is the
## single least volleyball thing in the game -- nobody on a court ever stands
## like that, because the whole point of the sport between contacts is being
## ready to move.
##
## So the floor is a stance rather than a rest position: knees bent, hips back,
## weight forward, hands up. The gait interpolates *out of* it as speed rises
## rather than out of nothing, which also means a player decelerating settles
## into a stance instead of straightening up.
## **A stance is wide and low, not a lean.** The first version bent the knees and
## pitched the trunk forward and left the feet where standing had put them, which
## reads as someone peering at something rather than someone about to move. What
## makes a ready position a ready position is the base: feet outside the
## shoulders, weight between them, hips dropped so the legs are already loaded.
## Without the width the crouch has nowhere to go and the voli looks folded.
const READY_HIP_DEGREES: float = 16.0
const READY_KNEE_DEGREES: float = -60.0
## How far each leg is carried out from under the hip. Bounded well inside
## `PlayerActor3D.HIP_ABDUCTION_LIMIT_DEGREES` (42), because this is a stance a
## voli holds for a whole rally rather than the extreme of a dig.
const READY_ABDUCTION_DEGREES: float = 15.0
const READY_ARM_DEGREES: float = -30.0
const READY_ELBOW_DEGREES: float = 54.0
## And the lean itself, which was the largest in this file.
##
## -0.30 rad is 17 degrees of forward pitch -- more than a *run* carries at
## -0.16, on a body that is standing still. Reported as reading unbalanced
## rather than low and compact, and the paragraph directly above it had already
## argued the case: a stance is wide and low, not a lean. The constant
## contradicted its own comment, which is the failure mode this repository keeps
## catching in the other direction.
##
## The height it was buying comes from the knee instead, which is where a ready
## position actually gets low: -54 to -60 degrees drops the hips without
## pitching the chest over the toes. Net effect is a body loaded between its
## feet rather than tipped past them.
const READY_TORSO_RADIANS: float = -0.17

## ## Travelling somewhere other than forwards
##
## A gait driven by distance alone can only describe running *at* something. Half
## of what a volleyball player does on the floor is neither: a defender opens and
## backpedals to cover deep, a passer shuffles along the line without ever
## crossing their feet, and both look nothing like a jog.
##
## Both are expressed as scalings of the same stride rather than as separate
## animations, because they are: a backpedal is a short-stepped run with the
## trunk upright, and a shuffle is a run whose hips barely swing because the feet
## are forbidden to pass each other. Blending keeps a player who turns while
## moving continuous through the change, which two clips could not.
const BACKPEDAL_HIP_SCALE: float = 0.62
const BACKPEDAL_KNEE_SCALE: float = 1.15
## Backpedalling puts the chest *up*, not down: the trunk counterweights behind
## the hips and the eyes stay on the ball. Positive is backward on this rig.
const BACKPEDAL_TORSO_RADIANS: float = 0.12
## A shuffle's feet never cross, so the thighs barely swing -- almost all of the
## motion is the pelvis sliding sideways over bent knees.
const SHUFFLE_HIP_SCALE: float = 0.28
const SHUFFLE_KNEE_SCALE: float = 1.30
const SHUFFLE_BOB_SCALE: float = 0.35
const SHUFFLE_ARM_SCALE: float = 0.40
## How much of the ready stance's width survives into a shuffle. Most of it: a
## player sliding along the net never lets their feet come together, which is
## the difference between a shuffle and a skip.
const SHUFFLE_STANCE_SHARE: float = 0.75


## Every joint locomotion needs, for one instant of one stride.
##
## `speed_mps` decides the gait; `cycle` decides where in it. Handedness does not
## enter -- people do not run left- or right-handed.
static func resolve(
	cycle: float,
	speed_mps: float,
	## Which way the voli is travelling *relative to the way they are facing*, in
	## radians. Zero is straight ahead, PI is a backpedal, and plus or minus a
	## right angle is a lateral shuffle. Defaulted so every existing caller keeps
	## the forward gait it already had.
	travel_heading_radians: float = 0.0,
	## The floor pose this gait interpolates *out of*, as the six joints below.
	##
	## Taken as an argument rather than being the `READY_*` constants outright,
	## because a body standing still is doing a job and there is more than one:
	## a defender crouches, a blocker stands tall with their hands at the tape,
	## and a voli watching a ball that is not theirs does neither. Which one is
	## `ReadyStance`'s decision -- a locomotion model has no business knowing
	## what a block is, so it is handed the answer instead of computing it.
	##
	## Empty means the crouch, so every caller that names nothing keeps exactly
	## the stance it had.
	stance: Dictionary = {},
) -> Dictionary:
	var floor_hip := float(stance.get("hip_degrees", READY_HIP_DEGREES))
	var floor_knee := float(stance.get("knee_degrees", READY_KNEE_DEGREES))
	var floor_abduction := float(
		stance.get("abduction_degrees", READY_ABDUCTION_DEGREES)
	)
	var floor_arm := float(stance.get("arm_degrees", READY_ARM_DEGREES))
	var floor_elbow := float(stance.get("elbow_degrees", READY_ELBOW_DEGREES))
	var floor_torso := float(stance.get("torso_radians", READY_TORSO_RADIANS))
	var speed := maxf(speed_mps, 0.0)
	var shape := _movement_shape(speed, travel_heading_radians)
	var backward := float(shape.backward)
	var sideways := float(shape.sideways)
	var run_blend := float(shape.run_blend)
	var gait_blend := float(shape.gait_blend)
	var ready_blend := float(shape.ready_blend)
	## What the ankle has to do for this stance's foot to sit under the body. The
	## same cancellation the walk's stance phase performs, read off the stance
	## rather than off the stride.
	var ready_ankle := -(floor_hip + floor_knee)
	var stance_share := float(shape.stance_share)
	var hip_amplitude := float(shape.hip_amplitude_degrees)
	var stance_knee := float(shape.stance_knee_degrees)
	var swing_knee := float(shape.swing_knee_degrees)

	var right := _leg(
		fposmod(cycle, 1.0), stance_share, hip_amplitude, stance_knee, swing_knee
	)
	## Half a stride out of phase, which is what makes it a pair of legs rather
	## than a hop.
	var left := _leg(
		fposmod(cycle + 0.5, 1.0),
		stance_share, hip_amplitude, stance_knee, swing_knee
	)

	## Arms counter the legs on the same side -- right arm back as the right leg
	## comes forward -- which is what cancels the rotation the legs put into the
	## trunk. Scaled to their own amplitude rather than to a fraction of the
	## hip's, because the ratio between them is not constant across gaits: a
	## runner's arms work proportionally harder than a walker's.
	var arm_amplitude := lerpf(WALK_ARM_DEGREES, RUN_ARM_DEGREES, run_blend)
	var arm_scale := arm_amplitude / maxf(absf(hip_amplitude), 0.001)

	## Two rises and two falls per stride in both gaits. Only the *phase* differs,
	## and it differs by exactly half a cycle -- the walk is highest over the
	## planted leg, the run is lowest there and highest in the air between steps.
	var midstance := stance_share * 0.5
	var bob := cos(TAU * 2.0 * (cycle - midstance) + PI * run_blend) \
		* lerpf(WALK_BOB_METERS, RUN_BOB_METERS, run_blend)

	## Arms quieten in a shuffle: they are held out for balance rather than
	## driving, which is most of what tells a shuffle from a run at a glance.
	var arm_swing := arm_scale * lerpf(1.0, SHUFFLE_ARM_SCALE, sideways)
	## The trunk. Forward in a run, *back* in a backpedal, and near square in a
	## shuffle -- a player sliding along the line is not leaning anywhere.
	var torso := lerpf(
		lerpf(WALK_TORSO_RADIANS, RUN_TORSO_RADIANS, run_blend),
		BACKPEDAL_TORSO_RADIANS, backward,
	) * lerpf(1.0, 0.5, sideways)

	## **Interpolated out of the ready stance, not out of zero.**
	##
	## Every joint used to be scaled by `gait_blend`, so a stationary voli got
	## zeros -- straight legs, level shoulders, arms hanging. Six players hold
	## that for most of a rally. Blending from the stance instead means standing
	## still *is* a pose, and a player decelerating settles into it rather than
	## straightening up as they arrive.
	return {
		"gait_name": gait_name(speed),
		"run_blend": run_blend,
		"gait_blend": gait_blend,
		"backpedal_blend": backward,
		"shuffle_blend": sideways,
		## The ready stance and the locomotion cycle are two layers, with upright
		## standing as the zero between them. Interpolating directly from the
		## crouch into the gait made a slow step's shoe follow the crouch while its
		## ground clock followed an upright leg -- most visibly in backpedaling.
		"right_hip_degrees": floor_hip * ready_blend + right.x * gait_blend,
		"right_knee_degrees": floor_knee * ready_blend + right.y * gait_blend,
		"left_hip_degrees": floor_hip * ready_blend + left.x * gait_blend,
		"left_knee_degrees": floor_knee * ready_blend + left.y * gait_blend,
		## **A zero ankle is aligned with the shank, not flat on the floor.**
		##
		## These read `lerpf(0.0, ...)`, on the stated reasoning that a voli
		## standing still "has their feet flat because the sole and the floor are
		## already parallel". They are not. The shoe hangs off `Knee` and so
		## inherits the whole leg chain: with the defending stance's hip 16 and
		## knee -54 the foot comes out **53.7 degrees** onto its toe, measured by
		## `tools/sole_contact.tscn` on every one of the six bodies, with the other
		## two stances near 19. That is the report that the ready stance looks
		## unbalanced with the volis up on their toes.
		##
		## The fix is the expression this file already uses for the walk's stance
		## phase -- the ankle cancels hip and knee exactly -- applied to the ready
		## stance's own joints and blended on `ready_blend`, so it arrives exactly
		## as the gait's own ankle leaves. No new angle: the stance says what the
		## leg does and the foot follows from it.
		"right_ankle_degrees": ready_ankle * ready_blend + right.z * gait_blend,
		"left_ankle_degrees": ready_ankle * ready_blend + left.z * gait_blend,
		## Which foot is down. `fposmod(cycle, 1.0) < stance_share` for the right
		## and the half-stride offset for the left -- recomputed here rather than
		## carried through the Vector3, because a bool in a float is the kind of
		## packing that ends up being read as a number.
		"right_in_stance": fposmod(cycle, 1.0) < stance_share,
		"left_in_stance": fposmod(cycle + 0.5, 1.0) < stance_share,
		"stance_share": stance_share,
		"ready_blend": ready_blend,
		## Negated against the same side's hip: that is the counter-swing. Both
		## arms rest at the same carriage, which is what makes the stance a stance
		## rather than a stride caught mid-swing.
		"right_arm_degrees": lerpf(
			floor_arm, -right.x * arm_swing, gait_blend
		),
		"left_arm_degrees": lerpf(
			floor_arm, -left.x * arm_swing, gait_blend
		),
		"elbow_degrees": lerpf(
			floor_elbow,
			lerpf(WALK_ELBOW_DEGREES, RUN_ELBOW_DEGREES, run_blend),
			gait_blend,
		),
		"torso_pitch_radians": lerpf(floor_torso, torso, gait_blend),
		## Feet outside the shoulders when set, closing as the stride takes over --
		## you cannot run with your legs abducted, and a shuffle keeps some of it
		## because a shuffle never brings the feet together either.
		"abduction_degrees": floor_abduction * ready_blend \
			+ floor_abduction * SHUFFLE_STANCE_SHARE * sideways * gait_blend,
		## Nothing bobs standing still, so this one really does go to zero.
		"bob_meters": bob * gait_blend * lerpf(1.0, SHUFFLE_BOB_SCALE, sideways),
	}


## The step length the drawn leg geometry actually describes.
##
## At foot strike the straight leg reaches `+hip_amplitude`; at toe-off it
## trails by the same angle. Across that stance the foot therefore sweeps
## `2 * leg_span * sin(amplitude)` beneath the hip. The body covers two steps
## per full cycle and this foot is down for `stance_share` of it, so the step
## that keeps the sole still is `leg_span * sin(amplitude) / stance_share`.
##
## Playback used the player's approach-step attribute directly at every speed.
## That forced a 20-degree walking leg and a 39-degree sprinting leg through the
## same ground distance, so one skated forward and the other backward. The
## player's stride still enters through their rig's leg span; this function
## reconciles that physique with the gait they are visibly performing.
static func geometric_step_meters(
	leg_span_meters: float,
	speed_mps: float,
	travel_heading_radians: float = 0.0,
) -> float:
	var shape := _movement_shape(speed_mps, travel_heading_radians)
	## The leg cycle grows out of upright standing as the gait comes in. The
	## ground step has to grow by the same share or a slow gait is clocked as if
	## it were already swinging through its full walking arc.
	var amplitude := absf(float(shape.hip_amplitude_degrees)) \
		* float(shape.gait_blend)
	var stance_share := maxf(float(shape.stance_share), 0.05)
	return maxf(
		maxf(leg_span_meters, 0.05) * sin(deg_to_rad(amplitude)) / stance_share,
		0.18,
	)


## Speed and direction terms shared by the joint pose and its ground clock.
## Keeping them together is load-bearing: a shuffle whose hips are shortened
## but whose cycle still uses the forward-run step length is another skating
## gait under a different name.
static func _movement_shape(
	speed_mps: float, travel_heading_radians: float
) -> Dictionary:
	var speed := maxf(speed_mps, 0.0)
	## Decomposed rather than branched on, so a defender opening from a shuffle
	## into a backpedal passes through the blend instead of snapping between two
	## clips.
	var backward := clampf(-cos(travel_heading_radians), 0.0, 1.0)
	var sideways := clampf(absf(sin(travel_heading_radians)), 0.0, 1.0)
	var run_blend := smoothstep(WALK_SPEED_MPS, RUN_SPEED_MPS, speed)
	## Separate from `run_blend`: this is how much gait there is at all.
	var gait_blend := smoothstep(IDLE_SPEED_MPS, WALK_SPEED_MPS, speed)
	## Release the tactical stance before a walk is fully established. This gap
	## is the initial hip-led weight shift; the cyclic leg motion itself remains
	## governed by `gait_blend` and begins from upright zero.
	var ready_blend := 1.0 - smoothstep(
		IDLE_SPEED_MPS, READY_RELEASE_SPEED_MPS, speed
	)
	var stance_share := lerpf(WALK_STANCE_SHARE, RUN_STANCE_SHARE, run_blend)
	var stride_scale := lerpf(1.0, BACKPEDAL_HIP_SCALE, backward) \
		* lerpf(1.0, SHUFFLE_HIP_SCALE, sideways)
	## A backpedal is not a forward gait with shorter steps. The stance foot has
	## to sweep toward the toes while the body travels toward the heels, so the
	## hip curve reverses. Blending the sign through oblique travel also avoids a
	## phase snap as a defender opens from a shuffle into a backpedal.
	var travel_sign := lerpf(1.0, -1.0, backward)
	var knee_scale := lerpf(1.0, BACKPEDAL_KNEE_SCALE, backward) \
		* lerpf(1.0, SHUFFLE_KNEE_SCALE, sideways)
	return {
		"backward": backward,
		"sideways": sideways,
		"run_blend": run_blend,
		"gait_blend": gait_blend,
		"ready_blend": ready_blend,
		"stance_share": stance_share,
		"hip_amplitude_degrees": lerpf(
			WALK_HIP_DEGREES, RUN_HIP_DEGREES, run_blend
		) * stride_scale * travel_sign,
		"stance_knee_degrees": lerpf(
			WALK_STANCE_KNEE_DEGREES, RUN_STANCE_KNEE_DEGREES, run_blend
		) * knee_scale,
		"swing_knee_degrees": lerpf(
			WALK_SWING_KNEE_DEGREES, RUN_SWING_KNEE_DEGREES, run_blend
		) * knee_scale,
	}


## One leg's hip and knee at a point in its own cycle, as `(hip, knee)`.
##
## `leg_phase` runs 0 at foot strike through `stance_share` at toe-off to 1 at
## the next strike.
static func _leg(
	leg_phase: float,
	stance_share: float,
	hip_amplitude: float,
	stance_knee: float,
	swing_knee: float,
) -> Vector3:
	var share := clampf(stance_share, 0.05, 0.95)
	var in_stance := leg_phase < share
	## Remapped so swing always fills the second half whatever share of the stride
	## stance actually takes.
	var normalized := 0.5 * leg_phase / share if in_stance \
		else 0.5 + 0.5 * (leg_phase - share) / (1.0 - share)
	## During stance the *shoe*, not the hip angle, sweeps linearly beneath the
	## body. A cosine hip curve comes almost to rest at strike and toe-off and
	## races through midstance, so even when its total step length is exact the
	## foot alternately sticks and skates. Inverting sine makes the straight-leg
	## horizontal reach linear from +amplitude to -amplitude. The airborne return
	## keeps the smoother cosine because there is no ground constraint to satisfy.
	var hip := 0.0
	if in_stance:
		var reach := lerpf(
			sin(deg_to_rad(hip_amplitude)),
			-sin(deg_to_rad(hip_amplitude)),
			leg_phase / share,
		)
		hip = rad_to_deg(asin(clampf(reach, -0.999, 0.999)))
	else:
		hip = hip_amplitude * cos(normalized * TAU)
	var knee := 0.0
	if in_stance:
		## The yield, deepest at midstance and gone at both ends -- the foot
		## meets the ground on a straightening leg and leaves it on one.
		knee = stance_knee * sin(leg_phase / share * PI)
	else:
		## The fold, skewed early: the leg shortens fast to clear the ground and
		## unfolds slowly to reach for the next strike.
		var progress := (leg_phase - share) / (1.0 - share)
		knee = swing_knee * sin(
			pow(smoothstep(0.0, 1.0, progress), SWING_PEAK_SKEW) * PI
		)
	## **Which foot is on the floor**, returned rather than discarded.
	##
	## This was computed on the first line of this function and thrown away with
	## the rest of the local scope, so nothing outside could tell a planted foot
	## from a swinging one -- and a foot that cannot be told apart is a foot that
	## cannot be planted. It is the whole precondition for procedural placement
	## and it has been sitting here since the model was written.
	##
	## Packed into the existing return rather than given a dictionary: this
	## function is called twice per voli per frame and the two callers both want
	## three floats.
	##
	## The ankle comes with it. A shoe that keeps its constant rotation while the
	## shin swings is a foot that points wherever the leg happens to aim, and the
	## thing that reads as a foot is the sole staying parallel to the floor
	## through stance. Cancelling hip and knee does exactly that, and in swing it
	## relaxes toward the shin so the toe drops the way a real one does.
	var ankle := -(hip + knee)
	if not in_stance:
		ankle *= SWING_ANKLE_RELAX
	return Vector3(hip, knee, ankle)


## What to call this speed, so a diagnostic can say "run" instead of printing a
## blend factor.
static func gait_name(speed_mps: float) -> String:
	if speed_mps < IDLE_SPEED_MPS:
		return "stand"
	if speed_mps < WALK_SPEED_MPS:
		return "walk"
	if speed_mps < RUN_SPEED_MPS:
		return "stride"
	return "run"
