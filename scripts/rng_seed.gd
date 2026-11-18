extends RefCounted
## Seed hook for gameplay generators. Without a base seed each generator draws a
## fresh one, exactly as randomize() did; with one the stream is reproducible.
## Every seed used is logged so a rally can be replayed.
static var used: Array = []

## `generators` maps a label to its RandomNumberGenerator. Each gets base_seed + its index so the streams differ.
static func seed_generators(generators: Dictionary, base_seed: int = -1) -> void:
	var index := 0
	for label in generators:
		var generator: RandomNumberGenerator = generators[label]
		if base_seed < 0:
			generator.randomize()
		else:
			generator.seed = base_seed + index
		used.append({"label": label, "seed": generator.seed})
		print("RNG %s seed %d" % [label, generator.seed])
		index += 1
