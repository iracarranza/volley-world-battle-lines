extends "res://tests/support/test_case.gd"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for capacity in [65,99]:
		var athlete := LabAthlete.new()
		athlete.build = {"height":1.86,"span":1.86,"power":65,"speed":65,"accuracy":65,"endurance":capacity}
		athlete.gameplay_effects = {"second_wind":23}
		athlete.stamina = athlete.max_stamina()
		athlete.spend_resolved(athlete.stamina)
		check(athlete.winded and is_equal_approx(athlete.stamina,athlete.max_stamina()*0.5+23),"Winded grants half capacity plus flat twenty-three Second Wind at capacity %d"%capacity)
		athlete.spend_resolved(athlete.stamina)
		check(athlete.exhausted and athlete.stamina == 0,"Depleting restored stamina while Winded still causes Exhaustion")
		athlete.recover(7,false)
		check(athlete.winded and is_equal_approx(athlete.stamina,athlete.max_stamina()*0.5),"Exhaustion returns to fifty percent; Second Wind cooldown prevents a duplicate bonus")
		athlete.recover(30,false)
		athlete.spend_resolved(athlete.stamina)
		check(is_equal_approx(athlete.stamina,athlete.max_stamina()*0.5+23),"Second Wind becomes available again after cooldown")
	print("WINDED RESTORATION: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
