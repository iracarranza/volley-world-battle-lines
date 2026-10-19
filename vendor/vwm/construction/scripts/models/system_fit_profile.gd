class_name SystemFitProfile
extends RefCounted

## A single "system fit" band for one player and one tactical quantity.
##
## Every profile answers the same three questions:
##   1. What value does this player naturally want? (`ideal_value`)
##   2. How much deviation can they absorb before it hurts? (`tolerance`)
##   3. Did they land inside the tight rhythm band? (`in_system_fraction`)
##
## The profile is intentionally unit-agnostic. Approach distance is measured in
## metres, set release in seconds, defensive depth in metres. Callers own the
## units; this model only owns the shape of the fit curve.
##
## Profiles are cached per player because they derive from career attributes and
## do not change during a rally. Transient state (fatigue, balance) is applied by
## the caller through `tolerance_scale` so the cache stays valid.

var key: StringName = &""
var ideal_value: float = 0.0
var tolerance: float = 1.0

## Fraction of `tolerance` that counts as fully "in system". Landing inside this
## band earns the discrete rhythm bonus on top of the continuous fit score.
var in_system_fraction: float = 0.25

## Multiplier applied by callers when the actor is in system. Kept modest: being
## on your mark should tilt marginal actions, not manufacture quality.
var in_system_bonus: float = 1.06

## Human-readable label for scouting screens and debug overlays.
var label: String = ""


static func create(
	profile_key: StringName,
	profile_ideal_value: float,
	profile_tolerance: float,
	profile_label: String = "",
	profile_in_system_fraction: float = 0.25,
	profile_in_system_bonus: float = 1.06,
) -> SystemFitProfile:
	var profile := SystemFitProfile.new()
	profile.key = profile_key
	profile.ideal_value = profile_ideal_value
	profile.tolerance = maxf(profile_tolerance, 0.001)
	profile.label = profile_label
	profile.in_system_fraction = clampf(profile_in_system_fraction, 0.05, 1.0)
	profile.in_system_bonus = maxf(profile_in_system_bonus, 1.0)
	return profile


## Signed distance from the player's preferred value. Negative means the actor
## undershot (too compact), positive means they overshot (too long).
func signed_deviation(actual_value: float) -> float:
	return actual_value - ideal_value


func deviation(actual_value: float) -> float:
	return absf(signed_deviation(actual_value))


func effective_tolerance(tolerance_scale: float = 1.0) -> float:
	return maxf(tolerance * maxf(tolerance_scale, 0.05), 0.001)


## Continuous 0-1 fit. 1.0 is exactly on the mark, 0.0 is a full tolerance band
## or more away from it.
func fit(actual_value: float, tolerance_scale: float = 1.0) -> float:
	return clampf(
		1.0 - deviation(actual_value) / effective_tolerance(tolerance_scale), 0.0, 1.0
	)


func is_in_system(actual_value: float, tolerance_scale: float = 1.0) -> bool:
	return deviation(actual_value) <= \
		effective_tolerance(tolerance_scale) * in_system_fraction


## Full evaluation bundle. Callers fold `fit` into their weighted quality score
## and multiply their result by `bonus_multiplier`.
func evaluate(actual_value: float, tolerance_scale: float = 1.0) -> Dictionary:
	var band := effective_tolerance(tolerance_scale)
	var raw_deviation := signed_deviation(actual_value)
	var in_system := absf(raw_deviation) <= band * in_system_fraction
	return {
		"key": key,
		"label": label,
		"ideal_value": ideal_value,
		"actual_value": actual_value,
		"tolerance": band,
		"signed_deviation": raw_deviation,
		"deviation": absf(raw_deviation),
		"fit": clampf(1.0 - absf(raw_deviation) / band, 0.0, 1.0),
		"in_system": in_system,
		"bonus_multiplier": in_system_bonus if in_system else 1.0,
		"undershot": raw_deviation < 0.0 and not in_system,
		"overshot": raw_deviation > 0.0 and not in_system,
	}


func to_dict() -> Dictionary:
	return {
		"key": String(key),
		"label": label,
		"ideal_value": ideal_value,
		"tolerance": tolerance,
		"in_system_fraction": in_system_fraction,
		"in_system_bonus": in_system_bonus,
	}
