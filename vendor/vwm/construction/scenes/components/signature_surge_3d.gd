class_name SignatureSurge3D
extends Node3D

## Presentation-only signature action aura.
##
## The rig supplies the actual volleyball action. This component reads that
## rig's current anatomy and adds short-lived light immediately around the body
## part doing the exceptional work. It never changes simulation, contact,
## trajectory, eligibility, or result state.

const MOVE_COLOURS := {
	"block_crush": Color(1.00, 0.20, 0.045, 1.0),
	"high_hands": Color(0.15, 0.88, 1.00, 1.0),
	"foresight": Color(0.52, 0.36, 1.00, 1.0),
	"heroics": Color(1.00, 0.76, 0.10, 1.0),
	"monster_block": Color(0.72, 0.12, 1.00, 1.0),
}

@onready var core: MeshInstance3D = $Core
@onready var pulse: MeshInstance3D = $Burst
@onready var fields: Array[MeshInstance3D] = [
	$Rings/Ring0, $Rings/Ring1, $Rings/Ring2,
]
@onready var traces: Array[MeshInstance3D] = [
	$Streams/Stream0, $Streams/Stream1, $Streams/Stream2,
	$Streams/Stream3, $Streams/Stream4, $Streams/Stream5,
]

var _move: String = ""
var _charge: float = 0.0
var _succeeded: bool = false

## Realised contact height supplied by PlayerActor3D. Review tools may set it
## directly. It is a presentation anchor, never a gameplay input.
var contact_anchor_meters: float = 1.2
## Local screen-plane direction used only by early-commit and pursuit
## afterimages. The body itself still carries the authoritative movement.
var action_direction: Vector2 = Vector2(1.0, 0.0)


func _ready() -> void:
	for visual in [core, pulse] + fields + traces:
		var material := visual.get_active_material(0) as StandardMaterial3D
		if material != null:
			visual.material_override = material.duplicate() as StandardMaterial3D
	_hide_all()
	visible = false


static func profile_for(move: String) -> Dictionary:
	var key := move.to_lower().replace(" ", "_")
	return {
		"move": key,
		"colour": Color(MOVE_COLOURS.get(key, Color(1.0, 0.84, 0.20, 1.0))),
		"precision": key in ["high_hands", "foresight"],
		"impact": key in ["block_crush", "heroics", "monster_block"],
		"advantage": {
			"foresight": "time",
			"heroics": "reach",
			"block_crush": "force",
			"high_hands": "precision",
			"monster_block": "space",
		}.get(key, "emphasis"),
		"shape": {
			"foresight": "early_commitment",
			"heroics": "reactive_reach",
			"block_crush": "contested_compression",
			"high_hands": "extreme_contact",
			"monster_block": "expanded_reach",
		}.get(key, "pulse"),
	}


func set_cue(move: String, charge: float, succeeded: bool, phase: float) -> void:
	_move = move.to_lower().replace(" ", "_")
	_charge = clampf(charge, 0.0, 1.0)
	_succeeded = succeeded
	_hide_all()
	if _move.is_empty() or _charge <= 0.001:
		visible = false
		return
	visible = phase >= -0.96 and phase <= 0.94
	if not visible:
		return

	var colour := Color(MOVE_COLOURS.get(_move, Color(1.0, 0.84, 0.20, 1.0)))
	var accent := colour.lerp(Color.WHITE, 0.52)
	var strength := lerpf(0.46, 1.0, _charge)
	match _move:
		"foresight":
			_draw_foresight(phase, strength, colour, accent)
		"heroics":
			_draw_heroics(phase, strength, colour, accent)
		"block_crush":
			_draw_block_crush(phase, strength, colour, accent)
		"high_hands":
			_draw_high_hands(phase, strength, colour, accent)
		"monster_block":
			_draw_monster_block(phase, strength, colour, accent)
		_:
			_place_field(core, _torso_point(), Vector2(0.54, 0.70), 0.0, colour, 0.18)


