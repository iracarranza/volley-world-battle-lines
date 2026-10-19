extends "res://vendor/vwm/construction/scenes/components/surface_mark_renderer_3d.gd"

## Presentation refinement for the existing surface-mark authority.
##
## The base renderer owns mark identity, placement, surface masks and sticker-mask
## compatibility. This subclass changes only the pigment contrast that reaches the
## same shader. The direction of contrast is derived from the mesh's live base
## material, so a mark that was already lighter than a dark coat becomes lighter
## still, while a dark mark on a light coat becomes darker. No mark changes
## silhouette, geometry, or physical state.

const GENERAL_CONTRAST_GAIN: float = 0.18
const PATCH_CONTRAST_GAIN: float = 0.34
const BLAZE_CONTRAST_GAIN: float = 0.22
const SCAR_CONTRAST_GAIN: float = 0.12


func _apply_overlay(
	mesh: MeshInstance3D,
	pattern: int,
	part_kind: int,
	arm_side: float,
	segment_index: int,
	mark_side: float,
	scar_arm_side: float,
	seed: float,
	ink: Color,
	flat: bool,
) -> void:
	var base_colour := _mesh_base_colour(mesh)
	var gain := GENERAL_CONTRAST_GAIN
	if pattern == PATTERN_PATCH:
		## Patches have to remain legible at roster/headshot scale; their irregular
		## silhouette already prevents this stronger value reading as an eye target.
		gain = PATCH_CONTRAST_GAIN
	elif pattern == PATTERN_BLAZE:
		gain = BLAZE_CONTRAST_GAIN
	elif pattern == PATTERN_SCAR:
		## Scars are intentionally quieter than coat markings.
		gain = SCAR_CONTRAST_GAIN

	var boosted := _push_away_from_surface(base_colour, ink, gain)
	super._apply_overlay(
		mesh, pattern, part_kind, arm_side, segment_index,
		mark_side, scar_arm_side, seed, boosted, flat,
	)


func _mesh_base_colour(mesh: MeshInstance3D) -> Color:
	var material := mesh.material_override as StandardMaterial3D
	if material != null:
		return material.albedo_color
	if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		var surface_material := mesh.get_active_material(0) as StandardMaterial3D
		if surface_material != null:
			return surface_material.albedo_color
	return Color(0.5, 0.5, 0.5, 1.0)


func _push_away_from_surface(base_colour: Color, ink: Color, gain: float) -> Color:
	var base_luma := base_colour.get_luminance()
	var ink_luma := ink.get_luminance()
	if ink_luma >= base_luma:
		return ink.lightened(gain)
	return ink.darkened(gain)
