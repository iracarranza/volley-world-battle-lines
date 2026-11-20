extends "res://tests/support/test_case.gd"
## Contract: every ActionTable row equals what ContactResolver.assess returns for that action (SADR-15).
const Table := preload("res://scripts/action_table.gd")
const Resolver := preload("res://scripts/contact/contact_resolver.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const Execution := preload("res://scripts/contact_execution.gd")

func _initialize() -> void:
	call_deferred("run")

## A local point in the action's volume whose zone can be sweet, found by scanning the volume.
func sweet_point(lab: Node3D, action: int) -> Variant:
	var shape: Dictionary = lab._hurtbox_definition(action)
	for x in range(-10, 11):
		for y in range(-10, 11):
			for z in range(-10, 11):
				var point: Vector3 = Vector3(shape.center) + Vector3(x, y, z) * 0.08
				var spatial := Geometry.evaluate(shape, point)
				if spatial.hit and str(spatial.zone) in ["SWEET SPOT", "CLEAN"] and not bool(spatial.get("rescue_only", false)) and float(spatial.get("block_sweet_weight", 1.0)) > 0.8:
					return point
	return null

func assess(lab: Node3D, action: int, point: Vector3, age: float) -> Dictionary:
	var request = lab.contact_request(action)
	request.local_point = point
	request.remembered = false
	request.confirmation_age = age
	request.block_confirmation_age = age
	request.auto_charge = false
	request.incoming_shot = {}
	return Resolver.assess(request)

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await physics_frame
	for windup in [0.25, 0.4]:
		Execution.spike_windup_seconds = windup
		for action in range(3):
			var row := Table.row(action)
			var point = sweet_point(lab, action)
			check(point != null, "Action %d has a sweet-capable point" % action)
			if point == null:
				continue
			var sweet_ages: Array[float] = []
			var live_ages: Array[float] = []
			for step in range(0, 125):
				var age := step * 0.005
				var result := assess(lab, action, point, age)
				if bool(result.timing_assessment.sweet_eligible):
					sweet_ages.append(age)
				if str(result.zone) != "EXPIRED" and bool(result.hit):
					live_ages.append(age)
			check(not sweet_ages.is_empty() and not live_ages.is_empty(), "Action %d is sweet and live somewhere (windup %.2f)" % [action, windup])
			if sweet_ages.is_empty() or live_ages.is_empty():
				continue
			check(absf(sweet_ages[0] - float(row.sweet_start)) < 0.0051 and absf(sweet_ages[-1] - float(row.sweet_end)) < 0.0051, "Action %d sweet window %.3f-%.3f equals the resolver's %.3f-%.3f (windup %.2f)" % [action, row.sweet_start, row.sweet_end, sweet_ages[0], sweet_ages[-1], windup])
			check(absf(live_ages[0] - float(row.live_start)) < 0.0051 and absf(live_ages[-1] - float(row.live_end)) < 0.0051, "Action %d live window %.3f-%.3f equals the resolver's %.3f-%.3f (windup %.2f)" % [action, row.live_start, row.live_end, live_ages[0], live_ages[-1], windup])
	Execution.spike_windup_seconds = 0.25
	# Block: no age window, only the press pulse; the mirror must not invent a sweet window (FC-12).
	var block := Table.row(3)
	check(block.kind == "pulse" and block.sweet_start < 0 and block.sweet_end < 0, "The Block row has no age-based sweet window")
	var point = sweet_point(lab, 3)
	check(point != null, "Block has a sweet-capable point")
	if point != null:
		var fresh := assess(lab, 3, point, 0.0)
		var spent := assess(lab, 3, point, float(block.pulse_seconds))
		check(bool(fresh.timing_assessment.sweet_eligible) and not bool(spent.timing_assessment.sweet_eligible), "Block sweet follows the press pulse of %.2f s" % block.pulse_seconds)
		check(not bool(fresh.rescue) and not bool(spent.rescue), "Block never has an age-based rescue")
	print("ACTION TABLE: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