func _draw_foresight(
	phase: float, strength: float, colour: Color, accent: Color,
) -> void:
	## This cue exists before opponent contact. Once truth arrives, a correct read
	## quietly resolves; a misread shears apart while the committed body remains
	## in the wrong place.
	var form := smoothstep(-0.92, -0.48, phase)
	var truth := smoothstep(-0.06, 0.18, phase)
	var dissipate := 1.0 - smoothstep(0.22, 0.72, phase)
	var weight := form * dissipate * strength
	var head := _head_point()
	var hips := _hips_point()
	var direction := action_direction.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT

	_place_field(core, head + Vector3(0.0, 0.01, 0.22), Vector2(0.46, 0.38), 0.0, colour, weight * 0.34)
	_place_field(fields[0], head + Vector3(direction.x * 0.10, -0.04, 0.23), Vector2(0.62, 0.46), 0.0, colour, weight * 0.24)
	## Two short ghosts point from the read into the already-started movement.
	for index in range(2):
		var offset := direction * (0.18 + float(index) * 0.18)
		var start := hips + Vector3(offset.x, offset.y, 0.13)
		var finish := start + Vector3(direction.x, direction.y, 0.0) * (0.34 + float(index) * 0.08)
		_place_trace(traces[index], start, finish, 0.14, colour, weight * (0.32 - float(index) * 0.06))

	if _succeeded:
		## Reality catches the prediction: the aura contracts toward the arriving
		## body instead of celebrating the later dig as a powered contact.
		var confirmation := truth * (1.0 - smoothstep(0.20, 0.52, phase))
		_place_field(fields[1], hips + Vector3(direction.x * 0.18, 0.04, 0.22), Vector2(0.70, 0.46), 0.0, accent, confirmation * strength * 0.28)
	else:
		## The wrong read breaks directionally. No icon and no fake dig: three
		## fragments simply lose their common line as truth diverges.
		var fracture := truth * dissipate * strength
		for index in range(3):
			var side := -1.0 if index % 2 == 0 else 1.0
			var origin := hips + Vector3(direction.x * 0.18, 0.12 + float(index) * 0.13, 0.14)
			var end := origin + Vector3(-direction.x * (0.18 + float(index) * 0.08), side * 0.18, 0.0)
			_place_trace(traces[index + 2], origin, end, 0.09, accent, fracture * (0.42 - float(index) * 0.06))


func _draw_heroics(
	phase: float, strength: float, colour: Color, accent: Color,
) -> void:
	## Heroics stays almost absent until its unusually small actionable window.
	var tell := smoothstep(-0.30, -0.12, phase)
	var action := smoothstep(-0.10, 0.10, phase)
	var fade := 1.0 - smoothstep(0.28, 0.76, phase)
	var legs := _hips_point() + Vector3(0.0, -0.40, 0.12)
	var direction := action_direction.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT

	if not _succeeded:
		## A denied attempt never reaches the ball. Only the tiny ignition tell is
		## allowed, and it is gone before ordinary continuation.
		var extinguish := 1.0 - smoothstep(-0.10, 0.08, phase)
		var denied := tell * extinguish * strength
		_place_field(core, legs + Vector3(0.0, 0.0, 0.10), Vector2(0.48, 0.32), 0.0, colour, denied * 0.28)
		_place_trace(traces[0], legs, legs + Vector3(direction.x * 0.28, 0.08, 0.0), 0.10, accent, denied * 0.25)
		return

	var active := maxf(tell * (1.0 - action), action) * fade * strength
	var torso := _torso_point()
	var contact := _platform_point()
	## Short body-bound afterimages trail the accelerating torso and legs. Their
	## overlapping softness reads as motion residue, not a projectile.
	for index in range(3):
		var back := direction * (-0.18 - float(index) * 0.20)
		var position := torso + Vector3(back.x, back.y - float(index) * 0.04, 0.10 + float(index) * 0.01)
		_place_field(fields[index], position + Vector3(0.0, 0.0, 0.10), Vector2(0.74 - float(index) * 0.09, 0.92 - float(index) * 0.10), 0.18 * direction.x, colour, active * (0.28 - float(index) * 0.055))
	for index in range(3):
		var start := legs + Vector3(0.0, float(index) * 0.10, 0.13)
		var end := start + Vector3(direction.x * (0.48 + float(index) * 0.12), 0.18 + float(index) * 0.05, 0.0)
		_place_trace(traces[index], start, end, 0.13, colour, active * (0.34 - float(index) * 0.055))
	var impact := action * (1.0 - smoothstep(0.14, 0.42, phase)) * strength
	_place_field(core, contact + Vector3(0.0, 0.0, 0.12), Vector2(0.62, 0.44), 0.0, accent, impact * 0.44)
	_place_field(pulse, contact + Vector3(0.0, 0.0, 0.10), Vector2(0.90, 0.58), 0.0, colour, impact * 0.28)


