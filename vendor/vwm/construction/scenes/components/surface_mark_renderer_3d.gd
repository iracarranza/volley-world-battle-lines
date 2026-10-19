class_name SurfaceMarkRenderer3D
extends Node

## Paints a voli's identity markings as colour on existing body surfaces.
##
## `BodyTypeModels` still describes the original tabby bars, spots, blazes,
## patches, speckles and scars as cosmetic meshes for compatibility. Those meshes
## are hidden here and the same deterministic marking choice is redrawn with a
## material overlay instead, so pigmentation cannot change silhouette or cast a
## little mark-shaped shadow.
##
## Anatomy remains geometry. Coat / skin identity remains surface colour. Animal
## marks live on the head and exposed arms; Vegi also paint applicable marks onto
## their produce torso, because that is their dominant exposed body surface.
##
## The rig faces -Z. Face and torso masks therefore use the -Z hemisphere, matching
## the expression system's own surface convention.

const BodyTypeModelsScript := preload("res://vendor/vwm/body_type_models.gd")

const PATTERN_NONE: int = 0
const PATTERN_TABBY: int = 1
const PATTERN_SPOTS: int = 2
const PATTERN_BLAZE: int = 3
const PATTERN_PATCH: int = 4
const PATTERN_SPECKLE: int = 5
const PATTERN_SCAR: int = 6

const PART_HEAD: int = 0
const PART_ARM: int = 1
const PART_TORSO: int = 2

const LEGACY_MARK_PREFIXES: Array[String] = [
	"Tabby", "Spot", "Blaze", "Patch", "Speckle", "Scar",
]

var _signature: String = ""
var _suppressed_for_mask: bool = false
var _shader: Shader = null


func _ready() -> void:
	## Mark identity changes only when the actor is rebuilt or repainted. The old
	## per-frame sync made every voli inspect the same invariant rig hierarchy on
	## every rendered frame (twelve tree walks in the match view).
	set_process(false)
	call_deferred("_sync")


## Explicit invalidation point for actor rebuilds and the sticker mask pass.
func refresh() -> void:
	_signature = ""
	_sync()


