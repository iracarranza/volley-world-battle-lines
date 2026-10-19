class_name PlayerActor3D
extends Node3D

const UIPalette := preload("res://vendor/vwm/construction/scripts/data/ui_palette.gd")
const RegionalKitsScript := preload("res://vendor/vwm/construction/scripts/data/regional_kits.gd")

const RallyEventModel := preload("res://vendor/vwm/construction/scripts/models/rally_event.gd")
const BodyTypeModelsScript := preload("res://vendor/vwm/body_type_models.gd")
const FaceExpressionsScript := preload("res://vendor/vwm/construction/scripts/data/face_expressions.gd")
const StanceTransitionScript := preload("res://vendor/vwm/construction/scripts/data/stance_transition.gd")
const GaitBiomechanicsScript := preload("res://vendor/vwm/construction/scripts/data/gait_biomechanics.gd")
const RallyKinematicsScript := preload(
	"res://vendor/vwm/construction/scripts/simulation/rally_kinematics.gd"
)
const BlockBiomechanicsScript := preload("res://vendor/vwm/construction/scripts/data/block_biomechanics.gd")
const LandingBiomechanicsScript := preload(
	"res://vendor/vwm/construction/scripts/data/landing_biomechanics.gd"
)
const ServeBiomechanicsScript := preload(
	"res://vendor/vwm/construction/scripts/data/serve_biomechanics.gd"
)
const ServeActionBiomechanicsScript := preload(
	"res://vendor/vwm/construction/scripts/data/serve_action_biomechanics.gd"
)
const SetBiomechanicsScript := preload("res://vendor/vwm/construction/scripts/data/set_biomechanics.gd")
const AttackActionBiomechanicsScript := preload(
	"res://vendor/vwm/construction/scripts/data/attack_action_biomechanics.gd"
)
const DefenseActionBiomechanicsScript := preload(
	"res://vendor/vwm/construction/scripts/data/defense_action_biomechanics.gd"
)
const ContactArrivalBiomechanicsScript := preload(
	"res://vendor/vwm/construction/scripts/data/contact_arrival_biomechanics.gd"
)
const IdleBiomechanicsScript := preload("res://vendor/vwm/construction/scripts/data/idle_biomechanics.gd")
const CoreVoliPerformanceScript := preload(
	"res://vendor/vwm/construction/scripts/data/core_voli_performance.gd"
)

@onready var body_pivot: Node3D = $BodyPivot
@onready var torso: MeshInstance3D = $BodyPivot/Torso
@onready var head: MeshInstance3D = $BodyPivot/Head
@onready var left_arm: Node3D = $BodyPivot/LeftArm
@onready var right_arm: Node3D = $BodyPivot/RightArm
@onready var left_wrist: Node3D = $BodyPivot/LeftArm/Elbow/Wrist
@onready var right_wrist: Node3D = $BodyPivot/RightArm/Elbow/Wrist
@onready var left_leg: Node3D = $BodyPivot/LeftLeg
@onready var right_leg: Node3D = $BodyPivot/RightLeg
@onready var shadow: MeshInstance3D = $Shadow
@onready var identity_label: Label3D = $IdentityLabel
@onready var focus_ring: MeshInstance3D = $FocusRing
@onready var signature_surge: SignatureSurge3D = $SignatureSurge3D

var player_id: int = -1
## Who this actor is, kept rather than spent.
##
## `configure` was handed a display name and put it straight into
## `identity_label.text`, formatted together with the position code, so the name
## survived only as part of a string meant for reading over the voli's head.
## Anything that wanted to *name* this actor -- the camera's follow list is the
## first thing that did -- had no way to ask, and asking anyway crashed the match
## view on open.
var voli_name: String = ""
var is_home_team: bool = true
## Which region's clubs this voli plays for, and therefore what they wear.
##
## Empty means "no region known", which is every probe, preview and portrait in
## the repository -- they keep the `UIPalette` colours they were drawn against.
## Only a match knows this, because only a match has two clubs in it.
var club_region: String = ""
var champion_region: String = ""
## Preview override for the three recorded kit passes. Gameplay leaves this at
## -1 and RegionalKits resolves the selected design.
var kit_design_attempt: int = -1
var tactical_position: Vector2 = Vector2.ZERO
var dominant_hand: String = "Right"
var height_cm: float = 188.0
var mass_kg: float = 82.0
var wingspan_cm: float = 191.0
var stride_length_m: float = 0.83
var body_type: String = "Vegi"
var produce: String = ""
var silhouette: Dictionary = {}
var shoulder_offset: Vector2 = Vector2(0.40, 1.52)
var hip_offset: Vector2 = Vector2(0.16, 0.48)
var body_height_scale: float = 1.0
var arm_length_scale: float = 1.0
## The authored torso scale after height/stride fitting. Pose deformation always
## starts here, so squash and extension do not accumulate from frame to frame.
var torso_rest_scale: Vector3 = Vector3.ONE
## Structural anchors after silhouette and physical-profile fitting. Attack
## performance rewrites them from these values every frame, never from the
## previous pose, so chest separation and squash/stretch cannot accumulate.
var torso_rest_position: Vector3 = Vector3.ZERO
var head_rest_position: Vector3 = Vector3.ZERO
## How long this voli's legs are for their height, from `stride_length_m`.
var leg_length_scale: float = 1.0
var leg_bone_lengths: Vector2 = Vector2(0.40, 0.34)
var arm_bone_lengths: Vector2 = Vector2(0.40, 0.48)
## How strained the contact the simulator resolved was. Not a visual choice:
## `_reception_pass_result` classifies every reception and dig as planted,
## moving, reaching or off-axis from the defender's reach margin, how far into
## the edge of their range the ball was, and how well their body could face it.
## Playback reads that verdict rather than inventing a pose.
var contact_posture: String = "planted"
## Where the forearms must point for the ball to leave the way it did, relative
## to this voli's own facing, from `PlatformAim`. Empty until playback supplies
## one, so a portfolio plate or a pose set by hand keeps the posture's own angle.
##
## The whole reason this is state rather than an argument: `set_pose` already
## carries seven parameters and the platform is not a property of the *pose*, it
## is a property of the *ball*. `contact_posture` and `contact_recovery` are
## carried the same way for the same reason.
var contact_platform_aim: Dictionary = {}
## What the contact *did* to them, as opposed to how strained it was.
## `_reception_recovery` decides this; playback draws it and does not invent it.
## "platform", "knee", "fall" or "blown_away" -- see `rally_simulator.gd`.
## The recovery and posture together choose the physical motion: an off-axis
## fall rolls sideways, a moving/reaching fall slides forward, and a blow-away
## rolls backward. The simulation still owns the cost and severity.
var contact_recovery: String = "platform"

## Block silhouette vocabulary: `two` is a clean sealed wall, `one` is a late
## reaching close, and `none` is a beaten/incomplete wall. These are descriptive
## presentation states supplied by the resolver, not a second block decision.
##
## Carried as state for the same reason `contact_posture` is -- the resolver
## decided it and the court's job is to hand that verdict over, not to form a
## second opinion from the positions. Derived upstream from the close fraction
## that already sets the wall's width, so a half-formed wall is now half-formed
## in the picture as well as in the contest.
var block_arms: StringName = &"two"
## What this voli stands like when they are not playing the ball -- "defending",
## "blocking" or "watching". See `ReadyStance`, which owns both the joints and
## the choice between them.
##
## Carried as state for the same reason `contact_posture` is: it is a property
## of the voli's *job on this rally*, not of the pose being drawn, and it has to
## survive `reset_player_poses()` -- which is exactly the call that leaves a body
## with nothing but a gait, and therefore the one this exists to answer.
##
## Defaulted to the crouch every body used to wear, so a portfolio plate or a
## unit test that names nothing is unchanged.
var ready_stance: String = "defending":
	set(value):
		## **A stance change is a movement, not an assignment.**
		##
		## `match_court_3d` writes this and `set_pose` read it fresh on the next
		## frame, so a middle dropping off the net went from hands-up at the tape
		## to a defender's crouch between two frames -- knees from -12 to -60 and
		## the arms from overhead to behind the hips, in 16 milliseconds. Nothing
		## tweened it because nothing held the previous one.
		##
		## The blend starts from wherever the body *currently* is rather than
		## from the stance being left, so a change of mind partway through a
		## change of stance continues from the pose on screen instead of
		## restarting from one nobody is in.
		if value == ready_stance:
			return
		_stance_from = _stance_joints(false)
		ready_stance = value
		_stance_duration = StanceTransitionScript.seconds_between(
			_stance_from, ReadyStance.joints(value)
		)
		_stance_remaining = _stance_duration
## Which of the five faces the actor is wearing. Purely presentational today --
## nothing in the simulator sets it yet -- so it stays a plain assignment rather
## than being derived from state that does not exist.
var expression: String = FaceExpressionsScript.NEUTRAL
## Generated nodes are static between configure/expression changes. These
## caches keep the per-frame pose path out of SceneTree.find_children().
var _cosmetic_cache: Array[MeshInstance3D] = []
var _face_feature_cache: Array[MeshInstance3D] = []
## Produce, colourway and coat, when somebody chose them rather than the id
## deciding. Empty means the hash, which is every generated voli.
var appearance: Dictionary = {}
## Kit or formal -- see `BodyTypeModels.GARMENT_KIT`.
var garment: String = BodyTypeModelsScript.GARMENT_KIT
var is_libero: bool = false
## Where the actor is currently facing, kept between frames so a change of
## heading can be turned into rather than snapped to.
var facing_yaw: float = 0.0
var has_facing: bool = false
## Where the head is looking, relative to where the body is facing. A voli can
## watch the ball without turning to it -- a defender tracking a set across the
## net keeps their platform pointed where they expect the attack, and a setter
## reads the block over their shoulder. Separating the two is what stops every
## actor being a mannequin that swivels as one piece.
var look_yaw: float = 0.0
var look_pitch: float = 0.0
## Ball attention arrives at the eyes before the mass of the head catches it.
## These are presentation targets only; simulation and body facing never read
## them. Action-specific safety poses (a dive chin tuck, for example) continue
## to write `look_yaw`/`look_pitch` directly and remain authoritative.
var _look_target_yaw: float = 0.0
var _look_target_pitch: float = 0.0
var _has_attention_target: bool = false
var stride_cycle: float = 0.0
var gait_blend: float = 0.0
## `VolleyballPlayer.stride_length_m` is metres per *step*: the locomotion
## identity is explicitly `metres per step x steps per second`, and approach
## distance multiplies the same value by a step count. `GaitBiomechanics.cycle`
## is a full right-left cycle. Advancing that cycle once per stored step doubled
## visible cadence and made the stance foot sweep roughly twice as far as the
## body. Two steps return to the same foot, so this conversion belongs at the
## sole playback seam rather than in either source model.
const STEPS_PER_GAIT_CYCLE: float = 2.0
## Where each foot was set down, in world space, and whether it is down at all.
## Index 0 is the left leg and 1 the right, matching `_PLANT_LEFT`/`_PLANT_RIGHT`.
##
## Only meaningful while the corresponding entry of `_plant_active` is true; a
## foot that has left the floor has no anchor rather than a stale one.
var _plant_anchor: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _plant_active: Array[bool] = [false, false]
## Whether the stance foot is held. Public and settable only so a probe can
## measure the same rig with and without it -- a claim about how much planting
## improved the slip is worthless if the two numbers came from two builds.
var foot_plant_enabled: bool = true
## The stance being eased out of, and how much of the ease is left.
var _stance_from: Dictionary = {}
var _stance_remaining: float = 0.0
var _stance_duration: float = 0.0
## The floor recovery that outlives the contact window. `_floor_joints` is the
## pose the body was left in on the last frame playback drew this voli as the
## contact actor; everything else is what that recovery was.
var _floor_joints: Dictionary = {}
var _floor_recovery: String = "platform"
var _floor_posture: String = "planted"
var _floor_direction: Vector2 = Vector2.ZERO
var _floor_remaining: float = 0.0
var _rig: Dictionary = {}
var _floor_duration: float = 0.0
## A short grounded handoff from the last authored contact pose into the gait.
## Landing, floor recovery and stance transitions already own their continuity;
## this state fills only the ordinary gap between those systems.
var _last_contact_joints: Dictionary = {}
var _last_contact_event: int = -1
var _last_contact_phase: float = -1.0
var _last_contact_performance: Dictionary = {}
var _last_pose_was_contact: bool = false
var _handoff_joints: Dictionary = {}
var _handoff_remaining: float = 0.0
var _handoff_duration: float = 0.0
## Which way this voli is travelling relative to the way they are facing, in
## radians: 0 straight ahead, PI a backpedal, plus or minus a right angle a
## lateral shuffle.
##
## **Travel direction and facing are two different things**, and the rig only had
## one of them. `set_tactical_position` turns a voli toward wherever they moved,
## so every journey was drawn as a forward run -- a defender opening to cover
## deep ran away from the ball with their back to it, and a passer sliding along
## the line rotated to face the sideline. Smoothed for the same reason the speed
## is: one frame of displacement is too noisy to pick a gait from.
var travel_heading_offset: float = 0.0
## Tiny frame displacements are accumulated until they contain one reliable
## centimetre of travel. Testing each frame against that centimetre made heading
## frame-rate dependent: a 1.1 m/s backpedal updates at 60 Hz and never updates
## at 144 Hz, so the body travelled backward with a forward gait.
var _heading_travel_accumulator: Vector3 = Vector3.ZERO
var locomotion_bob: float = 0.0
var has_world_position: bool = false
## How fast this voli is currently travelling, in metres per second, smoothed.
##
## Derived from the distance between successive placements rather than from the
## simulator, because playback interpolates positions and the smoothed rate of
## the drawn motion is what the gait has to match -- a gait driven by the
## simulator's own speed would be right about the player and wrong about the
## figure on screen.
var ground_speed_mps: float = 0.0
## The live horizontal direction of the body, in the same court-plane axes as
## tactical contact directions. SignatureSurge3D uses it only to place causal
## residue behind an action; it never feeds back into movement or simulation.
var action_movement_direction: Vector2 = Vector2.ZERO
var _signature_movement_frame: int = -1
## Whether this voli was off the floor on a previous frame, and what they were
## doing when they left it. A landing is *observed* rather than announced: the
## actor already sees elevation and event type every frame, so no caller has to
## learn to report a touchdown.
var _was_airborne: bool = false
var _airborne_action: String = "default"
## Seconds remaining in the current landing, counting down from the action's own
## duration. Zero means the voli is on their feet.
var _landing_remaining: float = 0.0
## Local presentation time for breathing, weight shift and blinking. It advances
## only while the actor is in the tree, and every resolver adds a stable player
## offset so a court of twelve bodies never moves in lockstep.
var _presentation_time_seconds: float = 0.0
## Whether the pose that just ran already put the feet on the floor itself, in
## which case `_ground_the_feet` must not do it a second time. Consumed on read.
var _feet_already_grounded: bool = false

## NOTE the ratio lives in body_type_models.gd because the trousers are cut to it
const THIGH_SHARE: float = BodyTypeModelsScript.THIGH_SHARE

## How far in front of the ankle the shoe sits, in rig units.
##
## Named rather than inlined because the stance solve needs it: a deeply folded
## knee swings the shoe's own forward offset sideways along with the shank, and
## leaving it out put a reaching dig's feet 12 percent wider than the stance it
## was asked for.
const SHOE_FORWARD_OFFSET: float = 0.06

## The pitch the shoe mesh is authored at in `player_actor_3d.tscn`.
##
## Stated here because the ankle adds to it: the mesh is modelled lying down and
## stood up by this rotation, so writing an ankle angle straight into
## `rotation_degrees.x` would lay the shoe flat on the floor rather than
## articulating it. Duplicating a scene value in code is a thing this repository
## has been burned by, so if the scene changes this is the line that has to
## change with it.
const SHOE_BASE_PITCH_DEGREES: float = 90.0

## Above this, a placement is the court re-seating a body rather than the body
## travelling. Comfortably above a sprint -- see the note in
## `set_tactical_position`.
const TELEPORT_SPEED_MPS: float = 12.0
const TELEPORT_METERS: float = 1.5

## ## Planting the stance foot
##
## The gait is distance-driven: `stride_cycle` advances by travelled distance
## divided by the step the drawn leg geometry can actually cover at this speed.
## A stored stride is one step, while this curve is a complete right-left cycle,
## so every cycle covers two of those geometry-derived steps. That keeps the
## visible turnover tied to the body crossing the floor instead of to frame time.
##
## Hip and knee arcs are still only an approximation of a planted kinematic
## chain, particularly in shuffles. A bounded planar correction pays the
## remaining fore-aft and lateral slip without replacing the contact overlays
## that make a dig, set, or attack legible.
##
## Applied to the hip and given back at the ankle, so the shin swings under a
## foot that stays where it was put and the sole stays flat while it does.
const PLANT_CORRECTION_LIMIT_DEGREES: float = 26.0
## The gait is rewritten from its base curve every frame before this correction
## is measured, so this is not an accumulated one-frame-late controller: a low
## gain simply leaves the same share of foot slip unpaid on every frame. Keep a
## little headroom for the one-degree local Jacobian, but spend most of the
## measured residual.
const PLANT_CORRECTION_GAIN: float = 0.90
const PLANT_JACOBIAN_SAMPLE_DEGREES: float = 1.0

const _PLANT_LEFT: int = 0
const _PLANT_RIGHT: int = 1

## How wide a joint ball is against the segments it joins. See the call sites in
## `_apply_physical_profile` for why these are under 1.0 and why they differ.
const JOINT_ARM: float = 0.94
const JOINT_LEG: float = 0.86

## What a manager wears, and the one colour on the court chosen to be nobody's.
##
## A slate the regional kits do not use: `RegionalKits` spends its range on
## saturated club hues, so a low-chroma cool grey reads as "not a strip" against
## every one of them without having to be checked against each. Trousers take the
## same colour darkened, the way the shorts take the shirt's -- one derivation,
## because two would be two things that can disagree.
const FORMAL_COLOR := Color("3c4250")

## How much darker the shorts are than the shirt.
##
## Named and shared rather than repeated, because two places deriving the same
## colour is two places that can drift -- and one of them did, the moment the
## short legs were added against the wrong key.
const SHORTS_DARKEN: float = 0.38


static func shorts_colour(team_color: Color) -> Color:
	return team_color.darkened(SHORTS_DARKEN)


## The club's contrast colour, for anything that has to be *seen against* the
## strip rather than be part of it -- construction marks, a collar, a sock top.
##
## Hoisted out of `_build_kit_marks`, which owned it privately, the moment a
## second garment needed the same answer. The alternative was a collar deriving
## its own contrast and drifting from the marks beside it.
func trim_colour() -> Color:
	return RegionalKitsScript.trim_colour(club_region) if is_home_team \
		else RegionalKitsScript.away_kit().darkened(0.42)


## How far a leg can swing out from under the hip, in degrees.
##
## Roughly what a squatting athlete has and well short of a gymnast's. It exists
## because the stance is asked for in metres and some widths are simply not
## available at some depths -- see `_stance_roll`.
const HIP_ABDUCTION_LIMIT_DEGREES: float = 42.0


## Upper-arm share of total arm length. Slightly under half, because the lower
## segment carries the hand as well as the forearm.
const UPPER_ARM_SHARE: float = BodyTypeModelsScript.UPPER_ARM_SHARE

## How bent a resting arm is. Deliberately not zero: nobody stands with their
## elbows locked, and straight arms are most of why the idle rig read as a
## mannequin. Small enough that it never competes with a pose that means
## something.
const READY_ELBOW_BEND: float = 17.0

## How far a head turns off the body before the body has to come with it. A neck
## does not reach ninety degrees, and a head that does reads as broken rather
## than as attentive -- so the look is clamped rather than the target being
## assumed reachable.
const HEAD_YAW_LIMIT_DEGREES: float = 62.0
const HEAD_PITCH_LIMIT_DEGREES: float = 24.0

## How fast a player can turn, in radians per second.
##
## Facing used to be assigned outright every frame, so a player pivoted through
## any angle in one frame the instant their heading changed. That reads as a
## teleport even when the position between two points is interpolating perfectly
## -- the body arrives smoothly and the *orientation* jumps -- and it is the
## cheaper half of what "teleporting" looks like on the court.
##
## About two turns a second at full rate. Fast enough that a defender squaring
## up to a ball never looks sluggish, slow enough that the turn is visible.
const FACING_TURN_RATE: float = 12.0
## How far the head will lead before the body comes round with it.
##
## Not `HEAD_YAW_LIMIT_DEGREES`. That is where the neck *runs out*, and a body
## that only turns at the limit would hold every glance at a hard 62 degrees
## before snapping round. This is where a look stops being comfortable, which is
## where a person actually starts to turn.
const NECK_LEAD_DEGREES: float = 38.0
## Past this, a turn is made of steps rather than of rotation.
##
## A body pivots a little way on the balls of its feet and no further; anything
## steeper reorders the feet, and drawing it as a continuous sweep is the same
## defect as gliding across the floor without stepping. Reported as pivoting
## smoothly to look around where a head turn, a torso rotation and a step
## belong.
const STEP_TURN_DEGREES: float = 55.0
## How long one turning step takes, and what share of it is spent rotating. The
## remainder is the foot arriving and the body standing on it, which is the half
## that makes a step read as a step -- the same shape the locomotion quantiser
## uses for travel.
const TURN_STEP_SECONDS: float = 0.26
const TURN_STEP_DUTY: float = 0.6

## Where in the current turning step this body is, 0 to 1. Held across frames
## because a step is a thing that takes time, not a thing a frame can decide.
var _turn_step_phase: float = 0.0

## How far a player has to actually move before their travel sets their heading.
##
## A centimetre accumulated across however many frames it takes. Below that,
## displacement direction is mostly rounding noise; applying the threshold to
## each frame made the answer change with refresh rate.
const TRAVEL_HEADING_FLOOR_METERS: float = 0.01
## How far off their facing a voli will travel before they turn to run. Inside
## it they shuffle or backpedal with their eyes where they were.
## NOTE sixty, not ninety -- at ninety the lateral bound could never fire, and
## the perpendicular case is the one it was written for -- MOVING_ORIENTATION.md
const OPEN_UP_CONE_RADIANS: float = PI / 3.0
## And the speed past which nobody shuffles, whatever the angle. `GaitBiomechanics`
## puts a run at 4.4 m/s; this sits below it, because the last stride before a
## genuine run is already too quick to keep square.
const OPEN_UP_SPEED_MPS: float = 3.6
## And the same bound for movement that is purely sideways. Above
## `GaitBiomechanics.RUN_SPEED_MPS`, so a blocker shuffling the width of the net
## stays square through the whole journey and only a genuine sprint opens them
## up. This is the number that makes a middle look like a middle.
const LATERAL_OPEN_UP_SPEED_MPS: float = 5.4
## How quickly the drawn travel heading catches up to the real one. Smoothed for
## the same reason ground speed is: a single frame's displacement direction is
## mostly rounding, and a gait that switched between shuffle and run on it would
## strobe.
const TRAVEL_HEADING_SMOOTHING: float = 0.28

const REFERENCE_HEIGHT_CM: float = 188.0
const REFERENCE_WINGSPAN_CM: float = 191.0
## Every silhouette is normalised to the 1.88 m reference before individual
## height applies.
## NOTE was one shared 0.93 constant, which made a 2.16 m Avi oversized against
## the net rather than merely tall
const REFERENCE_RIG_HEIGHT_M: float = 2.02


func configure(
	p_player_id: int,
	home_team: bool,
	display_name: String,
	p_dominant_hand: String = "Right",
	physical_profile: Dictionary = {},
) -> void:
	_ensure_node_bindings()
	look_yaw = 0.0
	look_pitch = 0.0
	_look_target_yaw = 0.0
	_look_target_pitch = 0.0
	_has_attention_target = false
	_handoff_remaining = 0.0
	_last_pose_was_contact = false
	player_id = p_player_id
	voli_name = display_name
	is_home_team = home_team
	dominant_hand = "Left" if p_dominant_hand == "Left" else "Right"
	body_type = str(physical_profile.get("body_type", "Vegi"))
	## NOTE overrides the id-derived produce, colourway and coat; a caller that
	## names nothing keeps the hash
	appearance = Dictionary(physical_profile.get("appearance", {}))
	## NOTE the profile carries what the view needs and the id cannot supply,
	## which is why a club strip rides here rather than as a sixth argument
	club_region = str(physical_profile.get("club_region", ""))
	## **Which garment class this voli wears.** A kit was the only clothing that
	## existed, so a manager -- who is attached to a club without being one of its
	## players -- got dressed as one. Defaulted to kit so every roster caller is
	## unchanged; only somebody who is not playing has to say so.
	garment = BodyTypeModelsScript.GARMENT_FORMAL \
		if str(physical_profile.get("garment", "")) \
			== BodyTypeModelsScript.GARMENT_FORMAL \
		else BodyTypeModelsScript.GARMENT_KIT
	## The libero wears a contrasting shirt, which the rules demand and the away
	## strip already is -- one rule, no second garment. Read from the role rather
	## than from the shirt number, because the number is a rotation fact and the
	## role is the one the kit follows.
	is_libero = str(physical_profile.get("position_role", "")) == "Libero"
	## Who last won the Sixnet, for the one region whose strip is a pointer
	## rather than a pattern. Rides the same dictionary as `club_region` and
	## for the same reason: it is something the view needs in order to draw
	## this voli that the id cannot tell it.
	champion_region = str(physical_profile.get("champion_region", ""))
	kit_design_attempt = clampi(int(physical_profile.get("kit_design_attempt", -1)), -1, 2)
	## Before the build, not after it. `_build_silhouette` draws the face, so
	## setting the expression afterwards would build nine boxes twice on every
	## voli on the court to change the second set.
	var chosen_face := str(physical_profile.get("expression", ""))
	if FaceExpressionsScript.has(chosen_face):
		expression = chosen_face
	_build_silhouette()
	_apply_physical_profile(physical_profile)
	torso_rest_scale = torso.scale
	torso_rest_position = torso.position
	head_rest_position = head.position
	## Name and position. It used to read `name · 200 cm · R`, which spent both
	## its fields on things the body already shows -- height in how tall the rig
	## is drawn, handedness in which arm swings -- and never said who this voli
	## is in the rotation. Position is the one thing the picture cannot tell you.
	var position_code := str(physical_profile.get("position_code", ""))
	identity_label.text = "%s · %s" % [display_name, position_code] \
		if not position_code.is_empty() else display_name
	identity_label.modulate = Color("f8f2d8")
	identity_label.visible = false
	apply_ui_palette(false)
	set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
	_refresh_surface_marks()


## Reset presentation-only state without rebuilding meshes, materials, faces or
## surface marks. Used when the same roster begins another rally.
func reset_for_rally(position: Vector2, world_position: Vector3) -> void:
	has_world_position = false
	ground_speed_mps = 0.0
	gait_blend = 0.0
	stride_cycle = 0.0
	_heading_travel_accumulator = Vector3.ZERO
	_landing_remaining = 0.0
	_floor_remaining = 0.0
	_handoff_remaining = 0.0
	_last_pose_was_contact = false
	contact_posture = "planted"
	contact_recovery = "platform"
	contact_platform_aim.clear()
	hide_cognition_cue()
	clear_look()
	set_tactical_position(position, world_position)
	set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)


## The match already draws a stable blob shadow under every voli. Avoid making
## the full articulated mesh a second animated shadow caster as well.
func set_realtime_shadows_enabled(enabled: bool) -> void:
	var setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null:
			mesh.cast_shadow = setting


func _refresh_surface_marks() -> void:
	var renderer := get_node_or_null("SurfaceMarkRenderer3D")
	if renderer != null and renderer.has_method("refresh"):
		renderer.call("refresh")


## The centre of the forearm surface that a reception or dig is visibly played
## from, read from the posed rig itself. Body types do not share arm proportions
## (the modelled spread is about twenty centimetres), so callers must not replace
## this with a universal reach constant.
func platform_contact_world_position() -> Vector3:
	_ensure_node_bindings()
	return (_hand_world_position(left_arm) + _hand_world_position(right_arm)) * 0.5