func _draw_block_crush(
	phase: float, strength: float, colour: Color, accent: Color,
) -> void:
	var prepare := smoothstep(-0.66, -0.22, phase)
	var collide := smoothstep(-0.10, 0.10, phase)
	var fade := 1.0 - smoothstep(0.28, 0.72, phase)
	var arm_weight := prepare * fade * strength
	var shoulder := _striking_shoulder()
	var forearm := _striking_forearm()
	var hand := _striking_hand()
	var contact := hand.lerp(Vector3(hand.x, contact_anchor_meters, hand.z), 0.45)

	_place_field(core, shoulder + Vector3(0.0, 0.0, 0.10), Vector2(0.48, 0.54), 0.0, colour, arm_weight * 0.15)
	_place_trace(traces[0], shoulder, forearm, 0.15, colour, arm_weight * 0.24)
	_place_trace(traces[1], forearm, hand, 0.13, accent, arm_weight * 0.28)
	## Full treatment requires resistance. A failed/absent collision retains the
	## arm aura but cannot manufacture a block-crush impact.
	var resistance := collide * fade * strength * (1.0 if _succeeded else 0.18)
	_place_field(fields[0], contact + Vector3(0.0, 0.10, 0.12), Vector2(0.74, 0.34), 0.0, colour, resistance * 0.26)
	_place_field(fields[1], contact + Vector3(0.0, -0.08, 0.13), Vector2(0.82, 0.30), 0.0, accent, resistance * 0.22)
	## The useful first-pass idea survives as compression along the contested
	## hand-ball-block axis, now made of brief light pressure rather than plates.
	_place_trace(traces[2], contact + Vector3(0.0, 0.30, 0.0), contact + Vector3(0.0, -0.24, 0.0), 0.20, accent, resistance * 0.34)
	_place_field(pulse, contact, Vector2(0.52, 0.44), 0.0, accent, resistance * 0.30)


func _draw_high_hands(
	phase: float, strength: float, colour: Color, accent: Color,
) -> void:
	var prepare := smoothstep(-0.68, -0.24, phase)
	var contact_time := smoothstep(-0.10, 0.10, phase)
	var fade := 1.0 - smoothstep(0.30, 0.72, phase)
	var weight := prepare * fade * strength
	var forearm := _striking_forearm()
	var hand := _striking_hand()
	var high_contact := Vector3(hand.x, maxf(contact_anchor_meters + 0.10, hand.y), hand.z)

	## A narrow aura climbs the hitting forearm and concentrates at the hand.
	_place_trace(traces[0], forearm, hand, 0.09, colour, weight * 0.18)
	_place_trace(traces[1], hand, high_contact + Vector3(0.05, 0.14, 0.0), 0.07, accent, weight * 0.24)
	_place_field(core, hand + Vector3(0.0, 0.0, 0.11), Vector2(0.34, 0.38), 0.0, colour, weight * 0.18)
	var interaction := contact_time * fade * strength * (1.0 if _succeeded else 0.30)
	## Only the extreme upper contact region is emphasized. The angled sliver
	## peels off the fingertips with the ball; nothing surrounds the lower body.
	_place_field(fields[0], high_contact + Vector3(0.0, 0.04, 0.13), Vector2(0.44, 0.26), -0.28, accent, interaction * 0.30)
	_place_trace(traces[2], high_contact, high_contact + Vector3(0.34, 0.24, 0.0), 0.07, accent, interaction * 0.34)
	_place_trace(traces[3], high_contact + Vector3(0.02, 0.02, 0.0), high_contact + Vector3(0.24, 0.36, 0.0), 0.05, colour, interaction * 0.24)
	_place_field(pulse, high_contact, Vector2(0.32, 0.26), 0.0, Color.WHITE, interaction * 0.26)


func _draw_monster_block(
	phase: float, strength: float, colour: Color, accent: Color,
) -> void:
	var establish := smoothstep(-0.60, -0.18, phase)
	var maximum := smoothstep(-0.08, 0.12, phase)
	var fade := 1.0 - smoothstep(0.30, 0.76, phase)
	var weight := establish * fade * strength
	var left_forearm := _forearm_point("Left")
	var right_forearm := _forearm_point("Right")
	var left_hand := _hand_point("Left")
	var right_hand := _hand_point("Right")

	_place_trace(traces[0], left_forearm, left_hand, 0.15, colour, weight * 0.24)
	_place_trace(traces[1], right_forearm, right_hand, 0.15, colour, weight * 0.24)
	var expansion := maximum * fade * strength
	## Each extension grows directly out of a blocking hand/forearm. The centre
	## remains open so the Voli's head and the actual block stay readable.
	var left_outer := left_hand + Vector3(-0.34 - expansion * 0.14, 0.10, 0.0)
	var right_outer := right_hand + Vector3(0.34 + expansion * 0.14, 0.10, 0.0)
	_place_field(fields[0], left_hand.lerp(left_outer, 0.38) + Vector3(0.0, 0.0, 0.22), Vector2(0.82 + expansion * 0.18, 0.82), -0.12, colour, weight * 0.27 + expansion * 0.15)
	_place_field(fields[1], right_hand.lerp(right_outer, 0.38) + Vector3(0.0, 0.0, 0.22), Vector2(0.82 + expansion * 0.18, 0.82), 0.12, colour, weight * 0.27 + expansion * 0.15)
	_place_trace(traces[2], left_hand, left_outer, 0.15, accent, expansion * 0.38)
	_place_trace(traces[3], right_hand, right_outer, 0.15, accent, expansion * 0.38)
	_place_trace(traces[4], left_hand, left_hand + Vector3(-0.12, 0.42, 0.0), 0.10, colour, expansion * 0.22)
	_place_trace(traces[5], right_hand, right_hand + Vector3(0.12, 0.42, 0.0), 0.10, colour, expansion * 0.22)
	_place_field(core, left_hand.lerp(right_hand, 0.5) + Vector3(0.0, 0.18, 0.11), Vector2(0.64, 0.28), 0.0, accent, expansion * 0.12)


