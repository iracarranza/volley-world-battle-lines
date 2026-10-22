extends RefCounted
## Auxiliary access earned from Setups. A completed Setup adds a small amount of its auxiliary to the athlete's build (`drill_auxiliaries`), which
## Athlete.trait_effect reads alongside Traits. Grants do not cap (tuning only); the amounts are placeholders.
const KEYS := {
	"SPIKE TRAINER": "spike_velocity",
	"SERVE MACHINE": "platform_quality",
	"BALANCE BALL SETTING": "placement",
	"TRANSITION SET": "court_vision",
}
const AMOUNT := 1.0

static func key_for(setup_name: String) -> String:
	return String(KEYS.get(setup_name, ""))

# Returns {key, amount, total}, or an empty dictionary for a Setup with no grant.
static func grant(athlete: RefCounted, setup_name: String) -> Dictionary:
	var key := key_for(setup_name)
	if key == "":
		return {}
	if not athlete.build.has("drill_auxiliaries"):
		athlete.build["drill_auxiliaries"] = {}
	var total := float(athlete.build.drill_auxiliaries.get(key, 0.0)) + AMOUNT
	athlete.build.drill_auxiliaries[key] = total
	return {"key": key, "amount": AMOUNT, "total": total}