## The ball-centre anchor for a contact, read after the real action pose has
## written every shoulder and elbow. There is deliberately no reach table here:
## silhouette, height, wingspan, handedness, posture, facing and phase have
## already changed these node transforms by the time this is called.
func contact_anchor_world_position(
	event_type: int, action_context: Dictionary = {}
) -> Vector3:
	_ensure_node_bindings()
	var left_hand := _hand_world_position(left_arm)
	var right_hand := _hand_world_position(right_arm)
	match event_type:
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DIG, RallyEventModel.EventType.ATTACK_COVERAGE:
			return (left_hand + right_hand) * 0.5
		RallyEventModel.EventType.SET:
			if str(action_context.get("set_posture_reason", "")) \
					== "under the hands":
				return (left_hand + right_hand) * 0.5
			return (left_hand + right_hand) * 0.5
		RallyEventModel.EventType.SERVE, RallyEventModel.EventType.ATTACK:
			return left_hand if dominant_hand == "Left" else right_hand
		RallyEventModel.EventType.BLOCK:
			if block_arms == &"left":
				return left_hand
			if block_arms == &"right":
				return right_hand
			return (left_hand + right_hand) * 0.5
	return global_position


func _hand_world_position(arm: Node3D) -> Vector3:
	if arm == null:
		return global_position
	var elbow := arm.get_node_or_null("Elbow") as Node3D
	if elbow == null:
		return arm.global_position
	## The wrist is seated at the exact endpoint the legacy inferred chain used.
	## Its local rotation may turn the palm, but its origin preserves reach.
	var wrist := elbow.get_node_or_null("Wrist") as Node3D
	if wrist != null:
		return wrist.global_position
	var forearm_length := arm_bone_lengths.y * arm_length_scale
	return elbow.global_transform * Vector3(0.0, -forearm_length, 0.0)


## Raise or lower the joined forearms until their real rendered surface reaches
## the ball's authoritative contact height. This is solved against node
## transforms, not a silhouette table: the six models have different shoulders,
## arms and scale, and the numerical slope automatically includes all of them.
func fit_platform_contact_height(target_height_meters: float) -> void:
	fit_contact_anchor_height(
		RallyEventModel.EventType.RECEPTION, target_height_meters, {}
	)


## Fit the relevant posed limb endpoints to the simulator's contact height.
## This solves the rig already on screen; it does not alter the ball, event
## time, jump height or body destination. Horizontal placement is measured only
## after this fit, because changing an arm angle changes both height and reach.
func fit_contact_anchor_height(
	event_type: int,
	target_height_meters: float,
	action_context: Dictionary = {},
) -> void:
	_ensure_node_bindings()
	var arms: Array[Node3D] = []
	match event_type:
		RallyEventModel.EventType.SERVE, RallyEventModel.EventType.ATTACK:
			arms.append(left_arm if dominant_hand == "Left" else right_arm)
		RallyEventModel.EventType.BLOCK:
			if block_arms != &"right":
				arms.append(left_arm)
			if block_arms != &"left":
				arms.append(right_arm)
		_:
			arms.assign([left_arm, right_arm])
	if arms.is_empty():
		return
	var platform_contact := event_type in [
		RallyEventModel.EventType.RECEPTION,
		RallyEventModel.EventType.DIG,
		RallyEventModel.EventType.ATTACK_COVERAGE,
	] or event_type == RallyEventModel.EventType.SET \
		and str(action_context.get("set_posture_reason", "")) == "under the hands"
	var joints: Array[Node3D] = []
	for arm in arms:
		joints.append(arm)
		if not platform_contact:
			var elbow := arm.get_node_or_null("Elbow") as Node3D
			if elbow != null:
				joints.append(elbow)
	for _iteration in 8:
		var current := contact_anchor_world_position(event_type, action_context)
		var error := target_height_meters - current.y
		if absf(error) < 0.001:
			return
		const PROBE_DEGREES: float = 0.5
		var slopes: Array[float] = []
		var slope_squared := 0.0
		for joint in joints:
			var before := joint.rotation_degrees
			joint.rotation_degrees.x += PROBE_DEGREES
			var slope := (
				contact_anchor_world_position(event_type, action_context).y - current.y
			) / PROBE_DEGREES
			joint.rotation_degrees = before
			slopes.append(slope)
			slope_squared += slope * slope
		if slope_squared < 0.00000001:
			return
		for index in range(joints.size()):
			var correction := clampf(
				error * slopes[index] / slope_squared, -18.0, 18.0
			)
			joints[index].rotation_degrees.x += correction
	## A few authored silhouettes have a shorter drawable arm chain than the
	## simulation reach carried by the same physical profile. Once the relevant
	## joints have reached their closest pose, translate the posed body by the
	## exact residual. This is still derived body placement around a fixed ball,
	## not a second contact height; it is most often the airborne part of a jump
	## and remains measurable on grounded sets in the anchor probe.
	var residual := target_height_meters - contact_anchor_world_position(
		event_type, action_context
	).y
	body_pivot.position.y += residual


## Every mesh in the rig, and the subset the arms are made of.
##
## Exposed so a caller can paint the whole body one colour and the arms another
## and read the result back as a mask. The tactic sheet needs that because an arm
## traced as part of one silhouette disappears the moment it crosses the torso --
## and a pose is mostly arms, so a figure whose arms have no edge is a figure
## whose pose cannot be read.
##
## Enumerated rather than walked, because "every MeshInstance3D under here"
## would also collect the shadow quad, the focus ring and the face features, and
## two of those are not the body.
func body_meshes() -> Array[MeshInstance3D]:
	_ensure_node_bindings()
	var out: Array[MeshInstance3D] = [torso, head]
	out.append_array(arm_meshes())
	for leg in [left_leg, right_leg]:
		for path in ["Mesh", "Joint", "Knee/Mesh", "Knee/Joint", "Knee/Shoe"]:
			var mesh := leg.get_node_or_null(path) as MeshInstance3D
			if mesh != null:
				out.append(mesh)
	for feature in _face_features():
		if feature is MeshInstance3D:
			out.append(feature as MeshInstance3D)
	for cosmetic in _cosmetics():
		if cosmetic is MeshInstance3D:
			out.append(cosmetic as MeshInstance3D)
	return out


func arm_meshes() -> Array[MeshInstance3D]:
	_ensure_node_bindings()
	var out: Array[MeshInstance3D] = []
	for arm in [left_arm, right_arm]:
		for path in [
			"Mesh", "Joint", "Elbow/Mesh", "Elbow/Joint", "Elbow/Wrist/Palm"
		]:
			var mesh := arm.get_node_or_null(path) as MeshInstance3D
			if mesh != null:
				out.append(mesh)
	return out


## Paint every mesh flat, for a mask pass. `apply_ui_palette` puts it all back.
func paint_flat(meshes: Array[MeshInstance3D], color: Color) -> void:
	for mesh in meshes:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		## **The line goes with the part it belongs to.**
		##
		## The mask pass paints the body black and the arms white and reads the
		## result back. An ink twin is a child of the mesh it outlines and is not
		## in either list, so left alone it would stay dark over a white arm and
		## eat the edge of the very region being measured. Painting it the same
		## colour means an arm's mask includes its own line, which is what the
		## trace should see -- the line is part of the arm, not a thing lying on
		## top of it.
		var ink := mesh.get_node_or_null("Ink") as MeshInstance3D
		if ink != null:
			var ink_material := StandardMaterial3D.new()
			ink_material.albedo_color = color
			ink_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ink_material.cull_mode = BaseMaterial3D.CULL_FRONT
			ink_material.grow = true
			ink_material.grow_amount = _ink_weight_for(mesh)
			ink.material_override = ink_material
	_refresh_surface_marks()


## How heavy a line this mesh takes.
##
## **The body models already say, and nothing was reading it.** Nine parts are
## authored `"ink": "body"` in `body_type_models.gd` -- every muzzle, the nose,
## the crown -- and it reaches the node as metadata. The weight was chosen from
## `INK_BODY_PARTS` instead, a list of *names*, and not one authored part name is
## in it. So every part that declared itself body took the 0.030 m cosmetic line.
##
## Measured before changing: `tools/body_ink_weight.tscn` reports the nose at
## 0.042 to 0.064 m across against a 0.030 m hull each side -- ratio 0.71 on
## Simi, 0.92 on Cani, 0.96 on Feli. Majority outline, which is the same
## arithmetic that made a Feli eye 0.053 m wide render at 0.113 m and produce the
## speckle the face pass removed.
##
## The name list stays as the fallback, because it is right about the parts it
## names and its own comment explains why it is a closed set. This only stops it
## overriding a part that stated its own weight.
static func _ink_weight_for(mesh: MeshInstance3D) -> float:
	if str(mesh.get_meta("ink", "")) == "body":
		return ink_metres
	return ink_metres if str(mesh.name) in INK_BODY_PARTS else crown_ink_metres


func apply_ui_palette(light_mode: bool) -> void:
	_ensure_node_bindings()
	## The cogniticon's drawn marks are rasterised in one of two inks and have to
	## be told which. Passed on here rather than looked up there, because
	## `UIPalette` is a table and not a state -- see the note on the billboard.
	if cognition_billboard != null:
		cognition_billboard.light_mode = light_mode
	## **A club's strip, where there used to be one of two colours for the whole
	## world.** `UIPalette` is keyed on `is_home_team` and nothing else, so every
	## club in every region wore the same teal or the same coral -- fourteen
	## regional identities, and a match showed none of them. A region overrides
	## it; no region keeps it, which is what every probe, preview and portrait in
	## the repository relies on.
	##
	## The kit does not follow the theme. `Mikasa` and `Molten` are the *desk's*
	## two moods and a club does not change shirt between them; the strips were
	## measured against the floor, not against the interface.
	var team_color := UIPalette.color(
		&"accent_alt" if is_home_team else &"danger", light_mode
	)
	if not club_region.is_empty():
		team_color = RegionalKitsScript.kit_for(club_region) if is_home_team \
			else RegionalKitsScript.away_kit()
	## The libero, in the one hue on the court that is already guaranteed to
	## contrast with the home strip. The rules want a shirt a referee can pick
	## out; the away kit is that shirt and it exists, so this costs one line
	## rather than a seventh cut.
	if is_libero and is_home_team:
		team_color = RegionalKitsScript.away_kit()
	## **A manager is not wearing a strip.** Formal dress is a neutral that is
	## deliberately not the club's hue: a manager is attached to a club without
	## being one of its players, and dressing them in its colour is the category
	## error a viewer reads instantly. The club appears on them as a mark, which
	## `_build_kit_marks` still places, rather than as the garment.
	if garment == BodyTypeModelsScript.GARMENT_FORMAL:
		team_color = FORMAL_COLOR
	var accent_color := UIPalette.color(
		&"accent" if is_home_team else &"ink", light_mode
	)
	## A Vegi's body is the produce, so painting the torso in team colours would
	## paint over the whole player. Those silhouettes wear their kit as a
	## separate band and keep their skin here; the others wear the torso.
	var skin_color: Color = silhouette.get("skin", Color("d6a06c"))
	var crown_color: Color = silhouette.get("crown", skin_color.lightened(0.3))
	var wears_kit := str(silhouette.get("torso_material", "kit")) == "kit"
	## Hoisted above both limb loops: the shoulder and the hip are dressed in
	## separate scopes and one of them cannot see the other's locals.
	##
	## **Two facts, and this flag used to be both.** `wears_kit` says whether the
	## *torso* is the strip's colour, which a produce's never is because the
	## produce is the body. `dressed` says whether this voli is wearing garments
	## at all -- and every body is, because `_add_garments` runs for all six and
	## a produce now has a singlet cut to its own profile. Conflating them left a
	## Vegi with sleeves, shorts and trousers hanging off skin-coloured shoulder,
	## hip and knee joints: the joints a garment covers, left bare.
	var dressed := BodyTypeModelsScript.draw_garments
	_apply_material_color(torso, team_color if wears_kit else skin_color)
	_build_kit_marks(wears_kit)
	_apply_material_color(head, skin_color)
	for arm in [left_arm, right_arm]:
		## Two bones, as the legs have been since the knee.
		_apply_material_color(arm.get_node("Mesh"), skin_color)
		_apply_material_color(arm.get_node("Elbow/Mesh"), skin_color)
		var palm := arm.get_node_or_null("Elbow/Wrist/Palm") as MeshInstance3D
		if palm != null:
			_apply_material_color(palm, skin_color)
		## The joints are skin too. Left out of this list they kept the default
		## grey and turned every shoulder and elbow into a bead -- a worse read
		## than the gap they were added to close.
		## The shoulder is the **cap of the sleeve** and the hip is the **seat of
		## the shorts**; neither is skin on a dressed voli.
		##
		## The sleeve is a cylinder ending on a flat plane and the shoulder ball
		## is a sphere sitting proud of it -- measured, the ball's top reached
		## 1.561 against a sleeve ending at 1.545, so 16 mm of bare skin capped
		## every shoulder. The hip ball is the same problem at the other end: it
		## sits at 0.636 to 0.902, in the gap between the shirt's hem and the leg
		## opening, and left as skin it is the bare patch that read as the torso
		## extruding out of the shorts from behind.
		##
		## Lengthening the sleeve past the ball would have hidden the skin and
		## left a cut tube where a shoulder should be round. Colouring it gives a
		## set-in sleeve with a domed cap, which is what the seam on a singlet
		## does -- and it is decided here, with every other colour, rather than
		## inside `_joint_ball`, which builds geometry and has no business
		## knowing what a club wears.
		_paint_joint(arm, team_color if dressed else skin_color)
		_paint_joint(arm.get_node("Elbow"), skin_color)
	for leg in [left_leg, right_leg]:
		## Two bones and a shoe. The shoe hangs off the knee now, not the hip.
		_apply_material_color(leg.get_node("Mesh"), skin_color)
		_apply_material_color(leg.get_node("Knee/Mesh"), skin_color)
		_paint_joint(
			leg, shorts_colour(team_color) if dressed else skin_color
		)
		## **The knee is inside the trouser and outside the shorts.**
		##
		## The same rule the hip already follows, one joint down: a garment that
		## crosses a joint has to include it, or the ball between its two halves
		## is a patch of bare skin where the leg bends. Shorts end above the knee,
		## so on a kit this stays skin and always did -- which is why the question
		## only arrived with the trouser.
		_paint_joint(
			leg.get_node("Knee"),
			shorts_colour(team_color) if dressed
				and garment == BodyTypeModelsScript.GARMENT_FORMAL
			else skin_color
		)
		_apply_material_color(leg.get_node("Knee/Shoe"), team_color.darkened(0.55))
	## A face has to read on a pale turnip and on a near-black aubergine, so the
	## colour is chosen against the skin's luminance rather than being one ink
	## that happens to suit the first body type tried.
	var face_color := Color("18131f") if skin_color.get_luminance() > 0.30 \
		else Color("f6eddc")
	## The pupil takes the other one. Both inks already exist and one of them is
	## always the wrong choice for this skin -- which is exactly what makes it the
	## right choice for a mark that has to read *against* the eye. No third colour
	## to check against six skins and fourteen strips.
	var pupil_color := Color("f6eddc") if face_color == Color("18131f") \
		else Color("18131f")
	for feature in _face_features():
		_apply_material_color(
			feature,
			pupil_color if str(feature.name).begins_with("Pupil") else face_color,
		)
	for cosmetic in _cosmetics():
		var part_alpha := float(cosmetic.get_meta("alpha", 1.0))
		match str(cosmetic.get_meta("color_key", "skin")):
			"kit":
				_apply_material_color(cosmetic, team_color, part_alpha)
			## The shorts are a *darker* member of the club's strip, and anything
			## that is part of them has to say so through the same expression the
			## shorts themselves use. The short legs were built with the `kit` key
			## and came out in the shirt's colour, which inverted the garment: the
			## real shorts read as a dark panel on the torso and the leg openings
			## read as the shorts. One key, one derivation, no second opinion.
			"shorts":
				_apply_material_color(
					cosmetic, shorts_colour(team_color), part_alpha
				)
			## A formal shirt and its trousers. Two keys rather than reusing
			## `kit`/`shorts` because those derive from the club's strip, and the
			## whole point of formal dress is that it does not.
			"formal":
				_apply_material_color(cosmetic, FORMAL_COLOR, part_alpha)
			## Through `shorts_colour`, not a second darkening of its own. The two
			## were 0.38 and 0.34, which is invisible on a trouser leg and a band
			## at the knee -- the joint takes this colour too, and a joint that is
			## nearly the trouser is worse than one that is obviously not.
			"formal_dark":
				_apply_material_color(
					cosmetic, shorts_colour(FORMAL_COLOR), part_alpha
				)
			"trim":
				_apply_material_color(cosmetic, trim_colour(), part_alpha)
			"crown":
				_apply_material_color(cosmetic, crown_color, part_alpha)
			"literal":
				_apply_material_color(
					cosmetic, cosmetic.get_meta("color_value"), part_alpha
				)
			_:
				_apply_material_color(cosmetic, skin_color, part_alpha)
	_apply_material_color(focus_ring, accent_color)
	_refresh_surface_marks()


## Place this body, and take its motion from whoever solved the leg.
##
## `motion` carries `{velocity, facing}` in court units off the resolver's
## authoritative path. When it is present the gait runs on the solved speed and
## the body turns onto the solved heading, and the reconstruction below is
## skipped entirely -- it exists to recover from successive placements what the
## simulation already knew and could not previously hand over.
##
## Empty for any leg not yet migrated, which keeps the derivation.
func set_tactical_position(
	position: Vector2, world_position: Vector3, motion: Dictionary = {}
) -> void:
	_ensure_node_bindings()
	var supplied_velocity: Vector2 = Vector2(motion.get("velocity", Vector2.ZERO)) \
		if motion.has("velocity") else Vector2.ZERO
	var supplied_facing: Vector2 = Vector2(motion.get("facing", Vector2.ZERO)) \
		if motion.has("facing") else Vector2.ZERO
	var has_supplied_motion := motion.has("velocity")
	if has_world_position:
		var world_delta := world_position - self.position
		var travelled := Vector2(
			world_delta.x, world_delta.z,
		).length()
		if travelled > 0.0001:
			_heading_travel_accumulator += world_delta
			action_movement_direction = Vector2(
				world_delta.x, world_delta.z
			).normalized()
			_signature_movement_frame = Engine.get_process_frames()
			if signature_surge != null:
				signature_surge.action_direction = action_movement_direction
		else:
			_heading_travel_accumulator = Vector3.ZERO
		## Speed, smoothed, before anything reads it.
		##
		## A single frame's displacement is far too noisy to drive a gait -- one
		## long frame would flip a walker into a sprint and back. The smoothing is
		## asymmetric on purpose: quick to pick speed up and slower to let it go,
		## so a player who is genuinely accelerating gets their run immediately
		## and one who stops decelerates out of it over a step rather than
		## freezing mid-stride.
		var frame_time := maxf(get_process_delta_time(), 0.0001)
		var instant_speed := travelled / frame_time
		## **A re-anchor is not a step.**
		##
		## `travelled` is raw displacement between two placements, and not every
		## placement is motion: seeking the timeline, starting a rally and the
		## court re-seating everyone between exchanges all move a body several
		## metres in one frame. Fed to the gait as travel, that spins
		## `stride_cycle` by the whole jump -- ten strides in a frame -- and hands
		## the smoother a speed no human reaches.
		##
		## It has been invisible because the cycle is periodic and a random phase
		## looks like any other phase. It stops being invisible the moment a foot
		## is planted, because then the cycle carries a world position with it and
		## a jumped phase is a foot that teleports out from under the body.
		##
		## **Two conditions, because either alone is wrong.**
		##
		## A speed bound on its own says nothing when the frame is short: at 240
		## frames a second a genuine sprint and a re-anchor are both "fast", and a
		## probe driving the rig as fast as it can hits that immediately. A
		## distance bound on its own drifts with frame rate: a metre in a frame is
		## a teleport at 60 and a slow jog at 4.
		##
		## Together they are unambiguous. 12 m/s is well past a sprint, 1.5 m is
		## far more than anything covers in a frame at any rate this game runs at,
		## and a placement that clears both is the court putting somebody down
		## rather than somebody running.
		if instant_speed > TELEPORT_SPEED_MPS \
				and travelled > TELEPORT_METERS:
			_plant_active[_PLANT_LEFT] = false
			_plant_active[_PLANT_RIGHT] = false
			ground_speed_mps = 0.0
			_heading_travel_accumulator = Vector3.ZERO
			action_movement_direction = Vector2.ZERO
			_signature_movement_frame = -1
			has_world_position = true
			tactical_position = position
			## Still moved. Skipping this is a body that never arrives where it
			## was put and reads the same jump again on the next frame, forever --
			## which is what the first version of this guard did.
			self.position = world_position
			return
		if has_supplied_motion:
			## The solved speed, unsmoothed. Smoothing exists to hide the noise in
			## a per-frame difference; a sampled velocity has none to hide.
			ground_speed_mps = RallyKinematicsScript.court_delta_meters(
				Vector2.ZERO, supplied_velocity
			).length()
		else:
			var smoothing := 0.45 if instant_speed > ground_speed_mps else 0.18
			ground_speed_mps = lerpf(ground_speed_mps, instant_speed, smoothing)
		## Face where you are going -- but only when you are going somewhere.
		## NOTE accumulated, so the centimetre floor stays above the noise without
		## making slow movement at a high refresh rate directionless
		var heading_distance := Vector2(
			_heading_travel_accumulator.x, _heading_travel_accumulator.z
		).length()
		var supplied_heading := Vector2.ZERO
		if has_supplied_motion and supplied_facing.length_squared() > 0.000001:
			## Court units are not world units -- the court is 9 m across and 18 m
			## long -- so a court-space direction has to be scaled before it is an
			## angle. `court_delta_meters` is the same conversion the resolver
			## measures every distance with.
			supplied_heading = RallyKinematicsScript.court_delta_meters(
				Vector2.ZERO, supplied_facing
			)
		if supplied_heading.length_squared() > 0.000001 \
				or heading_distance > TRAVEL_HEADING_FLOOR_METERS:
			## Rate-limited by the contact turn speed, so a player rounding a
			## corner leans rather than snaps.
			## NOTE `set_pose` applies the contact actor's facing afterwards and
			## still wins -- playing the ball beats footwork
			##
			## The solved leg supplies this heading when it has one. It is the
			## direction of *travel*, not the body's chosen facing -- whether the
			## body turns onto it is still `should_open_up`'s decision below, which
			## is what lets a voli shuffle or backpedal with their eyes on the ball.
			var travel_yaw := atan2(
				-supplied_heading.x, -supplied_heading.y
			) if supplied_heading.length_squared() > 0.000001 else atan2(
				-_heading_travel_accumulator.x,
				-_heading_travel_accumulator.z,
			)
			_heading_travel_accumulator = Vector3.ZERO
			## Measured before the turn below, because afterwards the two agree
			## by construction and the answer is always "forwards".
			travel_heading_offset = lerp_angle(
				travel_heading_offset,
				angle_difference(facing_yaw, travel_yaw),
				TRAVEL_HEADING_SMOOTHING,
			)
			## NOTE moving without turning is the default; `should_open_up` owns
			## the rule and the constants above own its measurements
			if should_open_up(
				facing_yaw, travel_yaw, ground_speed_mps, travel_heading_offset
			):
				_turn_toward(travel_yaw)
		## Clock the step after reading this leg's heading. Doing it before the
		## heading update gave an abrupt shuffle/backpedal one frame of forward-
		## gait distance while its joints were already drawing the new direction.
		if travelled > 0.0001:
			var leg_span := (
				leg_bone_lengths.x + leg_bone_lengths.y
			) * leg_length_scale * body_height_scale
			var drawn_step := GaitBiomechanicsScript.geometric_step_meters(
				leg_span, ground_speed_mps, travel_heading_offset
			)
			stride_cycle += travelled / maxf(
				drawn_step * STEPS_PER_GAIT_CYCLE, 0.36
			)
	has_world_position = true
	tactical_position = position
	self.position = world_position


## Whether a voli travelling this way has to turn and run, or can hold their
## facing and move anyway.
##
## Static and pure, so the suite can call it without building a court.
##
## Inside the cone the travel *is* the facing, so turning onto it is free.
## Otherwise speed forces the issue: you can shuffle and you cannot shuffle
## quickly, and sideways buys a higher bound than backwards because a blocker
## along the net never turns their back on it.
static func should_open_up(
	facing_yaw: float,
	travel_yaw: float,
	speed_mps: float,
	heading_offset: float,
	## An approach is a run at the net, and a person faces where they run.
	## NOTE exempt from the cone and the speed bound rather than given wider
	## ones -- those exist to protect a defender watching the ball
	is_approach: bool = false,
) -> bool:
	if is_approach:
		return true
	var lateral_share := absf(sin(heading_offset))
	var open_up_speed := lerpf(
		OPEN_UP_SPEED_MPS, LATERAL_OPEN_UP_SPEED_MPS, lateral_share
	)
	return absf(angle_difference(facing_yaw, travel_yaw)) <= OPEN_UP_CONE_RADIANS \
		or speed_mps >= open_up_speed


## Turn the body toward the ball, which is what a voli does when nothing else is
## asking anything of them.
##
## **The default facing has to come from somewhere.** `_turn_toward` is called
## from exactly two other places -- the open-up rule, which only fires when a
## voli is genuinely sprinting, and a contact pose. A voli who neither sprints
## nor touches the ball therefore never acquired a heading at all: `has_facing`
## stayed false and the body held the rig's default orientation, so a whole side
## faced the same arbitrary direction regardless of where the play was.
##
## That was the vacuum left by deleting the court's unconditional `face_travel`.
## Deleting it was right -- facing is not travel -- but the answer to "then what
## is it" is not "nothing". It is the ball, which is the thing a volleyball
## player looks at whenever they are not doing something more specific.
##
## Rate-limited like every other turn, and applied *before* the movement plan
## each frame, so the open-up rule still wins for a defender who has to turn and
## run. That ordering is the whole model: face the ball, shuffle and backpedal
## while you can, open up only when the distance forces it.
func face_ball(world_yaw: float) -> void:
	_turn_toward(world_yaw)


## **A turn is a head, then a torso, then a step.**
##
## This used to rotate the whole body toward the target at one constant rate,
## which is why looking around read as a glide: a 30-degree glance swung the
## shoulders 30 degrees, and a 120-degree turn swung them 120 without the feet
## ever moving. Three things were missing and they arrive in order.
##
## The head goes first and often goes alone. `look_toward` already aims it and
## already clamps it, so the body's job is not to point where the head is
## looking -- it is to bring the head back inside a comfortable range when the
## neck has run out of lead. A glance costs the shoulders nothing.
##
## Then the torso, at the rate it always turned at.
##
## Then the feet. Past `STEP_TURN_DEGREES` a body cannot pivot in place, so the
## rotation is spent in steps: it turns through `TURN_STEP_DUTY` of each step
## and stands still for the rest. The rate is divided by the duty so the average
## speed of a steep turn is unchanged -- this makes a turn *look* like steps
## without making it slower, which is the difference between a fix and a nerf.
func _turn_toward(target_yaw: float) -> void:
	if not has_facing:
		facing_yaw = target_yaw
		has_facing = true
		rotation.y = facing_yaw
		return
	var difference := angle_difference(facing_yaw, target_yaw)
	var body_target := body_turn_target(facing_yaw, target_yaw)
	if is_equal_approx(body_target, facing_yaw):
		## The neck covers it. Nothing else moves, and the step this body may
		## have been part way through is over.
		_turn_step_phase = 0.0
		rotation.y = facing_yaw
		return
	var delta := get_process_delta_time()
	if absf(difference) > deg_to_rad(STEP_TURN_DEGREES):
		_turn_step_phase = fposmod(
			_turn_step_phase + delta / TURN_STEP_SECONDS, 1.0
		)
	else:
		_turn_step_phase = 0.0
	var step := turn_rate_for(difference, _turn_step_phase) * delta
	var remaining := angle_difference(facing_yaw, body_target)
	facing_yaw = body_target if absf(remaining) <= step \
		else facing_yaw + signf(remaining) * step
	rotation.y = facing_yaw