func _sync() -> void:
	var actor := get_parent()
	if actor == null:
		return
	var silhouette_value: Variant = actor.get("silhouette")
	if not (silhouette_value is Dictionary):
		return
	var silhouette: Dictionary = silhouette_value
	if silhouette.is_empty():
		return

	## Compatibility mark meshes may be rebuilt when an actor is reconfigured, so
	## suppress them every frame even when the semantic marking signature is stable.
	_hide_legacy_mark_geometry(actor)

	var head := actor.get_node_or_null("BodyPivot/Head") as MeshInstance3D
	if head == null:
		return
	if _mask_pass_active(actor, head):
		if not _suppressed_for_mask:
			_clear_overlays(actor)
			_suppressed_for_mask = true
		return
	if _suppressed_for_mask:
		## `VoliSticker` restores the real palette immediately after its binary
		## contour-mask read. Rebuild the colour overlays on the next frame.
		_suppressed_for_mask = false
		_signature = ""

	var player_id := int(actor.get("player_id"))
	var body_type := str(actor.get("body_type"))
	var appearance_value: Variant = actor.get("appearance")
	var appearance: Dictionary = {}
	if appearance_value is Dictionary:
		appearance = appearance_value
	var marking := BodyTypeModelsScript.chosen_marking(
		body_type, player_id, appearance
	)
	var skin: Color = silhouette.get("skin", Color("d6a06c"))
	var flat := bool(actor.get("flat_shading"))
	var produce := str(silhouette.get("produce", ""))
	var next_signature := "%d|%s|%s|%s|%s|%s" % [
		player_id, body_type, produce, marking, skin.to_html(true), str(flat),
	]
	if next_signature == _signature:
		return
	_signature = next_signature
	_clear_overlays(actor)
	if marking == "none":
		return

	var pattern := _pattern_id(marking)
	if pattern == PATTERN_NONE:
		return
	var seed_offset := absi(hash("coat:%d" % player_id))
	var mark_side := 1.0 if (seed_offset & 1) == 0 else -1.0
	var scar_arm_side := -1.0 if (seed_offset & 1) == 0 else 1.0
	var seed := float(seed_offset % 10007)
	var ink := skin.darkened(0.34) if skin.get_luminance() > 0.22 \
		else skin.lightened(0.30)
	if marking == "scar":
		ink = skin.lightened(0.55)
	elif marking == "blaze":
		ink = skin.lightened(0.30).lerp(Color("f2e6c8"), 0.35)

	_apply_overlay(
		head, pattern, PART_HEAD, 0.0, 0, mark_side, scar_arm_side,
		seed, ink, flat,
	)

	## A Vegi's produce is its body, not a shirt. Put non-scar coat variation on
	## the torso as well as the small face so the marking reads at roster distance.
	## Scars stay local marks rather than becoming a stripe across the whole fruit.
	if body_type == "Vegi" and marking != "scar":
		var torso := actor.get_node_or_null("BodyPivot/Torso") as MeshInstance3D
		if torso != null:
			_apply_overlay(
				torso, pattern, PART_TORSO, 0.0, 0,
				mark_side, scar_arm_side, seed, ink, flat,
			)

	## Each arm bone owns its overlay, so the surface pattern follows the elbow.
	for side_info in [
		["BodyPivot/LeftArm", -1.0],
		["BodyPivot/RightArm", 1.0],
	]:
		var arm_root := actor.get_node_or_null(str(side_info[0])) as Node3D
		if arm_root == null:
			continue
		var upper := arm_root.get_node_or_null("Mesh") as MeshInstance3D
		var elbow := arm_root.get_node_or_null("Elbow") as Node3D
		var fore: MeshInstance3D = null
		if elbow != null:
			fore = elbow.get_node_or_null("Mesh") as MeshInstance3D
		if upper != null:
			_apply_overlay(
				upper, pattern, PART_ARM, float(side_info[1]), 0,
				mark_side, scar_arm_side, seed, ink, flat,
			)
		if fore != null:
			_apply_overlay(
				fore, pattern, PART_ARM, float(side_info[1]), 1,
				mark_side, scar_arm_side, seed, ink, flat,
			)


func _pattern_id(marking: String) -> int:
	match marking:
		"tabby":
			return PATTERN_TABBY
		"spots":
			return PATTERN_SPOTS
		"blaze":
			return PATTERN_BLAZE
		"patch":
			return PATTERN_PATCH
		"speckle":
			return PATTERN_SPECKLE
		"scar":
			return PATTERN_SCAR
	return PATTERN_NONE


