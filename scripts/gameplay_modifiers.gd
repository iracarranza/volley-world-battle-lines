extends RefCounted
## Actor-local, replace-by-source runtime changes. Stored build ratings never change.
var entries: Dictionary = {}

func add(id: String,spec: Dictionary) -> void:
	entries[id] = spec.duplicate(true)

func clear() -> void:
	entries.clear()

func expire(event: String) -> void:
	for id in entries.keys():
		if str(entries[id].get("until","")) == event: entries.erase(id)

func tick(dt: float) -> void:
	for id in entries.keys():
		var entry: Dictionary = entries[id]
		if not entry.has("duration"): continue
		entry.duration = maxf(0,float(entry.duration)-maxf(0,dt))
		if entry.duration <= 0: entries.erase(id)

func total(section: String,key: String) -> float:
	var value := 0.0
	for entry in entries.values(): value += float(entry.get(section,{}).get(key,0))
	return value

func bands(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries.values():
		if entry.get("bands",{}).has(name): result.append(entry.bands[name])
	return result
