extends RefCounted
## Auto is live preparation state. Confirmation never freezes its numeric value.
const Stats := preload("res://scripts/stat_tuning.gd")
const Isolation := preload("res://scripts/contact/set_isolation.gd")
const STANDARD_SET := 0.61
const Charge := preload("res://scripts/receive_charge.gd")
const SET_HANDLING_MARGIN := 0.075
var active := false
var action := 0
var prepared := 0.0
var age := 0.0
var seed := 0

func clear() -> void:
	active = false
	prepared = 0
	age = 0

func begin(action_type: int,response_seed: int) -> void:
	clear()
	active = true
	action = action_type
	seed = response_seed

static func receive_target(pressure: float,cushioning: float,available: float) -> float:
	return maxf(0,(pressure+Charge.ABOVE_LEEWAY*0.5-cushioning)/maxf(0.01,available))

func tick(dt: float,athlete: LabAthlete,shot: Dictionary,incoming: Vector3) -> void:
	if not active: return
	age += maxf(0,dt)
	var rating := athlete.stat("reaction_speed")
	var target := Stats.reaction_cap(rating)
	if action == 0:
		target = minf(target,receive_target(float(shot.get("charge",Isolation.pressure(shot,incoming))),athlete.cushioning_bonus(),athlete.low_stamina_factor()))
	elif action == 1:
		target = minf(target,(Isolation.effort(Isolation.pressure(shot,incoming))+SET_HANDLING_MARGIN)/maxf(0.01,athlete.low_stamina_factor()))
	prepared = move_toward(prepared,target,maxf(0,dt)*Stats.reaction_rate(rating))

func sample(athlete: LabAthlete,shot: Dictionary,incoming: Vector3) -> Dictionary:
	var rating := athlete.stat("reaction_speed")
	var cap := Stats.reaction_cap(rating)
	# Deterministic execution error: a systematic misjudgement that grows with incoming pace (faster balls are underestimated), never a roll.
	var error := -clampf((incoming.length()-18.0)/12.0,-1,1)*Stats.reaction_error(rating)
	var matched := clampf(prepared+error,0,cap)
	var output := STANDARD_SET if action == 1 else (cap if action in [2,3] else matched)
	return {"mode":"auto","action":action,"charge":output,"handling_charge":matched,"prepared":prepared,"age":age,"ceiling":cap,"reaction_speed":rating,"target_pressure":float(shot.get("charge",Isolation.pressure(shot,incoming))) if action == 0 else Isolation.pressure(shot,incoming),"error":error if action in [0,1] else 0.0}