## Where the body has to come round to, to bring the head back inside its
## comfortable range. The current facing while the neck can cover the look on
## its own, which is what makes a glance free.
##
## Static and pure so the suite can hold the rule without a rig to run it in.
static func body_turn_target(facing: float, target: float) -> float:
	var difference := angle_difference(facing, target)
	if absf(difference) <= deg_to_rad(NECK_LEAD_DEGREES):
		return facing
	return facing + difference - signf(difference) * deg_to_rad(NECK_LEAD_DEGREES)


## How fast the body may turn this frame. Constant for anything a body can
## pivot through, and gated to the moving half of a step for anything steeper.
static func turn_rate_for(difference: float, step_phase: float) -> float:
	if absf(difference) <= deg_to_rad(STEP_TURN_DEGREES):
		return FACING_TURN_RATE
	return FACING_TURN_RATE / TURN_STEP_DUTY if step_phase < TURN_STEP_DUTY \
		else 0.0


func set_highlighted(highlighted: bool) -> void:
	focus_ring.visible = highlighted
	identity_label.visible = highlighted
	identity_label.outline_modulate = Color("0a101b") if highlighted else Color("00000080")
	identity_label.outline_size = 5 if highlighted else 3


## The four postures the resolver distinguishes, drawn as four stances.
##
## `planted` is a defender who got there: a normal athletic dig, knees bent,
## platform square in front. `moving` is one still travelling through the
## contact. `reaching` is one at the limit of their range, which in this sport
## means going down -- deep knee, hips low, the shape a player makes when the
## ball is barely gettable. `off-axis` is one who got there but could not turn
## their body to face it, so the platform goes out to the side and the shoulders
## tilt with it.
##
## The depths are ordered so the two that matter tactically -- planted against
## reaching -- are unmistakably different at a glance from a court camera.
## `weight` is how far into the platform this instant is, 0 to 1.
##
## Wrapping the blend around the whole pose rather than threading it through
## forty assignments: the joints are captured before the pose runs and eased
## back toward those captured values afterwards. What is being eased *from* is
## therefore whatever the frame already had -- the gait, mid-stride -- so a
## passer running to the ball keeps running and the platform arrives under them.
## The recovery's own progress, from a pose phase that also carries the approach.
##
## Reception vocabulary: `planted` is clean/settled; `moving` is an arriving
## contact that retains its final adjustment step; `reaching` is a strained late
## extension outside a comfortable platform; `off-axis` is awkward body geometry
## with a compromised lateral platform. Each covers preparation, contact,
## follow-through, and handoff to its recovery without resetting locomotion.
func _recovery_clock(phase: float) -> float:
	return clampf(
		inverse_lerp(RECOVERY_START_PHASE, RECOVERY_END_PHASE, phase), 0.0, 1.0
	)


func _apply_dig_posture(
	weight: float = 1.0,
	drive: float = 0.0,
	recovery_progress: float = 0.0,
	contact_direction: Vector2 = Vector2.ZERO,
	phase: float = 0.0,
) -> void:
	var blend := clampf(weight, 0.0, 1.0)
	var push := clampf(drive, 0.0, 1.0)
	var before := _capture_joints()
	## **How far the hips drop below standing**, in metres.
	##
	## In metres for the same reason the stance is, and after the same discovery.
	## The knee angle this replaces could not reach the depth it was supposed to
	## mean: a squat folds the thigh forward and the shank back by equal amounts,
	## so the leg stays a chevron of length `span * cos(thigh_lift)` and a
	## 58-degree knee lowers a voli by **0.08 m**. The pose looked deeper than that
	## only because a separate hand-tuned `drop` pushed the whole body down and the
	## feet went through the floor with it -- 0.06 m under on a planted dig and
	## 0.19 m under on a reaching one. Depth that comes from sinking the figure
	## into the court is depth you cannot see, which is why a passer read as
	## someone leaning forward rather than someone getting low.
	##
	## Stated as a drop, the number is checkable against a photograph: a passer in
	## a serve-receive stance is a quarter of a metre below their standing height,
	## and one digging at the edge of their range is nearly half.
	var crouch_metres := 0.26
	var hip_pitch := -26.0
	## **How far apart the feet are**, as an outward roll on each leg.
	##
	## The stance had no width at all: measured, the two shoes sat 0.302 m apart in
	## every posture at every phase, which is exactly the hip width -- the legs
	## hung straight down from the pelvis and the only thing that moved was the
	## fold. A passer standing with their feet under their hips and their trunk
	## pitched forward is not low, they are *leaning*, and that is precisely how
	## the pose read.
	##
	## Rolling the legs out is also what makes the crouch cost nothing in balance:
	## a wide base is why a defender can put their shoulders in front of their toes
	## without falling over it, so the width and the depth belong together and are
	## set together per posture.
	##
	## **In metres between the shoes, not in degrees at the hip.** The roll needed
	## to hold a given width depends on how folded the knee is -- a straightening
	## leg reaches further sideways at the same angle -- so a fixed roll made the
	## feet slide apart by 22 cm as the legs drove through contact. Feet do not
	## move during a pass. The angle is solved from the width instead, which also
	## makes this a number a reader can check against a stance they have seen.
	var stance_metres := 0.76
	var platform_yaw := 0.0
	var platform_roll := 0.0
	## Whatever the platform could not be turned to, which the trunk leans into.
	var platform_residual := 0.0
	## How far the whole body twists toward the ball, and how far the *far* leg
	## steps across to let it. Zero for the two square postures.
	var torso_yaw := 0.0
	var far_leg_lead := 0.0
	## Whole-body lean, distinct from the hip pitch that folds the player up.
	##
	## Non-zero for a planted dig now. `hip_pitch * 0.24` alone left the trunk
	## almost upright, and an upright trunk is what put the platform up at chest
	## height -- the arms cannot reach down and forward from shoulders that have
	## not come down and forward themselves.
	##
	## Eased back from -11 once the knee and the stance took over the lowering.
	## Tilt and depth are two ways to get the shoulders down and they read
	## completely differently: depth reads as an athlete, tilt reads as a stoop.
	var body_tilt := -8.0
	## Mid-stride offsets, so a defender who arrived on the move is caught on the
	## move rather than standing still in a lower stance.
	var stride := 0.0
	match contact_posture:
		"reaching":
			## Forced down, and *leaning*. The knee folds nearly double and the
			## hips go with it, but the read that separates this from a deep
			## planted stance is the whole body committing forward -- a lunge is
			## a player who has given up their balance to get there, and a
			## crouch is not.
			crouch_metres = 0.34
			hip_pitch = -40.0
			## Widest of the four. A ball at the edge of the range is reached by
			## splitting the base, not by folding further over a narrow one, and
			## the split is what tells this apart from a deep planted dig at the
			## size a sticker is actually drawn.
			##
			## Not wider, though it should be: a folded leg cannot splay far, so
			## at this depth the hip clamp caps the base near 0.78 and asking for
			## more silently gets less. The pose a real reaching dig makes is a
			## *lunge* -- one leg folded under, one nearly straight and thrown out
			## to the side -- and this rig can only make both legs do the same
			## thing at once. Recorded in the backlog rather than faked here.
			stance_metres = 0.78
			platform_roll = 10.0
			## Enough lean to read as committed, not so much that the figure folds
			## into a ball. At -26 the torso came down over the knees and the legs
			## disappeared behind it, which loses the very thing the knee is for.
			body_tilt = -12.0
		"off-axis":
			## Got there, could not square up. The ball is off to one side and the
			## platform stretches out after it -- but the interesting part is what
			## the rest of the body does to keep the two forearms together.
			##
			## The **far** shoulder and the **far** leg rotate forward. That is
			## the whole trick of an off-axis dig: the near arm can reach the ball
			## on its own, and the only way the far arm joins it is if that side
			## of the body comes round. So the torso twists, the far leg steps
			## across behind the reach, and the platform ends up angled across the
			## body instead of square to it.
			##
			## Without the twist this was a player standing square with both arms
			## swung sideways, which is not a posture anybody has ever been in.
			crouch_metres = 0.24
			hip_pitch = -22.0
			## Wide, but not split: the reach here is sideways and it is bought with
			## the twist, not with the base.
			stance_metres = 0.72
			platform_yaw = 30.0
			platform_roll = 14.0
			torso_yaw = -22.0
			far_leg_lead = 22.0
		"moving":
			## Caught mid-step. The two legs are deliberately *unequal*: one is
			## still driving, the other is already planting, which is what makes
			## this read as arriving rather than as a shallower version of planted.
			crouch_metres = 0.21
			hip_pitch = -30.0
			## Narrowest, and for the opposite reason to the others: one foot is
			## still in the air. A player mid-step has not set their base yet, so a
			## wide one here would read as arriving and standing still at once.
			stance_metres = 0.58
			stride = 30.0
		_:
			pass
	## The drive: knees and hips extending under a platform that does not move.
	##
	## Applied after the posture is chosen rather than as four more posture
	## constants, because it is the same action whichever posture a defender got
	## there in -- a lunging dig extends out of a deeper start, not differently.
	## The trunk comes up with it, which is what carries the pass toward the target.
	##
	## The stance does *not* extend with it. Feet do not move during a pass; the
	## legs straighten between them, so the base stays as wide as it was set and
	## only the angles unwind.
	## **The ball decides the platform, when the ball is known.**
	##
	## The posture's own constant -- 0 square, 30 off-axis -- is kept as the
	## fallback and nothing more. It was the only source before, which meant every
	## square pass in the game had identical forearms whether the ball came from
	## the service line or off a blocker's hands two metres away, and an off-axis
	## one was 30 degrees to the same side regardless of which side the ball was
	## actually on.
	##
	## `PlatformAim` bisects the incoming and outgoing flights, which is where the
	## normal of a rebounding surface is. Both flights are already on the event.
	##
	## Resolved **here**, above the drive, because `body_tilt` and `torso_yaw` are
	## both consumed a dozen lines below and the first version of this wrote to
	## them after the fact -- a value computed and dropped, the failure this
	## repository logs more than any other, reproduced while fixing something else.
	if bool(contact_platform_aim.get("valid", false)):
		platform_yaw = float(contact_platform_aim.get("yaw_degrees", platform_yaw))
		platform_residual = float(
			contact_platform_aim.get("residual_degrees", 0.0)
		)
		## The trunk goes where the arms could not. A residual is by definition
		## the part of the reach the shoulders refused, so it is paid for by
		## turning the body -- which is what a passer actually does, and what
		## makes an off-axis contact read as a person rather than as a shrug.
		torso_yaw += clampf(platform_residual * 0.55, -34.0, 34.0)
		body_tilt += clampf(absf(platform_residual) * -0.16, -9.0, 0.0)

	crouch_metres = lerpf(crouch_metres, crouch_metres * 0.28, push)
	hip_pitch = lerpf(hip_pitch, hip_pitch * 0.35, push)
	body_tilt = lerpf(body_tilt, body_tilt * 0.30, push)
	body_pivot.rotation.x = deg_to_rad(hip_pitch * 0.24 + body_tilt)
	body_pivot.rotation.y = deg_to_rad(torso_yaw)
	## **The head keeps watching the ball.**
	##
	## An off-axis dig twists the whole body to get the far arm across, and the
	## head came with it -- so the defender ended up looking where they wanted
	## the ball to *go* rather than where it was coming *from*. That is backwards
	## from how anybody plays: you track the hitter and the flight, and the
	## platform is aimed by feel underneath you.
	##
	## Counter-rotating by the torso's own twist holds the head on the original
	## line, and the neck clamp decides how much survives -- past its limit the
	## head genuinely does have to travel with the shoulders, which is also true.
	look_yaw = clampf(
		-deg_to_rad(torso_yaw),
		-deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
		deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
	)
	## Eyes up the incoming line rather than down at the platform.
	look_pitch = deg_to_rad(-HEAD_PITCH_LIMIT_DEGREES * 0.45)
	_apply_head_look()
	## Legs posed, then *checked and corrected against the rig itself*.
	##
	## `_crouch_thigh_lift` is a closed form and it is close, but it is not exact:
	## the roll and the fold compose through three nested bases and the trunk pitch
	## swings the whole lower body with it, and every one of those costs the model
	## a centimetre or two. Left at the first guess, a planted dig asked for 0.26 m
	## and got 0.19.
	##
	## So the guess is posed, the hips are read where they actually landed, and the
	## residual is spent at the rate the geometry gives -- `span * sin(lift)` per
	## radian, the derivative of the chevron's own height.
	##
	## Four passes rather than one, because that rate is only right for a symmetric
	## squat. The `moving` posture splits the legs by a stride and takes the
	## trailing knee 40 percent straighter, so the step it needs is a fraction of
	## the step the formula predicts and a single correction landed it at 0.14 m
	## against the 0.21 it asked for. A slope in the right direction and the wrong
	## magnitude still converges; it just needs the iterations.
	##
	## Measured after, at the moment the platform is set: planted 0.252 against
	## 0.252 asked, reaching 0.330 against 0.330, off-axis 0.233 against 0.233,
	## and `moving` 0.176 against 0.204 -- the one posture whose legs are doing
	## two different things is the one still three centimetres shy, which is worth
	## knowing rather than rounding away.
	var span := (
		leg_bone_lengths.x + leg_bone_lengths.y
	) * leg_length_scale * body_height_scale
	var thigh_lift := _crouch_thigh_lift(crouch_metres, stance_metres)
	for _pass in 4:
		_pose_dig_legs(thigh_lift, stance_metres, far_leg_lead, stride)
		var per_degree := maxf(
			span * sin(deg_to_rad(thigh_lift)) * PI / 180.0, 0.0005
		)
		thigh_lift = clampf(
			thigh_lift + (crouch_metres - _dig_hip_drop(span)) / per_degree,
			0.0, 82.0
		)
	_pose_dig_legs(thigh_lift, stance_metres, far_leg_lead, stride)
	## The platform: two arms held *together* in front, not spread.
	##
	## The old dig swung them to -70 degrees with an 18-degree outward tilt each,
	## which under Godot's YXZ order reads as both arms straight out to the sides.
	## A platform is the opposite shape -- forearms joined, angled down and
	## forward -- so the pitch is shallower and the arms are brought inward
	## rather than splayed. `platform_yaw` then swings the whole platform off to
	## one side for a defender who could not square up, which is the thing worth
	## seeing.
	## Nearer horizontal, so the platform is a surface out in front rather than two
	## arms hanging down. Measured against the trunk's own fold: at 52 with a
	## planted hip pitch the forearms finish about eighty degrees off vertical in
	## world terms, which is a platform, and the extra reach is exactly what the
	## deeper knee is paying for.
	## Lifting a little through the drive -- the platform follows the ball toward
	## the target rather than being left behind by a body that stood up out of it.
	## Small: the arms are the one thing in a pass that is *not* supposed to travel.
	var lead := 52.0 - hip_pitch * 0.30 + 13.0 * push
	## And the platform's *tilt* comes off the same solve. A ball driven flat and
	## dug up needs a surface angled back; one dropping vertically and pushed
	## forward needs it angled down. That is the pitch of the same normal, and
	## reading only its yaw would leave the arms at one fixed rake for every ball
	## in the game -- the identical defect one axis over.
	if bool(contact_platform_aim.get("valid", false)):
		lead -= clampf(float(contact_platform_aim.get("pitch_degrees", 0.0)), -34.0, 38.0) * 0.5
	## Converging, not splayed -- and this sign was inverted too. Rotating an arm
	## about +Z by theta moves its hand to x = sin theta, so the *left* arm needs a
	## positive roll to bring its hand toward the centreline and the right arm a
	## negative one. Reversed, as it was, the two hands travel apart and the pose
	## becomes a shrug.
	##
	## Large enough that the forearms actually meet. Seven degrees was tuned by
	## eye against a camera standing behind the player, where two arms swung out
	## behind the back happen to overlap and read as joined.
	var spread := 26.0
	## Stretched, not swung. On an off-axis dig the two arms are doing different
	## jobs: the near one is already on the ball, and the far one is chasing it
	## across the body. So the far arm carries extra yaw and converges less --
	## it has further to go and cannot afford to be pulled inward as hard.
	##
	## Both arms rotating identically is what made the old off-axis pose read as
	## a shrug with a twist. A platform that is genuinely reaching is asymmetric.
	var far_arm_yaw := platform_yaw + (16.0 if torso_yaw != 0.0 else 0.0)
	var far_arm_spread := spread * (0.45 if torso_yaw != 0.0 else 1.0)
	left_arm.rotation_degrees = Vector3(
		lead, far_arm_yaw, far_arm_spread + platform_roll
	)
	right_arm.rotation_degrees = Vector3(
		lead, platform_yaw, -spread + platform_roll
	)
	## **Locked.** This is the one pose in the game whose elbows are deliberately
	## straighter than a resting arm, and it is the whole reason a platform is a
	## platform: two forearms joined into one flat surface. Bend either one and
	## the ball leaves at an angle nobody chose.
	##
	## It also does the legibility work the knee does lower down. A dig and a set
	## are both "arms in front of the body"; locked against folded is what makes
	## them different actions rather than two similar frames.
	_set_elbow(left_arm, 0.0)
	_set_elbow(right_arm, 0.0)
	if blend < 0.999:
		_blend_joints_toward(before, 1.0 - blend)
	var arrival := ContactArrivalBiomechanicsScript.resolve(
		phase, ground_speed_mps, stride_cycle, contact_posture
	)
	_blend_lower_body_toward(
		before, 1.0 - float(arrival.lower_body_weight)
	)
	body_pivot.rotation.z += deg_to_rad(float(arrival.momentum_roll_degrees))
	_ground_the_dig(blend)
	## Recovery starts after contact and is layered over a properly grounded dig.
	## That ordering matters: grounding a fallen pose by its shoe afterwards lifts
	## its hip back into the air, which is how the old static fall became a crouch.
	_apply_recovery_state(recovery_progress, contact_direction)


## How far below standing the hips currently are, in metres.
##
## Measured against the **lower** shoe, which is the one that will be on the floor
## once `_ground_the_dig` has run and therefore the one the hip height is really
## taken from. Reading a nominated leg's own shoe instead is wrong for exactly the
## posture that has a stride in it -- a foot swung forward is not under the hip,
## so `moving` asked for a 0.21 m crouch and landed on 0.11.
func _dig_hip_drop(span: float) -> float:
	return span - (
		to_local(left_leg.global_position).y - minf(
			to_local(
				(left_leg.get_node("Knee/Shoe") as Node3D).global_position
			).y,
			to_local(
				(right_leg.get_node("Knee/Shoe") as Node3D).global_position
			).y,
		)
	)


## Both legs into a squat of the given thigh angle over the given stance.
##
## **A knee folds backward.** This once had the thigh swinging back and the shank
## swinging *forward*, which puts the joint's point behind the leg -- a knee
## bending the wrong way. It survived because a crouch of roughly the right
## height is still a crouch of roughly the right height, and the tell is the one
## detail the knee was added to show.
##
## Correct squat: the thigh rotates forward as the hips drop and the shank folds
## back by twice that, so it finishes the same angle off vertical on the far side
## and the foot stays under the body at any depth.
##
## `far_lead` goes on the left leg only, because the off-axis twist is authored
## for a ball off to the player's right and the left side is the one that has to
## step across. `stride` splits the pair the other way, one forward and one back.
func _pose_dig_legs(
	thigh_lift: float, apart: float, far_lead: float, stride: float
) -> void:
	for index in [0, 1]:
		var leg: Node3D = left_leg if index == 0 else right_leg
		var lead_for_leg := (far_lead if index == 0 else 0.0) \
			+ (stride if index == 0 else -stride)
		## The trailing leg stays straighter -- it is still pushing.
		var knee_fold := -thigh_lift \
			* (0.6 if index == 1 and stride > 0.0 else 1.0) * 2.0
		(leg.get_node("Knee") as Node3D).rotation_degrees.x = knee_fold
		## Rolled out as well as folded, by however much this leg needs to put its
		## shoe on the stance line.
		##
		## Rotating a hanging leg about +Z carries its foot toward +x, so the
		## *left* leg -- which starts at negative x -- needs a negative roll to
		## travel outward and the right a positive one. Same sign trap the platform
		## fell into, and the same measurement settles it: with the roll at zero
		## the shoes sit 0.302 m apart, which is the hip width exactly.
		##
		## How far sideways a roll carries the shoe depends on the knee, because
		## only the part of the shank still pointing downward travels with it. The
		## fold is therefore resolved first and the roll solved against it -- the
		## reason the two are in this order and not the obvious one.
		leg.rotation_degrees = Vector3(
			thigh_lift + lead_for_leg, 0.0,
			_stance_roll(apart, knee_fold) * (-1.0 if index == 0 else 1.0)
		)


## The thigh angle that drops the hips by `drop` metres over a stance `apart`.
##
## A squat on this rig is a chevron: the thigh swings forward by this angle and
## the shank folds back by twice it, so the shank finishes the same angle off
## vertical on the other side and the foot stays under the hip. The pair
## therefore spans `leg * cos(lift)` vertically, and rolling the whole thing out
## to make the stance costs another `cos(roll)` on top.
##
## Two passes because the roll needed for a given width depends on how folded the
## knee is, and the fold depends on the roll. It converges immediately -- the
## second pass moves the answer by under a degree -- so a loop with an exit test
## would be more machinery than the problem has.
func _crouch_thigh_lift(drop: float, apart: float) -> float:
	var span := (
		leg_bone_lengths.x + leg_bone_lengths.y
	) * leg_length_scale
	if span < 0.01:
		return 0.0
	var lift := 0.0
	for _pass in 2:
		var roll := deg_to_rad(_stance_roll(apart, -lift * 2.0))
		var want := span - drop / maxf(body_height_scale, 0.01)
		lift = rad_to_deg(
			acos(clampf(want / maxf(span * cos(roll), 0.01), 0.0, 1.0))
		)
	return lift


## The hip roll that puts one shoe half a stance away from the centreline.
##
## `apart` is where the two shoes should be, in metres of court. The hip already
## contributes `hip_offset.x`, and the rest has to come from the leg swinging
## out: the thigh carries its full length sideways, the shank only the part of it
## still pointing downward once the knee has folded, which is why a folded leg
## needs a *larger* roll than a straight one to stand in the same place.
##
## Everything below the scale divide is in the rig's own units. `apart` is not,
## because a stance is a thing you could measure on a court with a tape, and the
## whole point of expressing it that way is that it stays checkable.
func _stance_roll(apart: float, knee_degrees: float) -> float:
	var fold := deg_to_rad(knee_degrees)
	## `leg_length_scale` is a scale on the leg node itself rather than a longer
	## pair of bones, so `leg_bone_lengths` is what was authored and not what is
	## on screen. Left out, a long-legged voli stood 5 percent wider than asked --
	## small, silent, and exactly the kind of thing a stance in metres exists to
	## make catchable.
	var reach := (
		leg_bone_lengths.x
		+ leg_bone_lengths.y * cos(fold)
		- SHOE_FORWARD_OFFSET * sin(fold)
	) * leg_length_scale
	if reach < 0.01:
		return 0.0
	var out := apart * 0.5 / maxf(body_height_scale, 0.01) - hip_offset.x
	## **A hip does not abduct to ninety degrees.** Past the limit the solve does
	## not fail, it saturates -- and a saturated `asin` returning 90 was quietly
	## catastrophic: `cos(roll)` went to zero, the depth solve divided by it and
	## the crouch collapsed to standing. The stance a deep squat can hold is
	## narrower than one taken standing up, and clamping says so instead of
	## breaking the pose that asked.
	return clampf(
		rad_to_deg(asin(clampf(out / reach, -1.0, 1.0))),
		-HIP_ABDUCTION_LIMIT_DEGREES, HIP_ABDUCTION_LIMIT_DEGREES
	)


## Put the dig's feet on the floor, and let that decide how low the hips are.
##
## This replaces four hand-tuned `drop` constants, and it replaces them because
## they were measurably wrong: the lower shoe finished **0.062 m below the floor**
## on a planted dig and **0.189 m below it** on a reaching one. A passer sunk a
## fifth of a metre into the court has the very thing the deep knee was added to
## show buried under the floorboards, which is a large part of why the pose read
## as a stoop rather than a squat.
##
## The right relationship is the other way round from the one the constants
## encoded. Hip height is not a number to pick alongside the knee angle -- it is
## the *consequence* of the knee angle, the hip fold and the stance width
## together, and any of the three moving changes it. So the shoe is read where it
## actually ended up and the pelvis is lifted until it sits at the height a
## straight leg would put it: `hip_offset.y` minus both bones, which is where the
## ankle lives when a voli is standing up.
##
## Read from the finished transforms rather than recomputed from the angles,
## because the trunk pitch rotates the legs with it on this rig and the blend
## back toward the gait moves them again. Trigonometry would have to model both;
## the transforms already have.
##
## Scaled by `blend` so a passer still mostly running is still owned by the gait,
## which does its own vertical travel through `bob_meters`.
func _ground_the_dig(blend: float) -> void:
	var rest := (
		hip_offset.y - leg_bone_lengths.x - leg_bone_lengths.y
	) * body_height_scale
	var lowest := minf(
		to_local(
			(left_leg.get_node("Knee/Shoe") as Node3D).global_position
		).y,
		to_local(
			(right_leg.get_node("Knee/Shoe") as Node3D).global_position
		).y,
	)
	body_pivot.position.y += (rest - lowest) * clampf(blend, 0.0, 1.0)
	_feet_already_grounded = true


## Every joint this pose writes, as it stands right now.
##
## Kept as a plain dictionary of the values rather than a Transform3D snapshot,
## because only the components the dig actually touches should come back -- the
## facing, the head look and the elevation are decided elsewhere and must
## survive the blend untouched.
func _capture_joints() -> Dictionary:
	return {
		"pivot_y": body_pivot.position.y,
		"pivot_rotation": body_pivot.rotation,
		"left_arm": left_arm.rotation_degrees,
		"right_arm": right_arm.rotation_degrees,
		"left_elbow": (left_arm.get_node("Elbow") as Node3D).rotation_degrees,
		"right_elbow": (right_arm.get_node("Elbow") as Node3D).rotation_degrees,
		"left_leg": left_leg.rotation_degrees,
		"right_leg": right_leg.rotation_degrees,
		"left_knee": (left_leg.get_node("Knee") as Node3D).rotation_degrees,
		"right_knee": (right_leg.get_node("Knee") as Node3D).rotation_degrees,
	}


## Ease back toward a captured set of joints by `amount`.
func _blend_joints_toward(captured: Dictionary, amount: float) -> void:
	var t := clampf(amount, 0.0, 1.0)
	body_pivot.position.y = lerpf(body_pivot.position.y, float(captured.pivot_y), t)
	body_pivot.rotation = body_pivot.rotation.lerp(Vector3(captured.pivot_rotation), t)
	left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(
		Vector3(captured.left_arm), t
	)
	right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(
		Vector3(captured.right_arm), t
	)
	var left_elbow := left_arm.get_node("Elbow") as Node3D
	var right_elbow := right_arm.get_node("Elbow") as Node3D
	left_elbow.rotation_degrees = left_elbow.rotation_degrees.lerp(
		Vector3(captured.left_elbow), t
	)
	right_elbow.rotation_degrees = right_elbow.rotation_degrees.lerp(
		Vector3(captured.right_elbow), t
	)
	left_leg.rotation_degrees = left_leg.rotation_degrees.lerp(
		Vector3(captured.left_leg), t
	)
	right_leg.rotation_degrees = right_leg.rotation_degrees.lerp(
		Vector3(captured.right_leg), t
	)
	var left_knee := left_leg.get_node("Knee") as Node3D
	var right_knee := right_leg.get_node("Knee") as Node3D
	left_knee.rotation_degrees = left_knee.rotation_degrees.lerp(
		Vector3(captured.left_knee), t
	)
	right_knee.rotation_degrees = right_knee.rotation_degrees.lerp(
		Vector3(captured.right_knee), t
	)


