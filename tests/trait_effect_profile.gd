extends SceneTree
## Warm-cache CPU microbenchmark; not an FPS or GPU measurement.
const Athlete = preload("res://scripts/athlete.gd")

func _initialize() -> void:
	var results := []
	for picks in [[], ["new_trait"], ["new_trait", "pow_tough_arms", "new_trait_3", "pow_heavy_arm", "pow_sledgehammer"]]:
		var athlete = Athlete.new()
		athlete.trait_ids.assign(picks)
		athlete.trait_via = {"new_trait_3": "new_trait"} if picks.size() > 1 else {}
		var expected: float = athlete.trait_effect("spike_velocity")
		var samples := []
		var checksum := 0.0
		for repeat in range(5):
			var start := Time.get_ticks_usec()
			for iteration in range(10000):
				checksum += athlete.trait_effect("spike_velocity")
			samples.append((Time.get_ticks_usec() - start) / 10000.0)
		results.append({"picks": picks.size(), "effect": expected, "checksum": checksum, "microseconds_per_call": samples})
	var file := FileAccess.open("res://artifacts/trait-effect-profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print(JSON.stringify(results))
	quit()
