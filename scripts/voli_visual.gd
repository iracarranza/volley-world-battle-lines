extends RefCounted

const Bodies := preload("res://vendor/vwm/body_type_models.gd")
const Pose := preload("res://scripts/athlete_pose.gd")
const ActorScene := preload("res://vendor/vwm/construction/scenes/components/player_actor_3d.tscn")

# Build through VWM's real scene/configure pipeline, including physical profile,
# garments, articulated hands, expressions, ink and painted surface markings.
# Transfer the finished body into the live input rig; replay controllers and
# presentation-only floor marks stay with the temporary actor.
static func build(lab: Node3D, parent: Node3D, body_type: String, appearance: Dictionary, physique: Dictionary) -> Dictionary:
	var actor = ActorScene.instantiate()
	parent.add_child(actor)
	actor.configure(42, true, str(physique.get("name", "Athlete")), str(physique.get("dominant_hand", lab.dominant_hand)), {
		"body_type": body_type,
		"appearance": appearance.duplicate(true),
		"height_cm": float(physique.height) * 100.0,
		"wingspan_cm": float(physique.span) * 100.0,
		"stride_length_m": clampf(0.43 * float(physique.height), 0.55, 1.15) * clampf(float(physique.get("stride_ratio", 1.0)), 0.8, 1.2),
		"position_role": "Libero" if str(physique.get("role", lab.position_role)) == "L" else str(physique.get("role", lab.position_role)),
	})
	var root: Node3D = actor.body_pivot
	var spec: Dictionary = actor.silhouette.duplicate(true)
	var rig_height: float = spec.get("rig_height", 1.88)
	var arms: Array[Node3D] = [actor.left_arm, actor.right_arm]
	var legs: Array[Node3D] = [actor.left_leg, actor.right_leg]
	var hip_x := absf(legs[1].position.x)
	actor.remove_child(root)
	parent.add_child(root)
	root.position = Vector3.ZERO
	root.rotation = Vector3.ZERO
	root.scale = Vector3.ONE * float(physique.height) / rig_height
	root.set_meta("vwm_construction", true)
	root.set_meta("shoe_base_pitch", PI * 0.5 if str(spec.shoe.get("shape", "capsule")) == "capsule" else 0.0)
	Pose.base(root, 0, 0, 0, false)
	Pose.ground_feet(root)
	parent.remove_child(actor)
	actor.queue_free()
	return {"body": root, "arms": arms, "legs": legs, "rig_height": rig_height, "hip_x": hip_x, "type": body_type, "spec": spec}
