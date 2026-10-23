extends CanvasLayer
## Vision focus (prototype). When an action is released a directed, triangular beam fans out from the athlete toward the ball, like light through a prism:
## the beam's width follows the action's charge (a strong action narrows it), the athlete's Accuracy sets how fast it clears from its centre line outward,
## and current Stamina sets how blurred and dark everything outside it is (Endurance softens the fatigue part). Its edges refract. The trajectory preview is shaped by Ball Control: its length and opacity grow with it, and it
## can be limited to the Moment of Contact. Every part is a setting, and the whole thing is off by default; the settings last for the session.
const Stats := preload("res://scripts/stat_tuning.gd")
const Shade := preload("res://resources/vision_focus.gdshader")

# Settings (session-wide)
static var enabled := false
static var focus_beam := true          # the charge-width beam and its clearing
static var fatigue_obscuration := true # Stamina sets the blur and darkness outside the beam
static var acc_clarity := true         # Accuracy sets how fast the beam clears
static var preview_by_ball_control := true
static var preview_only_in_moc := true
static var width_none := 0.55          # the beam's half-width at its far end, in screen heights, for a barely charged action
static var width_full := 0.17          # ... and for a full charge
static var peripheral_blur := 1.0      # scale on the blur outside the beam
static var clarity_seconds := 0.80     # how long the beam takes to clear at neutral Accuracy
const START_CLEAR := 0.20              # the share of the beam's width that is sharp the moment of release
const FADE_IN := 0.10
const FADE_OUT := 0.30

var lab: Node3D
var quad: MeshInstance3D
var material: ShaderMaterial
var age := 0.0          # seconds since the action was released
var strength := 0.0     # 0..1, the effect's fade
var was_armed := false
var last_contact_mark := -1.0

func _init() -> void:
	layer = 0 # over the 3D view, under the HUD (layer 1)

func setup(session: Node3D) -> void:
	lab = session
	# A post-process quad on the camera: the screen texture of a 2D layer does not include the 3D picture in this renderer, but a spatial shader's does.
	material = ShaderMaterial.new()
	material.shader = Shade
	quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	quad.mesh = mesh
	quad.material_override = material
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lab.camera.add_child(quad)
	quad.hide()

# --- The numbers the beam is made of ---------------------------------------------------------------------------------------------------------

static func beam_radius(charge: float) -> float:
	return lerpf(width_none, width_full, clampf(charge, 0.0, 1.0))

# Seconds the beam takes to clear at this Accuracy: better Accuracy clears faster.
static func clarity_time(accuracy: float) -> float:
	return clarity_seconds / maxf(Stats.pace(accuracy) if acc_clarity else 1.0, 0.2)

# 0 at release, 1 once the beam has cleared. Eased, so it opens quickly and settles.
static func clarity(seconds_since_release: float, accuracy: float) -> float:
	var t := clampf(seconds_since_release / maxf(clarity_time(accuracy), 0.01), 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.0)

# The share of the beam's width that is sharp: the centre line first, widening to the whole beam as it clears.
static func core_fraction(clarity_now: float) -> float:
	return lerpf(START_CLEAR, 1.0, clarity_now)

# The part of the screen the fatigue obscures: how far below full Stamina the athlete is, less what Endurance covers.
static func fatigue(stamina_fraction: float, endurance: float) -> float:
	if not fatigue_obscuration:
		return 0.0
	var tired := clampf(1.0 - stamina_fraction, 0.0, 1.0)
	var covered := clampf((endurance - 65.0) / 70.0, -0.2, 0.5)
	return clampf(tired * (1.0 - covered), 0.0, 1.0)

static func blur_for(fatigue_now: float) -> float:
	return 0.020 * peripheral_blur * (0.35 + 0.65 * fatigue_now)

static func darkness_for(fatigue_now: float) -> float:
	return 0.25 + 0.50 * fatigue_now

# The trajectory preview, shaped by Ball Control (a baseline stays readable for everyone) and, optionally, limited to the Moment of Contact.
static func ball_control_scale(ball_control: float) -> float:
	return lerpf(0.45, 1.0, clampf((ball_control - 50.0) / 49.0, 0.0, 1.0))

static func shape_preview(hint: Dictionary, ball_control: float, in_moc: bool) -> Dictionary:
	if not enabled or hint.is_empty():
		return hint
	if preview_only_in_moc and not in_moc:
		return {}
	if not preview_by_ball_control:
		return hint
	var scale := ball_control_scale(ball_control)
	var shaped := hint.duplicate()
	var points: Array = hint.get("points", [])
	var keep := maxi(2, int(round(float(points.size()) * scale)))
	shaped["points"] = points.slice(0, mini(keep, points.size()))
	shaped["opacity"] = scale
	return shaped

func _process(dt: float) -> void:
	tick(dt)

# --- Per frame --------------------------------------------------------------------------------------------------------------------------------

func tick(dt: float) -> void:
	if lab == null:
		return
	var live: bool = enabled and focus_beam and lab.armed and lab.ball_active and not lab.is_benched()
	if live and not was_armed:
		age = 0.0
	was_armed = live
	if live:
		age += dt
		strength = minf(1.0, strength + dt / FADE_IN)
	else:
		strength = maxf(0.0, strength - dt / FADE_OUT)
	quad.visible = strength > 0.001
	if not quad.visible:
		return
	var athlete = lab.athlete
	var charge: float = lab.prepared_output_charge()
	var half_width := beam_radius(charge)
	var accuracy: float = float(athlete.build.accuracy)
	var size_now: Vector2 = lab.get_viewport().get_visible_rect().size
	# The beam runs from the athlete toward the ball (or, with no ball, straight ahead and up the screen).
	var apex := Vector2(0.5, 0.82)
	var head: Vector3 = lab.player.position + Vector3.UP * float(athlete.body_height()) * 0.85
	if not lab.camera.is_position_behind(head):
		apex = _to_uv(lab.camera.unproject_position(head), size_now)
	var target := Vector2(0.5, 0.35)
	if lab.ball_active and not lab.camera.is_position_behind(lab.ball.position):
		target = _to_uv(lab.camera.unproject_position(lab.ball.position), size_now)
	if apex.distance_to(target) < 0.04:
		target = apex + Vector2(0.0, -0.3)
	var tired := fatigue(athlete.stamina / maxf(athlete.max_stamina(), 1.0), float(athlete.build.endurance))
	material.set_shader_parameter("apex", apex)
	material.set_shader_parameter("target", target)
	material.set_shader_parameter("aspect", size_now.x / maxf(size_now.y, 1.0))
	material.set_shader_parameter("half_width", half_width)
	material.set_shader_parameter("core", core_fraction(clarity(age, accuracy)))
	material.set_shader_parameter("blur_amount", blur_for(tired))
	material.set_shader_parameter("darkness", darkness_for(tired))
	material.set_shader_parameter("strength", strength)

func _to_uv(screen: Vector2, size: Vector2) -> Vector2:
	return Vector2(clampf(screen.x / maxf(size.x, 1.0), -0.5, 1.5), clampf(screen.y / maxf(size.y, 1.0), -0.5, 1.5))