## Preserve the live support step while the contact apparatus prepares above it.
## This deliberately excludes root court position: locomotion remains its sole
## owner, and the action can only blend joint presentation.
func _blend_lower_body_toward(captured: Dictionary, amount: float) -> void:
	var t := clampf(amount, 0.0, 1.0)
	left_leg.rotation_degrees = left_leg.rotation_degrees.lerp(
		Vector3(captured.left_leg), t
	)
	right_leg.rotation_degrees = right_leg.rotation_degrees.lerp(
		Vector3(captured.right_leg), t
	)
	var left_knee := left_leg.get_node("Knee") as Node3D
	var right_knee := right_leg.get_node("Knee") as Node3D
	left_knee.rotation_degrees = left_knee.rotation_degrees.lerp(
		Vector3(captured.left_knee), t
	)
	right_knee.rotation_degrees = right_knee.rotation_degrees.lerp(
		Vector3(captured.right_knee), t
	)


func _blend_upper_body_toward(captured: Dictionary, amount: float) -> void:
	var t := clampf(amount, 0.0, 1.0)
	body_pivot.rotation = body_pivot.rotation.lerp(
		Vector3(captured.pivot_rotation), t
	)
	left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(
		Vector3(captured.left_arm), t
	)
	right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(
		Vector3(captured.right_arm), t
	)
	var left_elbow := left_arm.get_node("Elbow") as Node3D
	var right_elbow := right_arm.get_node("Elbow") as Node3D
	left_elbow.rotation_degrees = left_elbow.rotation_degrees.lerp(
		Vector3(captured.left_elbow), t
	)
	right_elbow.rotation_degrees = right_elbow.rotation_degrees.lerp(
		Vector3(captured.right_elbow), t
	)


## Pure directional plan for a recovery. Keeping this separate from the rig
## makes "which way did they go?" a testable fact while the joint posing below
## remains free to change with the model.
##
## Recovery vocabulary: `platform` is a controlled on-feet continuation; `knee`
## is a low but supported recovery; a planted/off-axis `fall` rolls sideways; a
## moving/reaching `fall` slides forward; `blown_away` absorbs a hard impact
## backward before gathering the legs and returning to stance.
static func recovery_motion(
	recovery_state: String,
	posture: String,
	progress: float,
	contact_direction: Vector2 = Vector2.ZERO,
	handedness: String = "Right",
) -> Dictionary:
	var recovery := clampf(progress, 0.0, 1.0)
	var down := smoothstep(0.0, 0.34, recovery)
	## **Down, and then back up.**
	##
	## `down` is the descent and nothing else, and for a long time nothing else
	## existed -- so a half-kneel went down in the first third and stayed there
	## for the remaining two, and `pose_recover_knee` was six frames of a body
	## kneeling. A recovery that never recovers is a pose with a clock attached
	## to it.
	##
	## `stand_up` is the counterpart, and it is **per state** rather than shared,
	## because the three states are not equally far from their feet. A kneel has
	## one leg already under the body and needs a push; being blown away starts
	## flat on your back and has to gather the legs before the trunk can come up
	## at all, so it begins later *and* takes the whole remaining span. The rolling
	## receive keeps `rise` below, which is the same idea under an older name.
	##
	## Both finish at 1, which is what makes the handover to the standing pose
	## seamless: the overlay's last frame and the gait's first are the same body.
	var stand_up := 0.0
	match recovery_state:
		"knee":
			stand_up = smoothstep(0.58, 1.0, recovery)
		"blown_away":
			stand_up = smoothstep(0.46, 1.0, recovery)
	## **Being hit by a ball is fast; getting up from it is not.**
	##
	## The impact borrowed `roll` and `travel`, which are the rolling receive's
	## terms and run to 0.88 and 0.82 -- so the body was still going down while it
	## was already standing up, and the two curves crossed near 0.62 with the
	## fall never completing at all. A defender driven off a ball is on the floor
	## in the first third of the recovery and spends the rest of it getting back
	## to their feet, which is exactly why the simulator prices this state at 1.35
	## seconds against a kneel's 0.55.
	var impact := smoothstep(0.06, 0.42, recovery)
	## When the legs come back under an impact. Before the trunk, because that is
	## the order it happens in: you pull your knees in, find the floor, and only
	## then is there anything to push against.
	var legs_down := smoothstep(0.44, 0.82, recovery)
	var travel := smoothstep(0.08, 0.82, recovery)
	var roll := smoothstep(0.18, 0.88, recovery)
	## **When the legs come in.** Late, and deliberately after the roll has
	## started.
	##
	## The legs used to fold on `down` -- 0 to 0.34 -- so the body balled up in
	## the first third and the 112-degree roll then turned a ball. Photographed as
	## a strip that reads as a forward tumble, which is what it was: the rotation
	## was there all along and had nothing extended to rotate.
	##
	## A dive roll extends into the contact, takes the floor on the platform and
	## the outside hip, and gathers the legs over the top as it comes round. So
	## the gather trails the roll instead of leading it.
	var gather := smoothstep(0.46, 0.96, recovery)
	## **The roll, as the sequence it actually is.**
	##
	## A rolling receive is not a fall with a rotation on it. In order: the arms
	## lead to the ball; the platform breaks; the body is guided onto its lateral
	## line -- hip, glute, back, shoulder -- keeping the elbows and knees *off*
	## the floor, with a hand down only if it is needed; the core stays stable
	## until after impact and only then lets the limbs tuck; the trailing leg and
	## the near shoulder turn the body together; and the legs and core bring it
	## back upright.
	##
	## The previous version was two curves -- a pitch and a 112-degree tip -- and
	## it ended lying on the floor. Nothing in it broke the platform, nothing
	## chose which surfaces took the load, and there was no way back to the feet,
	## which is why the last three frames of every strip were a body lying still.
	##
	## NOTE the bands overlap on purpose -- a stage that waits for the previous
	## one to finish is a sequence of poses rather than a movement
	var platform_hold := 1.0 - smoothstep(0.05, 0.21, recovery)
	var lateral_line := smoothstep(0.09, 0.44, recovery)
	var core_release := smoothstep(0.15, 0.36, recovery)
	var tuck := smoothstep(0.26, 0.63, recovery)
	var turn := smoothstep(0.14, 0.88, recovery)
	var rise := smoothstep(0.66, 1.0, recovery)
	var side := signf(contact_direction.x)
	if is_zero_approx(side):
		side = -1.0 if handedness == "Left" else 1.0
	var mode := recovery_state
	var pitch := 0.0
	var body_roll := 0.0
	var offset := Vector3.ZERO
	match recovery_state:
		"knee":
			## **Folded over the down knee**, not standing with a leg back.
			##
			## This was -14 degrees, which is a lean. Somebody who has lost their
			## balance and put a knee down is *catching* themselves: the trunk
			## folds over the knee that is taking the weight, and the fold is most
			## of what tells a kneel from a lunge. Unwound by `stand_up` so the
			## body comes back up the way it went down.
			##
			## Added to the dig posture's own fold rather than replacing it, which
			## is why this is smaller than it looks: -34 on top of a planted dig
			## put the head near the floor and `_settle_to_floor` then rested the
			## figure on its shoulder.
			pitch = deg_to_rad(-21.0) * down * (1.0 - stand_up)
		"fall":
			if posture in ["moving", "reaching"]:
				mode = "slide_forward"
				# A slide still has to hand back a standing body. `rise` begins only
				# after the chest and hips have reached the floor, then unwinds the
				# presentation overlay without changing simulation position.
				# Preserve the established full-travel read through phase 0.82; only
				# the final hand-back unwinds this local presentation displacement.
				var slide_hold := 1.0 - smoothstep(0.84, 1.0, recovery)
				pitch = deg_to_rad(-56.0) * down * slide_hold
				body_roll = deg_to_rad(7.0) * side * roll * slide_hold
				offset.z = -0.48 * travel * slide_hold
			else:
				mode = "roll_sideways"
				## A full turn, because the roll ends on the feet. The old
				## 112 degrees was a body tipping over and staying there.
				body_roll = deg_to_rad(360.0) * side * turn
				## Forward at the contact, unwinding as the core brings the body
				## back up. Pitch that only ever increases is a player who folded.
				pitch = deg_to_rad(-26.0) * lateral_line * (1.0 - rise)
				## The lateral travel is bought during the contact and stops once
				## the turn is carrying the body instead of the floor.
				offset.x = 0.42 * side * lateral_line
		"blown_away":
			## **And then they get up**, which they did not.
			##
			## Being driven off a ball was drawn as a fall with no floor after it:
			## the body pitched 106 degrees onto its back and the clock ran out
			## there. It is the longest of the three recoveries -- the simulator
			## already prices it at 1.35 seconds against a kneel's 0.55 -- and it
			## was the only one with nothing on the other side of the impact.
			##
			## Unwound rather than re-choreographed: coming up off your back is
			## the fall in reverse plus a fold at the end, and the fold is the
			## part where you sit up over your own knees before standing.
			mode = "roll_backward"
			pitch = deg_to_rad(106.0) * impact * (1.0 - stand_up) \
				- deg_to_rad(22.0) * stand_up * (1.0 - stand_up) * 4.0
			body_roll = deg_to_rad(13.0) * side * impact * (1.0 - stand_up)
			offset.z = 0.42 * impact * (1.0 - stand_up)
	return {
		"mode": mode,
		"down": down,
		"impact": impact,
		"stand_up": stand_up,
		"legs_down": legs_down,
		"travel": travel,
		"roll": roll,
		"gather": gather,
		"platform_hold": platform_hold,
		"lateral_line": lateral_line,
		"core_release": core_release,
		"tuck": tuck,
		"turn": turn,
		"rise": rise,
		"side": side,
		"pitch_radians": pitch,
		"roll_radians": body_roll,
		"offset": offset,
	}


## The four things that can happen to a defender who plays a ball.
##
## Layered *over* the posture rather than replacing it, because the two are
## independent: a reaching contact that puts someone on one knee still started
## as a reach, and the pose should say both. So this only adds -- it drops the
## hips, folds a leg, rolls the body -- and never rewrites what the platform was
## doing.
##
## `recovery` and `posture` default to the ivars, which is what every in-window
## caller wants. The overlay that runs *after* the window passes them explicitly:
## by then this voli is no longer the contact actor and the ivars belong to
## whatever contact playback moved on to.
func _apply_recovery_state(
	progress: float = 1.0,
	contact_direction: Vector2 = Vector2.ZERO,
	recovery_name: String = "",
	posture_name: String = "",
) -> void:
	var recovery := clampf(progress, 0.0, 1.0)
	var state := recovery_name if not recovery_name.is_empty() \
		else contact_recovery
	var posture := posture_name if not posture_name.is_empty() \
		else contact_posture
	if state == "platform" or recovery <= 0.0001:
		return
	## Where the feet are *now*, before this state folds them. The posture already
	## put them on the floor, crouch and all, so this is the height the body has
	## to come back to -- measuring against a bare y = 0 instead would quietly
	## undo whatever sink the dig itself asked for.
	var contact_floor := _lowest_body_point()
	## And where the hips are, for the same reason. A roll of forty degrees turns
	## the body about the *feet*, which slides the whole rig sideways off the spot
	## it was standing on -- the fallen voli ended up beside its own floor marker
	## rather than on it.
	var contact_hips := _hip_offset_from_actor()
	var motion := recovery_motion(
		state, posture, recovery, contact_direction, dominant_hand,
	)
	var down := float(motion.down)
	match state:
		"knee":
			## A half-kneel: one shin folded flat behind, the other leg braced in
			## front. Asymmetry is the whole read -- two knees down is kneeling,
			## one is a player who *went* down to finish a play.
			##
			## The two legs are posed to reach the *same* depth below the hip, so
			## the down knee and the braced foot arrive at the floor together. A
			## pose where one reaches further leaves the other hanging in the air
			## once the body is planted, which is what "kneeling in mid-air"
			## actually was.
			## **Deeper, because the knee is what is holding them up.**
			##
			## The first numbers were a thigh 12 degrees behind vertical over a
			## shin folded to -100, which puts the shank 22 degrees *above*
			## horizontal -- a raised foot with a straightish leg under it. Drawn,
			## it reads as somebody picking a foot up rather than as somebody
			## whose knee is on the floor taking their weight, which is what a
			## half-kneel is.
			##
			## So the down leg's thigh comes forward of vertical and the shin
			## folds hard back and up, which makes the **knee** unambiguously the
			## lowest part of the body -- and `_settle_to_floor` then rests the
			## whole figure on it rather than on a shoe. The braced leg takes the
			## thigh to horizontal with the shin vertical under it, so the front
			## foot is planted flat instead of reaching forward.
			var kneel := down * (1.0 - float(motion.stand_up))
			body_pivot.rotation.x += float(motion.pitch_radians)
			left_leg.rotation_degrees.x = lerpf(
				left_leg.rotation_degrees.x, 2.0, kneel
			)
			(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x,
				-128.0, kneel
			)
			right_leg.rotation_degrees.x = lerpf(
				right_leg.rotation_degrees.x, 84.0, kneel
			)
			(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x,
				-80.0, kneel
			)
		"fall":
			## One severity, three honest directions. Off-axis contacts have already
			## said the miss was lateral, moving/reaching contacts have committed
			## forward, and a planted fall has only the lateral escape left. Nothing
			## here reclassifies the contact or changes its recovery cost.
			if str(motion.mode) == "slide_forward":
				## A forward pancake-like slide: chest and hips travel through the
				## platform while the legs trail rather than folding under it.
				body_pivot.rotation.x += float(motion.pitch_radians)
				body_pivot.position += Vector3(motion.offset)
				body_pivot.rotation.z += float(motion.roll_radians)
			else:
				## **The rolling receive, stage by stage.**
				var lateral := float(motion.lateral_line)
				var roll_rise := float(motion.rise)
				var hold := float(motion.platform_hold)
				var roll_side := float(motion.side)
				body_pivot.rotation.x += float(motion.pitch_radians)
				body_pivot.rotation.z += float(motion.roll_radians)
				body_pivot.position += Vector3(motion.offset)
				## **The core is stable until after impact.** Until it releases,
				## the trunk resists the tip instead of collapsing into it, which
				## is the difference between a controlled roll and being knocked
				## over. Counter-rotating a share of the roll is how a held core
				## reads from outside.
				body_pivot.rotation.z -= float(motion.roll_radians) \
					* (1.0 - float(motion.core_release)) * 0.55
				## **The hips take the floor first, and only as low as the lateral
				## line needs.** Dropping to the floor and staying there is what
				## made this a fall; the body comes back up on the legs below.
				body_pivot.position.y -= lerpf(0.0, 0.46, lateral) * (1.0 - roll_rise)

				## **The platform breaks after the ball has gone.** Holding two
				## arms locked together through a roll is the pose that reads as a
				## mannequin tipping over -- and it is also how an elbow ends up
				## taking the load.
				var break_weight := 1.0 - hold
				left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(
					## Near arm sweeps across the chest as the body turns; the
					## hand is available to the floor without the elbow going
					## anywhere near it.
					Vector3(-24.0, 42.0 * roll_side, -46.0 * roll_side), break_weight
				)
				right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(
					## Trailing arm opens away and *up*, which is what keeps the
					## shoulder rather than the elbow presenting to the floor.
					Vector3(-96.0, -30.0 * roll_side, 38.0 * roll_side), break_weight
				)
				## Elbows deliberately close to straight. A bent elbow under a
				## rolling body is the injury this technique exists to avoid, and
				## a drawing that shows it teaches the wrong thing.
				_set_elbow(left_arm, lerpf(
					(left_arm.get_node("Elbow") as Node3D).rotation_degrees.x,
					-14.0, break_weight
				))
				_set_elbow(right_arm, lerpf(
					(right_arm.get_node("Elbow") as Node3D).rotation_degrees.x,
					-8.0, break_weight
				))
				## **Step 5: the chin tucks.**
				##
				## The head keeps tracking the ball through every other pose, which
				## is right -- and wrong here. With the trunk pitched and rolled
				## past ninety degrees, a head still aimed at the ball is a head
				## driven back through the shoulders, which is the geometry behind
				## the frames where it disappears into the torso.
				##
				## Nobody rolls looking at the ball anyway. The tuck is the first
				## thing taught about going to the floor, so damping the look by
				## the roll is both the fix and the correct behaviour.
				var tuck := 1.0 - float(motion.roll)
				look_yaw *= tuck
				look_pitch = lerpf(look_pitch, 0.42, float(motion.roll))
				_apply_head_look()
			## Thighs well past horizontal, so the folded legs finish at hip height
			## and the *hip* becomes the lowest thing on the body. With the legs
			## reaching lower than the hip the floor solve plants a shoe instead
			## and leaves the body standing over it, which is a crouch.
			## **The legs.** Two different jobs, and the old single fold did
			## neither: it drove both knees to 118 and 126 degrees in the first
			## third, putting the knees on the floor during the load and leaving
			## the body folded for the rest.
			##
			## The trailing leg turns the body with the shoulder -- that pair is
			## what makes the rotation smooth rather than a topple -- and the near
			## leg gathers under the hips so there is something to stand up on.
			## Both stay well clear of a knee-first landing.
			if str(motion.mode) == "roll_sideways":
				var turn_drive := float(motion.turn)
				var gather_in := float(motion.tuck)
				var stand := float(motion.rise)
				## Trailing leg: extended through the load, swinging across to
				## carry the turn, then coming under for the rise.
				right_leg.rotation_degrees.x = lerpf(
					lerpf(-16.0, 62.0, turn_drive), 8.0, stand
				)
				right_leg.rotation_degrees.z = lerpf(
					0.0, -28.0 * float(motion.side), turn_drive
				)
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					lerpf(-6.0, -54.0, turn_drive), -18.0, stand
				)
				## Near leg: tucks in, then plants.
				left_leg.rotation_degrees.x = lerpf(
					lerpf(-8.0, 96.0, gather_in), 14.0, stand
				)
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					lerpf(-4.0, -104.0, gather_in), -26.0, stand
				)
			else:
				var fold := float(motion.gather)
				left_leg.rotation_degrees.x = lerpf(
					left_leg.rotation_degrees.x, 128.0, fold
				)
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					(left_leg.get_node("Knee") as Node3D).rotation_degrees.x, -118.0, fold
				)
				right_leg.rotation_degrees.x = lerpf(
					right_leg.rotation_degrees.x, 138.0, fold
				)
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					(right_leg.get_node("Knee") as Node3D).rotation_degrees.x, -126.0, fold
				)
		"blown_away":
			## Not a play, an impact. The body pitches *backward* -- the only pose
			## in the game that does, since a block bends forward at -0.12 -- the
			## arms are driven up and back off the ball rather than held on it, and
			## the legs come up in front. The backward pitch is the entire tell:
			## everything else a defender does goes toward the ball.
			body_pivot.rotation.x += float(motion.pitch_radians)
			body_pivot.rotation.z += float(motion.roll_radians)
			body_pivot.position += Vector3(motion.offset)
			## Every impact term is scaled by what is left of the fall, so the
			## whole pose unwinds instead of being held until the clock stops.
			var struck := float(motion.impact) * (1.0 - float(motion.stand_up))
			left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(
				Vector3(-138.0, 0.0, -34.0), struck
			)
			right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(
				Vector3(-146.0, 0.0, 30.0), struck
			)
			_set_elbow(left_arm, lerpf(
				(left_arm.get_node("Elbow") as Node3D).rotation_degrees.x, 52.0, struck
			))
			_set_elbow(right_arm, lerpf(
				(right_arm.get_node("Elbow") as Node3D).rotation_degrees.x, 44.0, struck
			))
			## Past horizontal, so the feet finish *above* the hip and the body
			## plants on its back rather than on a shoe.
			## The legs come down before the trunk comes up, which is the order it
			## happens in: you gather your knees, find the floor with your feet,
			## and only then is there anything to push against. `legs_down` runs
			## ahead of `stand_up` for exactly that reason.
			var kicked := float(motion.impact) * (1.0 - float(motion.legs_down))
			left_leg.rotation_degrees.x = lerpf(
				left_leg.rotation_degrees.x, 110.0, kicked
			)
			right_leg.rotation_degrees.x = lerpf(
				right_leg.rotation_degrees.x, 95.0, kicked
			)
			(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x,
				-60.0, kicked
			)
			(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x,
				-50.0, kicked
			)
			## Eyes still up the line the ball came from, because they are being
			## pushed away from it rather than turning from it.
			look_pitch = deg_to_rad(-HEAD_PITCH_LIMIT_DEGREES)
			_apply_head_look()
		_:
			return
	_settle_to_floor(contact_floor, contact_hips)


## Drop the posed body until its lowest part rests on the court.
##
## This replaced three hand-tuned drops, and the reason is worth keeping: a drop
## written as a number is a claim about how far a *particular* pose lifts a
## *particular* body off the floor, and both halves of that claim change with
## every silhouette and every angle. The three numbers were tuned by eye on one
## portfolio plate of four subjects; measured, they put a shoe up to 0.6 m
## underground on the same four.
##
## Solving it instead makes the pose the only thing an author has to get right.
## Whatever reaches lowest -- a knee, a shoe, a hip, a hand -- is what the body
## comes to rest on, which is also what "landing" means.
func _settle_to_floor(floor_height: float, hips: Vector3) -> void:
	var drift := hips - _hip_offset_from_actor()
	body_pivot.position.x += drift.x
	body_pivot.position.z += drift.z
	body_pivot.position.y += floor_height - _lowest_body_point()


## A pre-contact dive reaches the floor before recovery has a non-zero clock,
## leaving that solver no settlement to apply at phase zero. Clamp only actual
## penetration: forward commitment and airborne height remain untouched, while
## no hand, knee, or shoe is allowed through the court.
func _keep_above_floor(floor_height: float) -> void:
	# Nested arm/leg transforms are lazily propagated. A short convergence loop
	# lets the next measurement observe the previous lift, just as the crouch
	# solver iterates after composing its nested joints.
	for _pass in 4:
		_force_transform_tree(body_pivot)
		var lowest := _lowest_body_point()
		if lowest >= floor_height - 0.0005:
			break
		body_pivot.position.y += floor_height - lowest


func _force_transform_tree(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).force_update_transform()
	for child in node.get_children():
		_force_transform_tree(child)


## Where the hips sit relative to the actor.
##
## **Read from the leg roots, which are the hip joint.** This used to read the
## shorts, on the reasoning that they were the one mesh that *was* the hip rather
## than merely near it -- true while they were a box sitting on the joint, and
## false the moment they became the bottom section of the torso. Moving a mesh
## silently moved a measurement taken off it, and the landing poses settled to the
## wrong height for it.
##
## The joint is the honest source: it is where the legs actually hang from, it is
## not a garment, and it cannot be restyled out from under this.
func _hip_offset_from_actor() -> Vector3:
	var inverse := global_transform.affine_inverse()
	return (
		(inverse * left_leg.global_transform).origin
		+ (inverse * right_leg.global_transform).origin
	) * 0.5


## The lowest point of the body, in the actor's own space.
##
## Measured relative to `self` rather than in world space so it survives the
## actor being moved or turned on the court, and taken from mesh bounds rather
## than from bone maths because the shoe hangs off the shin and the produce
## bodies are spheres -- neither is where a limb length says it is.
func _lowest_body_point() -> float:
	var into_actor := global_transform.affine_inverse()
	var lowest := INF
	var pending: Array[Node] = [body_pivot]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if not (current is VisualInstance3D):
			continue
		var visual := current as VisualInstance3D
		if not visual.visible or visual is Label3D:
			continue
		var box := visual.get_aabb()
		var placement := into_actor * visual.global_transform
		for corner in 8:
			lowest = minf(lowest, (placement * box.get_endpoint(corner)).y)
	return 0.0 if is_inf(lowest) else lowest


## Point the head at a spot on the court, independently of where the body faces.
##
## `world_yaw` is an absolute heading in the same convention `set_pose` uses --
## `atan2(-dx, -dz)` for a direction in court space. The turn is stored relative
## to the body and clamped, so a target behind the player turns the head as far
## as a neck goes and no further; the body has to do the rest.
func look_toward(world_yaw: float, pitch_degrees: float = 0.0) -> void:
	var relative := angle_difference(facing_yaw, world_yaw)
	_look_target_yaw = clampf(
		relative,
		-deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
		deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
	)
	_look_target_pitch = deg_to_rad(clampf(
		pitch_degrees, -HEAD_PITCH_LIMIT_DEGREES, HEAD_PITCH_LIMIT_DEGREES
	))
	_has_attention_target = true


## Forget the target and face straight ahead again.
func clear_look() -> void:
	_look_target_yaw = 0.0
	_look_target_pitch = 0.0
	_has_attention_target = true


func _advance_head_attention() -> void:
	if not _has_attention_target:
		return
	var advanced := CoreVoliPerformanceScript.attention_step(
		Vector2(look_yaw, look_pitch),
		Vector2(_look_target_yaw, _look_target_pitch),
		get_process_delta_time(),
	)
	look_yaw = advanced.x
	look_pitch = advanced.y


func _apply_head_look() -> void:
	if head != null:
		head.rotation = Vector3(look_pitch, look_yaw, 0.0)


## Keep the shoes on the floor when a pose folds a knee.
##
## This rig has a hip and a knee and no ankle, so bending the knee swings the
## whole shin backward and lifts the shoe clear of the ground. Every pose that
## crouches was doing it in mid-air: a hitter absorbing a landing four
## centimetres above the floor, a blocker loading into a squat while hovering,
## a defender digging off the ground. It was fixed once inside the landing and
## then found again in the block, which is the signal that it belongs here --
## it is a property of the *rig*, not of any one action.
##
## Two things keep it honest:
##
## **Only the extra fold counts.** `baseline_knee` is what the gait had already
## produced, and the gait owns its own vertical travel through `bob_meters`.
## Compensating the total would count a runner's stance compression twice.
##
## **Only while a foot is down.** In flight the hips are ballistic and the foot
## is free, so a tucked knee lifts the shoe rather than lowering the body --
## which is exactly what a spike's tuck and a block's flight should look like.
## `elevation` is how much of that applies.
##
## The leg that matters is the *straighter* one, because that is the one holding
## the voli up. During a stride the deeply folded leg is the swing leg with
## nothing under it.
## Where a signature effect sits for this action, in metres above the feet.
func _signature_anchor_height(event_type: int) -> float:
	var reach := REFERENCE_RIG_HEIGHT_M * maxf(body_height_scale, 0.5)
	match event_type:
		RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.BLOCK, \
		RallyEventModel.EventType.SERVE:
			## At the hand, and above the jump the body is already carrying.
			return reach * 1.06 + body_pivot.position.y
		RallyEventModel.EventType.SET:
			return reach * 0.92 + body_pivot.position.y
	## A floor contact happens off the platform, out in front and low.
	return reach * 0.36 + body_pivot.position.y


func _ground_the_feet(elevation: float, baseline_knee: float) -> void:
	## **Unless the pose already did it exactly.** The dig computes its own hip
	## height from where its feet finished, and this approximation -- which knows
	## about the shank and nothing about the thigh, the stance or the trunk --
	## would then lower it again by a number that was never right for a crouch.
	if _feet_already_grounded:
		_feet_already_grounded = false
		return
	var current := maxf(
		(left_leg.get_node("Knee") as Node3D).rotation_degrees.x,
		(right_leg.get_node("Knee") as Node3D).rotation_degrees.x,
	)
	if current >= baseline_knee - 0.01:
		return
	var shank := leg_bone_lengths.y
	var before := shank * cos(deg_to_rad(baseline_knee))
	var after := shank * cos(deg_to_rad(current))
	body_pivot.position.y += (after - before) \
		* (1.0 - clampf(elevation, 0.0, 1.0))


## When in a contact's phase the player stops running and starts squaring up.
##
## Not one number, because the actions differ in a way anyone who has played
## will recognise. A defender waiting on a serve is facing the ball almost the
## whole time -- they are shuffling, not travelling, and the platform has to be
## pointed at the ball well before it arrives. A hitter is the opposite: they
## run their approach facing where they are going and only turn to the ball in
## the last stride, because turning early is how you approach badly.
##
## A blocker never turns to the ball at all. They face the net, which is where
## `contact_direction` happens to point anyway, so their value is nominal.
const SQUARE_UP_PHASE := {
	RallyEventModel.EventType.RECEPTION: -0.85,
	## Both defensive contacts turn to face the ball the same way.
	RallyEventModel.EventType.DIG: -0.85,
	RallyEventModel.EventType.ATTACK_COVERAGE: -0.85,
	RallyEventModel.EventType.SET: -0.70,
	RallyEventModel.EventType.SERVE: -0.90,
	RallyEventModel.EventType.BLOCK: -1.0,
	RallyEventModel.EventType.ATTACK: -0.35,
}
const DEFAULT_SQUARE_UP_PHASE: float = -0.60

