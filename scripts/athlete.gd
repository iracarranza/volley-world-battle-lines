class_name LabAthlete
extends RefCounted

# Standing reach and stride originate in VWM. Other coefficients are prototype tuning.
const Store := preload("res://scripts/athlete_store.gd")
const Stats := preload("res://scripts/stat_tuning.gd")
const JUMP_HEIGHT_MULTIPLIER := 2.25
const BUILDS = [
	{"name": "BALANCED / OH", "height": 1.86, "span": 1.90, "power": 65.0, "speed": 65.0, "accuracy": 65.0, "endurance": 65.0},
	{"name": "REACH / MB", "height": 2.05, "span": 2.13, "power": 78.0, "speed": 48.0, "accuracy": 55.0, "endurance": 76.0},
	{"name": "CONTROL / S", "height": 1.83, "span": 1.86, "power": 48.0, "speed": 72.0, "accuracy": 88.0, "endurance": 58.0},
	{"name": "COVERAGE / L", "height": 1.67, "span": 1.70, "power": 44.0, "speed": 88.0, "accuracy": 72.0, "endurance": 78.0}
]
var build: Dictionary = BUILDS[0].duplicate()
var jump_power_bonus := 0.0
var second_wind_cooldown := 0.0
var _effect_key := ""
var _effects: Dictionary = {}
var flow := 0.0
var fatigue_epoch := 0
var hp := 100.0
var stamina := 100.0
var exhausted := false
var winded := false
var winded_remaining := 0.0
var exhaustion_remaining := 0.0
const WINDED_SECONDS := 10.5
const EXHAUSTION_SECONDS := 7.0
const WINDED_REGEN_FACTOR := 0.5
var traits: Array[String] = []
const POWER_SERVE_PER_CHARGE := 0.10
const QUICK_STEP_HP := 3.0
const ROLLING_RECEIVE_HP := 5.0

func stat(name: String) -> float:
	return clampf(Stats.rating(build,name)+(jump_power_bonus if name == "jump_power" else 0.0),50,99)

func trait_effect(name: String) -> float:
	var book = Store.trait_book()
	var key := str(traits)+str(book.get_instance_id())
	if key != _effect_key:
		_effect_key = key
		_effects.clear()
		for node in book.nodes:
			if str(node.name) in traits:
				for effect in node.get("effects",{}):
					_effects[effect] = float(_effects.get(effect,0))+float(node.effects[effect])
	return float(_effects.get(name,0))

func recovery_rate() -> float:
	return 1.0+trait_effect("recovery")/100.0

func effective_receive_charge(charge: float) -> float:
	return maxf(0,charge*low_stamina_factor()+cushioning_bonus())

func effective_serve_charge(charge: float) -> float:
	return maxf(0,charge*low_stamina_factor()+trait_effect("serve_velocity")/100.0)

func jump_output_factor() -> float:
	var threshold := trait_effect("jump_stamina_threshold")/100.0
	if threshold > 0 and stamina/max_stamina() > threshold:
		return 1.0
	return low_stamina_factor()

func explosiveness_rate() -> float:
	return Stats.pace(stat("explosiveness"))

func transition_rate() -> float:
	return Stats.pace(stat("transition_speed"))

func acceleration() -> float:
	return (10.0+65.0*0.15)*Stats.pace(stat("acceleration"))

func strafe_factor() -> float:
	return Stats.strafe_factor(stat("lateral_speed"))

func max_stamina() -> float:
	return Stats.capacity(stat("capacity"))

func cushioning_bonus() -> float:
	return Stats.cushioning(stat("cushioning"))

func effective_jump_charge(charge: float) -> float:
	return maxf(0,charge)*Stats.charge_multiplier(stat("jump_power"))

func effective_attack_charge(charge: float) -> float:
	return maxf(0,charge)*Stats.charge_multiplier(stat("swing_power"))+trait_effect("spike_velocity")/100.0

func jump_gravity(gravity: float, rising: bool) -> float:
	return gravity*pow(explosiveness_rate(),2) if rising else gravity

func jump_velocity(height: float, gravity: float) -> float:
	return sqrt(2.0*jump_gravity(gravity,true)*maxf(height,0))

func jump_flight_time(height: float, gravity: float) -> float:
	return sqrt(2.0*maxf(height,0)/jump_gravity(gravity,true))+sqrt(2.0*maxf(height,0)/gravity)

func low_stamina_factor() -> float:
	if exhausted:
		return 1.0 # Keep the existing explicit Exhausted penalties.
	var fraction := clampf(stamina/max_stamina(),0,1)
	var deficit := clampf((0.30-fraction)/0.30,0,1)
	return 1.0-0.20*deficit*Stats.work_penalty(stat("work_rate"))

func stabilize_set(assessment: Dictionary) -> Dictionary:
	var result := assessment.duplicate(true)
	result["geometry_quality"] = float(assessment.get("quality",1))
	result["quality"] = Stats.set_quality(float(assessment.get("quality",1)),stat("stability"))
	result["stability"] = stat("stability")
	return result

func has_trait(trait_name: String) -> bool:
	return trait_name in traits

func serve_speed_factor(charge: float) -> float:
	return (1.0+0.5*effective_serve_charge(charge))/maxf(0.1,1.0+0.5*charge)

func jump_stamina_cost() -> float:
	return 19.0 * (1.3 - 65.0 / 200.0) * float(build.height) / 1.86

