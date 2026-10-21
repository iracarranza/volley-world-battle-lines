extends RefCounted
## Read-only interface to creation-owned proportions. Distances are meters.
static func stride_ratio(build: Dictionary) -> float:
	return clampf(float(build.get("stride_ratio",1.0)),0.8,1.2)
static func wingspan_ratio(build: Dictionary) -> float:
	var height := maxf(0.01,float(build.get("height",1.86)))
	return clampf(float(build.get("wingspan_ratio",float(build.get("span",height))/height)),0.8,1.2)
static func leg_difference(build: Dictionary) -> float:
	return 0.43*float(build.get("height",1.86))*(stride_ratio(build)-1.0)
static func arm_difference(build: Dictionary) -> float:
	return float(build.get("height",1.86))*(wingspan_ratio(build)-1.0)*0.5
static func proportion_cost(ratio: float) -> float:
	var increments := (ratio-1.0)/0.04
	return increments*(1.0 if increments >= 0 else 1.5)