## When a passer starts bringing their arms together, and when the platform is
## fully formed.
##
## Both on the signed contact phase, so they scale with the flight rather than
## being a fixed number of milliseconds -- a passer has as long as the ball
## takes, and a short serve leaves less of it. The platform is complete a little
## *before* contact, which is what a passer is trying to do: get set, then let
## the ball arrive at a surface that is already still.
const PLATFORM_PHASE: float = -0.34
const PLATFORM_SET_PHASE: float = -0.08

## How far up an arm that did not make the wall still comes.
##
## Not zero: a blocker who only got one arm across is not standing with the other
## by their side, they are travelling with it. Most of the way back to the gait
## keeps it recognisably an arm in motion rather than a second wall.
const TRAILING_ARM_REACH: float = 0.30
## And when the legs finish driving through it.
##
## **A pass is played with the legs.** The platform is set early and then held
## still -- coaches teach actively against swinging it, because an arm swing is
## what makes a pass unrepeatable -- and what supplies the lift and the direction
## is the knees and hips extending under a quiet platform. So the drive starts a
## little before the ball arrives, is already underway at contact, and carries on
## afterwards: the follow-through of a pass is the body rising and travelling
## toward the target, not the arms going anywhere.
##
## Before this the posture simply froze at `PLATFORM_SET_PHASE` and stayed frozen
## for the whole outgoing flight -- a passer crouched at full depth watching the
## ball they had already played.
const PLATFORM_DRIVE_START: float = -0.14
const PLATFORM_DRIVE_END: float = 0.34
## Where the recovery's own 0-to-1 lives inside the pose phase.
##
## It starts at contact rather than before it, and finishes before the pose does
## so a voli is back on their feet with a moment to spare rather than arriving
## upright exactly as the next contact begins.
const RECOVERY_START_PHASE: float = 0.0
const RECOVERY_END_PHASE: float = 0.86


func _square_up_phase(event_type: int) -> float:
	return float(SQUARE_UP_PHASE.get(event_type, DEFAULT_SQUARE_UP_PHASE))


## How high off the floor counts as airborne, in normalised elevation.
## NOTE both bounds were picked by eye; no probe has measured the settling
## noise floor or the lowest real jump -- FAILURE_MODES.md section 0
const AIRBORNE_ELEVATION: float = 0.14
const GROUNDED_ELEVATION: float = 0.03


## Notice a touchdown and start the landing clock.
##
## NOTE observed rather than announced -- elevation and event type already
## arrive every frame, so no caller has to remember to report a landing
func _track_landing(event_type: int, elevation: float) -> void:
	if elevation >= AIRBORNE_ELEVATION:
		_was_airborne = true
		_airborne_action = _landing_action_name(event_type)
	elif _was_airborne and elevation <= GROUNDED_ELEVATION:
		_was_airborne = false
		_landing_remaining = LandingBiomechanicsScript.duration_seconds(
			_airborne_action
		)
	elif _landing_remaining > 0.0:
		_landing_remaining = maxf(_landing_remaining - get_process_delta_time(), 0.0)


## The stance in effect this instant, partway between the last one and the one
## asked for.
##
## `tick` is false when the setter asks -- it wants to know where the body is,
## not to advance it -- and true from `set_pose`, which is called once per frame
## per actor and is therefore the honest place for the clock to run.
func _stance_joints(tick: bool) -> Dictionary:
	var target := ReadyStance.joints(ready_stance)
	if _stance_remaining <= 0.0 or _stance_from.is_empty():
		return target
	if tick:
		_stance_remaining = maxf(
			_stance_remaining - get_process_delta_time(), 0.0
		)
	return StanceTransitionScript.blend(
		_stance_from, target,
		1.0 - _stance_remaining / maxf(_stance_duration, 0.0001),
	)


## Remember a floor recovery for as long as it takes to finish it.
##
## Refreshed on every frame this voli is drawn as the contact actor, so what
## survives the end of the window is the last state it was in -- the same shape
## `_track_landing` uses, and for the same reason.
##
## `platform` recoveries cost nothing: a defender who stayed on their feet has
## nothing to get up from, and arming a clock for them would put every dig in
## the game through a transition that does not exist.
func _track_floor_recovery(
	event_type: int, phase: float, is_contact_actor: bool
) -> void:
	var floor_action := event_type == RallyEventModel.EventType.RECEPTION \
		or event_type == RallyEventModel.EventType.DIG \
		or event_type == RallyEventModel.EventType.ATTACK_COVERAGE
	if is_contact_actor and floor_action and contact_recovery != "platform":
		_floor_recovery = contact_recovery
		_floor_posture = contact_posture
		_floor_duration = StanceTransitionScript.floor_seconds(contact_recovery)
		## What is left of the getting-up, in seconds. Handing over at clock 0.6
		## leaves 40 per cent of the duration, and `_apply_floor_recovery`
		## recovers 0.6 from it -- so the overlay resumes the recovery rather
		## than restarting it.
		_floor_remaining = _floor_duration * (1.0 - _recovery_clock(phase))
		_floor_joints = _capture_joints()
		return
	if not is_contact_actor and _floor_remaining > 0.0:
		_floor_remaining = maxf(
			_floor_remaining - get_process_delta_time(), 0.0
		)


## Finish getting up, after the window that started it has closed.
##
## Two things at once, in the order the in-window version does them: the limbs
## ease out of the pose the floor left them in and toward whatever the gait and
## the stance now say, and the recovery's own trunk motion continues over the
## top. Reversing that order would have the roll rotating a body that had
## already stood up.
func _apply_floor_recovery() -> void:
	var progress := 1.0 - _floor_remaining / maxf(_floor_duration, 0.0001)
	_blend_joints_toward(
		_floor_joints, 1.0 - StanceTransitionScript.settle(progress)
	)
	_apply_recovery_state(
		progress, _floor_direction, _floor_recovery, _floor_posture
	)


## Which landing an event leaves behind. A jump serve lands like a serve, a
## spike like a spike, and a block like a block; everything else that somehow
## got airborne gets the neutral absorb.
func _landing_action_name(event_type: int) -> String:
	match event_type:
		RallyEventModel.EventType.ATTACK:
			return "attack"
		RallyEventModel.EventType.BLOCK:
			return "block"
		RallyEventModel.EventType.SERVE:
			return "serve"
	return "default"


## Fold this voli into the landing they are partway through.
##
## Applied over the gait rather than instead of it, so a hitter who lands and
## immediately starts moving is absorbing *and* stepping, which is what actually
## happens. The knee takes the deeper of the two, because a leg cannot be both
## folding to absorb a landing and straight for a stride.
func _apply_landing() -> void:
	var duration := LandingBiomechanicsScript.duration_seconds(_airborne_action)
	var progress := 1.0 - _landing_remaining / maxf(duration, 0.0001)
	var landing := LandingBiomechanicsScript.resolve(progress, _airborne_action)
	body_pivot.rotation.x += float(landing.torso_pitch_radians)
	var lead_leg := left_leg if dominant_hand == "Left" else right_leg
	var trail_leg := right_leg if dominant_hand == "Left" else left_leg
	lead_leg.rotation_degrees.x += float(landing.lead_hip_degrees)
	trail_leg.rotation_degrees.x += float(landing.trail_hip_degrees)
	var fold := float(landing.knee_degrees)
	for leg in [left_leg, right_leg]:
		var knee := leg.get_node("Knee") as Node3D
		knee.rotation_degrees.x = minf(knee.rotation_degrees.x, fold)
	## A blocker's hands are still up on the touchdown frame and come down after
	## the feet; everyone else's swing down and forward for balance. `arm_hold`
	## carries which of those this is, so the two are one expression.
	##
	## Blended into the gait's swing by how much landing is left rather than
	## assigned over it. Assigned, the arms would snap from the landing's value
	## back to the stride's on the frame the timer expires -- a pop at exactly the
	## moment this overlay exists to remove one.
	var arm := float(landing.arm_degrees)
	var arm_weight := maxf(float(landing.absorb), float(landing.arm_hold))
	left_arm.rotation_degrees.x = lerpf(
		left_arm.rotation_degrees.x, arm, arm_weight
	)
	right_arm.rotation_degrees.x = lerpf(
		right_arm.rotation_degrees.x, arm, arm_weight
	)


## Bend one arm at the elbow. Positive folds the forearm forward, matching the
## knee's convention of positive folding the shank back -- both are "toward the
## way the joint actually goes".
func _set_elbow(arm: Node3D, bend_degrees: float) -> void:
	var elbow := arm.get_node_or_null("Elbow") as Node3D
	if elbow != null:
		elbow.rotation_degrees = Vector3(bend_degrees, 0.0, 0.0)


## The ankle, written onto the shoe mesh's own transform.
##
## The leg's counterpart to `_set_elbow`, and the reason the rig needs no new
## node for a foot: `Knee/Shoe` is a `MeshInstance3D`, a `MeshInstance3D` is a
## `Node3D`, and its transform was already in the scene holding a constant. What
## was missing was somebody writing to it.
##
## Null-tolerant on the same principle as `_set_elbow`: a silhouette variant
## that has no shoe should lose its ankle, not crash.
func _set_ankle(
	leg: Node3D, ankle_degrees: float, roll_correction_degrees: float = 0.0
) -> void:
	var shoe := leg.get_node_or_null("Knee/Shoe") as Node3D
	if shoe != null:
		shoe.rotation_degrees.x = SHOE_BASE_PITCH_DEGREES + ankle_degrees
		shoe.rotation_degrees.z = roll_correction_degrees


## How far this leg's hip has to give back, in pitch and roll degrees, to leave
## the foot where it was set down. Zero when the foot is in the air, on the frame
## it lands, or when there is no shoe to read.
##
## Measured *after* the gait has been written, because the question is where the
## gait put the foot -- asking before would be asking about last frame's pose.
## Both components in the floor plane are corrected. Pitch pays fore-aft slip;
## roll pays lateral slip during a shuffle, and its inverse at the shoe keeps the
## sole from banking with the hip.
func _plant_correction(leg: Node3D, side: int, in_stance: bool) -> Vector2:
	var shoe := leg.get_node_or_null("Knee/Shoe") as Node3D
	## A plant is a claim about world space, and an actor outside the tree has
	## none -- `global_position` on a detached node returns identity and warns.
	## Posing a detached rig is legitimate (the suite does it, and so does every
	## preview sheet), so this is a case to sit out rather than to complain about.
	if shoe == null or not in_stance or not is_inside_tree():
		_plant_active[side] = false
		return Vector2.ZERO
	var foot := shoe.global_position
	if not _plant_active[side]:
		## Touchdown. The anchor is wherever the gait just put this foot, so the
		## correction starts from zero and the plant never snaps the leg to a
		## position it did not choose.
		_plant_active[side] = true
		_plant_anchor[side] = foot
		return Vector2.ZERO
	## Both in the actor's own frame, because the body turns and a world-space
	## delta would read a turn as a slip.
	var anchored := to_local(_plant_anchor[side])
	var current := to_local(foot)
	var wanted := Vector2(anchored.x - current.x, anchored.z - current.z)

	## Measure this particular drawn leg rather than assuming its axes. The old
	## `slip / leg_span` approximation was correct for an upright forward gait and
	## wrong after the body leaned, turned, shuffled, or backpedaled -- precisely
	## the poses foot planting exists to support. One degree about each hip axis
	## gives a two-column local Jacobian from joint degrees to shoe movement.
	var base_rotation := leg.rotation_degrees
	leg.rotation_degrees.x = base_rotation.x + PLANT_JACOBIAN_SAMPLE_DEGREES
	var pitch_sample := to_local(shoe.global_position)
	leg.rotation_degrees = base_rotation
	leg.rotation_degrees.z = base_rotation.z + PLANT_JACOBIAN_SAMPLE_DEGREES
	var roll_sample := to_local(shoe.global_position)
	leg.rotation_degrees = base_rotation
	var pitch_axis := Vector2(
		pitch_sample.x - current.x, pitch_sample.z - current.z
	)
	var roll_axis := Vector2(
		roll_sample.x - current.x, roll_sample.z - current.z
	)
	var determinant := pitch_axis.x * roll_axis.y \
		- roll_axis.x * pitch_axis.y
	if absf(determinant) < 0.0000001:
		return Vector2.ZERO
	var pitch_samples := (
		wanted.x * roll_axis.y - roll_axis.x * wanted.y
	) / determinant
	var roll_samples := (
		pitch_axis.x * wanted.y - wanted.x * pitch_axis.y
	) / determinant
	## Clamped because a correction large enough to matter is a sign the anchor
	## is stale, and holding a wrong foot down is worse than letting a right one
	## slide. The inverse rotation written at the shoe below keeps its sole level.
	return Vector2(
		clampf(
			pitch_samples * PLANT_JACOBIAN_SAMPLE_DEGREES
				* PLANT_CORRECTION_GAIN,
			-PLANT_CORRECTION_LIMIT_DEGREES, PLANT_CORRECTION_LIMIT_DEGREES,
		),
		clampf(
			roll_samples * PLANT_JACOBIAN_SAMPLE_DEGREES
				* PLANT_CORRECTION_GAIN,
			-PLANT_CORRECTION_LIMIT_DEGREES, PLANT_CORRECTION_LIMIT_DEGREES,
		),
	)


## Pose this voli for one instant of one contact.
##
## **`phase` is signed, and contact is at 0.** It runs -1 at the start of the
## wind-up, through 0 at the moment the ball is struck, to +1 at the end of the
## follow-through -- which means it spans *two* playback windows: the negative
## half plays during the incoming ball's flight and the positive half during the
## outgoing one.
##
## It used to be 0 to 1 within each window independently, and the cost of that
## was not subtle. Every contact pose was drawn one whole window late: the
## attacker was cocked behind their head at the frame the ball left their hand,
## the server the same, the setter still gathering. Worse, the attacker is posed
## in *both* windows -- once as the upcoming contact and once as the current one
## -- so the entire swing played through during the approach, snapped back to
## fully cocked at the instant of contact, and played again while the ball was
## already crossing the net. Elevation was continuous across that boundary and
## only the arms teleported, which is why it read as a broken limb rather than a
## timing error.
func _apply_torso_deformation(
	event_type: int, phase: float, is_contact_actor: bool,
	contact_direction: Vector2,
) -> void:
	torso.scale = torso_rest_scale
	torso.rotation = Vector3.ZERO
	if not is_contact_actor:
		return
	var compression := 0.0
	var extension := 0.0
	match event_type:
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DIG, RallyEventModel.EventType.ATTACK_COVERAGE:
			compression = smoothstep(-0.35, 0.18, phase) * (1.0 - smoothstep(0.55, 1.0, phase))
		RallyEventModel.EventType.SET:
			compression = 1.0 - smoothstep(-0.45, 0.05, phase)
			extension = smoothstep(-0.08, 0.55, phase) * (1.0 - smoothstep(0.72, 1.0, phase))
		RallyEventModel.EventType.ATTACK:
			## Applied after the joint solve, where the connected head and shoulder
			## roots can travel with the torso instead of being reset underneath it.
			pass
		RallyEventModel.EventType.BLOCK:
			compression = 1.0 - smoothstep(-0.58, -0.18, phase)
			extension = smoothstep(-0.28, 0.08, phase) * (1.0 - smoothstep(0.55, 0.95, phase))
		RallyEventModel.EventType.SERVE:
			compression = smoothstep(-0.75, -0.38, phase) * (1.0 - smoothstep(-0.18, 0.04, phase))
			extension = smoothstep(-0.24, 0.04, phase) * (1.0 - smoothstep(0.50, 0.90, phase))
	var response := _body_motion_response()
	var vertical := 1.0 - 0.10 * compression * response + 0.085 * extension * response
	var width := 1.0 + 0.07 * compression * response - 0.045 * extension * response
	torso.scale = Vector3(
		torso_rest_scale.x * width,
		torso_rest_scale.y * vertical,
		torso_rest_scale.z * width,
	)
	var handed := -1.0 if dominant_hand == "Left" else 1.0
	var action_roll := 0.0
	if event_type in [RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.SERVE]:
		action_roll = handed * (extension - compression * 0.35) * 4.5 * response
	elif event_type in [RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DIG, RallyEventModel.EventType.ATTACK_COVERAGE]:
		action_roll = clampf(contact_direction.x, -1.0, 1.0) * compression * 5.0 * response
	torso.rotation.z = deg_to_rad(action_roll)


func _body_motion_response() -> float:
	match body_type:
		"Feli", "Simi": return 1.18
		"Avi": return 1.10
		"Cani": return 0.96
		"Ursi": return 0.78
		"Vegi": return 1.12 if produce in ["Stalk", "Aubergine"] else 0.92
	return 1.0


## Secondary weight shift belongs to the whole toy, not only the torso mesh.
## The primary biomechanics still own every joint; this adds the small opposing
## lean that makes anticipation load one side and follow-through finish on the
## other. It is deliberately a single-body curve, not an anatomical spine.
func _apply_secondary_body_motion(
	event_type: int, phase: float, contact_direction: Vector2,
	action_context: Dictionary,
) -> Dictionary:
	var performance := CoreVoliPerformanceScript.resolve(
		event_type, phase, body_type, dominant_hand, contact_direction,
		action_context, block_arms, _body_motion_response(),
	)
	body_pivot.rotation.z += deg_to_rad(float(performance.body_roll_degrees))
	body_pivot.position.x += float(performance.lateral_metres) * body_height_scale
	# The head counterweight is deliberately small and added after the head's
	# actual gaze. It changes the read of force without choosing what is watched.
	head.rotation.x += deg_to_rad(float(performance.head_pitch_degrees))
	head.rotation.z += deg_to_rad(float(performance.head_roll_degrees))
	return performance


func _restore_passive_anatomy() -> void:
	for cosmetic in _cosmetics():
		if not cosmetic.has_meta("performance_rest_rotation"):
			continue
		cosmetic.rotation = Vector3(cosmetic.get_meta("performance_rest_rotation"))
		cosmetic.position = Vector3(cosmetic.get_meta("performance_rest_position"))


func _apply_passive_anatomy(performance: Dictionary, weight: float = 1.0) -> void:
	var w := clampf(weight, 0.0, 1.0)
	for cosmetic in _cosmetics():
		if not cosmetic.has_meta("performance_rest_rotation"):
			continue
		var angles := CoreVoliPerformanceScript.passive_response(
			body_type, str(cosmetic.name), performance, dominant_hand
		) * w
		if angles.is_zero_approx():
			continue
		var rest_rotation := Vector3(cosmetic.get_meta("performance_rest_rotation"))
		var rest_position := Vector3(cosmetic.get_meta("performance_rest_position"))
		var root := Vector3(cosmetic.get_meta("performance_root_local", Vector3.ZERO))
		var rest_basis := Basis.from_euler(rest_rotation)
		var scaled_root := root * cosmetic.scale
		var moved_rotation := rest_rotation + Vector3(
			deg_to_rad(angles.x), deg_to_rad(angles.y), deg_to_rad(angles.z)
		)
		var moved_basis := Basis.from_euler(moved_rotation)
		cosmetic.rotation = moved_rotation
		# Preserve the attachment point while the free end follows through.
		cosmetic.position = rest_position \
			+ rest_basis * scaled_root - moved_basis * scaled_root


func _apply_action_handoff() -> void:
	if _landing_remaining > 0.0 or _floor_remaining > 0.0:
		_handoff_remaining = 0.0
		_last_pose_was_contact = false
		return
	if _last_pose_was_contact:
		_last_pose_was_contact = false
		if _last_contact_phase >= 0.35 and not _last_contact_joints.is_empty():
			_handoff_joints = _last_contact_joints.duplicate(true)
			_handoff_duration = CoreVoliPerformanceScript.handoff_seconds(
				_last_contact_event
			)
			_handoff_remaining = _handoff_duration
	if _handoff_remaining <= 0.0 or _handoff_joints.is_empty():
		return
	var progress := 1.0 - _handoff_remaining / maxf(_handoff_duration, 0.0001)
	var weight := CoreVoliPerformanceScript.handoff_weight(progress)
	_blend_joints_toward(_handoff_joints, weight)
	_apply_passive_anatomy(_last_contact_performance, weight)
	_handoff_remaining = maxf(
		_handoff_remaining - get_process_delta_time(), 0.0
	)


## Quiet life under the action layer. The biomechanics resolver bounds every
## amplitude; this weight removes it continuously as locomotion appears and
## suppresses it completely for a contact actor.
func _apply_idle_motion(is_contact_actor: bool) -> void:
	var weight := (1.0 - gait_blend) * (0.0 if is_contact_actor else 1.0)
	if weight <= 0.0001:
		return
	var idle := IdleBiomechanicsScript.resolve(
		_presentation_time_seconds, player_id, ready_stance
	)
	body_pivot.position.y += float(idle.rise_metres) * weight * body_height_scale
	body_pivot.position.x += float(idle.lateral_metres) * weight * body_height_scale
	body_pivot.rotation.z += deg_to_rad(float(idle.torso_roll_degrees) * weight)
	## Chest expansion is small and applied over the silhouette's authored scale.
	body_pivot.scale.y *= lerpf(1.0, float(idle.torso_scale_y), weight)
	var knee_add := float(idle.knee_degrees) * weight
	for leg in [left_leg, right_leg]:
		var knee := leg.get_node_or_null("Knee") as Node3D
		if knee != null:
			knee.rotation_degrees.x += knee_add
	var arm_lag := float(idle.arm_lag_degrees) * weight
	left_arm.rotation_degrees.x += arm_lag
	right_arm.rotation_degrees.x -= arm_lag


## Add the commitment and flight that precede a resolved floor recovery. The
## recovery model still owns contact-to-floor-to-standing; this overlay supplies
## the missing push toward the ball before phase zero.
func _apply_dive_receive_overlay(
	phase: float, contact_direction: Vector2
) -> void:
	var diving := DefenseActionBiomechanicsScript.is_diving(
		contact_posture, contact_recovery
	)
	var dive := DefenseActionBiomechanicsScript.resolve(phase, diving)
	if float(dive.dive_weight) <= 0.0001:
		return
	body_pivot.position.z -= float(dive.forward_metres) * body_height_scale
	body_pivot.position.y -= float(dive.drop_metres) * body_height_scale
	body_pivot.rotation.x += float(dive.torso_pitch_radians)
	var trail_leg := right_leg if contact_direction.x <= 0.0 else left_leg
	trail_leg.rotation_degrees.x += float(dive.trail_hip_degrees)


## Blink and pupil drift are overlays on the built expression, never new faces.
## At contact the eyes remain open; the choreography spec makes that a hard
## presentation rule rather than a probabilistic coincidence.
func _apply_face_micro_motion(is_contact_actor: bool, phase: float) -> void:
	var suppress_blink := is_contact_actor and absf(phase) < 0.22
	var blink := IdleBiomechanicsScript.blink_weight(
		_presentation_time_seconds, player_id, suppress_blink
	)
	var pupil := IdleBiomechanicsScript.pupil_offset(
		_presentation_time_seconds, player_id
	)
	var attention := Vector2.ZERO
	if _has_attention_target:
		attention = CoreVoliPerformanceScript.pupil_attention_offset(
			Vector2(look_yaw, look_pitch),
			Vector2(_look_target_yaw, _look_target_pitch),
		)
	var head_radius := float(Dictionary(silhouette.get("head", {})).get(
		"radius", 0.13
	))
	for feature in _face_features():
		var base_scale: Vector3 = feature.get_meta(
			"micro_base_scale", Vector3.ONE
		)
		var base_position: Vector3 = feature.get_meta(
			"micro_base_position", feature.position
		)
		feature.scale = base_scale
		feature.position = base_position
		if str(feature.name).begins_with("Eye") \
				or str(feature.name).begins_with("Pupil"):
			feature.scale.y = base_scale.y * lerpf(1.0, 0.08, blink)
		if str(feature.name).begins_with("Pupil") and blink < 0.92:
			feature.position.x += (pupil.x + attention.x) * head_radius
			feature.position.y += (pupil.y + attention.y) * head_radius


