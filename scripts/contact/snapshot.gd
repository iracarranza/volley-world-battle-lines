extends RefCounted
## Copy first: publishing must never freeze a caller's mutable working state.
static func freeze(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = freeze(value[key])
		result.make_read_only()
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(freeze(item))
		result.make_read_only()
		return result
	return value