func quick_step_stamina_cost() -> float:
	return jump_stamina_cost() * 0.5

func ball_control() -> float:
	return Stats.anchor(stat("ball_control"))

func timing() -> float:
	return Stats.anchor(stat("timing"))

func reach() -> float:
	return 1.215 * float(build.height) + 0.32 * (float(build.span) - float(build.height))

func stride() -> float:
	return clampf(0.43 * float(build.height), 0.55, 1.15)

func speed() -> float:
	return (3.6 + Stats.anchor(float(build.speed)) * 0.035) * stride() / 0.80 * (0.55 if exhausted else 1.0)

func leap(charge: float, approach: float, extra_jump_power: float = 0.0) -> float:
	return JUMP_HEIGHT_MULTIPLIER * (0.20 + 65.0 * 0.007) * lerpf(0.55, 1.0, maxf(charge,0)*Stats.charge_multiplier(clampf(stat("jump_power")+extra_jump_power,50,99))) * lerpf(0.78, 1.0, approach) * (0.65 if exhausted else 1.0) * jump_output_factor()

# The most an exploration (travel) jump can rise: a share of what this build's own standing leap is,
# and never more than EXPLORE_JUMP_CAP. An attack approach converts its run-up into height and clears this
# by a wide margin on every build, which is what lets some jumps require the approach.
const EXPLORE_JUMP_CAP := 1.6
const EXPLORE_JUMP_SHARE := 0.8
# This build's standing leap when fresh: the base the attack approach multiplies up and the exploration jump falls short of.
func fresh_leap() -> float:
	return JUMP_HEIGHT_MULTIPLIER * (0.20 + 65.0 * 0.007) * lerpf(0.55,1.0,effective_jump_charge(1.0))

func explore_jump_max() -> float:
	return minf(EXPLORE_JUMP_CAP, EXPLORE_JUMP_SHARE * fresh_leap()) * (0.65 if exhausted else 1.0)

# The jump factor an attack approach gives when Space is released at `charge` after a full run-up, and the charge that
# gives a wanted factor. A release at no charge is 0.6 of the standing leap and a full charge is 1.2.
static func attack_factor_at(charge: float) -> float:
	return ApproachRun.jump_factor(2, charge)

static func charge_for_factor(factor: float) -> float:
	var low := 0.0
	var high := ApproachRun.LAUNCH_START
	for step in range(30):
		var middle := (low + high) * 0.5
		if attack_factor_at(middle) < factor:
			low = middle
		else:
			high = middle
	return high

# What a clean full attack approach rises to, before the run-up's extra energy: the number ledge heights are built under.
func attack_jump_floor() -> float:
	return 1.2 * fresh_leap()

func spend(sta: float, hitting: float = 0.0) -> void:
	var before := stamina
	stamina = maxf(0.0, stamina - maxf(0, sta)*maxf(0.1,1.0-trait_effect("exertion_efficiency")/100.0))
	hp = maxf(0.0, hp - hitting * (1.5 if exhausted else 1.0))
	# Repeated costs at zero are not a second depletion event.
	if before > 0.0 and stamina <= 0.0 and not exhausted:
		if winded:
			flow = 0.0
			fatigue_epoch += 1
			exhausted = true
			exhaustion_remaining = EXHAUSTION_SECONDS
			winded = false
			winded_remaining = 0.0
		else:
			_enter_winded()

func _enter_winded() -> void:
	flow = 0.0
	fatigue_epoch += 1
	winded = true
	winded_remaining = WINDED_SECONDS
	if trait_effect("second_wind") > 0 and second_wind_cooldown <= 0:
		stamina = minf(max_stamina(),stamina+max_stamina()*trait_effect("second_wind")/100.0)
		second_wind_cooldown = 30.0

func reset_fatigue() -> void:
	second_wind_cooldown = 0.0
	jump_power_bonus = 0.0
	exhausted = false
	winded = false
	exhaustion_remaining = 0.0
	winded_remaining = 0.0

func fatigue_text() -> String:
	if exhausted:
		return "EXHAUSTED %.1fs" % exhaustion_remaining
	return "WINDED %.1fs" % winded_remaining if winded else ""

func recover(delta: float, resting: bool) -> void:
	second_wind_cooldown = maxf(0,second_wind_cooldown-delta)
	var remaining := maxf(0, delta)
	var rate := (9.0 if resting else 2.0)*(1.0+trait_effect("stamina_recovery")/100.0)
	if exhausted:
		stamina = 0.0
		var locked := minf(remaining, exhaustion_remaining)
		exhaustion_remaining = maxf(0, exhaustion_remaining - locked)
		remaining -= locked
		if exhaustion_remaining > 0.000001:
			return
		exhausted = false
		exhaustion_remaining = 0.0
		_enter_winded()
	if winded:
		var slowed := minf(remaining, winded_remaining)
		stamina = minf(max_stamina(), stamina + slowed * rate * WINDED_REGEN_FACTOR)
		winded_remaining = maxf(0, winded_remaining - slowed)
		remaining -= slowed
		if winded_remaining <= 0.000001:
			winded = false
			winded_remaining = 0.0
	stamina = minf(max_stamina(), stamina + remaining * rate)

func contact_cost(_action: int, _repeat: int) -> Vector2:
	# Ordinary volleyball contacts spend stamina. HP is reserved for abilities.
	return Vector2(8.0 * (1.25 - 65.0 / 200.0), 0.0)
