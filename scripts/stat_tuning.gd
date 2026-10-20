extends RefCounted
# Neutral band ends at 65. Within each band capability is unchanged.
const PARENTS := {"explosiveness":"power","jump_power":"power","swing_power":"power","acceleration":"speed","reaction_speed":"speed","transition_speed":"speed","ball_control":"accuracy","timing":"accuracy","stability":"accuracy","cushioning":"endurance","work_rate":"endurance","capacity":"endurance"}
static func tier(rating: float) -> int:
	if rating >= 99: return 5
	if rating >= 90: return 4
	if rating >= 80: return 3
	if rating >= 70: return 2
	if rating >= 66: return 1
	if rating >= 61: return 0
	if rating >= 56: return -1
	return -2
static func rating(build: Dictionary, name: String) -> float:
	var named: Dictionary = build.get("statistics",{})
	if named.has(name):
		return clampf(float(named[name]),50,99)
	var parent: String = PARENTS[name]
	var value := float(build.get(parent,65))
	# Runtime inputs use canonical named values. Bare comparison builds inherit
	# their parent rating; legacy offset interpretation belongs to Store.migrate.
	return clampf(value, 50, 99)

static func pace(rating: float) -> float:
	var band := tier(rating)
	return 0.70 if band == -2 else (0.90 if band == -1 else 1.0+0.08*band)
static func charge_multiplier(rating: float) -> float:
	var band := tier(rating)
	return 0.80 if band == -2 else (0.92 if band == -1 else 1.0+0.04*band)
static func capacity(rating: float) -> float:
	var band := tier(rating)
	return 70.0 if band == -2 else (90.0 if band == -1 else 100.0+10.0*band)
static func cushioning(rating: float) -> float:
	return 0.04*tier(rating)
static func work_penalty(rating: float) -> float:
	var band := tier(rating)
	return 1.50 if band == -2 else (1.15 if band == -1 else 1.0-0.15*band)
static func set_quality(quality: float, rating: float) -> float:
	var band := tier(rating)
	var penalty := 1.50 if band == -2 else (1.15 if band == -1 else 1.0-0.15*band)
	return clampf(1.0-(1.0-quality)*penalty,0,1)

static func anchor(rating: float) -> float:
	return [50.0,56.0,65.0,66.0,70.0,80.0,90.0,99.0][tier(rating)+2]

static func band_name(rating: float) -> String:
	var band := tier(rating)
	return "Harsh negative" if band == -2 else ("Negative" if band == -1 else ("Neutral" if band == 0 else "T%d"%band))

static func reaction_cap(rating: float) -> float:
	return [0.35,0.48,0.61,0.65,0.70,0.75,0.80,0.85][tier(rating)+2]

static func reaction_rate(rating: float) -> float:
	return [0.50,0.80,1.20,1.45,1.70,2.00,2.40,3.00][tier(rating)+2]

static func reaction_error(rating: float) -> float:
	return [0.16,0.11,0.075,0.060,0.045,0.030,0.018,0.010][tier(rating)+2]