func _is_legacy_mark_name(node_name: String) -> bool:
	for prefix in LEGACY_MARK_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _hide_legacy_mark_geometry(actor: Node) -> void:
	for path in ["BodyPivot", "BodyPivot/LeftArm", "BodyPivot/RightArm"]:
		var parent := actor.get_node_or_null(path)
		if parent == null:
			continue
		for child in parent.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null or not mesh.has_meta("cosmetic"):
				continue
			if not _is_legacy_mark_name(str(mesh.name)):
				continue
			mesh.visible = false
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _markable_meshes(actor: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for path in ["BodyPivot/Head", "BodyPivot/Torso"]:
		var mesh := actor.get_node_or_null(path) as MeshInstance3D
		if mesh != null:
			meshes.append(mesh)
	for root_path in ["BodyPivot/LeftArm", "BodyPivot/RightArm"]:
		var root := actor.get_node_or_null(root_path) as Node3D
		if root == null:
			continue
		var upper := root.get_node_or_null("Mesh") as MeshInstance3D
		if upper != null:
			meshes.append(upper)
		var elbow := root.get_node_or_null("Elbow") as Node3D
		var fore: MeshInstance3D = null
		if elbow != null:
			fore = elbow.get_node_or_null("Mesh") as MeshInstance3D
		if fore != null:
			meshes.append(fore)
	return meshes


func _clear_overlays(actor: Node) -> void:
	for mesh in _markable_meshes(actor):
		var overlay := mesh.material_overlay
		if overlay != null and overlay.has_meta("voli_surface_mark"):
			mesh.material_overlay = null


func _mask_pass_active(actor: Node, head: MeshInstance3D) -> bool:
	## `VoliSticker` paints the whole body exact black, then the arms exact white,
	## to recover an arm contour. Surface colour must disappear for that render.
	if not bool(actor.get("flat_shading")):
		return false
	var material := head.material_override as StandardMaterial3D
	if material == null:
		return false
	var color := material.albedo_color
	return _same_color(color, Color.BLACK) or _same_color(color, Color.WHITE)


func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.0001 \
		and absf(a.g - b.g) < 0.0001 \
		and absf(a.b - b.b) < 0.0001 \
		and absf(a.a - b.a) < 0.0001


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
	if mesh.mesh == null:
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _shader_code()
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.render_priority = 1
	material.set_meta("voli_surface_mark", true)
	var bounds := mesh.get_aabb()
	material.set_shader_parameter("bounds_center", bounds.position + bounds.size * 0.5)
	material.set_shader_parameter("bounds_half", bounds.size * 0.5)
	material.set_shader_parameter("pattern", pattern)
	material.set_shader_parameter("part_kind", part_kind)
	material.set_shader_parameter("arm_side", arm_side)
	material.set_shader_parameter("segment_index", segment_index)
	material.set_shader_parameter("mark_side", mark_side)
	material.set_shader_parameter("scar_arm_side", scar_arm_side)
	material.set_shader_parameter("seed_value", seed)
	material.set_shader_parameter("mark_color", ink)
	material.set_shader_parameter("flat_mode", flat)
	mesh.material_overlay = material


func _shader_code() -> String:
	return """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform int pattern = 0;
uniform int part_kind = 0;
uniform float arm_side = 0.0;
uniform int segment_index = 0;
uniform float mark_side = 1.0;
uniform float scar_arm_side = -1.0;
uniform float seed_value = 0.0;
uniform vec4 mark_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform bool flat_mode = false;
uniform vec3 bounds_center = vec3(0.0);
uniform vec3 bounds_half = vec3(1.0);

varying vec3 mark_local;
const float PI_F = 3.14159265359;

float hash11(float n) {
	return fract(sin(n * 12.9898 + seed_value * 0.071) * 43758.5453);
}

float soft_disc(vec2 p, vec2 centre, float radius) {
	float d = distance(p, centre);
	return 1.0 - smoothstep(radius * 0.78, radius, d);
}

float head_pattern(vec3 q) {
	// The actor faces -Z; this also prevents marks bleeding onto the back of head.
	float front = 1.0 - smoothstep(-0.22, 0.08, q.z);
	float m = 0.0;
	if (pattern == 1) {
		// Three short, tapered forehead slashes. They sit above the eye line rather
		// than spanning the whole face as a dark visor.
		for (int i = 0; i < 3; i++) {
			float fi = float(i) - 1.0;
			float cx = fi * 0.215 + (hash11(10.0 + float(i)) - 0.5) * 0.030;
			float cy = 0.50 + (hash11(20.0 + float(i)) - 0.5) * 0.035;
			float lean = fi * 0.20 + (hash11(30.0 + float(i)) - 0.5) * 0.08;
			float py = q.y - cy;
			float line = abs((q.x - cx) - lean * py);
			float stroke = 1.0 - smoothstep(0.026, 0.050, line);
			float half_length = 0.24 - abs(fi) * 0.045;
			float extent = 1.0 - smoothstep(half_length * 0.72, half_length, abs(py));
			m = max(m, stroke * extent * front);
		}
	} else if (pattern == 2) {
		// One facial spot; the rest of this coat lives around the arms.
		vec2 centre = vec2(0.48 * mark_side, -0.16);
		m = soft_disc(q.xy, centre, 0.18) * front;
	} else if (pattern == 3) {
		// Organic blaze: asymmetric centre line, variable width and soft tapered
		// ends. The surface curvature supplies the rest of the shape.
		float phase = seed_value * 0.013;
		float t = clamp((q.y + 0.62) / 1.34, 0.0, 1.0);
		float centre = 0.035 * mark_side
			+ 0.032 * sin(q.y * 5.0 + phase)
			+ 0.016 * sin(q.y * 11.0 + phase * 0.63);
		float width = mix(0.085, 0.165, t)
			+ 0.014 * sin(q.y * 7.0 + phase * 1.17);
		width = max(width, 0.070);
		float stripe = 1.0 - smoothstep(width, width + 0.035, abs(q.x - centre));
		float vertical = smoothstep(-0.72, -0.51, q.y)
			* (1.0 - smoothstep(0.72, 0.86, q.y));
		m = stripe * vertical * front;
	} else if (pattern == 4) {
		// Irregular eye-side coat patch: a union of unequal lobes with a small
		// notch toward the nose. The eye can sit inside it without defining it.
		vec2 c = vec2(0.39 * mark_side, 0.15);
		float a = soft_disc(q.xy, c, 0.235);
		float b = soft_disc(q.xy, c + vec2(0.10 * mark_side, -0.17), 0.175);
		float d = soft_disc(q.xy, c + vec2(-0.08 * mark_side, 0.19), 0.145);
		float patch = max(a, max(b, d));
		float notch = soft_disc(q.xy, c + vec2(-0.19 * mark_side, 0.05), 0.105);
		m = patch * (1.0 - notch * 0.72) * front;
	} else if (pattern == 5) {
		// Small cheek / temple clusters, deliberately leaving the eye band and
		// centre of the face quiet. Sizes vary enough to avoid a freckle grid.
		for (int i = 0; i < 10; i++) {
			float fi = float(i);
			float side = mod(fi, 2.0) < 1.0 ? -1.0 : 1.0;
			float xmag = 0.34 + hash11(40.0 + fi * 3.1) * 0.24;
			float cy = 0.0;
			if (i < 6) {
				cy = -0.30 + hash11(80.0 + fi * 5.3) * 0.22;
			} else {
				cy = 0.42 + hash11(80.0 + fi * 5.3) * 0.15;
			}
			vec2 centre = vec2(side * xmag, cy);
			float radius = 0.027 + hash11(120.0 + fi) * 0.024;
			m = max(m, soft_disc(q.xy, centre, radius) * front);
		}
	} else if (pattern == 6) {
		// Thin diagonal change in coat tone. No thickness, no cast shadow.
		float signed_line = q.y - (0.13 + mark_side * 0.82 * (q.x - 0.18 * mark_side));
		float stroke = 1.0 - smoothstep(0.027, 0.048, abs(signed_line));
		float extent = 1.0 - smoothstep(0.34, 0.48, abs(q.x - 0.18 * mark_side));
		m = stroke * extent * front;
	}
	return m;
}

float arm_pattern(vec3 q) {
	float m = 0.0;
	float angle = atan(q.x, -q.z) / PI_F; // 0 is the front of the arm.
	if (pattern == 1) {
		// Rings are genuinely circumferential because the mask depends only on Y.
		if (segment_index == 0) {
			float a = 1.0 - smoothstep(0.055, 0.085, abs(q.y - 0.30));
			float b = 1.0 - smoothstep(0.055, 0.085, abs(q.y + 0.42));
			m = max(a, b);
		} else {
			m = 1.0 - smoothstep(0.055, 0.085, abs(q.y - 0.10));
		}
	} else if (pattern == 2) {
		// Spots use angle + height, so they wrap around the limb instead of
		// becoming flat pills stuck to the camera-facing side.
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float local_seed = seed_value + arm_side * 31.0 + float(segment_index) * 67.0;
			float cx = fract(sin(local_seed * 0.013 + fi * 4.17) * 43758.5453) * 1.55 - 0.775;
			float cy = fract(sin(local_seed * 0.021 + fi * 7.91) * 24634.6345) * 1.50 - 0.75;
			float radius = 0.11 + fract(sin(local_seed + fi * 9.3) * 15731.743) * 0.055;
			float dx = abs(angle - cx);
			dx = min(dx, 2.0 - dx);
			m = max(m, 1.0 - smoothstep(radius * 0.76, radius, length(vec2(dx, q.y - cy))));
		}
	} else if (pattern == 6 && segment_index == 1 && abs(arm_side - scar_arm_side) < 0.1) {
		// One forearm scar, diagonal across the cylindrical surface.
		float line = q.y - 0.70 * angle;
		float stroke = 1.0 - smoothstep(0.035, 0.060, abs(line));
		float around = 1.0 - smoothstep(0.32, 0.50, abs(angle));
		m = stroke * around;
	}
	return m;
}

float torso_pattern(vec3 q) {
	float front = 1.0 - smoothstep(-0.18, 0.16, q.z);
	float angle = atan(q.x, -q.z) / PI_F;
	float m = 0.0;
	if (pattern == 3) {
		// Vegi blaze: the same language as the facial blaze, enlarged for the
		// produce body and allowed a little more lateral drift.
		float phase = seed_value * 0.013;
		float centre = 0.055 * mark_side
			+ 0.045 * sin(q.y * 4.2 + phase)
			+ 0.020 * sin(q.y * 9.1 + phase * 0.71);
		float width = 0.14 + 0.035 * (0.5 + 0.5 * sin(q.y * 5.6 + phase * 1.11));
		float stripe = 1.0 - smoothstep(width, width + 0.045, abs(q.x - centre));
		float vertical = smoothstep(-0.95, -0.78, q.y)
			* (1.0 - smoothstep(0.82, 0.98, q.y));
		m = stripe * vertical * front;
	} else if (pattern == 5) {
		// Produce speckling wraps around the body, so a profile still reads as
		// mottled produce rather than a face-only freckle treatment.
		for (int i = 0; i < 18; i++) {
			float fi = float(i);
			float cx = hash11(210.0 + fi * 4.7) * 1.70 - 0.85;
			float cy = hash11(260.0 + fi * 6.1) * 1.52 - 0.76;
			float radius = 0.045 + hash11(310.0 + fi * 2.3) * 0.045;
			float dx = abs(angle - cx);
			dx = min(dx, 2.0 - dx);
			m = max(m, 1.0 - smoothstep(radius * 0.72, radius, length(vec2(dx, q.y - cy))));
		}
	} else if (pattern == 2) {
		// Future-safe if a Vegi palette ever admits spots: broad, sparse mottling.
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float cx = hash11(360.0 + fi * 5.7) * 1.55 - 0.775;
			float cy = hash11(410.0 + fi * 7.1) * 1.30 - 0.65;
			float radius = 0.12 + hash11(460.0 + fi) * 0.07;
			float dx = abs(angle - cx);
			dx = min(dx, 2.0 - dx);
			m = max(m, 1.0 - smoothstep(radius * 0.76, radius, length(vec2(dx, q.y - cy))));
		}
	} else if (pattern == 4) {
		// Future-safe irregular flank patch; currently not a generated Vegi mark.
		vec2 p = vec2(angle - 0.30 * mark_side, q.y - 0.05);
		float a = soft_disc(p, vec2(0.0), 0.29);
		float b = soft_disc(p, vec2(0.12 * mark_side, -0.19), 0.20);
		m = max(a, b);
	}
	return m;
}

void vertex() {
	mark_local = VERTEX;
}

void fragment() {
	vec3 safe_half = max(bounds_half, vec3(0.0001));
	vec3 q = (mark_local - bounds_center) / safe_half;
	float mask = head_pattern(q);
	if (part_kind == 1) {
		mask = arm_pattern(q);
	} else if (part_kind == 2) {
		mask = torso_pattern(q);
	}
	if (mask < 0.38) {
		discard;
	}
	ROUGHNESS = 0.78;
	if (flat_mode) {
		// Sticker bake: reproduce unshaded colour regions without forcing the live
		// court actor to become unlit too.
		ALBEDO = vec3(0.0);
		EMISSION = mark_color.rgb;
	} else {
		ALBEDO = mark_color.rgb;
		EMISSION = vec3(0.0);
	}
}
"""