func _place_field(
	visual: MeshInstance3D, position_: Vector3, size: Vector2,
	rotation_z: float, colour: Color, alpha: float,
) -> void:
	visual.position = position_
	visual.rotation = Vector3(0.0, 0.0, rotation_z)
	visual.scale = Vector3(size.x, size.y, 1.0)
	_set_glow(visual, colour, alpha)


func _place_trace(
	visual: MeshInstance3D, start: Vector3, finish: Vector3, width: float,
	colour: Color, alpha: float,
) -> void:
	var delta := finish - start
	var length := Vector2(delta.x, delta.y).length()
	if length < 0.001:
		_set_glow(visual, colour, 0.0)
		return
	visual.position = start.lerp(finish, 0.5) + Vector3(0.0, 0.0, 0.14)
	visual.rotation = Vector3(0.0, 0.0, atan2(-delta.x, delta.y))
	visual.scale = Vector3(width, length, 1.0)
	_set_glow(visual, colour, alpha)


func _head_point() -> Vector3:
	return _rig_point("BodyPivot/Head", Vector3.ZERO, Vector3(0.0, 1.72, 0.0))


func _torso_point() -> Vector3:
	return _rig_point("BodyPivot/Torso", Vector3.ZERO, Vector3(0.0, 1.10, 0.0))


func _hips_point() -> Vector3:
	var left := _rig_point("BodyPivot/LeftLeg", Vector3.ZERO, Vector3(-0.16, 0.48, 0.0))
	var right := _rig_point("BodyPivot/RightLeg", Vector3.ZERO, Vector3(0.16, 0.48, 0.0))
	return left.lerp(right, 0.5) + Vector3(0.0, 0.18, 0.0)


func _platform_point() -> Vector3:
	return _forearm_point("Left").lerp(_forearm_point("Right"), 0.5) + Vector3(0.0, 0.0, 0.08)


func _striking_side() -> String:
	var actor := get_parent()
	if actor != null and str(actor.get("dominant_hand")) == "Left":
		return "Left"
	return "Right"


func _striking_shoulder() -> Vector3:
	var side := _striking_side()
	var x := -0.40 if side == "Left" else 0.40
	return _rig_point("BodyPivot/%sArm" % side, Vector3.ZERO, Vector3(x, 1.52, 0.0))


func _striking_forearm() -> Vector3:
	return _forearm_point(_striking_side())


func _striking_hand() -> Vector3:
	return _hand_point(_striking_side())


func _forearm_point(side: String) -> Vector3:
	var x := -0.40 if side == "Left" else 0.40
	return _rig_point(
		"BodyPivot/%sArm/Elbow" % side,
		Vector3(0.0, -0.18, 0.0), Vector3(x, 1.04, 0.0),
	)


func _hand_point(side: String) -> Vector3:
	var x := -0.40 if side == "Left" else 0.40
	return _rig_point(
		"BodyPivot/%sArm/Elbow" % side,
		Vector3(0.0, -0.43, 0.0), Vector3(x, 0.80, 0.0),
	)


func _rig_point(path: NodePath, offset: Vector3, fallback: Vector3) -> Vector3:
	var actor := get_parent()
	if actor == null:
		return fallback
	var node := actor.get_node_or_null(path) as Node3D
	if node == null:
		return fallback
	return to_local(node.to_global(offset))


func _set_glow(visual: MeshInstance3D, colour: Color, alpha: float) -> void:
	var material := visual.material_override as StandardMaterial3D
	if material == null:
		return
	alpha = clampf(alpha, 0.0, 0.72)
	visual.visible = alpha > 0.003
	material.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	material.emission = Color(colour.r, colour.g, colour.b, 1.0)
	material.emission_energy_multiplier = lerpf(0.50, 2.75, alpha / 0.72)


func _hide_all() -> void:
	for visual in [core, pulse] + fields + traces:
		visual.visible = false


func clear() -> void:
	_move = ""
	_charge = 0.0
	_succeeded = false
	_hide_all()
	visible = false
