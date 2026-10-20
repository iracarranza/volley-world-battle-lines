extends RefCounted
## Point attribution only. Match scores and serving rotation are separate systems.
const HOME := 0
const AWAY := 1
var last_touch_side := -1
var last_result: Dictionary = {}
func begin(serving_side: int = -1) -> void:
	last_touch_side = serving_side
	last_result = {}
func touch(side: int) -> void:
	last_touch_side = side
func fault(side: int,reason: String) -> Dictionary:
	if side not in [HOME,AWAY]: return {"winner":-1,"loser":-1,"reason":reason,"last_touch_side":last_touch_side}
	return {"winner":1-side,"loser":side,"reason":reason,"last_touch_side":last_touch_side}
func landing(point: Vector3,center: Vector3,half_width: float,half_depth: float,radius: float) -> Dictionary:
	# A ball touching a boundary line is in.
	var inside := absf(point.x-center.x) <= half_width+radius and absf(point.z-center.z) <= half_depth+radius
	if not inside: return fault(last_touch_side,"OUT")
	return fault(HOME if point.z >= center.z else AWAY,"BALL DOWN")
func out() -> Dictionary:
	return fault(last_touch_side,"OUT")
func record(result: Dictionary) -> void:
	last_result = result.duplicate(true)
func label() -> String:
	return ("HOME" if int(last_result.winner) == HOME else "AWAY")+" POINT" if not last_result.is_empty() and int(last_result.winner) in [HOME,AWAY] else ""
