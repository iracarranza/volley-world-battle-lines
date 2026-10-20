extends RefCounted
## One preparation per airborne episode; a press is not a second jump/charge.
var active := false
var used_confirmation := false
var confirmation_age := -1.0
var latched := false
func start() -> void:
	active = true
	used_confirmation = false
	confirmation_age = -1
	latched = false
func confirm(age: float = 0.0) -> bool:
	if used_confirmation: return false
	used_confirmation = true
	confirmation_age = maxf(0,age)
	return true
func tick(dt: float) -> void:
	if active and confirmation_age >= 0: confirmation_age += dt
func land() -> void:
	active = false
	latched = false
	confirmation_age = -1