func set_pose(
	event_type: int,
	elevation: float,
	phase: float,
	contact_direction: Vector2,
	is_contact_actor: bool,
	action_context: Dictionary = {},
) -> void:
	_ensure_node_bindings()
	_restore_passive_anatomy()
	## Presentation channels that translate structural anchors are rewritten from
	## the configured body on every frame. Without this reset a chest rotation or
	## mass extension would be integrated repeatedly and the rig would drift.
	if torso_rest_position != Vector3.ZERO:
		torso.position = torso_rest_position
	if head_rest_position != Vector3.ZERO:
		head.position = head_rest_position
	for wrist in [left_wrist, right_wrist]:
		if wrist != null:
			wrist.rotation = Vector3.ZERO
	if is_inside_tree():
		_presentation_time_seconds += get_process_delta_time()
	_advance_head_attention()
	_track_landing(event_type, elevation)
	var lift := clampf(elevation, 0.0, 1.0) * 0.82
	## Every joint of the walk-to-run comes from `GaitBiomechanics`, which knows
	## the difference between the two. This branch used to be a single sine at a
	## fixed 32-degree amplitude with the knees explicitly zeroed on the next
	## line, so every voli on the court walked at exactly one speed with legs
	## that never bent, whether they were strolling to a seat or sprinting for a
	## dig. Its leg cycle is rooted at upright standing; the named ready stance
	## releases first as an initial hip-led weight shift, so a crouched defender's
	## shoe geometry is not mistaken for a walking step.
	var gait := GaitBiomechanicsScript.resolve(
		stride_cycle, ground_speed_mps, travel_heading_offset,
		_stance_joints(true),
	)
	gait_blend = float(gait.gait_blend)
	locomotion_bob = float(gait.bob_meters)
	body_pivot.position = Vector3(0.0, lift + locomotion_bob, 0.0)
	body_pivot.rotation = Vector3(float(gait.torso_pitch_radians), 0.0, 0.0)
	body_pivot.scale = Vector3.ONE * body_height_scale
	_apply_torso_deformation(event_type, phase, is_contact_actor, contact_direction)
	left_arm.rotation_degrees = Vector3(float(gait.left_arm_degrees), 0.0, -12.0)
	right_arm.rotation_degrees = Vector3(float(gait.right_arm_degrees), 0.0, 12.0)
	left_arm.position = Vector3(-shoulder_offset.x, shoulder_offset.y, 0.0)
	right_arm.position = Vector3(shoulder_offset.x, shoulder_offset.y, 0.0)
	## The z component is the stance's *width*, and it used to be a hard zero --
	## which is why a ready stance could only ever be a lean. Mirrored the way
	## `_stance_roll` mirrors, so both legs carry out from under the hips rather
	## than both leaning the same way.
	var abduction := float(gait.get("abduction_degrees", 0.0))
	left_leg.rotation_degrees = Vector3(
		float(gait.left_hip_degrees), 0.0, -abduction
	)
	right_leg.rotation_degrees = Vector3(
		float(gait.right_hip_degrees), 0.0, abduction
	)
	## The knees now carry the gait rather than being flattened. They are still
	## rewritten from scratch every frame, which is what stops a dig leaving the
	## defender bent for the rest of the rally.
	(left_leg.get_node("Knee") as Node3D).rotation_degrees = Vector3(
		float(gait.left_knee_degrees), 0.0, 0.0
	)
	(right_leg.get_node("Knee") as Node3D).rotation_degrees = Vector3(
		float(gait.right_knee_degrees), 0.0, 0.0
	)
	## **The ankle, which the rig has always had and never used.**
	##
	## `Shoe` is a `MeshInstance3D` under `Knee` carrying a constant `(90, 0, 0)`
	## from the scene, so a foot rotated with whatever the leg above it was
	## doing: the sole tipped through the floor at midstance and pointed at the
	## sky through swing. Adding a joint was never necessary -- a
	## `MeshInstance3D` is a `Node3D` and this transform was already there,
	## holding still.
	##
	## `SHOE_BASE_PITCH_DEGREES` is that scene value and the gait's angle is
	## added to it rather than replacing it, so the mesh keeps the orientation it
	## was modelled in and only the ankle moves.
	var left_ankle := float(gait.get("left_ankle_degrees", 0.0))
	var right_ankle := float(gait.get("right_ankle_degrees", 0.0))
	_set_ankle(left_leg, left_ankle)
	_set_ankle(right_leg, right_ankle)
	## **And then the foot stays where it was put.**
	##
	## Read after the gait is written and applied on top of it, so the stride is
	## still the thing driving the leg and this only spends the difference between
	## where the cycle put the foot and where the ground is. Each correction is
	## added at the hip and subtracted at the ankle, which is what keeps the sole
	## flat while the shin swings over it -- the same cancellation the gait does
	## for the stance phase, extended to cover the correction.
	##
	## The first hip-led weight shift is allowed to happen inside the ready base;
	## once a leg cycle is legible, however, a planted foot is a world-space
	## constraint rather than a percentage. Scaling it directly by `gait_blend`
	## left a slow backpedal paying only three quarters of every correction and
	## visibly skating for the unpaid quarter on every frame.
	var plant := smoothstep(0.08, 0.35, gait_blend) \
		if foot_plant_enabled else 0.0
	if plant > 0.001:
		var left_plant := _plant_correction(
			left_leg, _PLANT_LEFT, bool(gait.get("left_in_stance", false))
		) * plant
		var right_plant := _plant_correction(
			right_leg, _PLANT_RIGHT, bool(gait.get("right_in_stance", false))
		) * plant
		left_leg.rotation_degrees.x += left_plant.x
		right_leg.rotation_degrees.x += right_plant.x
		left_leg.rotation_degrees.z += left_plant.y
		right_leg.rotation_degrees.z += right_plant.y
		_set_ankle(left_leg, left_ankle - left_plant.x, -left_plant.y)
		_set_ankle(right_leg, right_ankle - right_plant.x, -right_plant.y)
	else:
		_plant_active[_PLANT_LEFT] = false
		_plant_active[_PLANT_RIGHT] = false
	## The head keeps its own heading through a pose change. Everything else here
	## is reset each frame; the look is not, because it is a decision about what
	## the voli is watching rather than a property of the action they are in.
	_apply_head_look()
	## NOTE the gait's elbow wins when it is larger; the ready bend is a floor,
	## not zero, because nobody stands with their arms locked straight
	var carried_elbow := maxf(READY_ELBOW_BEND, float(gait.elbow_degrees))
	_set_elbow(left_arm, carried_elbow)
	_set_elbow(right_arm, carried_elbow)
	_apply_idle_motion(is_contact_actor)
	## The landing sits on top of the gait and under the contact pose: a voli who
	## has just come down is absorbing it whatever else they are doing, and a voli
	## who is playing the ball right now is doing that instead.
	if not is_contact_actor and _landing_remaining > 0.0:
		_apply_landing()
	## **And getting up off the floor, which nothing did.**
	##
	## The recovery runs on `_recovery_clock`, which is a *phase* -- so it only
	## advances while playback is still drawing this voli as the contact actor,
	## and the moment that window closes the body snaps to standing from
	## wherever it had got to. Photographed at 0.86 the roll is upright with the
	## arms still out; the half-kneel never came up at all.
	##
	## Carried on a clock in seconds for exactly the reason the landing is: the
	## thing that has to survive is the part that happens *after* the action, and
	## a phase cannot outlive its own window.
	if not is_contact_actor and _floor_remaining > 0.0:
		_apply_floor_recovery()
	## What the gait alone would have folded the supporting knee to, kept so the
	## grounding below can tell a pose's crouch apart from a stride's.
	var gait_knee := maxf(
		float(gait.left_knee_degrees), float(gait.right_knee_degrees)
	)
	shadow.scale = Vector3.ONE * lerpf(1.0, 1.35, elevation)
	shadow.transparency = lerpf(0.0, 0.58, elevation)
	var signature_move := str(action_context.get("signature_move", ""))
	var signature_charge := float(action_context.get(
		"signature_charge", 1.0 if not signature_move.is_empty() else 0.0
	))
	## Portfolio/unit callers can pose an actor before it enters the tree, while
	## @onready bindings are still null. The body pose remains pure in that case;
	## the attached court actor gains the effect as soon as it is ready.
	if signature_surge != null:
		## The effect belongs where the action does. A swing and a block are
		## struck at the top of the reach; a dig is played off the platform in
		## front of the hips. `body_pivot.position.y` already carries the jump, so
		## the anchor rises with it rather than being a constant.
		signature_surge.contact_anchor_meters = _signature_anchor_height(event_type)
		## The gallery can assign this directly; live playback cannot. Prefer the
		## body's displacement from the movement plan in this frame, falling back
		## to the resolved action/contact direction when the body is planted. This
		## keeps leftward and along-court trails on the side the action actually
		## came from instead of every cue inheriting SignatureSurge3D's +X default.
		var signature_direction := action_movement_direction \
			if _signature_movement_frame == Engine.get_process_frames() \
			else contact_direction
		if signature_direction.length_squared() > 0.0001:
			signature_surge.action_direction = signature_direction.normalized()
		signature_surge.set_cue(
			signature_move, signature_charge,
			bool(action_context.get("signature_succeeded", false)), phase,
		)
	if contact_direction.length_squared() > 0.0001:
		## Godot's forward is -Z, and this rig genuinely faces that way -- both
		## shoes sit at z = -0.06. Rotating by theta about Y puts local -Z at
		## world (-sin theta, -cos theta), so facing (dx, dz) needs
		## atan2(-dx, -dz). Passing (dx, dz) instead yields theta + PI, which
		## drew every server, setter and attacker with their back to the ball.
		##
		## The direction is still in normalized court space, where x spans 9 m
		## and y spans 18 m, so the angle remains slightly aspect-compressed.
		## That is a much smaller error than the sign and is left for a caller
		## that knows the court dimensions.
		## The contact actor faces the ball -- but only once they are close
		## enough to contact to be squaring up for it.
		##
		## This override used to run for the whole window, and that is what made
		## every player strafe. A hitter is posed as the upcoming contact from
		## phase -1, so they faced across the net for the entire approach and slid
		## sideways to their mark; a receiver ran to the ball crab-wise. Facing
		## is set from travel in `set_tactical_position` every frame, and this was
		## overwriting it on every one of them.
		##
		## Nothing here interpolates the turn: `_turn_toward` is already rate
		## limited, so simply declining to override until the squaring-up point
		## produces the turn for free, at a speed a body can actually manage.
		if event_type == RallyEventModel.EventType.BLOCK:
			## A blocker faces the net. Always, and not the ball.
			##
			## Every other contact takes its heading from where the ball is
			## going, and a block was doing the same -- from the *deflection*,
			## which points wherever the ball came off the hands. A stuffed ball
			## goes back into the hitter's court, so the blocker was handed a
			## heading pointing behind them and turned through 180 degrees in
			## mid-air while the announcer read out the block forming. Posing the
			## block a window earlier made it worse: two full flights to spin in
			## rather than one.
			##
			## The net runs along z = 0, so facing it is a matter of which side
			## the blocker stands on, and nothing about the ball enters into it.
			_turn_toward(0.0 if position.z > 0.0 else PI)
		elif event_type == RallyEventModel.EventType.SET \
				and bool(action_context.get("back_set", false)):
			## The defining fact of a back set is that the ball leaves behind the
			## setter. Turning the whole actor toward that flight converts it into a
			## front set before the arch and hand carry can be read.
			pass
		elif phase >= _square_up_phase(event_type) or not is_contact_actor:
			_turn_toward(atan2(-contact_direction.x, -contact_direction.y))
	if not is_contact_actor:
		_ground_the_feet(elevation, gait_knee)
		_apply_action_handoff()
		_apply_face_micro_motion(false, phase)
		return
	_handoff_remaining = 0.0
	var striking_arm := left_arm if dominant_hand == "Left" else right_arm
	var guide_arm := right_arm if dominant_hand == "Left" else left_arm
	var diving_floor_guard := event_type in [
		RallyEventModel.EventType.RECEPTION,
		RallyEventModel.EventType.DIG,
		RallyEventModel.EventType.ATTACK_COVERAGE,
	] and DefenseActionBiomechanicsScript.is_diving(
		contact_posture, contact_recovery
	)
	var contact_court_floor := 0.0
	if diving_floor_guard:
		# Ground reference after the ordinary gait/stance has been posed, before
		# any action-specific reach or fall can lower a limb through it.
		_force_transform_tree(body_pivot)
		contact_court_floor = _lowest_body_point()
	match event_type:
		RallyEventModel.EventType.SERVE:
			## Every joint comes from `ServeBiomechanics`, for the same reason the
			## spike and the block have their own modules: this branch was two
			## lines that saturated at -0.20 and then held, so a server cocked,
			## swung, and stood frozen with their arm overhead for the whole
			## outgoing flight -- no follow-through, no weight transfer, no toss
			## arm coming down, and no legs at all.
			var toss := ServeActionBiomechanicsScript.resolve(
				phase, -1.0 if dominant_hand == "Left" else 1.0,
				float(action_context.get("action_power", 0.0)),
				str(action_context.get("serve_style", "Standing")),
				int(action_context.get(
					"serve_routine_variant",
					ServeActionBiomechanicsScript.routine_variant(player_id),
				)),
			)
			body_pivot.rotation.x = float(toss.torso_pitch_radians)
			body_pivot.position.y += float(toss.get("rise_metres", 0.0)) \
				* body_height_scale
			## The trunk winding against the facing, applied here rather than by
			## turning the actor -- `_turn_toward` is where the voli is looking.
			body_pivot.rotation.y += deg_to_rad(float(toss.torso_twist_degrees))
			var serve_lead := left_leg if dominant_hand == "Left" else right_leg
			var serve_trail := right_leg if dominant_hand == "Left" else left_leg
			serve_lead.rotation_degrees.x = float(toss.lead_hip_degrees)
			serve_trail.rotation_degrees.x = float(toss.trail_hip_degrees)
			for leg in [left_leg, right_leg]:
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
					toss.knee_degrees
				)
			## Two axes on the hitting arm, as on the spike: the roll is what
			## carries the elbow out away from the ribs on the way back and brings
			## the hand across the body on the way down.
			striking_arm.rotation_degrees = Vector3(
				float(toss.striking_shoulder_degrees),
				float(toss.get("striking_internal_rotation_degrees", 0.0)),
				float(toss.striking_abduction_degrees)
			)
			_set_elbow(striking_arm, float(toss.striking_elbow_degrees))
			guide_arm.rotation_degrees.x = float(toss.guide_shoulder_degrees)
			_set_elbow(guide_arm, float(toss.guide_elbow_degrees))
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DIG, RallyEventModel.EventType.ATTACK_COVERAGE:
			## A dig is drawn by bending, not by squashing.
			##
			## This used to scale the whole actor on one axis -- head, produce
			## torso, beak and all -- because the leg was a single capsule with
			## nothing to bend. It now has a knee, and how far that knee folds is
			## the simulator's own verdict on the contact rather than a constant.
			##
			## Being forced low is tactically real: a defender who had to drop to
			## reach a ball played it differently from one who stayed on their
			## feet, and `_reception_pass_result` already decided which happened.
			## `contact_posture` is that decision, built from the defender's reach
			## margin, how deep into the edge of their range the ball was, and how
			## well their body could face it. Playback reads it; it does not
			## invent it.
			##
			## **But not for the whole flight.** A passer runs to the ball with
			## their arms swinging and forms the platform in the last stride --
			## nobody travels with their forearms already locked together. This
			## branch ran from phase -1, so a receiver crossed several metres of
			## court holding a finished platform out in front of them, which is
			## the single most obviously wrong thing a defender can do.
			##
			## Blended rather than switched, and by phase rather than by a timer,
			## so the arms come together over the approach to contact and are
			## there when the ball is. Before the blend starts the gait owns the
			## arms, which is what running looks like.
			if phase >= PLATFORM_PHASE:
				# Commitment is applied before posture/recovery grounding. Applied
				# afterwards, its vertical offset pushed an already-settled body
				# through the court and defeated `_settle_to_floor`.
				_apply_dive_receive_overlay(phase, contact_direction)
				_apply_dig_posture(
					smoothstep(PLATFORM_PHASE, PLATFORM_SET_PHASE, phase),
					smoothstep(PLATFORM_DRIVE_START, PLATFORM_DRIVE_END, phase),
					## Step 3: **the recovery has its own clock, and it starts at
					## contact.**
					##
					## This was `clampf(phase, 0, 1)` -- the same number the
					## approach runs on -- so a voli began going to the floor
					## while they were still travelling to the ball. Photographed
					## as a frame strip the shape is unmistakable: nothing visible
					## for the first 15% of the phase, then the entire collapse
					## between 15% and 40%, then five frames of a body already
					## down. A fall that has finished before the ball is played is
					## not a consequence of playing it.
					##
					## Renormalised so 0 is the contact and 1 is back on the feet.
					## The recovery curves inside `recovery_motion` -- down at
					## 0-0.34, travel at 0.08-0.82, roll at 0.18-0.88 -- were
					## written against a span that means this, and were being fed
					## one that did not.
					_recovery_clock(phase), contact_direction,
					phase,
				)

		RallyEventModel.EventType.SET:
			## Every joint comes from `SetBiomechanics`. What was here got the
			## preparation right and stopped: the release saturated at contact, so
			## past phase 0 the setter held the finish for the whole outgoing flight
			## with their hands stopped where the ball had been. The legs were never
			## touched at all, which left a setter standing straight-legged while
			## their arms did the work -- and a set is a push from the floor.
			## Which of the three second-contact actions this is. The simulator
			## decides it in `_jump_set_decision` and stamps `set_posture` and
			## `set_posture_reason` on the event; before this the rig drew all
			## three identically, so a setter who could not get off the floor and
			## one who jumped looked the same, and a ball taken off the platform
			## looked like a ball taken above the head.
			##
			## `under the hands` is the reason, not the posture, because the
			## posture only says they stayed down -- it cannot say *why*, and the
			## why is what decides whether the forearms or the fingers play it.
			var before_set := _capture_joints()
			var set_posture := SetBiomechanicsScript.POSTURE_STANDING
			if str(action_context.get("set_posture", "")) == "jump":
				set_posture = SetBiomechanicsScript.POSTURE_JUMP
			elif str(action_context.get("set_posture_reason", "")) \
					== "under the hands":
				set_posture = SetBiomechanicsScript.POSTURE_UNDERHAND
			var push := SetBiomechanicsScript.resolve(
				phase, -1.0 if dominant_hand == "Left" else 1.0, set_posture,
				bool(action_context.get("back_set", false)),
			)
			body_pivot.rotation.x = float(push.torso_pitch_radians)
			## Only the rise. The dip comes free from the knee fold below, which
			## `_ground_the_feet` turns into a body drop -- subtracting a crouch
			## here as well would lower the setter twice and put their shoes
			## through the floor, which is what the dig was doing.
			body_pivot.position.y += float(push.rise_metres) * body_height_scale
			var split := float(push.hip_split_degrees)
			left_leg.rotation_degrees.x = -split
			right_leg.rotation_degrees.x = split
			for leg in [left_leg, right_leg]:
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
					push.knee_degrees
				)
			var set_pitch := float(push.shoulder_degrees)
			var set_flare := float(push.flare_degrees)
			left_arm.rotation_degrees = Vector3(set_pitch, 0.0, set_flare)
			right_arm.rotation_degrees = Vector3(set_pitch, 0.0, -set_flare)
			_set_elbow(left_arm, float(push.elbow_degrees))
			_set_elbow(right_arm, float(push.elbow_degrees))
			## Hands can gather while the final adjustment step is still active.
			## The live gait supplies the captured joints; the shared arrival solve
			## progressively hands them to the existing set biomechanics.
			var set_arrival := ContactArrivalBiomechanicsScript.resolve(
				phase, ground_speed_mps, stride_cycle
			)
			_blend_upper_body_toward(
				before_set, 1.0 - float(set_arrival.upper_body_weight)
			)
			_blend_lower_body_toward(
				before_set, 1.0 - float(set_arrival.lower_body_weight)
			)
			body_pivot.rotation.z += deg_to_rad(
				float(set_arrival.momentum_roll_degrees)
			)
		RallyEventModel.EventType.ATTACK:
			## **The approach, which used to be a jog.**
			##
			## `SpikeBiomechanics` begins at its `PLANT_END`, phase -0.62, with both
			## feet already down and the arms already back. Everything before that
			## fell through to the running gait -- so every attacker in the game ran
			## to the net and then teleported into a plant, and the part of the
			## action a viewer actually reads to judge a swing was not drawn at all.
			##
			## Handed off rather than blended: at -0.62 the approach's close has the
			## feet square and the knees at `KNEE_LOAD_DEGREES`, which is the pose
			## the spike's plant starts from, so the two meet without a step in the
			## curve and neither model has to know about the other's timing.
			if phase < SpikeBiomechanics.PLANT_END:
				var run_up := ApproachBiomechanics.resolve(
					inverse_lerp(-1.0, SpikeBiomechanics.PLANT_END, phase),
					dominant_hand != "Left",
				)
				body_pivot.rotation.x = float(run_up.torso_pitch_radians)
				left_leg.rotation_degrees.x = float(run_up.left_hip_degrees)
				right_leg.rotation_degrees.x = float(run_up.right_hip_degrees)
				for leg in [left_leg, right_leg]:
					(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
						run_up.knee_degrees
					)
				left_arm.rotation_degrees.x = float(run_up.left_arm_degrees)
				right_arm.rotation_degrees.x = float(run_up.right_arm_degrees)
				_set_elbow(left_arm, float(run_up.elbow_degrees))
				_set_elbow(right_arm, float(run_up.elbow_degrees))
			else:
				_apply_spike_pose(phase, action_context)
		RallyEventModel.EventType.BLOCK:
			## Every joint comes from `BlockBiomechanics`, which sequences them
			## the way `SpikeBiomechanics` sequences a swing.
			##
			## This was the last static pose in the rig -- one set of angles with
			## no phase in it -- so the arms teleported to full extension on the
			## frame playback first posed this actor, held there for the whole
			## flight, and dropped out just as abruptly. What the peak of the
			## motion looks like is unchanged; the model is the route into and
			## out of it.
			##
			## A block *presses*: straight up is a player reaching, over the net
			## is a player taking space, and the difference is a forward lean
			## plus a shoulder shrug that arrives after the arms are already up.
			## The legs kick forward, not back -- a blocker leaves the floor from
			## a squat and the shins swing under and ahead of them on the way up.
			var wall := BlockBiomechanicsScript.resolve(
				phase,
				StringName(str(action_context.get("block_response", "wall"))),
				-1.0 if contact_direction.x < 0.0 else 1.0,
			)
			body_pivot.rotation.x = float(wall.torso_pitch_radians)
			left_leg.rotation_degrees.x = float(wall.lead_hip_degrees)
			right_leg.rotation_degrees.x = float(wall.trail_hip_degrees)
			for leg in [left_leg, right_leg]:
				## Backward, like every other knee in the file.
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
					wall.knee_degrees
				)
			var girdle := float(wall.shoulder_lift_meters)
			left_arm.position.y = shoulder_offset.y + girdle
			right_arm.position.y = shoulder_offset.y + girdle
			var reach := float(wall.shoulder_degrees)
			var spread := float(wall.hand_spread_degrees)
			## **Both arms only when both arms got there.**
			##
			## The wall's width has always narrowed with an unfinished close --
			## `half_width_m` is the close fraction times a body's half width --
			## and the drawing showed two arms locked out regardless, so a
			## one-armed reach and a sealed double block were the same picture.
			##
			## The uncommitted arm falls back toward the angle the gait already
			## put it at rather than having its reach scaled: `reach` is a
			## shoulder angle in degrees, and a fraction of an angle is not
			## a fraction of a movement. Interpolating to where the arm would
			## otherwise be is the only version that means anything.
			var trailing := lerpf(
				float(gait.left_arm_degrees), reach, TRAILING_ARM_REACH
			)
			var lead_left := contact_direction.x < 0.0
			var left_reach := reach
			var right_reach := reach
			match block_arms:
				&"one":
					## Reaching with the arm on the ball's side, which is the side
					## they were still travelling toward when they ran out of time.
					if lead_left:
						right_reach = trailing
					else:
						left_reach = trailing
				&"none":
					left_reach = trailing
					right_reach = trailing
			left_reach += float(wall.get("left_shoulder_delta_degrees", 0.0))
			right_reach += float(wall.get("right_shoulder_delta_degrees", 0.0))
			left_arm.rotation_degrees = Vector3(left_reach, 0.0, -spread)
			right_arm.rotation_degrees = Vector3(right_reach, 0.0, spread)
			## Straight at the press, and deliberately so. A block that bends at
			## the elbow is a block that gets driven back through the net, and
			## keeping it near zero *there* is what makes a block read as a wall
			## next to a set's folded triangle -- the two poses put the arms in
			## nearly the same place, and the elbow is the only thing telling
			## them apart. It folds again either side of the press, which is the
			## ready posture a blocker waits in.
			_set_elbow(left_arm, float(wall.elbow_degrees) \
				+ float(wall.get("left_elbow_delta_degrees", 0.0)))
			_set_elbow(right_arm, float(wall.elbow_degrees) \
				+ float(wall.get("right_elbow_delta_degrees", 0.0)))
			body_pivot.rotation.z += deg_to_rad(float(
				wall.get("response_roll_degrees", 0.0)
			))
	## Last, after the primary joint solution, so anticipation and follow-through
	## shift the completed toy-body silhouette instead of fighting the action's
	## biomechanics for ownership of individual limbs.
	var performance := _apply_secondary_body_motion(
		event_type, phase, contact_direction, action_context
	)
	## Last, after whichever branch ran, so every pose that crouches does it with
	## its feet on the ground rather than above it.
	_ground_the_feet(elevation, gait_knee)
	if diving_floor_guard:
		_keep_above_floor(contact_court_floor)
	## After the grounding, because the pose this hands over is the finished one.
	_track_floor_recovery(event_type, phase, is_contact_actor)
	_apply_face_micro_motion(true, phase)
	_apply_passive_anatomy(performance)
	_last_contact_joints = _capture_joints()
	_last_contact_event = event_type
	_last_contact_phase = phase
	_last_contact_performance = performance.duplicate(true)
	_last_pose_was_contact = true
	_apply_wing_for_state(event_type, is_contact_actor)


## Whether this rig is being lit or being *printed*.
##
## Unshaded at sticker size, because a hundred pixels of posterised directional
## lighting is a smudge and the silhouette does the shaping instead.
##
## A flag rather than a second rig: same voli, same kit, same body type, and only
## the lighting is a lie.
@export var flat_shading: bool = false


