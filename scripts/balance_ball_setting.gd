extends "res://scripts/transition_set_drill.gd"
## Balance Ball Setting (Setup, Solo): the Transition Set's pass-and-set, but done standing on a wobbling balance ball, so Stability decides
## how hard it is to stay on the pad. Its reward is not decided yet; Stability is provisional.
const Progress := preload("res://scripts/workout_progress.gd")
const REWARD_SUBATTRIBUTE := "stability"
const PAD_RADIUS := 1.1
var wobble_time := 0.0
var last_growth: Dictionary = {}

func setup(host: Node3D, anchors: Dictionary = {}) -> void:
	super.setup(host, anchors)
	var pad: MeshInstance3D = lab.world_builder.ring(PAD_RADIUS, Color("c9b8ff"))
	pad.position = anchor + Vector3(0, 0.03, 0)
	lab.world_builder.world_label("BALANCE BALL SETTING / STAY ON THE PAD", anchor + Vector3(0, 0.2, 5.4), 24, Color("c9b8ff"))

func setup_name() -> String:
	return "BALANCE BALL SETTING"

func in_pad() -> bool:
	var p: Vector3 = lab.player.position - anchor
	return Vector2(p.x, p.z).length() <= PAD_RADIUS and lab.player.position.y < 0.5

func wobble_amplitude() -> float:
	var rating: float = preload("res://scripts/stat_tuning.gd").rating(lab.athlete.build, "stability")
	return lerpf(1.3, 0.35, clampf((rating - 50.0) / 49.0, 0.0, 1.0))

func tick(dt: float) -> void:
	super.tick(dt)
	if running() and in_pad() and lab.player.is_on_floor():
		wobble_time += dt
		var a := wobble_amplitude()
		lab.player.position.x += a * dt * sin(wobble_time * 2.3)
		lab.player.position.z += a * dt * cos(wobble_time * 1.7 + 0.6)
	elif not running():
		wobble_time = 0.0

func _spike_used(success: bool, actor: String, reason: String) -> void:
	var cooling_before: bool = distributor.cooldown > 0.0
	super._spike_used(success, actor, reason)
	if not cooling_before and distributor.cooldown > 0.0 and distributor.pile > 0:
		last_growth = Progress.record(lab.athlete, REWARD_SUBATTRIBUTE)

func hud_text() -> String:
	return "BALANCE BALL SETTING / %d OF %d\n%s" % [progress, PASSES_REQUIRED, detail]
