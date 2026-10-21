extends RefCounted
## Sub-attribute growth from Workouts. Every completion of a Workout counts toward its sub-attribute; enough completions raise that rating by
## one point (a "marginal" gain), and the higher the band the sub-attribute is already in, the more completions a point needs.
const Stats := preload("res://scripts/stat_tuning.gd")
# Completions per point, by band tier (-2 .. 5): the neutral band needs 3; higher bands need steadily more.
const NEEDED := {-2: 2, -1: 2, 0: 3, 1: 4, 2: 6, 3: 9, 4: 13, 5: 18}

static func needed(rating: float) -> int:
	return int(NEEDED.get(Stats.tier(rating), 3))

# Records one completion for `key` (a sub-attribute such as "explosiveness"). Returns {count, needed, gained, rating}.
static func record(athlete: RefCounted, key: String) -> Dictionary:
	var build: Dictionary = athlete.build
	if not build.has("workout_counts"):
		build["workout_counts"] = {}
	var rating := Stats.rating(build, key)
	var needs := needed(rating)
	var count := int(build.workout_counts.get(key, 0)) + 1
	var gained := false
	if count >= needs and rating < 99.0:
		count = 0
		gained = true
		if not build.has("statistics"):
			build["statistics"] = {}
		build.statistics[key] = rating + 1.0
		rating += 1.0
	build.workout_counts[key] = count
	return {"count": count, "needed": needs, "gained": gained, "rating": rating}