## The construction marks on this voli's shirt -- panels, seams, ticks, a band.
##
## **Value structure, because colour could not carry it.** Every regional kit is
## dark by necessity, so telling two sides apart by hue would mean making the
## kits louder and losing the contrast against the floor that was the point. How
## a shirt is *built* survives both grayscale and distance.
##
## Rebuilt rather than tinted, because a voli can be repainted at any time --
## theme change, kit change -- and a mark left over from a previous region is a
## Xérvyan rhythm on a Taktikãni shirt. Cheap: eight boxes at the very most, on
## a rig that already builds forty.
##
## A body whose torso is not kit -- a Vegi, whose produce *is* the body -- wears
## none. Marking those is drawing a placket on an aubergine.
func _build_kit_marks(wears_kit: bool) -> void:
	for existing in _kit_marks():
		existing.queue_free()
	if club_region.is_empty() or torso == null:
		return
	var trim := trim_colour()
	## Where a mark actually sits on the shirt.
	##
	## `RegionalKits.MARKS` places every mark at torso-local z ±0.112, and its own
	## comment calls that "just clear of the torso's own surface". It never was.
	## A kit mark is a child of the torso *mesh*, so that number has to clear the
	## torso's **radius** -- and the narrowest kit-wearing body in the roster is
	## 0.235 while the widest is 0.347. `probe_kit_mark_depth.gd` reports **15 of
	## 15** bodies burying their construction between 0.12 and 0.24 m inside the
	## shirt: every region, every build, since the table was written.
	##
	## So the whole "construction, not colour" system -- the one that exists so a
	## side stays nameable in a grayscale frame and at the distance a match is
	## watched from -- has been rendering nothing, and every kit has been reading
	## as a single flat colour, which is the exact thing it was built to stop.
	##
	## It was reviewed in a probe that drew the patterns flat and never put one on
	## a torso. That is how a table can be correct and invisible at once, and it
	## is the same shape of mistake as a threshold measured against the wrong
	## distribution.
	##
	## The authored z is therefore kept only for its **sign** -- front face or
	## back, which is what `marks_for` mirrors -- and the distance comes from the
	## body being dressed, plus half the mark's own depth so the slab sits proud
	## of the surface instead of half-sunk in it.
	var torso_spec: Dictionary = silhouette.get("torso", {})
	var torso_radius := float(torso_spec.get("radius", 0.28))
	## A mark can live on the shirt, on a sleeve or on a shorts leg.
	##
	## `MARKS` used to be torso-only, which quietly bounded what a kit could say:
	## Spëddigh's ticks belong on the sleeve and the hem, Pāwa Hitō's panel has to
	## reach the thigh to read as one sweep, and Lo-ong Ralī's whole idea is a
	## line that crosses the waist and keeps going. All three were being drawn as
	## torso decals of themselves.
	##
	## Placed on the **bone** rather than on the garment mesh, the same way
	## `_add_garments` hangs the sleeve and the cuff, so a mark travels with the
	## pose and needs no knowledge of where the garment was built.
	var arm_spec: Dictionary = silhouette.get("arm", {})
	var leg_spec: Dictionary = silhouette.get("leg", {})
	var arm_radius := float(arm_spec.get("top_radius", 0.07))
	var leg_radius := float(leg_spec.get("top_radius", 0.11))
	## Marks sit on the garment, not the limb under it. `_add_garments` builds a
	## flared shell from the clearing radius; using the naked limb radius here
	## buried every sleeve/shorts motif inside that shell, most visibly on Vegi
	## where those are the only regional surfaces. Use the middle of each flare,
	## which is the surface the authored mark spans.
	var sleeve_surface := BodyTypeModelsScript._clearing_radius(arm_radius, 1.30) * 1.32
	var shorts_surface := BodyTypeModelsScript._clearing_radius(leg_radius, 1.28) * 1.34
	var places := {
		"torso": [[torso, torso_radius]],
		"sleeves": [
			[left_arm, sleeve_surface],
			[right_arm, sleeve_surface],
		],
		"legs": [
			[left_leg, shorts_surface],
			[right_leg, shorts_surface],
		],
	}
	## RegionalKits authors against the reference cut, while the current body
	## system changes the cut itself. Scale the drawing in the garment's frame so
	## a full-height column stays full-height on Avi and Ursi, and an outer panel
	## stays at the same longitude on narrow and broad torsos. The host node's
	## later pose/physical scaling is inherited normally; these factors account
	## only for differences in the authored body geometry.
	var place_scale := {
		"torso": Vector2(torso_radius / 0.28, float(torso_spec.get("height", 0.9)) / 0.9),
		"band": Vector2(torso_radius / 0.28, float(torso_spec.get("height", 0.9)) / 0.9),
		"sleeves": Vector2(
			float(arm_spec.get("top_radius", 0.07)) / 0.07,
			float(arm_spec.get("height", 0.84)) / 0.84
		),
		"legs": Vector2(
			float(leg_spec.get("top_radius", 0.11)) / 0.11,
			float(leg_spec.get("height", 0.66)) / 0.66
		),
	}
	## A darker relative of the trim, for a rule that has to read *against* the
	## trim rather than against the shirt -- the edging on a heritage band.
	var shade := trim.darkened(0.42)
	var lane := 0
	for mark in RegionalKitsScript.marks_for(
		club_region, champion_region, kit_design_attempt
	):
		lane += 1
		var roll := float(mark[2]) if mark.size() > 2 else 0.0
		var place := str(mark[3]) if mark.size() > 3 else "torso"
		var profile: Dictionary = mark[4] if mark.size() > 4 else {}
		## Vegi keep produce as their torso, but their sleeves and shorts are still
		## garments. Suppress only marks that would paint the produce itself; the
		## previous early return also erased the real garment marks and made every
		## regional Vegi identical.
		if not wears_kit and place in ["torso", "band"]:
			continue
		var garment_scale: Vector2 = place_scale.get(place, place_scale["torso"])
		var source_size: Vector3 = mark[0]
		var source_at: Vector3 = mark[1]
		var size := Vector3(
			source_size.x * garment_scale.x,
			source_size.y * garment_scale.y,
			source_size.z,
		)
		var at := Vector3(
			source_at.x * garment_scale.x,
			source_at.y * garment_scale.y,
			source_at.z,
		)
		var ink := shade if str(profile.get("ink", "trim")) == "shade" else trim
		## A band rings the whole body, so it is built once rather than per face.
		if place == "band":
			if at.z < 0.0:
				continue
			var ring := MeshInstance3D.new()
			## Tapered to the body at both edges for the same reason: a band tall
			## enough to matter reaches into the caps, and a straight-sided ring
			## there stands off the shirt at its lower edge.
			var band_semi := float(torso_spec.get("height", 0.9)) * 0.5
			var half := size.y * 0.5
			ring.mesh = BodyTypeModelsScript.build_mesh({
				"shape": "cylinder",
				"top_radius": size.z + BodyTypeModelsScript._torso_radius_at(
					torso_spec, (at.y + half) / maxf(band_semi, 0.001)
				),
				"bottom_radius": size.z + BodyTypeModelsScript._torso_radius_at(
					torso_spec, (at.y - half) / maxf(band_semi, 0.001)
				),
				"height": size.y,
			})
			ring.position = Vector3(0.0, at.y, 0.0)
			ring.set_meta("kit_mark", true)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			torso.add_child(ring)
			_apply_material_color(ring, ink)
			continue
		## Limb garments are short, narrow cylinders that rotate aggressively with
		## the pose. A front/back patch on one has almost no projected area once the
		## arm turns, and on Vegi that erased the only regional construction they
		## wear. Wrap limb motifs around the garment instead. Their authored height,
		## count and spacing still distinguish a cuff rule, a broad sponsor tab, a
		## stack of Spëddigh pulses and a long Pāwa continuation, while the ring
		## remains readable from every volleyball pose.
		if place in ["sleeves", "legs"]:
			if at.z < 0.0:
				continue
			for host in Array(places[place]):
				var parent := host[0] as Node3D
				if parent == null:
					continue
				var limb_ring := MeshInstance3D.new()
				limb_ring.mesh = BodyTypeModelsScript.build_mesh({
					"shape": "cylinder",
					"top_radius": float(host[1]) + size.z,
					"bottom_radius": float(host[1]) + size.z,
					"height": size.y,
				})
				limb_ring.position = Vector3(0.0, at.y, 0.0)
				limb_ring.set_meta("kit_mark", true)
				limb_ring.set_meta("kit_mark_lane", lane)
				limb_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(limb_ring)
				_apply_material_color(limb_ring, ink)
			continue
		## **A mark is a shape down its own length, not one rectangle.**
		##
		## A box is one width for its whole length, which rules out three things
		## the design sheets ask for by name: a panel that is widest at the chest
		## and narrows at the waist, a stroke whose ends taper rather than cut
		## square, and a panel that bows inward as it descends to follow the
		## ribcage. Those were listed as "not expressible" and they are, as soon
		## as one authored mark is allowed to vary its width and its offset along
		## itself.
		##
		## `waist` is the width multiplier at the bottom, `taper` the multiplier
		## at *both* ends, and `bow` the lateral drift from top to bottom. With no
		## profile a mark is a plain rectangle, so nothing authored before this
		## changes shape.
		##
		## `segments` is now only a **minimum row count** rather than a number of
		## separate meshes: the patch subdivides to `PATCH_STEP` on its own, so a
		## short tick gets two rows whatever the profile says and a long panel
		## gets enough to be smooth whether or not anyone remembered to ask.
		var segments := maxi(int(profile.get("segments", 1)), 1)
		var waist := float(profile.get("waist", 1.0))
		var taper := float(profile.get("taper", 1.0))
		var bow := float(profile.get("bow", 0.0))
		for host in Array(places.get(place, places["torso"])):
			var parent := host[0] as Node3D
			if parent == null:
				continue
			var face := 1.0 if at.z >= 0.0 else -1.0
			## How far the mark stands off the shirt.
			##
			## Three earlier readings of this number all assumed the speckling
			## along a long panel was a *seating* fault -- half the depth left
			## inside the body, a coplanar overlap, a segment swallowed by the
			## curve. None of them was it, and `build_surface_patch` records what
			## was: a stack of flat boxes stepping down a curved body shows the
			## top face of every step. The depth is just a depth again.
			var proud := size.z
			var on_torso := place == "torso"
			var torso_semi := float(torso_spec.get("height", 0.9)) * 0.5
			## **The angle is fixed once, at the mark's own middle.**
			##
			## Holding the *cartesian* x while the radius shrinks toward the caps
			## drives every segment further around the body: Blôc's outermost
			## stripe sat at 50 degrees through its middle and 60 at its ends, so
			## it splayed onto the flank top and bottom instead of running
			## vertically -- which is what put marks up on the shoulder ball.
			##
			## A vertical line on a body is a line of constant *longitude*, so the
			## angle is computed once against the radius at the mark's centre and
			## every segment keeps it. The per-segment radius is then only used to
			## place the mark on the surface, never to re-derive where it is.
			var reference_radius := (
				BodyTypeModelsScript._torso_radius_at(
					torso_spec, at.y / maxf(torso_semi, 0.001)
				) if on_torso else float(host[1])
			) + proud
			## **On the body, not on a plane in front of it.**
			##
			## Every mark used to take the same z whatever its x, which is only
			## correct on the centre line: with a torso radius of 0.308 the body's
			## surface has fallen to 0.104 by x = 0.29, so a mark placed on the
			## tangent plane floats two hundred millimetres off the shirt at the
			## edge. That is why the whole table was authored small and central --
			## the geometry could not support anything wider, and the constraint was
			## mistaken for a style.
			##
			## A mark offset `x` sits at angle `asin(x / r)` around the body, and
			## every vertex of it is evaluated on that circle. The authored width is
			## then spent as **arc**, which is what a garment spec means by a width:
			## how much shirt the panel covers, not how wide its shadow would fall
			## on a wall behind it.
			var roll_radians := deg_to_rad(clampf(roll, -70.0, 70.0))
			var roll_lean := tan(roll_radians)
			var roll_widen := 1.0 / maxf(cos(roll_radians), 0.34)
			## Enough rows that no quad is longer than `PATCH_STEP`, and never fewer
			## than the profile asked for.
			var rows := clampi(
				maxi(segments, int(ceil(size.y / 0.028))), 2, 28
			)
			var patch: Array = []
			for row in range(rows + 1):
				## 0 at the top of the mark, 1 at the bottom. Rows are the **edges**
				## of the shape rather than the centres of slabs, so a taper actually
				## reaches its stated end width instead of stopping a half-step short
				## of it.
				##
				## The slab version read `segment / (segments - 1)`, which is 0.0 for
				## an unsegmented mark -- so every mark without a profile was placed
				## half its own height too high. Blôc's stripes are 0.54 long, so they
				## sat 0.27 above where they were authored: measured top 1.617 against
				## a torso ending at 1.510, which is a pinstripe floating above the
				## shirt and under the chin. Rhėn's fan and Tãul's seams rode onto the
				## shoulder for the same reason.
				var along := float(row) / float(rows)
				## Symmetric about the middle, for the taper.
				var from_end := 1.0 - absf(along - 0.5) * 2.0
				var width := size.x \
					* lerpf(1.0, waist, along) \
					* lerpf(taper, 1.0, from_end)
				var row_y := at.y + size.y * (0.5 - along)
				## The radius is read at the row's own height, because the body has
				## narrowed by the time a long mark reaches its ends and a mark held
				## at the middle radius would hang off it.
				var row_radius := (
					BodyTypeModelsScript._torso_radius_at(
						torso_spec, row_y / maxf(torso_semi, 0.001)
					) if on_torso else float(host[1])
				)
				var theta := asin(clampf(
					(at.x + bow * garment_scale.x * along) \
						/ maxf(reference_radius, 0.001), -1.0, 1.0
				))
				## A roll is a **shear along the surface**, not a slab tipped in
				## front of it. Rotating the mesh tilted its whole plane off the
				## curve, so a fan of steep strokes lifted its outer ends clear of the
				## shirt; shearing the arc-centre with height keeps every vertex on
				## the body and only the drawing leans. The ends come out level rather
				## than cut square to the stroke, which is what a seam sewn onto a
				## curved panel does anyway.
				patch.append({
					"y": row_y,
					"radius": row_radius,
					"u": theta * reference_radius - roll_lean * (row_y - at.y),
					"half": width * 0.5 * roll_widen,
				})
			var node := MeshInstance3D.new()
			node.mesh = BodyTypeModelsScript.build_surface_patch(
				patch, face, reference_radius, proud
			)
			node.set_meta("kit_mark", true)
			## Which authored mark this patch came from. Godot names every generated
			## mesh alike, so without this a diagnostic cannot tell "one stripe bent"
			## from "nine stripes at nine different longitudes", and the second is
			## the design.
			node.set_meta("kit_mark_lane", lane)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(node)
			_apply_material_color(node, ink)


## Every kit mark, wherever it hangs.
##
## Walked rather than read off the torso's children, because a mark can now sit
## on a sleeve or a shorts leg. The old version cleared only the torso's, so a
## region change would have left the previous kit's sleeve marks in place -- one
## shirt wearing two clubs.
func _kit_marks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_collect_kit_marks(self, found)
	return found


