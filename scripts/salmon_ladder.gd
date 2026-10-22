extends "res://scripts/workout_drill.gd"
## A carried bar climbs paired notches; the kip and pull have separate charge clocks.
const RISE := 0.5
const RUNGS := 6
var bar: MeshInstance3D
var pull := 0.0
var kip := 0.0
var kip_age := 10.0
var kip_power := 0.0
var pulling := false
var kipping := false
var lift := 0.0
var from_height := 0.0
var bar_height := 2.5
const FLIGHT_SECONDS := 0.85
var target_rung := 0
var attempted_rung := 1
var peak_height := 2.5
var result_hold := 0.0
var last_success := false
var notches: Array[MeshInstance3D] = []
var notch_labels: Array[Label3D] = []
var attempt_label: Label3D
var idle_material: StandardMaterial3D
var target_material: StandardMaterial3D
var caught_material: StandardMaterial3D
var failed_material: StandardMaterial3D

func _init() -> void:
	title = "SALMON LADDER"
	subattribute = "core_strength"
	time_limit = 55.0
	xp_reward = 25
	hp_reward = 12.0
	zone = Rect2(-4, -16, 8, 20)

func _build_course() -> void:
	idle_material = lab.world_builder.material(Color("6c8298"))
	target_material = lab.world_builder.material(Color("ffce73"), true)
	caught_material = lab.world_builder.material(Color("65e5a0"), true)
	failed_material = lab.world_builder.material(Color("f07872"), true)
	for side in [-1.0, 1.0]:
		lab.world_builder.box(self, Vector3(0.16, 6, 0.22), anchor + Vector3(side, 3, -3), Color("4d6075"))
		for i in range(RUNGS + 1):
			var notch: MeshInstance3D = lab.world_builder.box(self, Vector3(0.3, 0.12, 0.5), anchor + Vector3(side, 2.395 + RISE * i, -2.85), Color("9bc4ff"))
			notches.append(notch)
	bar = lab.world_builder.box(self, Vector3(2.4, 0.09, 0.09), anchor + Vector3(0, 2.5, -2.7), Color("dddddd"))
	for i in range(RUNGS + 1):
		var label := Label3D.new()
		label.text = "%d / %.1f m" % [i, i * RISE]
		label.font_size = 24
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = anchor + Vector3(1.7, 2.5 + i * RISE, -2.7)
		add_child(label)
		notch_labels.append(label)
	attempt_label = Label3D.new()
	attempt_label.font_size = 25
	attempt_label.pixel_size = 0.007
	attempt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(attempt_label)
	_refresh_notches()
	lab.world_builder.world_label("HOLD CLICK TO KIP / RELEASE SPACE NEAR KIP PEAK", anchor + Vector3(0, 0.2, 2), 22, Color("9bc4ff"))

func core() -> float:
	return (preload("res://scripts/stat_tuning.gd").rating(lab.athlete.build, "core_strength") - 50.0) / 49.0

func attempt_quality(charge_value: float, age: float, power: float) -> float:
	var timing := maxf(0.0, 1.0 - absf(age - 0.25) / lerpf(0.25, 0.65, core()))
	return charge_value * 0.55 + power * timing * lerpf(0.6, 1.0, core())

func _begin_run() -> void:
	_reset_run()
	lab.player.position = anchor + Vector3(0, 0.3, -2.7)
	detail = "Hold Space to pull; hold/release click to kip, then release Space at the crunch peak"

func drill_input(event: InputEvent) -> bool:
	if not running(): return false
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.echo: return true
		pulling = event.pressed
		if not pulling: propel()
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		kipping = event.pressed
		if not kipping:
			kip_power = kip
			kip_age = 0.0
			kip = 0.0
		return true
	return event is InputEventMouseButton

func propel() -> void:
	if lift > 0.0 or result_hold > 0.15: return
	var quality := attempt_quality(pull, kip_age, kip_power)
	lab.athlete.spend_resolved(7.0 + pull * 4.0)
	pull = 0.0
	pulling = false
	from_height = bar_height
	last_success = quality >= 0.88 and lab.athlete.stamina > 0.0
	target_rung = mini(RUNGS, steps_done + (2 if quality > 1.35 else 1)) if last_success else steps_done
	attempted_rung = target_rung if last_success else mini(RUNGS, steps_done + 1)
	# Even failed attempts leave their notch, but cannot clear the next support.
	peak_height = 2.5 + target_rung * RISE + 0.18 if last_success else from_height + lerpf(0.08, RISE - 0.08, clampf(quality / 0.88, 0, 1))
	lift = FLIGHT_SECONDS
	bar.material_override = target_material
	detail = "Bar launched / clear notch %d" % attempted_rung
	_refresh_notches()
	lab._message(detail)

