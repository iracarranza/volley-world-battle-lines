extends RefCounted
## Pick a visible open lane before the approach commits. No future motion/DI reads.
static func choose(origin: Vector3,center: Vector3,half_width: float,half_depth: float,blockers: Array,defenders: Array) -> Vector3:
	var side := -1.0 if origin.z > center.z else 1.0
	var best := center+Vector3(0,1,side*half_depth*0.7)
	var best_score := -INF
	var usable := maxf(0.2,half_width-0.65)
	for column in range(9):
		for depth in [0.55,0.72,0.88]:
			var target := center+Vector3(lerpf(-usable,usable,column/8.0),1,side*maxf(1,half_depth*depth-0.25))
			var crossing := origin.lerp(target,clampf((center.z-origin.z)/(target.z-origin.z),0,1))
			var clearance := 2.5
			for blocker in blockers:
				clearance = minf(clearance,absf(crossing.x-Vector3(blocker).x))
			var open_floor := half_width
			for defender in defenders:
				open_floor = minf(open_floor,Vector2(target.x-Vector3(defender).x,target.z-Vector3(defender).z).length())
			# Blocking lane matters most. Small centre/depth preferences keep ties stable.
			var score := clearance*3.0+open_floor*0.35-absf(target.x-center.x)*0.025-absf(depth-0.72)*0.05
			if score > best_score:
				best_score = score
				best = target
	return best