func _collect_kit_marks(node: Node, found: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		var mesh_node := child as MeshInstance3D
		if mesh_node != null and mesh_node.has_meta("kit_mark"):
			found.append(mesh_node)
		_collect_kit_marks(child, found)


func _apply_material_color(
	mesh: MeshInstance3D, color: Color, alpha: float = 1.0
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.72
	if flat_shading:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 0.999:
		## Alpha scissor rather than blend would give a stipple; blend is right
		## for a membrane. Depth draw stays on so two overlapping wings still
		## read as two, and culling goes off so a wing seen from behind is not a
		## hole.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material


func _apply_physical_profile(profile: Dictionary) -> void:
	height_cm = clampf(float(profile.get("height_cm", REFERENCE_HEIGHT_CM)), 150.0, 220.0)
	## Mass is interpreted relative to height, so 82 kg means something different
	## on a 160 cm and a 210 cm player. Missing mass deliberately lands at the
	## reference build for that height, preserving every older portrait caller.
	var expected_mass := 82.0 * pow(height_cm / REFERENCE_HEIGHT_CM, 2.0)
	mass_kg = clampf(float(profile.get("mass_kg", expected_mass)), 45.0, 145.0)
	var mass_girth := clampf(pow(mass_kg / maxf(expected_mass, 1.0), 0.35), 0.88, 1.14)
	var limb_girth := lerpf(1.0, mass_girth, 0.58)
	wingspan_cm = clampf(float(profile.get("wingspan_cm", REFERENCE_WINGSPAN_CM)), 150.0, 235.0)
	stride_length_m = clampf(float(profile.get("stride_length_m", 0.83)), 0.55, 1.15)
	## Scale the silhouette so its own stated height becomes this player's real
	## one. The old form multiplied by a 0.93 constant, which is exactly
	## 1.88 / 2.02 for the single rig that existed; stating it as a ratio makes
	## it correct for a 2.16 m Avi and a 1.76 m Pumpkin too.
	var rig_height := float(silhouette.get("rig_height", REFERENCE_RIG_HEIGHT_M))
	body_height_scale = (height_cm / 100.0) / maxf(rig_height, 0.5)
	var reference_ratio := REFERENCE_WINGSPAN_CM / REFERENCE_HEIGHT_CM
	arm_length_scale = clampf(
		(wingspan_cm / height_cm) / reference_ratio, 0.78, 1.24
	)
	## **Leg length is a tracked number, so the legs are drawn from it.**
	##
	## `stride_length_m` has driven cadence since the locomotion work and has
	## never touched geometry, so two players with a 0.62 m and a 1.02 m stride
	## stood on identical legs and only *moved* differently. Stride is the leg
	## measurement this model actually carries -- there is no separate inseam --
	## and it is compared against what this player's height would ordinarily
	## produce, so the scale reads "long-legged for their size" rather than
	## "tall".
	##
	## Total height is preserved. A player with the same height and longer legs
	## has a shorter torso, not a taller body, so the hips rise by exactly what
	## the legs gained and the feet stay on the floor. Without that the rig would
	## quietly contradict `height_cm`, which every reach calculation trusts.
	var expected_stride := clampf(height_cm / 100.0 * 0.43, 0.55, 1.15)
	leg_length_scale = clampf(
		stride_length_m / maxf(expected_stride, 0.01), 0.86, 1.16
	)
	## Longer legs mean a **shorter torso**, not a higher waist on the same body.
	##
	## The first pass raised the hips and left everything above them alone, so
	## the upper body simply overlapped further and the legs barely changed --
	## the whole difference went into a gap nobody could see. Two volis of the
	## same height with a 0.62 m and a 1.02 m stride should look like two
	## genuinely different builds, and the only way that happens is if the
	## torso gives back exactly what the legs take.
	##
	## So the upper body is compressed about the raised hip by the ratio of the
	## span it has left. The crown of the head lands where it always did, which
	## is what keeps `height_cm` honest, and every part between hip and head
	## moves proportionally rather than being individually re-authored.
	var leg_span := leg_bone_lengths.x + leg_bone_lengths.y
	var leg_gain := leg_span * (leg_length_scale - 1.0)
	var hip_y := hip_offset.y + leg_gain
	for leg in [left_leg, right_leg]:
		leg.scale = Vector3(limb_girth, leg_length_scale, limb_girth)
		leg.position.y = hip_y
	var crown := float(silhouette.get("rig_height", REFERENCE_RIG_HEIGHT_M))
	var upper_span := maxf(crown - hip_offset.y, 0.1)
	var squeeze := clampf((upper_span - leg_gain) / upper_span, 0.55, 1.45)
	for part in [torso, head]:
		part.position.y = hip_y + (part.position.y - hip_offset.y) * squeeze
	torso.scale = Vector3(mass_girth, squeeze, mass_girth)
	_seat_collar()
	for arm in [left_arm, right_arm]:
		arm.scale = Vector3(limb_girth, 1.0, limb_girth)
		arm.position.y = hip_y + (arm.position.y - hip_offset.y) * squeeze
	shoulder_offset.y = hip_y + (shoulder_offset.y - hip_offset.y) * squeeze
	hip_offset.y = hip_y

	## The hips sit on the hip joint, and this is where that is decided.
	##
	## The shorts used to be placed from the *torso's* bottom, so a body type
	## with a tall torso pushed them down past the joint they are supposed to be
	## capping -- Stalk, Aubergine, Pear and Ursi worst, because their torsos are
	## the tallest. A block floating below the pelvis does not read as hips, it
	## reads as shorts worn badly.
	##
	## Derived here rather than in `_build_silhouette` because the hip has just
	## moved: two functions both placing the shorts is exactly the
	## correct-then-clobbered shape that has bitten this file three times, so the
	## one that knows the final hip height owns it outright.
	## **The shorts are the bottom of the torso, not a box on it.**
	##
	## They were a box wider than the body sitting at the waist, and under a drawn
	## line that box earned an outline of its own -- which is what turned a pair of
	## shorts into a shelf. A voli in a singlet does not have a ledge at the hip.
	##
	## So they are now a section of the torso's own profile: the same shape,
	## sampled at the height they sit at, a shade wider so they clear it without
	## fighting for pixels, and less than half its height so they read as the
	## bottom of a garment rather than as a second body. `_torso_radius_at` is the
	## same function the collar uses, for the same reason -- a band sized from the
	## widest point of a round body is a hoop somebody has been posted through.
	## **The shorts shell is gone.**
	##
	## It was a straight-sided section of the torso's own profile -- an unbroken
	## ring of dark right round the body, which is a skirt by construction and was
	## never shorts-shaped. Every problem attributed to it was really it: the
	## "torso extruding from the shorts" was its bottom face meeting the capsule's
	## cap in the same plane, and the overhang added to fix that governed a mesh
	## that should not have been drawn at all.
	##
	## What dresses the hips now is what a garment actually is: the hip joint
	## takes the shorts' colour, and `_add_garments` hangs a real leg opening on
	## each thigh. The node, its mesh resource, its share constant and its place
	## in the ink and mask lists are all removed rather than left hidden -- a mesh
	## kept alive at `visible = false` is the next person's mystery.

	## Scales the *whole two-bone chain*, elbow included.
	##
	## This ran straight after `_build_silhouette` and rewrote the upper arm's
	## mesh to half the length of the entire arm -- correct while an arm was one
	## capsule, and wrong the moment it became two. The mesh then reached right
	## past the elbow, which sat at the upper bone's proper end, so every bent
	## pose came out as a T: a forearm crossing an upper arm at its middle.
	## NOTE the tell: a length measured from a whole where the code below it
	## works in parts.
	var upper_length := arm_bone_lengths.x
	var fore_length := arm_bone_lengths.y
	for arm in [left_arm, right_arm]:
		var upper_mesh := arm.get_node("Mesh") as MeshInstance3D
		upper_mesh.scale.y = arm_length_scale
		upper_mesh.position.y = -upper_length * 0.5 * arm_length_scale
		var elbow := arm.get_node("Elbow") as Node3D
		elbow.position.y = -upper_length * arm_length_scale
		var fore_mesh := elbow.get_node("Mesh") as MeshInstance3D
		fore_mesh.scale.y = arm_length_scale
		fore_mesh.position.y = -fore_length * 0.5 * arm_length_scale
		## **Cosmetics on a bone are part of that bone.** This scaled `Mesh`,
		## `Elbow` and the forearm and stopped, so an Avi with a non-unit arm ratio
		## grew a limb out from under its own wing -- the fans stayed the length
		## they were authored while the arm they grow from did not. Only sibling
		## cosmetics of the two arm bones are touched; everything else on the body
		## is scaled by its own rule or by none.
		var wing_elbow := elbow.get_node_or_null("WingElbow") as Node3D
		var wing_bones: Array[Node3D] = [arm, elbow]
		if wing_elbow != null:
			(wing_elbow.get_node("WingWrist") as Node3D).position.y = (
				-fore_length * arm_length_scale
			)
			wing_bones.append(wing_elbow)
			wing_bones.append(arm.get_node("WingShoulder") as Node3D)
		for bone in wing_bones:
			for child in bone.get_children():
				var fan := child as MeshInstance3D
				if fan == null or not fan.has_meta("cosmetic"):
					continue
				fan.scale.y = arm_length_scale
	identity_label.position.y = (
		float(silhouette.get("rig_height", REFERENCE_RIG_HEIGHT_M)) + 0.26
	) * body_height_scale


## Create or update every joint of a rig description -- VOLI_RIG_AS_DATA.md.
## The .tscn is the default skeleton; this positions it and adds what it lacks (the wing).
func _build_rig(rig_data: Dictionary) -> void:
	_rig = rig_data
	for raw in rig_data.get("joints", []):
		var joint: Dictionary = raw
		var path := str(joint.path)
		var node := get_node_or_null(path) as Node3D
		if node == null:
			node = Node3D.new()
			node.name = path.get_file()
			var parent := get_node(path.get_base_dir())
			parent.add_child(node)
		node.position = joint.position
		for mesh_name in joint.get("meshes", []):
			if node.get_node_or_null(str(mesh_name)) == null:
				var mesh_node := MeshInstance3D.new()
				mesh_node.name = str(mesh_name)
				node.add_child(mesh_node)


## Which joint nodes a wing pose drives, for one side. Empty when the body has no wing.
func _wing_joints(side: String) -> Dictionary:
	var arm_path := "BodyPivot/%sArm" % side
	var wrist_path := arm_path + "/Elbow/WingElbow/WingWrist"
	var wrist := get_node_or_null(wrist_path) as Node3D
	if wrist == null:
		return {}
	return {
		"shoulder": get_node(arm_path + "/WingShoulder"),
		"elbow": get_node(arm_path + "/Elbow/WingElbow"),
		"wrist": wrist,
		"tips": [
			get_node(wrist_path + "/WingTipSpread1"),
			get_node(wrist_path + "/WingTipSpread2"),
			get_node(wrist_path + "/WingTipSpread3"),
		],
	}


## Blend two named wing poses and write the joints, clamped to the rig's limits.
## Sits under the arm pose: only wing joints move, so reach geometry is untouched.
func apply_wing_pose(from_pose: String, to_pose: String, weight: float) -> void:
	var wing: Dictionary = _rig.get("wing", {})
	if wing.is_empty():
		return
	var poses: Dictionary = wing.poses
	var a: Dictionary = poses[from_pose]
	var b: Dictionary = poses[to_pose]
	var w := clampf(weight, 0.0, 1.0)
	var limits: Dictionary = wing.limits
	for side in ["Left", "Right"]:
		var joints := _wing_joints(side)
		if joints.is_empty():
			continue
		var out := -1.0 if side == "Left" else 1.0
		(joints.shoulder as Node3D).rotation_degrees = Vector3(0.0, 0.0, out * _wing_clamp(
			lerpf(a.shoulder, b.shoulder, w), limits.WingShoulder.z))
		(joints.elbow as Node3D).rotation_degrees = Vector3(0.0, 0.0, out * _wing_clamp(
			lerpf(a.elbow, b.elbow, w), limits.WingElbow.z))
		(joints.wrist as Node3D).rotation_degrees = Vector3(0.0, 0.0, out * _wing_clamp(
			lerpf(a.wrist, b.wrist, w), limits.WingWrist.z))
		var spread := _wing_clamp(lerpf(a.spread, b.spread, w), limits.WingTipSpread.x)
		var tips: Array = joints.tips
		for index in tips.size():
			(tips[index] as Node3D).rotation_degrees = Vector3(
				spread * float(index - 1), 0.0, 0.0)


func _wing_clamp(value: float, limit: Vector2) -> float:
	return clampf(value, limit.x, limit.y)


## Wing pose for the frame: tucked at ready, spread to balance on a dig or a
## floor recovery, thrown out on a block, flared on landing.
func _apply_wing_for_state(event_type: int, is_contact_actor: bool) -> void:
	if _rig.get("wing", {}).is_empty():
		return
	var target := "tucked"
	var weight := 0.0
	if is_contact_actor and event_type == RallyEventModel.EventType.BLOCK:
		target = "block"
		weight = 1.0
	elif is_contact_actor and event_type == RallyEventModel.EventType.DIG:
		target = "balance"
		weight = 1.0
	elif not is_contact_actor and _floor_remaining > 0.0:
		target = "balance"
		weight = _floor_remaining / maxf(_floor_duration, 0.0001)
	elif not is_contact_actor and _landing_remaining > 0.0:
		var duration := LandingBiomechanicsScript.duration_seconds(_airborne_action)
		var progress := 1.0 - _landing_remaining / maxf(duration, 0.0001)
		target = "flare"
		weight = float(LandingBiomechanicsScript.resolve(progress, _airborne_action).absorb)
	apply_wing_pose("tucked", target, weight)


func _ensure_node_bindings() -> void:
	if body_pivot != null:
		return
	body_pivot = get_node("BodyPivot")
	torso = get_node("BodyPivot/Torso")
	head = get_node("BodyPivot/Head")
	left_arm = get_node("BodyPivot/LeftArm")
	right_arm = get_node("BodyPivot/RightArm")
	left_wrist = get_node_or_null("BodyPivot/LeftArm/Elbow/Wrist")
	right_wrist = get_node_or_null("BodyPivot/RightArm/Elbow/Wrist")
	left_leg = get_node("BodyPivot/LeftLeg")
	right_leg = get_node("BodyPivot/RightLeg")
	shadow = get_node("Shadow")
	identity_label = get_node("IdentityLabel")
	focus_ring = get_node("FocusRing")


## Rebuild every mesh on the rig for this player's body type.
##
## The node graph is untouched: `set_pose()` still finds a Torso, a Head, two
## arms and two legs wherever it looks, and still poses them by rotating the
## same joints. Only the geometry hanging off those joints and the points they
## attach at change -- which is what lets one pose model serve a cat, a bird and
## an aubergine without a branch anywhere in the animation code.
func _build_silhouette() -> void:
	_ensure_node_bindings()
	var choices := appearance.duplicate()
	choices["garment"] = garment
	silhouette = BodyTypeModelsScript.silhouette(body_type, player_id, choices)
	produce = str(silhouette.get("produce", ""))
	shoulder_offset = silhouette.get("shoulder", Vector2(0.40, 1.52))
	hip_offset = silhouette.get("hip", Vector2(0.16, 0.48))
	_build_rig(BodyTypeModelsScript.rig(silhouette))

	torso.mesh = BodyTypeModelsScript.build_mesh(silhouette.get("torso", {}))
	torso.position = Vector3(0.0, float(silhouette.get("torso_y", 1.13)), 0.0)
	head.mesh = BodyTypeModelsScript.build_mesh(silhouette.get("head", {}))
	head.position = Vector3(0.0, float(silhouette.get("head_y", 1.82)), 0.0)

	## The arm is two bones now, for the same reason the leg is.
	##
	## Two bones, because elbow bend is how a dig, a set and a swing are told
	## apart from the stands.
	##
	## Upper arm slightly shorter than the forearm-and-hand it carries, so the
	## elbow reads as an elbow rather than a midpoint.
	var arm_spec: Dictionary = silhouette.get("arm", {})
	## **Not a cylinder.** This line is why every voli was a produce with four rods
	## in it: whatever a body type authored, the rig overwrote it with a shape that
	## ends in a flat disc. A limb tapers and finishes in a dome -- see
	## `BodyTypeModels._limb_mesh`, which lathes one because Godot has no tapered
	## capsule to reach for.
	arm_spec["shape"] = "limb"
	var arm_height := float(arm_spec.get("height", 0.88))
	var upper_length := arm_height * UPPER_ARM_SHARE
	var fore_length := arm_height - upper_length
	arm_bone_lengths = Vector2(upper_length, fore_length)
	var upper_spec := arm_spec.duplicate()
	upper_spec["height"] = upper_length
	## The forearm picks up where the upper arm left off, so the two read as one
	## limb rather than as two cylinders of unrelated width.
	var fore_spec := arm_spec.duplicate()
	fore_spec["height"] = fore_length
	fore_spec["top_radius"] = arm_spec.get("bottom_radius", 0.08)
	for arm in [left_arm, right_arm]:
		var arm_mesh := arm.get_node("Mesh") as MeshInstance3D
		arm_mesh.mesh = BodyTypeModelsScript.build_mesh(upper_spec)
		arm_mesh.position = Vector3(0.0, -upper_length * 0.5, 0.0)
		var elbow := arm.get_node("Elbow") as Node3D
		elbow.rotation_degrees = Vector3.ZERO
		var fore_mesh := elbow.get_node("Mesh") as MeshInstance3D
		fore_mesh.mesh = BodyTypeModelsScript.build_mesh(fore_spec)
		fore_mesh.position = Vector3(0.0, -fore_length * 0.5, 0.0)
		## A small asymmetric palm at the existing forearm endpoint. Its origin is
		## the old inferred hand position, so articulation adds orientation without
		## silently adding reach.
		var wrist := elbow.get_node_or_null("Wrist") as Node3D
		if wrist != null:
			wrist.position = Vector3(0.0, -fore_length, 0.0)
			wrist.rotation = Vector3.ZERO
			var palm := wrist.get_node_or_null("Palm") as MeshInstance3D
			if palm != null:
				var hand_width := float(arm_spec.get("bottom_radius", 0.08)) / 0.08
				palm.scale = Vector3(0.78, 1.08, 0.46) * hand_width
		## The shoulder and the elbow, as joints rather than as the gap between
		## two pills. Rounding the limb ends stopped them reading as rods and left
		## the other half of the problem standing: a bent elbow opens a wedge on
		## the outside of the bend, and a shoulder that only touches the torso
		## reads as an arm resting against a body rather than growing out of one.
		## **Under 1.0, and not the same figure for the arm and the leg.**
		##
		## These were 1.08 and 1.06 -- a ball *wider* than the segments it joins,
		## which makes the limb sections read as stubs plugged into a bead rather
		## than as a limb that bends. Under 1.0 the ball sits inside both radii
		## and does its one job, filling the crease where two capsule caps meet,
		## while the limb stays the widest thing on the arm.
		##
		## The arm and the leg differ because an elbow joins two slim segments and
		## can afford to be nearly as wide as they are, while a knee joins the
		## thickest bones on the body and the same *ratio* there produces a far
		## larger ball in absolute terms. Judged square-on, front and back, where
		## a joint's crease sits on the silhouette edge -- a three-quarter view
		## hides half of it behind the limb's own curve, which is why the elbows
		## looked settled long before the knees did.
		_joint_ball(arm, float(arm_spec.get("top_radius", 0.09)) * JOINT_ARM, 0.0)
		_joint_ball(elbow, float(arm_spec.get("bottom_radius", 0.08)) * JOINT_ARM, 0.0)

	## Legs are placed so the foot lands just above the floor whatever the hip
	## height and shank length are, rather than by the pair of literals that
	## happened to suit the one rig.
	var leg_spec: Dictionary = silhouette.get("leg", {})
	leg_spec["shape"] = "limb"
	var leg_height := float(leg_spec.get("height", 0.74))
	var shoe_spec: Dictionary = silhouette.get("shoe", {})
	## The leg is two bones now, not one.
	##
	## A single capsule from hip to shoe cannot be bent, which is why a dig used
	## to be drawn by squashing the whole actor on one axis. Being forced low is
	## a tactical fact -- a defender who had to go to their knees to reach a ball
	## did something different from one who stayed on their feet -- so it needs a
	## joint that can say so rather than a scale factor that flattens the head
	## along with everything else.
	##
	## Thigh slightly longer than shank, which is both roughly true and the ratio
	## that keeps the knee reading as a knee when it folds.
	var thigh_length := leg_height * THIGH_SHARE
	var shank_length := leg_height - thigh_length
	leg_bone_lengths = Vector2(thigh_length, shank_length)
	var thigh_spec := leg_spec.duplicate()
	thigh_spec["height"] = thigh_length
	## The shank tapers on from where the thigh left off, so the two bones read
	## as one limb rather than two stacked cylinders of unrelated width.
	var shank_spec := leg_spec.duplicate()
	shank_spec["height"] = shank_length
	shank_spec["top_radius"] = leg_spec.get("bottom_radius", 0.07)
	for index in [0, 1]:
		var leg: Node3D = left_leg if index == 0 else right_leg
		var side := -1.0 if index == 0 else 1.0
		var leg_mesh := leg.get_node("Mesh") as MeshInstance3D
		leg_mesh.mesh = BodyTypeModelsScript.build_mesh(thigh_spec)
		leg_mesh.position = Vector3(0.0, -thigh_length * 0.5, 0.0)
		var knee := leg.get_node("Knee") as Node3D
		knee.rotation_degrees = Vector3.ZERO
		var shank_mesh := knee.get_node("Mesh") as MeshInstance3D
		shank_mesh.mesh = BodyTypeModelsScript.build_mesh(shank_spec)
		shank_mesh.position = Vector3(0.0, -shank_length * 0.5, 0.0)
		_joint_ball(leg, float(leg_spec.get("top_radius", 0.11)) * JOINT_LEG, 0.0)
		_joint_ball(knee, float(leg_spec.get("bottom_radius", 0.09)) * JOINT_LEG, 0.0)
		var shoe := knee.get_node("Shoe") as MeshInstance3D
		shoe.mesh = BodyTypeModelsScript.build_mesh(shoe_spec)
		shoe.position = Vector3(0.0, -shank_length, -SHOE_FORWARD_OFFSET)
		## A box foot is authored lying flat already; only the capsule shoe
		## needs standing on its side to become a foot rather than a leg.
		shoe.rotation_degrees = Vector3(
			90.0 if str(shoe_spec.get("shape", "capsule")) == "capsule" else 0.0,
			0.0, 0.0
		)
	_build_cosmetics()
	_build_face()
	## Last, so every mesh the body build produced -- including the cosmetics and
	## the face -- gets its line.
	_apply_ink()


## The joint ball on a bone, if it has one yet.
func _paint_joint(bone: Node, color: Color) -> void:
	var ball := bone.get_node_or_null("Joint") as MeshInstance3D
	if ball != null:
		_apply_material_color(ball, color)


## How thick the drawn line is, in metres of world space.
##
## **In metres, which is the whole point.** An outline measured in pixels thins as
## a voli walks upcourt and thickens as they come toward the camera, so the
## drawing changes weight for reasons that have nothing to do with the drawing.
## In metres a line is a property of the body, and a voli at the endline carries
## the same pen as one at the net.
##
## The crown is heavier than the body because it is smaller. A crest, a pair of
## ears or a beak is the thing that says which type this is, occupies a few dozen
## pixels doing it, and is the one place where more line buys legibility instead
## of weight.
## NOTE the body weight lives in body_type_models.gd because the garments have to
## NOTE clear it -- GARMENT_INK_CLEARANCE.md. This is the same number, read.
static var ink_metres: float:
	get: return BodyTypeModelsScript.body_ink_metres
	set(value): BodyTypeModelsScript.body_ink_metres = value
static var crown_ink_metres: float = 0.030
const INK_COLOR := Color(0.06, 0.07, 0.10)
## Everything else is a cosmetic and takes the heavier line. Named as the body
## rather than as a list of cosmetics because the body is a closed set and the
## cosmetics are not -- a new ear or tail should get the crown weight without
## anybody remembering to add it here.
const INK_BODY_PARTS: Array[String] = [
	"Torso", "Head", "Mesh", "Joint", "Shoe", "Kit",
]


## Draw every part of the rig with a line round it.
##
## An inverted hull: each mesh gets a twin, grown outward, painted flat and
## rendered inside-out so only its far side shows. What survives is a band around
## the silhouette of *that part*, which is why an arm crossing the torso keeps its
## own edge instead of dissolving into it -- the same separation the sticker trace
## does in 2D, obtained here for the cost of a second draw call per part.
##
## Rebuilt with the body rather than authored in the scene, because the twins have
## to follow whatever mesh each body type produced.
func _apply_ink() -> void:
	_ink_node(self)


func _ink_node(node: Node) -> void:
	for child in node.get_children():
		_ink_node(child)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if mesh_instance.name == "Ink":
		return
	## The shadow and the focus ring are marks on the floor, not parts of a body.
	if mesh_instance == shadow or mesh_instance == focus_ring:
		return
	## **A part that is already a line does not get a line round it.** A whisker is
	## four millimetres thick and the hull is thirty, so inking one produces a
	## black rod eight times its own width -- the same failure the nose hit at a
	## quarter of a muzzle, and the mouth hit seven times over. Where a cosmetic is
	## drawn *as* the stroke, the stroke is the geometry.
	if str(mesh_instance.get_meta("ink", "")) == "none":
		return
	var existing := mesh_instance.get_node_or_null("Ink") as MeshInstance3D
	var twin := existing if existing != null else MeshInstance3D.new()
	if existing == null:
		twin.name = "Ink"
		mesh_instance.add_child(twin)
	twin.mesh = mesh_instance.mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = INK_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	## **Name first, then an explicit exception.** The name rule is right by
	## default and the comment above says why: the body is a closed set and the
	## cosmetics are not, so an unlisted part should take the heavier crown line
	## unasked. It is wrong for exactly one thing so far -- the Avi wing fans,
	## which are the largest cosmetic in the game rather than the smallest, and
	## which read as separate objects precisely because a 30 mm contour announced
	## them as such. An opt-in meta keeps the default and admits the exception.
	var heavy := str(mesh_instance.name) not in INK_BODY_PARTS
	if mesh_instance.has_meta("ink"):
		heavy = str(mesh_instance.get_meta("ink")) != "body"
	material.grow_amount = crown_ink_metres if heavy else ink_metres
	twin.material_override = material


## Put the collar on top of the shirt the rig actually drew.
##
## `_add_garments` places it from `torso_y + torso.height * 0.5`, which describes
## a nominal capsule. Two things then move underneath it: a Vegi's torso is a
## lathed produce whose mesh overshoots that height, and `_apply_physical_profile`
## has just scaled the torso by mass girth and squeeze, which the collar does not
## inherit because it hangs off `BodyPivot` rather than off the torso.
##
## Measured before this existed: the collar's top sat 20 mm inside the drawn
## torso on Feli and 64 mm inside on Vegi, well below where that torso's 0.018 m
## outline reaches -- the neckline dashing in
## `docs/review/GARMENT_INK_CLEARANCE.md`.
##
## Owned here for the reason the shorts are: the function that knows the final
## torso is the one that may place things against it, and two functions both
## placing the collar is the correct-then-clobbered shape this file has been
## bitten by repeatedly.
func _seat_collar() -> void:
	if torso == null or torso.mesh == null:
		return
	var collar := body_pivot.get_node_or_null("Collar") as MeshInstance3D
	if collar == null or collar.mesh == null:
		return
	var torso_bounds := torso.mesh.get_aabb()
	var torso_top := torso.position.y \
		+ (torso_bounds.position.y + torso_bounds.size.y) * torso.scale.y
	var collar_bounds := collar.mesh.get_aabb()
	var above_origin := collar_bounds.position.y + collar_bounds.size.y
	## One line width clear of the torso's outline, the same standoff and the
	## same hull `BodyTypeModels._clearing_radius` sizes the sleeves against.
	collar.position.y = maxf(
		collar.position.y,
		torso_top + BodyTypeModelsScript.body_ink_metres * 2.0 - above_origin,
	)


## A ball at a joint, so two segments read as one limb bending.
##
## Named and reused rather than four near-identical blocks, and rebuilt on every
## body build rather than authored in the scene, because the radius comes from
## the body type -- a Vegi's arm and an Ursi's are not the same thickness and a
## joint sized for one is a bead or a boil on the other.
func _joint_ball(bone: Node3D, radius: float, drop: float) -> void:
	var existing := bone.get_node_or_null("Joint") as MeshInstance3D
	var ball := existing if existing != null else MeshInstance3D.new()
	if existing == null:
		ball.name = "Joint"
		bone.add_child(ball)
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	ball.mesh = sphere
	ball.position = Vector3(0.0, drop, 0.0)


## Ears, beaks, wings, tails, stems and leaves.
##
## Parented by path so a wing can hang off an arm node and travel with every
## swing and block the pose code already produces, while a stem sits on the body
## and does not.
func _build_cosmetics() -> void:
	for existing in _cosmetics():
		## `configure` is a synchronous rebuild. Deferring this removal leaves the
		## old coat in the tree while the replacement is added below, so a slider
		## that reconfigures one preview actor can draw two copies of every Tabby
		## bar for the rest of that frame. With one-centimetre slider steps the
		## rebuild count looks like height parity even though height never chooses a
		## marking. Nothing keeps a reference to these generated meshes, so remove
		## them in the same operation that replaces them.
		existing.free()
	_cosmetic_cache.clear()
	for raw_part in silhouette.get("extras", []):
		var part: Dictionary = raw_part
		var parent := get_node_or_null(str(part.get("parent", "BodyPivot")))
		if parent == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = str(part.get("name", "Cosmetic"))
		instance.mesh = BodyTypeModelsScript.build_mesh(part)
		instance.position = part.get("position", Vector3.ZERO)
		instance.rotation_degrees = part.get("rotation", Vector3.ZERO)
		## Non-uniform scale, which the primitives cannot express on their own: a
		## `SphereMesh` has one radius for both horizontal axes, so anything that
		## has to be wider one way than the other -- a pepper's lobe bulging
		## outward, a stripe lying along a flank -- can only be got by scaling the
		## instance. Applied after the rotation, so a part turned to face outward
		## scales along its own axes rather than the world's.
		instance.scale = part.get("scale", Vector3.ONE)
		instance.set_meta("cosmetic", true)
		if part.has("color_value"):
			instance.set_meta("color_key", "literal")
			instance.set_meta("color_value", part.color_value)
		else:
			instance.set_meta("color_key", str(part.get("color", "skin")))
		if part.has("alpha"):
			instance.set_meta("alpha", float(part.alpha))
		## Which pen this cosmetic is drawn with, when the default is wrong for it.
		## Absent means the name rule in `_ink_node` decides, which is what keeps
		## a new ear or tail on the crown weight without anybody remembering.
		if part.has("ink"):
			instance.set_meta("ink", str(part.ink))
		parent.add_child(instance)
		_cosmetic_cache.append(instance)
		instance.set_meta("performance_rest_rotation", instance.rotation)
		instance.set_meta("performance_rest_position", instance.position)
		var passive_name := str(instance.name).to_lower()
		var root := Vector3.ZERO
		if "tail" in passive_name or "ear" in passive_name \
				or "stem" in passive_name or "shoot" in passive_name \
				or "crest" in passive_name or "calyx" in passive_name \
				or "cap" in passive_name:
			root = Vector3(0.0, instance.mesh.get_aabb().size.y * 0.5, 0.0)
		instance.set_meta("performance_root_local", root)


func _cosmetics() -> Array[MeshInstance3D]:
	return _cosmetic_cache


## Two eyes and a seven-segment mouth, parented to the head so they travel with
## every turn and pose the rig already produces.
##
## Kept under a `Face` node and tagged with their own meta rather than reusing
## the cosmetic tag: `_build_cosmetics` frees everything it finds, so sharing the
## tag would mean a face that silently vanished the next time a stem or a wing
## was rebuilt.
func _build_face() -> void:
	var face := head.get_node_or_null("Face")
	if face != null:
		face.free()
	_face_feature_cache.clear()
	face = Node3D.new()
	face.name = "Face"
	head.add_child(face)
	var head_spec: Dictionary = silhouette.get("head", {})
	var radius := float(head_spec.get("radius", 0.13))
	## Heads are slightly wide ellipsoids, so the vertical semi-axis is half the
	## authored height rather than the radius. Using the radius for both puts the
	## eyes too high on every body type at once, which is the kind of error that
	## looks like a style until you measure it.
	var half_height := float(head_spec.get("height", radius * 2.0)) * 0.5
	for part in FaceExpressionsScript.parts(
		expression, radius, half_height, _mouth_override()
	):
		var instance := MeshInstance3D.new()
		instance.name = str(part.get("name", "Feature"))
		instance.mesh = BodyTypeModelsScript.build_mesh(part)
		instance.position = part.get("position", Vector3.ZERO)
		instance.rotation_degrees = part.get("rotation", Vector3.ZERO)
		instance.set_meta("face", true)
		## Transient blinks and saccades restore these authored transforms every
		## frame. The underlying expression remains a stable data choice.
		instance.set_meta("micro_base_scale", instance.scale)
		instance.set_meta("micro_base_position", instance.position)
		if part.has("ink"):
			instance.set_meta("ink", str(part.ink))
		face.add_child(instance)
		_face_feature_cache.append(instance)


## Some body types already have something where the mouth goes.
##
## Feli has a muzzle and Avi has a beak, both sitting exactly on the spot the
## mouth is drawn -- so the first pass produced a cat and a bird with invisible
## expressions, the mouth buried inside a solid. A muzzle wants the mouth drawn
## on it; a beak *is* the mouth, and gets none.
##
## Read off the cosmetic's own spec rather than tabulated per body type. Those
## numbers already exist in `body_type_models.gd`, and a second copy here would
## be a constant wearing the muzzle's name -- silently wrong the first time the
## muzzle moved.
func _mouth_override() -> Dictionary:
	var head_spec: Dictionary = silhouette.get("head", {})
	var head_radius := float(head_spec.get("radius", 0.13))
	for raw_part in silhouette.get("extras", []):
		var part: Dictionary = raw_part
		match str(part.get("name", "")):
			"Muzzle":
				var part_position: Vector3 = part.get("position", Vector3.ZERO)
				var part_radius := float(part.get("radius", 0.1))
				## Extras are placed in BodyPivot space; the face lives under the
				## head, so the anchor has to come back by the head's own height.
				## The muzzle's *centre*, in head-local space, plus its own
				## semi-axes -- the mouth then wraps it the same way it would wrap
				## a small head, instead of being drawn flat somewhere near it.
				return {
					"anchor": Vector3(
						0.0,
						part_position.y - head.position.y,
						part_position.z,
					),
					"radius": part_radius,
					"half_height": float(part.get("height", part_radius * 2.0)) * 0.5,
					"scale": clampf(part_radius / maxf(head_radius, 0.001), 0.2, 1.0),
					## **A wedge's front is a plane, so the mouth stops wrapping.**
					## `FaceExpressions` projects onto an ellipsoid, which is right
					## for a sphere muzzle and wrong for a snout with a flat pad:
					## the stroke would bow away from a face that does not curve.
					## The pad's own half-extents and its depth are published here
					## so the seating is read off the muzzle rather than assumed.
					"flat": str(part.get("shape", "sphere")) == "wedge",
					"taper_width": clampf(
						float(part.get("taper_width", 1.0)), 0.05, 1.0
					),
					"taper_height": clampf(
						float(part.get("taper_height", 1.0)), 0.05, 1.0
					),
					"reach": float(part.get(
						"depth", part_radius * 2.0
					)) * 0.5,
					## Read off the body spec rather than inferred from having a
					## muzzle: a bear and a monkey have snouts and do not read as
					## whiskered, so this is a per-type statement and not a
					## consequence of geometry.
					"whiskers": bool(silhouette.get("whiskers", false)),
				}
			"Beak":
				return {"omit": true}
	return {}


func _face_features() -> Array[MeshInstance3D]:
	return _face_feature_cache


## Swap the face. Rebuilds rather than reposing, because nine small boxes is
## cheaper to recreate than to track, and expressions change on the scale of
## weeks rather than frames.
func set_expression(new_expression: String, light_mode: bool = false) -> void:
	if not FaceExpressionsScript.has(new_expression):
		return
	expression = new_expression
	_build_face()
	apply_ui_palette(light_mode)


## The cognition badge above this voli's head, created on first use.
##
## A child node and one call, deliberately: `player_actor_3d.gd` is the file the
## new 3D models and VFX are about to rewrite, and the cognition layer is meant
## to survive that. Everything it needs lives in `CognitionBillboard3D`; the
## actor only owns *where* the badge hangs, which is the one fact the component
## cannot know for itself.
var cognition_billboard: CognitionBillboard3D


func show_cognition_cue(cue: Resource, simulation_time: float = -1.0) -> void:
	if cognition_billboard == null:
		if cue == null:
			return
		cognition_billboard = CognitionBillboard3D.new()
		add_child(cognition_billboard)
	cognition_billboard.show_cue(
		cue, cognition_head_anchor(), simulation_time
	)


func hide_cognition_cue() -> void:
	if cognition_billboard != null:
		cognition_billboard.hide_cue()


## Head height for this body, from the rig reference and the per-voli scale, so
## a tall middle's badge sits above their head and not through it.
func _cognition_head_height() -> float:
	return REFERENCE_RIG_HEIGHT_M * maxf(body_height_scale, 0.5)


## Where this voli's head actually is, in the actor's own space.
##
## **The height was a number, and a number cannot lean.** `_cognition_head_height`
## multiplies a rig constant by a body scale, which describes a voli standing to
## attention. Every voli on this court is in a ready stance with the trunk
## pitched forward, and `BodyPivot` carries that pitch -- so the head is a
## decimetre or so in *front* of the actor's origin and the mark was being hung
## above the origin, which is behind the head. Reported as marks reading behind
## and to the left of their volis, and that is most of it.
##
## Reading the node instead picks up everything that moves a head for free: the
## lean, the crouch, a jump's lift, the fold of a dig. A blocker at the top of
## their jump now carries their mark up with them, which the constant could not
## have done at any value.
##
## Falls back to the constant when the rig is not in the tree, which is the
## portfolio and unit-test case -- a pose set by hand before `_ready` has no
## global transforms to read.
## **The crown, not the head's centre.** A `MeshInstance3D`'s origin is the
## middle of its mesh, so anchoring to `head.global_position` hangs the mark
## half a head too low and the blade's grip lands on the voli's face. The mesh
## knows its own extent; asking it means a tall silhouette and a short one both
## get their mark clear of the hair rather than one of them wearing it.
func cognition_head_anchor() -> Vector3:
	if head == null or not head.is_inside_tree() or not is_inside_tree():
		return Vector3(0.0, _cognition_head_height(), 0.0)
	var crown := head.global_position \
		+ head.global_transform.basis.y.normalized() \
		* head.get_aabb().size.y * 0.5 * head.scale.y
	return global_transform.affine_inverse() * crown


## Carry attack deformation through the connected upper-body silhouette. The
## torso changes volume, while the head and shoulder roots travel with that
## volume; limb lengths and the actor's authoritative elevation stay untouched.
func _apply_attack_connected_mass(swing: Dictionary) -> void:
	var response := _body_motion_response()
	var height_scale := lerpf(
		1.0, float(swing.get("mass_height_scale", 1.0)), response
	)
	var width_scale := lerpf(
		1.0, float(swing.get("mass_width_scale", 1.0)), response
	)
	var depth_scale := lerpf(
		1.0, float(swing.get("mass_depth_scale", 1.0)), response
	)
	var anchor_scale := lerpf(
		1.0, float(swing.get("anchor_height_scale", 1.0)), response
	)
	torso.scale = Vector3(
		torso_rest_scale.x * width_scale,
		torso_rest_scale.y * height_scale,
		torso_rest_scale.z * depth_scale,
	)
	torso.position.y = hip_offset.y \
		+ (torso_rest_position.y - hip_offset.y) * anchor_scale
	head.position.y = hip_offset.y \
		+ (head_rest_position.y - hip_offset.y) * anchor_scale
	for arm in [left_arm, right_arm]:
		arm.position.y = hip_offset.y \
			+ (arm.position.y - hip_offset.y) * anchor_scale
		arm.position.x *= width_scale


## Let the upper silhouette keep using the legacy BodyPivot so face, ears,
## garments and every body-type attachment remain one connected mass. The legs
## counter-rotate around the hip centre to show the pelvis carrying less of the
## chest wind-up. This is the missing pelvis/ribcage separation without a new
## skeleton, reparenting existing anatomy, or moving the actor root.
func _apply_attack_pelvis_delta(delta_rotation: Vector3) -> void:
	var delta := Basis.from_euler(delta_rotation)
	var anchor := Vector3(hip_offset.x, hip_offset.y, 0.0)
	for part in [left_leg, right_leg]:
		var posed: Transform3D = part.transform
		posed.origin = anchor + delta * (posed.origin - anchor)
		posed.basis = delta * posed.basis
		part.transform = posed


func _apply_attack_performance(
	swing: Dictionary,
	striking_arm: Node3D,
	guide_arm: Node3D,
	lead_leg: Node3D,
	trail_leg: Node3D,
	chest_delta: Vector3,
) -> void:
	_apply_attack_connected_mass(swing)
	var striking_side := -1.0 if striking_arm == left_arm else 1.0
	var guide_side := -striking_side
	var strike_offset := Vector3(swing.get(
		"striking_shoulder_offset", Vector3.ZERO
	))
	var guide_offset := Vector3(swing.get(
		"guide_shoulder_offset", Vector3.ZERO
	))
	striking_arm.position += Vector3(
		striking_side * strike_offset.x, strike_offset.y, strike_offset.z
	)
	guide_arm.position += Vector3(
		guide_side * guide_offset.x, guide_offset.y, guide_offset.z
	)
	_set_ankle(lead_leg, float(swing.get("lead_ankle_degrees", 0.0)))
	_set_ankle(trail_leg, float(swing.get("trail_ankle_degrees", 0.0)))
	var wrist := left_wrist if striking_arm == left_arm else right_wrist
	if wrist != null:
		wrist.rotation_degrees = Vector3(
			float(swing.get("wrist_flex_degrees", 0.0)),
			float(swing.get("forearm_pronation_degrees", 0.0)),
			float(swing.get("wrist_deviation_degrees", 0.0)),
		)
	_apply_attack_pelvis_delta(chest_delta)


## The swing itself, from the plant onward.
##
## Covers the phase range from `SpikeBiomechanics.PLANT_END` onward; the
## approach model owns everything before it.
func _apply_spike_pose(phase: float, action_context: Dictionary) -> void:
	## Recomputed rather than passed: they are one-line reads off `dominant_hand`,
	## and threading two node references through a signature to save two lines
	## would make the caller know about the callee's internals.
	var striking_arm := left_arm if dominant_hand == "Left" else right_arm
	var guide_arm := right_arm if dominant_hand == "Left" else left_arm
	## Every joint comes from `SpikeBiomechanics`, which staggers them so
	## the legs extend before the trunk arches, the trunk before the
	## shoulder, and the elbow opens last. This branch used to interpolate
	## one `swing` value into all of them at once, which moved the whole
	## body as a single rigid unit -- and held the legs at a fixed stride
	## and the torso at a fixed lean for the entire action, so a spike had
	## no jump in it at all.
	##
	## Kept in its own module rather than inline because it is the only
	## pose in the game complex enough that it cannot be checked by
	## reading it, and a pure function of phase is one the suite can test.
	var swing := AttackActionBiomechanicsScript.resolve(
		phase, -1.0 if dominant_hand == "Left" else 1.0,
		float(action_context.get("action_power", 0.0)),
		str(action_context.get("attack_type", "Power swing")),
		StringName(str(action_context.get("attack_adjustment", "clean"))),
	)
	var total_pitch := float(swing.torso_pitch_radians)
	var total_twist_degrees := float(swing.torso_twist_degrees)
	var pelvis_pitch := total_pitch * float(swing.get(
		"pelvis_pitch_share", 1.0
	))
	var pelvis_twist_degrees := total_twist_degrees * float(swing.get(
		"pelvis_twist_share", 1.0
	))
	var adjustment_roll := float(swing.get("adjustment_roll_degrees", 0.0))
	var chest_pitch := total_pitch \
		+ float(swing.get("chest_pitch_extra_radians", 0.0))
	var chest_twist_degrees := total_twist_degrees \
		+ float(swing.get("chest_twist_extra_degrees", 0.0))
	var chest_roll_degrees := adjustment_roll \
		+ float(swing.get("chest_roll_degrees", 0.0))
	body_pivot.rotation.x = chest_pitch
	body_pivot.rotation.y += deg_to_rad(chest_twist_degrees)
	body_pivot.rotation.z += deg_to_rad(chest_roll_degrees)
	var lead_leg := left_leg if dominant_hand == "Left" else right_leg
	var trail_leg := right_leg if dominant_hand == "Left" else left_leg
	lead_leg.rotation_degrees.x = float(swing.lead_hip_degrees)
	trail_leg.rotation_degrees.x = float(swing.trail_hip_degrees)
	var landing_stagger := float(swing.get("landing_stagger_degrees", 0.0))
	lead_leg.rotation_degrees.x += landing_stagger
	trail_leg.rotation_degrees.x -= landing_stagger
	for leg in [left_leg, right_leg]:
		(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
			swing.knee_degrees
		)
	## Two axes, not one. The roll is the abduction that carries the elbow out
	## as well as back and stands the forearm up *out* of it -- without it the
	## whole swing happens in one plane and reads as a hinge.
	striking_arm.rotation_degrees = Vector3(
		float(swing.striking_shoulder_degrees),
		float(swing.get("striking_internal_rotation_degrees", 0.0)),
		float(swing.striking_abduction_degrees)
	)
	_set_elbow(striking_arm, float(swing.striking_elbow_degrees))
	guide_arm.rotation_degrees.x = float(swing.guide_shoulder_degrees)
	_set_elbow(guide_arm, float(swing.guide_elbow_degrees))
	_apply_attack_performance(
		swing, striking_arm, guide_arm, lead_leg, trail_leg,
		Vector3(
			pelvis_pitch - chest_pitch,
			deg_to_rad(pelvis_twist_degrees - chest_twist_degrees),
			deg_to_rad(adjustment_roll * 0.42 - chest_roll_degrees),
		),
	)
