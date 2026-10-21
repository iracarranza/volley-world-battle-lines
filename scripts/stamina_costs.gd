extends RefCounted
## Pure quotes. Discrete costs and rates deliberately have different units/floors.
const Morphology := preload("res://scripts/morphology_runtime.gd")
const Stats := preload("res://scripts/stat_tuning.gd")
static func height_band(height: float) -> int:
	var inches := roundi(height/0.0254)
	if inches <= 65: return -3
	if inches <= 68: return -2
	if inches <= 71: return -1
	if inches <= 74: return 0
	if inches <= 77: return 1
	if inches <= 80: return 2
	return 3
static func height_adjustment(height: float) -> float:
	var inches := roundi(height/0.0254)
	var band := height_band(height)
	if band < 0: return (72-inches)*[-1.0,-0.75,-0.625][band+3]
	if band > 0: return (inches-74)*[0.50,0.625,0.75][band-1]
	return 0.0
static func quote(kind: String,build: Dictionary,work_rate: float,efficiency: float,mismatch: float = 0.0,sourspot: float = 0.0) -> Dictionary:
	var height := float(build.get("height",1.86))
	var continuous := kind in ["movement","sprint","jump_charge"]
	var exempt := kind in ["timing_miss","drill_step","bound","split_step"]
	var base := 0.0
	var height_cost := 0.0
	var stride := 0.0
	var wingspan := 0.0
	var reduction := 0.0
	if continuous:
		base = 15.0 if kind == "sprint" else 3.0
		var band := height_band(height)
		height_cost = band*(0.25 if band < 0 else 0.50) if kind != "jump_charge" else 0.0
	else:
		match kind:
			"timing_miss": base = 2.0
			"drill_step": base = 3.0
			"bound", "split_step": base = 0.0
			"jump":
				base = 20.0
				height_cost = height_adjustment(height)
				stride = Morphology.proportion_cost(Morphology.stride_ratio(build))
			"contact", "serve":
				base = 15.0 if kind == "contact" else 4.0
				wingspan = Morphology.proportion_cost(Morphology.wingspan_ratio(build))
			"travel_jump":
				base = 5.0
				stride = Morphology.proportion_cost(Morphology.stride_ratio(build))
			"quick_step":
				base = 20.0*0.5
				height_cost = height_adjustment(height)*0.5
				stride = Morphology.proportion_cost(Morphology.stride_ratio(build))*0.5
		reduction = 0.0 if exempt else 2.0*clampi(Stats.tier(work_rate),0,5)
	var subtotal := maxf(0,base+height_cost+stride+wingspan+maxf(0,mismatch)+maxf(0,sourspot))
	var mitigated := subtotal*maxf(0.1,1.0-efficiency/100.0)
	var floor_value := 0.0 if continuous or exempt else 5.0
	var result := {"kind":kind,"units":"stamina/second" if continuous else "stamina","base":base,"height":height_cost,"stride":stride,"wingspan":wingspan,"mismatch":maxf(0,mismatch),"sourspot":maxf(0,sourspot),"subtotal":subtotal,"efficiency_percent":efficiency,"after_efficiency":mitigated,"work_rate":reduction,"floor":floor_value,"total":maxf(floor_value,mitigated-reduction)}
	result.make_read_only()
	return result