func _refresh_notches() -> void:
	for i in range(notches.size()):
		var rung := i % (RUNGS + 1)
		notches[i].material_override = caught_material if rung == steps_done else (target_material if rung == attempted_rung else idle_material)
	for i in range(notch_labels.size()):
		notch_labels[i].modulate = Color("65e5a0") if i == steps_done else (Color("ffce73") if i == attempted_rung else Color.WHITE)

func drill_motion(dt: float, _move: Vector3) -> bool:
	if not running() or not in_zone(): return false
	kip_age += dt
	result_hold = maxf(0.0, result_hold - dt)
	if pulling: pull = minf(1.0, pull + dt / 0.8)
	if kipping: kip = minf(1.0, kip + dt / 0.6)
	if pulling or kipping: lab.athlete.spend_resolved(dt * 2.0)
	else: lab.athlete.recover(dt, true)
	if lift > 0.0:
		lift = maxf(0.0, lift - dt)
		var flight := 1.0 - lift / FLIGHT_SECONDS
		var destination := 2.5 + target_rung * RISE
		# Launch, apex above the notch, then a visible downward catch.
		if flight < 0.55:
			bar_height = lerpf(from_height, peak_height, 1.0 - pow(1.0 - flight / 0.55, 2))
		else:
			bar_height = lerpf(peak_height, destination, pow((flight - 0.55) / 0.45, 2))
		bar.position.z = anchor.z - 2.7 + 0.22 * sin(flight * PI)
		if lift <= 0.0:
			steps_done = target_rung
			result_hold = 1.0
			bar.material_override = caught_material if last_success else failed_material
			detail = "CAUGHT NOTCH %d / +%.1f m" % [steps_done, destination - from_height] if last_success else "SHORT BY %.2f m / caught notch %d again" % [2.5 + attempted_rung * RISE - peak_height, steps_done]
			attempted_rung = mini(RUNGS, steps_done + 1)
			_refresh_notches()
			lab._message(detail)
	attempt_label.position = anchor + Vector3(-2.0, bar_height + 0.25, -2.7)
	attempt_label.text = "BAR +%.2f m / TARGET +%.2f m" % [bar_height - from_height, (attempted_rung * RISE + 2.5) - from_height] if lift > 0.0 else (detail if result_hold > 0.0 else "HANG / NOTCH %d" % steps_done)
	bar.position.y = anchor.y + bar_height
	lab.player.position = anchor + Vector3(0, bar_height - lab.athlete.reach(), -2.7)
	lab.player.velocity = Vector3.ZERO
	if steps_done == RUNGS and lift <= 0.0 and result_hold <= 0.0: _complete()
	return true

func apply_drill_pose() -> void:
	if not running(): return
	# Long backswing while charging, then a strong knee-to-chest snap at release.
	var pulse := maxf(0.0, sin(clampf(kip_age / 0.65, 0, 1) * PI)) * kip_power
	var backswing := kip * 0.65
	var launch := sin((1.0 - lift / FLIGHT_SECONDS) * PI) if lift > 0.0 else 0.0
	lab.body.rotation = Vector3(backswing * 0.3 - pulse * 0.4, 0, 0)
	lab.body.position = Vector3.ZERO
	for arm in lab.arms:
		arm.rotation = Vector3(PI - backswing * 0.45 + pulse * 0.35, 0, 0)
		arm.get_node("Elbow").rotation.x = -0.12 - pull * 0.35 - launch * 0.5
	for leg in lab.legs:
		leg.rotation.x = backswing - pulse * 2.1 + launch * 0.25
		leg.get_node("Knee").rotation.x = -pulse * 1.8 - backswing * 0.45
	# Anchor after the whole-body swing so the hands never detach from the bar.
	var hands: Vector3 = (lab.arms[0].get_node("Elbow/Wrist").global_position + lab.arms[1].get_node("Elbow/Wrist").global_position) * 0.5
	lab.body.position += lab.player.global_basis.inverse() * (bar.global_position - hands)

func _reset_run() -> void:
	if phase != Phase.COOLDOWN:
		steps_done = 0
		bar_height = 2.5
	pull = 0.0
	kip = 0.0
	kip_power = 0.0
	kip_age = 10.0
	pulling = false
	kipping = false
	lift = 0.0
	result_hold = 0.0
	target_rung = steps_done
	attempted_rung = mini(RUNGS, steps_done + 1)
	from_height = bar_height
	if is_instance_valid(bar):
		bar.position = anchor + Vector3(0, bar_height, -2.7)
		bar.material_override = caught_material
		_refresh_notches()
	if is_instance_valid(attempt_label): attempt_label.text = ""

func hud_text() -> String:
	if not running(): return super.hud_text()
	var cue := "KIP NOW" if kip_age > 0.8 else ("PULL NOW" if absf(kip_age - 0.25) < lerpf(0.12, 0.3, core()) else "KIP RISING / FALLING")
	return "SALMON LADDER / RUNG %d OF %d / I STOP\nSPACE PULL %.0f%% / CLICK KIP %.0f%% / %s\n%s" % [steps_done, RUNGS, pull * 100, kip * 100, cue, detail]
